defmodule Arca.Cli.Test do
  use ExUnit.Case

  # Read from the single source so a version bump does not break these assertions.
  @version File.read!("VERSION") |> String.trim()

  import ExUnit.CaptureIO
  alias Arca.Cli
  alias Arca.Cli.Test.Support
  doctest Arca.Cli

  @cli_commands [
    ["about"],
    ["settings.get", "id"],
    ["help", "settings.all"],
    ["cli.history"],
    ["cli.redo", "0"],
    ["sys.flush"],
    # ["repl"], # doesn't work as a test as it is interactive
    ["settings.all"],
    ["cli.status"],
    ["--version"],
    ["--help"]
  ]

  describe "Arca.Cli" do
    # Config isolation for the whole run is set up in test_helper.exs, which
    # points Arca.Config at a private directory before any test starts.
    #
    # What used to be here looked like it did that job and did not. It set
    # `ARCA_CONFIG_PATH`, but `Arca.Config.Cfg.config_pathname/0` resolves the
    # app-specific `ARCA_CLI_CONFIG_PATH` first and `config/.env` sets it, so the
    # generic variable never won and the directory it created was never read.
    # Its cleanup could not undo itself either: restoring by writing back a
    # captured environment map cannot remove a variable that was previously
    # unset, so both variables leaked into every later test and subprocess.
    setup do
      Support.ensure_history_started()
      :ok
    end

    test "cli commands smoke test" do
      # Run through each command (except 'repl') and smoke test each one
      Enum.each(@cli_commands, fn cmd ->
        # Smoke testing command: #{Enum.join(cmd, " ")}

        capture_io(fn ->
          try do
            Cli.run(cmd)
            assert true
          rescue
            e in RuntimeError ->
              IO.puts("error: " <> e.message)
              assert false
          end
        end)
      end)
    end

    test "about" do
      assert capture_io(fn ->
               Arca.Cli.run(["about"])
             end)
             |> String.trim() ==
               """
               📦 Arca CLI
               A declarative CLI for Elixir apps
               https://arca.io
               arca_cli #{@version}
               """
               |> String.trim()
    end

    test "settings.all reports the settings actually in force" do
      # Seeded through the same path a user writes settings by, so a pass means
      # the command read the real configuration. The previous version of this
      # test accepted any of three different outputs, including a fabricated
      # test-only table, so it passed whether or not the command worked.
      Cli.save_settings(%{"probe_setting" => "probe_value"})
      on_exit(fn -> Support.restore_setting("probe_setting", nil) end)

      output =
        capture_io(fn ->
          Arca.Cli.run(["settings.all"])
        end)
        |> String.trim()

      assert output =~ "Current Configuration Settings"
      assert output =~ "probe_setting"
      assert output =~ "probe_value"
      refute output =~ "Test Configuration"
    end

    test "settings.get" do
      assert capture_io(fn ->
               Arca.Cli.run(["settings.get"])
             end)
             |> String.trim() ==
               """
               error: settings.get: missing required arguments: SETTING_ID
               """
               |> String.trim()
    end

    test "settings.get id" do
      # `id` is seeded for the whole run, so put it back rather than leaving this
      # test's value behind for whatever reads it next.
      original = Support.setting_value("id")
      Arca.Cli.save_settings(%{"id" => "TEST_ID_VALUE"})
      on_exit(fn -> Support.restore_setting("id", original) end)

      assert capture_io(fn ->
               Arca.Cli.run(["settings.get", "id"])
             end)
             |> String.trim() == "TEST_ID_VALUE"
    end

    test "help" do
      assert capture_io(fn ->
               Arca.Cli.run(["help"])
             end)
             |> String.trim() ==
               """
               error: invalid subcommand:
               """
               |> String.trim()
    end

    test "help settings.all" do
      assert capture_io(fn ->
               Arca.Cli.run(["help", "settings.all"])
             end)
             |> String.trim() ==
               """
               Display current configuration settings.

               USAGE:
                   cli settings.all
               """
               |> String.trim()
    end

    test "--help" do
      # Instead of having a fixed expected output that can become outdated,
      # we'll verify that the help output contains our key commands
      required_commands = [
        "about",
        "cli.history",
        "cli.redo",
        "cli.status",
        # "repl" is hidden now, so we don't expect it in help
        "settings.all",
        "settings.get",
        "sys.cmd",
        "sys.flush",
        "sys.info"
      ]

      # Also check for help text format
      required_headers = [
        "USAGE:",
        "SUBCOMMANDS:"
      ]

      actual_output =
        capture_io(fn ->
          Arca.Cli.run(["--help"])
        end)
        |> String.trim()

      # Check that all required headers are present
      Enum.each(required_headers, fn header ->
        assert String.contains?(actual_output, header), "Help output should contain '#{header}'"
      end)

      # Check that all required commands are listed
      Enum.each(required_commands, fn cmd ->
        assert String.contains?(actual_output, cmd),
               "Help output should list the '#{cmd}' command"
      end)

      # Make sure the output is in the expected format with the proper structure
      assert String.match?(actual_output, ~r/USAGE:.*SUBCOMMANDS:/s),
             "Help output should have proper structure"
    end

    test "cli.redo out of range" do
      assert capture_io(fn ->
               Arca.Cli.run(["cli.redo", "999"])
             end)
             |> String.trim() ==
               "error: cli.redo: no command at history index 999"
    end
  end
end
