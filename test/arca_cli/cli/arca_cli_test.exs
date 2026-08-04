defmodule Arca.Cli.Test do
  use ExUnit.Case
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
    setup do
      # Get previous env var for config path and file names
      previous_env = System.get_env()

      # Set up to use a test-specific config file in the local directory
      test_config_path = "./.arca_test"
      test_config_file = "arca_cli_test.json"

      System.put_env("ARCA_CONFIG_PATH", test_config_path)
      System.put_env("ARCA_CONFIG_FILE", test_config_file)

      # Write a known config file to a known location
      config_file_path = Path.join(test_config_path, test_config_file)
      File.mkdir_p!(test_config_path)
      File.write!(config_file_path, Jason.encode!(%{}, pretty: true))

      # Ensure History GenServer is started
      Support.ensure_history_started()

      # Clean up on exit
      on_exit(fn ->
        # Delete test config file
        File.rm(config_file_path)
        # Delete test config directory
        File.rmdir(test_config_path)
        # Restore environment variables
        System.put_env(previous_env)
      end)

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
               arca_cli 0.1.0
               """
               |> String.trim()
    end

    test "settings.all" do
      # Check that the output is properly formatted as a table
      output =
        capture_io(fn ->
          Arca.Cli.run(["settings.all"])
        end)
        |> String.trim()

      # In test mode, should show "Test Configuration" with a simple table
      # The output will be in plain mode (no ANSI) in test environment
      assert String.contains?(output, "Test Configuration") or
               String.contains?(output, "Current Configuration Settings") or
               String.contains?(output, "No settings available")

      # Should contain table structure (either actual table or message)
      assert String.contains?(output, "Setting") or
               String.contains?(output, "No settings")
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
      # For this test, we need to set up a known setting first
      # Create the test config with a known value for "id"
      Arca.Cli.save_settings(%{"id" => "TEST_ID_VALUE"})

      # Now verify we can read it back
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
               "error: invalid command index: 999"
    end
  end
end
