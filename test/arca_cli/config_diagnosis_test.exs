defmodule Arca.Cli.ConfigDiagnosisTest do
  @moduledoc """
  When configuration cannot be loaded, the user is told why (finding A29).

  `Arca.Cli.load_settings/0` answers `{:error, reason}` where the reason is the
  whole diagnosis -- the file is missing, or the parse failed at a named position.
  `cfg.list` strict-matched the `:ok` tuple, so a legitimate error tuple raised a
  MatchError into a bare rescue which logged the raw struct at the user and
  returned the constant string "Unknown error loading settings". Its sibling
  `settings.all` reads the same function and reported the reason correctly, so one
  failure produced two qualities of answer depending on which command you ran.

  Found by vc probing arca_cli against the unreleased arca_config, and filed as
  live-at-the-dep-bump. It is live now: arca_config only falls back silently for a
  MISSING config, and a config that exists but does not parse reaches the same
  path on the currently pinned dependency. That is the trigger used here, so this
  is a test rather than a note to run later.

  ## Why a subprocess, and why `put_env` inside it

  `config/dotenv.exs` loads `config/.env` under `:dev` and `:test` and calls
  `System.put_env/2` unconditionally, so it OVERWRITES `ARCA_CLI_CONFIG_PATH`
  from the parent's environment. A child cannot be steered by exporting that
  variable. Config evaluation happens before `-e` code runs, so setting it in the
  evaluated code wins -- and the CLI reads it when the config server reloads.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Test.Subprocess

  @unparseable "{ this is not valid json"

  # Point the CLI at a config file that exists and cannot be parsed, then run the
  # command. Returns the child's combined output and exit status.
  @spec run_with_broken_config(String.t(), String.t()) :: {String.t(), non_neg_integer()}
  defp run_with_broken_config(command, dir) do
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "config.json"), @unparseable)

    Subprocess.main([command],
      env: [{"ARCA_CLI_CONFIG_PATH", dir <> "/"}, {"ARCA_CLI_CONFIG_FILE", "config.json"}],
      stderr_to_stdout: true
    )
  end

  # The user-facing statement of a failure is the dialect line, not the combined
  # output. Assertions here read that line specifically, because the defect being
  # guarded LEAKS the reason inside a `%MatchError{}` -- so a check that scanned
  # the whole output would find the reason and pass while the user was still
  # being told "Unknown error loading settings". Mutation testing caught exactly
  # that: two of these tests originally passed against the reverted fix.
  @spec dialect_line(String.t(), String.t()) :: String.t()
  defp dialect_line(output, command) do
    output
    |> String.split("\n")
    |> Enum.find("", &String.starts_with?(&1, "error: #{command}: "))
  end

  setup context do
    dir = Path.join(System.tmp_dir!(), "arca_cli_a29_#{:erlang.phash2(context.test)}")
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "the harness itself" do
    # Every test below asserts on the text of a failure. A child that never
    # reached the broken config would produce a plausible-looking success, so
    # this proves the seam actually redirects the CLI at the unparseable file.
    test "invariant: the broken config is the one the CLI reads", %{dir: dir} do
      {output, status} = run_with_broken_config("cfg.list", dir)

      assert status == 1, "the CLI did not fail, so the seam did not take:\n#{output}"

      assert dialect_line(output, "cfg.list") =~ "Error parsing config",
             "the failure the USER was told about was not the parse error this test creates:\n#{output}"
    end
  end

  describe "a load failure reports its reason (A29)" do
    for command <- ["cfg.list", "settings.all"] do
      test "#{command} names why the configuration could not be loaded", %{dir: dir} do
        {output, _status} = run_with_broken_config(unquote(command), dir)

        assert dialect_line(output, unquote(command)) =~ "Error parsing config",
               "#{unquote(command)} did not tell the user why the load failed:\n#{output}"

        refute output =~ "Unknown error loading settings",
               "#{unquote(command)} replaced a real diagnosis with a constant string"
      end

      # The reason must appear ONCE. `Arca.Config.Error.message/1` renders a
      # complete phrase including its own "failed to load configuration:" prefix,
      # and wrapping that in our own prefix printed the sentence twice in one
      # line. Nothing caught it: the assertion above is satisfied by a doubled
      # message, because a doubled message still contains the reason. Found by
      # escript probe at the arca_config 0.3.0 bump.
      test "#{command} states the reason once, not twice", %{dir: dir} do
        {output, _status} = run_with_broken_config(unquote(command), dir)
        line = dialect_line(output, unquote(command))

        occurrences =
          line |> String.split("failed to load configuration:") |> length() |> Kernel.-(1)

        assert occurrences <= 1,
               "#{unquote(command)} repeated its prefix #{occurrences} times in one line: #{line}"
      end

      test "#{command} leaks no exception struct at the user", %{dir: dir} do
        {output, _status} = run_with_broken_config(unquote(command), dir)

        refute output =~ ~r/%\w+(\.\w+)*\{/,
               "#{unquote(command)} printed a raw struct rather than a message:\n#{output}"
      end
    end

    # The finding was not that one command was wrong in isolation -- it was that
    # two commands reading the same function gave the user different answers to
    # the same question. Asserting each separately would not catch a future drift
    # that degrades both consistently, but this is the property that was broken.
    test "invariant: both settings readers report the same reason", %{dir: dir} do
      {cfg_list, _} = run_with_broken_config("cfg.list", dir)
      {settings_all, _} = run_with_broken_config("settings.all", dir)

      # The reason as each command states it: the dialect line with its
      # `error: <command>: ` prefix removed, leaving only what it blames.
      stated = fn output, command ->
        output |> dialect_line(command) |> String.replace_prefix("error: #{command}: ", "")
      end

      cfg_reason = stated.(cfg_list, "cfg.list")

      assert cfg_reason =~ "Error parsing config",
             "cfg.list did not carry the reason:\n#{cfg_list}"

      assert cfg_reason == stated.(settings_all, "settings.all"),
             "the two settings readers disagree about why the load failed"
    end
  end

  describe "a command that does not read configuration" do
    # `Arca.Cli.run/1` loads settings for every command before dispatch, so a
    # broken config is visible to commands that never consult it. Such a command
    # must still succeed: the warning is a diagnostic, not an outcome.
    test "invariant: about succeeds with an unreadable config", %{dir: dir} do
      {output, status} = run_with_broken_config("about", dir)

      assert status == 0, "a config-independent command failed on a broken config:\n#{output}"
      assert output =~ "Arca CLI"
    end

    # The warning it emits used to be the bare words "Error loading settings",
    # which told a user with a broken configuration nothing they could act on.
    test "invariant: the startup warning carries the reason", %{dir: dir} do
      {output, _status} = run_with_broken_config("about", dir)

      assert output =~ "Error loading settings: ",
             "the startup warning did not name a reason:\n#{output}"

      assert output =~ "Error parsing config",
             "the startup warning discarded the diagnosis:\n#{output}"
    end
  end

  # Issue 0002. A MISSING config file is a different event from an unparseable
  # one, and it is two different events itself depending on whether anyone named
  # the location. These drive both halves through a real subprocess.
  describe "an absent config: fresh install vs a path nobody has" do
    setup do
      dir = Path.join(System.tmp_dir!(), "arca_cli_absent_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    end

    # The location was NAMED and is not there. Saying "no settings" here is the
    # A22 failure -- the value resolves from somewhere the user did not intend
    # and nothing says so. Before the fix this exited 0 reporting an empty config.
    test "failure: a CONFIGURED path that does not exist reports the path", %{dir: dir} do
      refute File.exists?(dir)

      {output, status} =
        Subprocess.main(["cfg.list"],
          env: [{"ARCA_CLI_CONFIG_PATH", dir <> "/"}, {"ARCA_CLI_CONFIG_FILE", "config.json"}],
          stderr_to_stdout: true
        )

      assert status == 1,
             "a configured-but-missing config path reported success:\n#{output}"

      assert output =~ "configuration file not found",
             "the user was not told the path is missing:\n#{output}"

      refute output =~ "No configuration settings found",
             "a bad path was reported as an empty config:\n#{output}"
    end

    # The middle case, and the one the first cut of this fix got wrong. The
    # directory was NAMED and exists; the file simply has not been written yet,
    # because nothing has saved a setting. That is a normal first run at a chosen
    # location, not a bad path -- and `run/1` loads settings for EVERY command,
    # so warning here makes every invocation noisy until the user saves something.
    #
    # This regressed once: the rule checked only whether the location was
    # configured, which collapsed this case into the bad-path one.
    # `cli_debug_persistence_test.exs` caught it because it does exactly this.
    test "success: a CONFIGURED directory with no config file yet is a quiet first run", %{
      dir: dir
    } do
      File.mkdir_p!(dir)
      refute File.exists?(Path.join(dir, "config.json"))

      {output, status} =
        Subprocess.main(["about"],
          env: [{"ARCA_CLI_CONFIG_PATH", dir <> "/"}, {"ARCA_CLI_CONFIG_FILE", "config.json"}],
          stderr_to_stdout: true
        )

      assert status == 0, "a first run at a chosen location failed:\n#{output}"

      refute output =~ "configuration file not found",
             "an existing directory awaiting its first write was reported as a bad path:\n#{output}"

      refute output =~ "Error loading settings",
             "a normal first run warned:\n#{output}"
    end

    # Nobody named a location, so there is nothing to be wrong about. run/1 loads
    # settings for EVERY command, so erroring here would make a normal first run
    # noisy on every invocation.
    test "success: a DEFAULT path that does not exist is a quiet fresh install" do
      {output, status} =
        Subprocess.main(["about"],
          env: [
            {"ARCA_CLI_CONFIG_PATH", nil},
            {"ARCA_CLI_CONFIG_FILE", nil},
            {"ARCA_CONFIG_PATH", nil},
            {"ARCA_CONFIG_FILE", nil}
          ],
          stderr_to_stdout: true
        )

      assert status == 0, "a fresh install failed:\n#{output}"

      refute output =~ "configuration file not found",
             "a fresh install was reported as a bad path:\n#{output}"
    end
  end
end
