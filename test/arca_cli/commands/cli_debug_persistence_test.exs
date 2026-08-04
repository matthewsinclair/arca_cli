defmodule Arca.Cli.Commands.CliDebugPersistenceTest do
  @moduledoc """
  Covers `cli.debug` persistence (finding A9).

  `cli.debug on` wrote `debug_mode` to the settings file and to the application
  environment of the process that was, moments later, about to exit. Nothing read
  the file back at startup. Every consumer of debug mode -- the error formatter
  and two REPL paths -- reads the application environment, so the next invocation
  saw `false` again.

  What made this hard to spot is that `cli.debug` reported the setting from disk
  rather than the value in force, so a later invocation cheerfully answered
  "Debug mode is currently ON" while formatting errors as though it were off. The
  display and the behaviour were reading different variables.

  The escript tests are the ones that matter: the defect is a process-boundary
  defect, and it cannot be reproduced inside a single VM.
  """
  use ExUnit.Case, async: false

  @escript "_build/escript/arca_cli"

  setup do
    original = Application.get_env(:arca_cli, :debug_mode, false)
    on_exit(fn -> Application.put_env(:arca_cli, :debug_mode, original) end)

    {:ok, escript: Path.expand(@escript), built?: File.exists?(@escript)}
  end

  # Run the escript in its own directory so it reads and writes its own settings
  # file, leaving the repository's tracked config alone.
  defp in_clean_cli(escript, argv_list) do
    dir = Path.join(System.tmp_dir!(), "arca_debug_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      Enum.map(argv_list, fn argv ->
        {output, status} = System.cmd(escript, argv, cd: dir, stderr_to_stdout: true)
        {String.trim(output), status}
      end)
    after
      File.rm_rf!(dir)
    end
  end

  defp run_when_built(%{built?: false}, _assertions) do
    IO.puts("\n  (skipped: #{@escript} not built -- run `mix escript.build`)")
  end

  defp run_when_built(%{built?: true, escript: escript}, assertions), do: assertions.(escript)

  describe "apply_persisted_settings/1" do
    test "success: a persisted debug_mode takes effect in the application environment" do
      Application.put_env(:arca_cli, :debug_mode, false)

      Arca.Cli.apply_persisted_settings(%{"debug_mode" => true})

      assert Application.get_env(:arca_cli, :debug_mode) == true
    end

    test "success: an absent setting leaves the application environment alone" do
      Application.put_env(:arca_cli, :debug_mode, true)

      Arca.Cli.apply_persisted_settings(%{"something_else" => "value"})

      assert Application.get_env(:arca_cli, :debug_mode) == true
    end

    test "invariant: settings outside the mapping cannot write application environment" do
      Arca.Cli.apply_persisted_settings(%{"configurators" => "hijacked"})

      refute Application.get_env(:arca_cli, :configurators) == "hijacked"
    end
  end

  describe "cli.debug reports the value in force" do
    test "success: it reads the application environment, not the file" do
      Application.put_env(:arca_cli, :debug_mode, true)

      output = Arca.Cli.Commands.CliDebugCommand.handle(%{args: %{toggle: nil}}, %{}, nil)

      assert output == "Debug mode is currently ON"
    end

    test "failure: an unrecognised toggle is rejected" do
      assert {:error, :invalid_argument, message} =
               Arca.Cli.Commands.CliDebugCommand.handle(%{args: %{toggle: "maybe"}}, %{}, nil)

      assert message =~ "maybe"
    end
  end

  describe "debug mode survives a process boundary" do
    test "success: a later invocation reports the setting an earlier one made", context do
      run_when_built(context, fn escript ->
        [_on, later] = in_clean_cli(escript, [["cli.debug", "on"], ["cli.debug"]])

        assert later == {"Debug mode is currently ON", 0}
      end)
    end

    test "success: turning it off again survives too", context do
      run_when_built(context, fn escript ->
        [_on, _off, later] =
          in_clean_cli(escript, [["cli.debug", "on"], ["cli.debug", "off"], ["cli.debug"]])

        assert later == {"Debug mode is currently OFF", 0}
      end)
    end

    test "success: a later invocation actually shows debug detail on an error", context do
      run_when_built(context, fn escript ->
        [_on, {with_debug, _}] =
          in_clean_cli(escript, [["cli.debug", "on"], ["cli.error", "raise"]])

        [{without_debug, _}] = in_clean_cli(escript, [["cli.error", "raise"]])

        assert with_debug =~ "Debug Information"
        refute without_debug =~ "Debug Information"
      end)
    end

    test "invariant: a fresh install starts with debug off", context do
      run_when_built(context, fn escript ->
        [first] = in_clean_cli(escript, [["cli.debug"]])

        assert first == {"Debug mode is currently OFF", 0}
      end)
    end
  end
end
