defmodule Arca.Cli.Commands.FlushCommandTest do
  use ExUnit.Case
  # import ExUnit.CaptureIO
  alias Arca.Cli.Commands.FlushCommand
  alias Arca.Cli.Test.Support
  doctest Arca.Cli.Commands.FlushCommand

  describe ".Commands.AboutCommand" do
    setup do
      # Ensure the History GenServer is running for tests that will use it
      Support.ensure_history_started()

      :ok
    end

    test "success: config/0 declares the flush command" do
      assert FlushCommand.config() == [
               flush: [
                 name: "flush",
                 about: "Flush the command history."
               ]
             ]
    end

    test "success: handle/3 flushes history and returns ok" do
      assert FlushCommand.handle(nil, nil, nil) == "ok"
    end
  end
end
