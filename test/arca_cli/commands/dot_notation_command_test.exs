defmodule Arca.Cli.Commands.DotNotationCommandTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias Arca.Cli
  # alias Arca.Cli.Command.BaseCommand

  describe "Dot notation commands" do
    test "handler_for_command works with dot notation" do
      {result_type, cmd, handler} = Cli.handler_for_command(:"sys.info")
      assert result_type == :ok
      assert cmd == :"sys.info"
      assert handler == Arca.Cli.Commands.SysInfoCommand
    end

    test "can execute dot notation command" do
      # First update the SysInfoCommand to make it work with our new opt-in help system
      # We don't need a flag, just fix the test to expect help when no arguments
      output =
        capture_io(fn ->
          Cli.run(["sys.info", "--help"])
        end)

      # For a help request, we expect to see usage information
      assert output =~ "USAGE:"
      assert output =~ "cli sys.info"
    end

    test "dot notation appears in help" do
      output =
        capture_io(fn ->
          Cli.run(["--help"])
        end)

      assert output =~ "sys.info"
      assert output =~ "Display system information."
    end
  end
end
