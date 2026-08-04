defmodule Arca.Cli.Testing.CliCommandHelper do
  @moduledoc """
  Helper functions for testing CLI commands in applications built with Arca.Cli.

  This module is part of Arca.Cli's comprehensive testing framework for CLI applications.
  It provides low-level utilities for running commands, managing test isolation, and
  verifying behavior. These helpers power the declarative fixture testing framework
  (`Arca.Cli.Testing.CliFixturesTest`) and can also be used directly for custom tests.

  ## Overview

  Arca.Cli provides two complementary approaches to testing CLI commands:

  ### 1. Declarative Fixture Testing (Recommended)

  Use `Arca.Cli.Testing.CliFixturesTest` for most CLI testing:
  - Create test cases as files in `test/cli/fixtures/<command>/<variation>/`
  - Tests are automatically discovered and generated
  - Supports setup/teardown, pattern matching, and output validation
  - See `Arca.Cli.Testing.CliFixturesTest` for full documentation

  ### 2. Custom Testing with Helpers (This Module)

  Use `CliCommandHelper` directly when you need:
  - Complex assertions beyond simple output matching
  - Programmatic test generation
  - Custom test logic or workflows
  - Integration with other testing patterns

  ## Core Capabilities

  This module provides three essential functions:

  ### 1. Command Execution (`run_command/1`)

  Runs commands through the full CLI stack and captures output:

      output = run_command("config.set theme dark")
      assert output =~ "Theme updated"

  - Parses arguments correctly (handles quotes, options, etc.)
  - Sets `ARCA_STYLE=plain` for consistent, testable output
  - Captures both stdout and stderr
  - Executes through `Arca.Cli.run/1` (full integration testing, without halting)

  ### 2. Test Isolation (`with_clean_config/1`)

  Ensures complete isolation between tests:

      with_clean_config(fn ->
        setup_test_env()
        # Changes here won't affect other tests
        run_command("config.set foo bar")
        assert run_command("config.get foo") =~ "bar"
      end)

  Each test gets:
  - Unique temporary config directory
  - Clean state (no leftover data from other tests)
  - Automatic cleanup (temp files deleted after test)
  - Original config restored

  ### 3. Environment Setup (`setup_test_env/0`)

  Initializes required processes:

      setup_test_env()
      # Now Arca.Config.Server is ready

  Called automatically by fixture tests, manually in custom tests.

  ## Usage Patterns

  ### Pattern 1: Simple Command Testing

  For basic "run command, check output" tests:

      import Arca.Cli.Testing.CliCommandHelper

      test "about command shows version" do
        with_clean_config(fn ->
          setup_test_env()
          output = run_command("about")
          assert output =~ "arca_cli"
          version = Application.spec(:arca_cli, :vsn) |> to_string()
          assert output =~ version
        end)
      end

  ### Pattern 2: Multi-Step Workflows

  For testing command sequences:

      test "config workflow" do
        with_clean_config(fn ->
          setup_test_env()

          # Step 1: Set config
          output1 = run_command("config.set theme dark")
          assert output1 =~ "saved"

          # Step 2: Verify it persisted
          output2 = run_command("config.get theme")
          assert output2 =~ "dark"

          # Step 3: Change it
          output3 = run_command("config.set theme light")
          assert output3 =~ "saved"

          # Step 4: Verify the change
          output4 = run_command("config.get theme")
          assert output4 =~ "light"
        end)
      end

  ### Pattern 3: State-Dependent Testing

  For commands that depend on previous state:

      test "history tracking" do
        with_clean_config(fn ->
          setup_test_env()

          # Build up state
          run_command("about")
          run_command("status")
          run_command("config.get theme")

          # Verify state
          history = run_command("cli.history")
          assert history =~ "about"
          assert history =~ "status"
          assert history =~ "config.get"
        end)
      end

  ### Pattern 4: Error Testing

  For testing error conditions and edge cases:

      test "invalid command shows error" do
        with_clean_config(fn ->
          setup_test_env()
          output = run_command("nonexistent.command")
          assert output =~ "Unknown command"
        end)
      end

      test "missing required argument" do
        with_clean_config(fn ->
          setup_test_env()
          output = run_command("config.set")
          assert output =~ "required"
        end)
      end

  ### Pattern 5: Custom Assertions

  For complex validation logic:

      test "llm models returns valid JSON structure" do
        with_clean_config(fn ->
          setup_test_env()
          output = run_command("llm.models --format json")

          # Parse and validate JSON structure
          {:ok, data} = Jason.decode(output)
          assert is_map(data)
          assert Map.has_key?(data, "providers")
          assert is_list(data["providers"])

          # Validate each provider
          for provider <- data["providers"] do
            assert Map.has_key?(provider, "name")
            assert Map.has_key?(provider, "models")
            assert is_list(provider["models"])
          end
        end)
      end

  ## Integration with Fixture Tests

  When you use `use Arca.Cli.Testing.CliFixturesTest`, it automatically:
  - Imports this module's functions
  - Wraps each fixture test with `with_clean_config/1`
  - Calls `setup_test_env/0` before running fixtures
  - Uses `run_command/1` to execute commands from `.cli` files

  You can combine both approaches:

      defmodule MyApp.CliTest do
        use ExUnit.Case, async: false
        use Arca.Cli.Testing.CliFixturesTest

        # Fixture tests are auto-generated from test/cli/fixtures/

        # Custom tests using helpers directly
        test "custom validation logic" do
          with_clean_config(fn ->
            setup_test_env()
            # Your custom test code here
          end)
        end
      end

  ## Test Isolation Details

  ### Why Isolation Matters

  Without isolation, tests can:
  - Share configuration state (test A's changes affect test B)
  - Have unpredictable order-dependent failures
  - Leave artifacts that affect subsequent test runs
  - Interfere with your real application config

  ### How Isolation Works

  `with_clean_config/1` creates a bubble for each test:

  1. **Before test**: Creates `/tmp/.arca_test_<pid>_<unique_id>/`
  2. **During test**: All config operations use this directory
  3. **After test**: Restores previous config, deletes temp directory

  This ensures:
  - Tests can run in any order
  - Tests can run in parallel (if marked `async: true`)
  - No cleanup code needed in tests
  - No risk of corrupting real config

  ### Config Initialization

  By default, each test gets minimal config:

      %{
        "global" => %{
          "context" => %{
            "ux" => %{
              "spinners" => "off"  # Cleaner test output
            }
          }
        }
      }

  You can modify config during tests:

      with_clean_config(fn ->
        setup_test_env()
        run_command("config.set custom.key value")
        # Changes only affect this test
      end)

  ## Best Practices

  ### DO: Use Test Isolation

  ✅ Always wrap tests in `with_clean_config/1`:

      test "my test" do
        with_clean_config(fn ->
          setup_test_env()
          # test code
        end)
      end

  ### DO: Call setup_test_env/0

  ✅ Initialize the environment before testing:

      with_clean_config(fn ->
        setup_test_env()  # Starts Arca.Config.Server
        run_command("...")
      end)

  ### DO: Test Real CLI Behavior

  ✅ Use `run_command/1` for integration tests:

      # Tests the full stack: parsing, dispatch, execution
      output = run_command("config.set theme dark")

  ### DON'T: Call Module Functions Directly

  ❌ Avoid bypassing the CLI layer:

      # Don't do this in CLI tests:
      MyApp.Commands.ConfigSet.handle(...)

      # Do this instead:
      run_command("config.set theme dark")

  ### DON'T: Share State Between Tests

  ❌ Don't rely on test execution order:

      # Bad: depends on previous test
      test "get config" do
        assert run_command("config.get theme") =~ "dark"
      end

      # Good: sets up own state
      test "get config" do
        with_clean_config(fn ->
          setup_test_env()
          run_command("config.set theme dark")
          assert run_command("config.get theme") =~ "dark"
        end)
      end

  ### DON'T: Mix Testing Approaches

  ❌ Don't mix unit and integration testing:

      # Unit test - test the function
      test "parse_args handles quotes" do
        assert Parser.parse_args("cmd \"arg\"") == ["cmd", "arg"]
      end

      # Integration test - test the CLI
      test "command accepts quoted args" do
        with_clean_config(fn ->
          setup_test_env()
          run_command("cmd \"arg with spaces\"")
        end)
      end

  ## Debugging Tests

  ### Enable Debug Output

  Set debug mode in your test:

      test "my test" do
        Application.put_env(:arca_cli, :debug_mode, true)

        with_clean_config(fn ->
          setup_test_env()
          output = run_command("...")
          IO.inspect(output, label: "Command output")
        end)
      end

  ### Check Temp Directory

  To see what's in the temp config:

      with_clean_config(fn ->
        setup_test_env()

        # Get temp directory path
        {:ok, config} = Arca.Config.get_config_location()
        IO.inspect(config, label: "Config location")

        # Run your test
        run_command("...")
      end)

  ### Verify Command Output

  Run commands manually to see actual output:

      $ ARCA_STYLE=plain mix run -e 'Arca.Cli.main(["about"])'

  ## See Also

  - `Arca.Cli.Testing.CliFixturesTest` - Declarative fixture testing framework
  - `Arca.Cli` - Main CLI module
  - `Arca.Config` - Configuration management

  ## Examples from Arca.Cli Test Suite

  See `test/arca_cli/cli/fixtures/` for example fixture tests, including:
  - `about/001/` - Simple output validation
  - `cli.history/001/` - Setup/teardown lifecycle
  - `cli.status/001/` - Pattern matching for dynamic content
  """

  import ExUnit.CaptureIO

  @doc """
  Run a CLI command and capture its output.

  Executes the command through the full CLI stack (parsing, dispatch, execution)
  and returns the captured output as a string.

  ## Parameters

  - `command_string` - The command to run, as a string (e.g., "status --verbose")

  ## Returns

  The captured output as a string.

  ## Examples

      iex> run_command("about")
      "📦 Arca CLI...\\n"

      iex> run_command("history --limit 5")
      "0: about\\n1: status\\n..."

  ## Notes

  - Sets `ARCA_STYLE=plain` for consistent output formatting
  - Restores original style setting after execution
  - Uses `OptionParser.split/1` to handle quoted arguments correctly
  """
  @spec run_command(String.t()) :: String.t()
  def run_command(command_string) when is_binary(command_string) do
    args = OptionParser.split(command_string)

    # Ensure we're in test mode for plain output
    original_style = System.get_env("ARCA_STYLE")
    System.put_env("ARCA_STYLE", "plain")

    output =
      capture_io(fn ->
        # Run the command through the CLI. run/1 rather than main/1: this runs
        # inside the test VM, and main/1 halts it on failure.
        Arca.Cli.run(args)
      end)

    # Restore original style
    if original_style do
      System.put_env("ARCA_STYLE", original_style)
    else
      System.delete_env("ARCA_STYLE")
    end

    output
  end

  @doc """
  Run a test with a clean configuration environment.

  Creates a unique temporary config directory for this test, switches to it,
  runs the test function, and cleans up afterward. This ensures complete test
  isolation - no test can affect another test's configuration.

  ## Parameters

  - `fun` - A zero-arity function containing the test code

  ## Returns

  The return value of the test function.

  ## Example

      test "isolated config test" do
        with_clean_config(fn ->
          setup_test_env()
          # Your test code here
          # Config changes won't affect other tests
          run_command("config.set foo bar")
          assert run_command("config.get foo") =~ "bar"
        end)
      end

  ## How It Works

  1. Creates unique temp directory: `/tmp/.arca_test_<pid>_<unique_id>`
  2. Writes minimal test config with spinners disabled
  3. Switches Arca.Config to use temp location
  4. Runs your test function
  5. Restores previous config location
  6. Deletes temp directory

  ## Configuration

  By default, creates a minimal config with:
  - Spinners: off (for cleaner test output)

  You can modify this by updating the config after calling `setup_test_env/0`.
  """
  @spec with_clean_config(function()) :: any()
  def with_clean_config(fun) when is_function(fun, 0) do
    # Create unique temp config directory for this test
    test_id = System.unique_integer([:positive])
    temp_dir = System.tmp_dir!()
    config_path = Path.join(temp_dir, ".arca_test_#{:os.getpid()}_#{test_id}")
    File.mkdir_p!(config_path)

    # Write test config with spinners disabled for cleaner output
    config_file = Path.join(config_path, "test_config.json")

    test_config = %{
      "global" => %{
        "context" => %{
          "ux" => %{
            "spinners" => "off"
          }
        }
      }
    }

    File.write!(config_file, Jason.encode!(test_config))

    # Switch to test-specific config location
    {:ok, previous} =
      Arca.Config.switch_config_location(
        path: config_path,
        file: "test_config.json"
      )

    try do
      fun.()
    after
      # Restore previous config location
      Arca.Config.switch_config_location(previous)

      # Clean up temp directory
      File.rm_rf!(config_path)
    end
  end

  @doc """
  Set up a test environment with all necessary processes started.

  Ensures that the Arca.Config server is running and ready for tests.
  Call this at the beginning of tests that need config access.

  ## Example

      test "my test" do
        with_clean_config(fn ->
          setup_test_env()
          # Now you can safely run commands
          output = run_command("about")
          assert output =~ "Arca"
        end)
      end

  ## What It Does

  - Checks if Arca.Config.Server is running
  - Starts it if needed
  - Returns `:ok` when ready

  ## Notes

  This function is automatically called by the CLI fixtures test framework,
  so you typically only need to call it manually when writing custom tests.
  """
  @spec setup_test_env() :: :ok
  def setup_test_env do
    # Ensure Arca.Config is ready
    case Process.whereis(Arca.Config.Server) do
      nil ->
        {:ok, _} = Arca.Config.Server.start_link([])

      _pid ->
        :ok
    end

    # Ensure History GenServer is ready and flushed for clean test state
    case Process.whereis(Arca.Cli.History) do
      nil ->
        {:ok, _} = Arca.Cli.History.start_link()
        :ok

      _pid ->
        # History exists, flush it for clean test state
        Arca.Cli.History.flush_history()
        :ok
    end

    :ok
  end
end
