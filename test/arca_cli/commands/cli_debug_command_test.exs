defmodule Arca.Cli.Commands.CliDebugCommandTest do
  use ExUnit.Case, async: false
  alias Arca.Cli.Commands.CliDebugCommand
  alias Arca.Cli.Test.Support

  # Since we're modifying application configuration, we can't run tests in parallel

  setup do
    # Store the original debug mode settings (Application env + Arca.Config)
    original_app_setting = Application.get_env(:arca_cli, :debug_mode)
    original_config_setting = Support.setting_value("debug_mode")

    # Restore both after each test
    on_exit(fn ->
      Support.restore_app_env(:arca_cli, :debug_mode, original_app_setting)
      Support.restore_setting("debug_mode", original_config_setting)
    end)

    :ok
  end

  describe "config/0" do
    test "returns the expected command configuration" do
      [{command, options}] = CliDebugCommand.config()

      assert command == :"cli.debug"
      assert options[:name] == "cli.debug"
      assert options[:about] =~ "debug mode"

      # Verify args configuration
      assert Keyword.has_key?(options, :args)
      args = options[:args]
      assert Keyword.has_key?(args, :toggle)
      assert args[:toggle][:required] == false
    end
  end

  describe "handle/3" do
    test "shows current debug mode status when no toggle is provided" do
      # Test with debug mode OFF
      Application.put_env(:arca_cli, :debug_mode, false)
      Arca.Cli.save_settings(%{"debug_mode" => false})
      args = %{args: %{toggle: nil}}
      result = CliDebugCommand.handle(args, %{}, nil)

      assert result == "Debug mode is currently OFF"

      # Test with debug mode ON
      Application.put_env(:arca_cli, :debug_mode, true)
      Arca.Cli.save_settings(%{"debug_mode" => true})
      args = %{args: %{toggle: nil}}
      result = CliDebugCommand.handle(args, %{}, nil)

      assert result == "Debug mode is currently ON"
    end

    test "enables debug mode with 'on' argument" do
      # Start with debug mode off
      Application.put_env(:arca_cli, :debug_mode, false)
      Arca.Cli.save_settings(%{"debug_mode" => false})

      args = %{args: %{toggle: "on"}}
      result = CliDebugCommand.handle(args, %{}, nil)

      assert result == "Debug mode is now ON"
      assert Application.get_env(:arca_cli, :debug_mode) == true

      # The setting was persisted to Arca.Config
      assert Arca.Cli.get_setting("debug_mode") == {:ok, true}
    end

    test "disables debug mode with 'off' argument" do
      # Start with debug mode on
      Application.put_env(:arca_cli, :debug_mode, true)
      Arca.Cli.save_settings(%{"debug_mode" => true})

      args = %{args: %{toggle: "off"}}
      result = CliDebugCommand.handle(args, %{}, nil)

      assert result == "Debug mode is now OFF"
      assert Application.get_env(:arca_cli, :debug_mode) == false

      # The setting was persisted to Arca.Config
      assert Arca.Cli.get_setting("debug_mode") == {:ok, false}
    end

    test "returns error with invalid argument" do
      args = %{args: %{toggle: "invalid"}}
      result = CliDebugCommand.handle(args, %{}, nil)

      assert match?({:error, :invalid_argument, _}, result)
      assert elem(result, 2) =~ "Invalid value 'invalid'. Use 'on' or 'off'."
    end

    test "can toggle debug mode multiple times" do
      # Start with debug mode off
      Application.put_env(:arca_cli, :debug_mode, false)
      Arca.Cli.save_settings(%{"debug_mode" => false})

      # Turn on
      args_on = %{args: %{toggle: "on"}}
      result1 = CliDebugCommand.handle(args_on, %{}, nil)
      assert result1 == "Debug mode is now ON"
      assert Application.get_env(:arca_cli, :debug_mode) == true

      # Check persistent storage
      {:ok, setting1} = Arca.Cli.get_setting("debug_mode")
      assert setting1 == true

      # Turn off
      args_off = %{args: %{toggle: "off"}}
      result2 = CliDebugCommand.handle(args_off, %{}, nil)
      assert result2 == "Debug mode is now OFF"
      assert Application.get_env(:arca_cli, :debug_mode) == false

      # Check persistent storage
      {:ok, setting2} = Arca.Cli.get_setting("debug_mode")
      assert setting2 == false

      # Turn on again
      result3 = CliDebugCommand.handle(args_on, %{}, nil)
      assert result3 == "Debug mode is now ON"
      assert Application.get_env(:arca_cli, :debug_mode) == true

      # Check persistent storage
      {:ok, setting3} = Arca.Cli.get_setting("debug_mode")
      assert setting3 == true
    end
  end
end
