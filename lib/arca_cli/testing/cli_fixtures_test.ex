defmodule Arca.Cli.Testing.CliFixturesTest do
  import ExUnit.Assertions

  @moduledoc """
  Declarative, file-based testing framework for CLI commands.

  This module provides a powerful way to test CLI commands using fixture files.
  It automatically discovers test cases from your `test/cli/fixtures/` directory
  and generates individual ExUnit tests for each one.

  ## Quick Start

  1. Add `use Arca.Cli.Testing.CliFixturesTest` to a test file
  2. Create fixture directories under `test/cli/fixtures/`
  3. Run `mix test`

  ## Usage

      defmodule MyApp.CliFixturesTest do
        use ExUnit.Case, async: false
        use Arca.Cli.Testing.CliFixturesTest

        # Tests are automatically discovered and generated!
      end

  ## Directory Structure

  Fixtures are organized in a two-level hierarchy:

      test/cli/fixtures/
        <command.name>/              # e.g., "about", "config.set", "llm.chat"
          001/                       # Test variation (001-999)
            cmd.cli                  # REQUIRED: Command to test
            expected.out             # OPTIONAL: Expected output
            setup.cli                # OPTIONAL: Setup commands
            teardown.cli             # OPTIONAL: Cleanup commands
            skip                     # OPTIONAL: Skip this test
          002/
            ...

  ### File Types

  - **`cmd.cli`** (REQUIRED)
    - The command to test
    - Only this command's output is validated
    - Example: `config.get theme`

  - **`expected.out`** (OPTIONAL)
    - Expected output from cmd.cli
    - Supports pattern matching (see Pattern Syntax below)
    - If missing, test just verifies command runs without error
    - Example: `theme: dark`

  - **`setup.cli`** (OPTIONAL)
    - Commands to run before cmd.cli
    - Output is ignored (not validated)
    - Use for test data setup
    - Example: `config.set theme dark`

  - **`teardown.cli`** (OPTIONAL)
    - Commands to run after cmd.cli (even if it fails)
    - Output is ignored
    - Use for cleanup
    - Example: `config.reset`

  - **`skip`** (OPTIONAL)
    - Empty file that marks test as skipped
    - Test will show as "skipped" in test output
    - Useful for WIP or temporarily broken tests

  ### CLI File Format

  - One command per line
  - Blank lines are ignored
  - Lines starting with `#` are comments
  - Commands support quoted arguments: `cmd "arg with spaces"`

  ## Pattern Syntax

  The `expected.out` file supports pattern matching for dynamic content:

  ### Available Patterns

  - `{{*}}` - Non-greedy wildcard (matches any text, minimal)
  - `{{.*}}` - Greedy wildcard (matches any text, maximal)
  - `{{??}}` or `{{\d+}}` - Digits (one or more)
  - `{{\w+}}` - Word characters (letters, digits, underscore)

  ### Pattern Examples

      # Exact match (no patterns)
      Status: active
      Config loaded successfully

      # Match any provider name
      Provider: {{*}}
      Model: gpt-4

      # Match timestamps
      Created: {{\d+}}-{{\d+}}-{{\d+}}

      # Match IDs
      Agent ID: {{\w+}}

      # Match variable content with greedy wildcard
      Response: {{.*}}

  ### Pattern Matching Rules

  1. Patterns are anchored (must match entire output)
  2. Whitespace is normalized (multiple spaces/tabs → single space)
  3. Newlines are preserved
  4. If expected.out contains any `{{` sequence, pattern matching is used
  5. Otherwise, exact matching is used (with normalization)

  ## Complete Example

      # test/cli/fixtures/llm.chat/001/setup.cli
      config.reset
      llm.config.provider synthetic echo

      # test/cli/fixtures/llm.chat/001/cmd.cli
      llm.chat -s "Hello world"

      # test/cli/fixtures/llm.chat/001/expected.out
      Hello world

      # test/cli/fixtures/llm.chat/001/teardown.cli
      config.reset

  This creates a test named `llm.chat/001` that:
  1. Runs setup commands (resets config, sets provider)
  2. Runs the chat command
  3. Verifies output matches exactly
  4. Always runs teardown (even if test fails)

  ## Test Isolation

  Each test runs in a completely isolated environment:
  - Unique temporary config directory
  - Clean state (no shared data between tests)
  - Automatic cleanup after test completes

  ## Naming Conventions

  ### Command Names
  - Use dot notation for namespaced commands: `config.set`, `llm.chat`
  - Match your actual command structure

  ### Variation Numbers
  - Use 3-digit numbers: `001`, `002`, `099`
  - Numbers determine test execution order
  - Leave gaps for inserting tests later

  ## Tips & Best Practices

  ### When to Use Fixtures

  ✅ Good for:
  - Integration tests (full CLI stack)
  - Smoke tests (command runs without errors)
  - Output format validation
  - Regression tests (capture expected behavior)

  ❌ Not ideal for:
  - Unit tests (use regular ExUnit for those)
  - Tests requiring complex assertions
  - Tests with heavy mocking/stubbing

  ### Organizing Tests

  - One command per directory: `llm.chat/`, `config.set/`
  - Multiple variations per command: `001`, `002`, `003`
  - Use descriptive variation numbers:
    - `001` - Happy path
    - `002` - Error cases
    - `003` - Edge cases

  ### Pattern Matching

  - Use patterns for dynamic content (timestamps, IDs, etc.)
  - Use exact match when output is predictable
  - Start with exact match, add patterns as needed
  - Test your patterns (they're regexes!)

  ### Debugging Fixtures

  If a fixture test fails:
  1. Check the error message (shows expected vs actual)
  2. Run the command manually to see actual output
  3. Check for trailing whitespace issues
  4. Verify pattern syntax (escaped characters, etc.)

  ### Skip vs Delete

  - Use `skip` file to temporarily disable tests
  - Delete fixture directories to permanently remove tests
  - Commit `skip` files to track known issues

  ## Troubleshooting

  ### "Missing cmd.cli"
  - Every fixture variation needs a `cmd.cli` file
  - Check file name (lowercase, `.cli` extension)

  ### "Output mismatch"
  - Compare expected vs actual in error message
  - Check for whitespace differences
  - Try pattern matching for dynamic content
  - Verify output normalization isn't causing issues

  ### "Pattern doesn't match"
  - Test your regex pattern separately
  - Remember patterns are anchored (must match full output)
  - Check for special characters that need escaping

  ### Tests interfering with each other
  - Ensure `async: false` in your test module
  - Add proper teardown.cli to clean up state
  - Check that setup.cli creates isolated test data

  ## Advanced Usage

  ### Custom Test Setup

  You can add custom setup in your test module:

      defmodule MyApp.CliFixturesTest do
        use ExUnit.Case, async: false
        use Arca.Cli.Testing.CliFixturesTest

        setup do
          # Custom per-test setup
          :ok
        end
      end

  ### Accessing Helper Functions

  The following functions are available for custom tests:

  - `run_command/1` - Run a CLI command and capture output
  - `with_clean_config/1` - Run test with isolated config
  - `setup_test_env/0` - Initialize test environment
  """

  defmacro __using__(_opts) do
    # Discover fixtures at macro expansion time (not at the module's compile time)
    fixtures = discover_fixtures()

    # Generate test cases for each discovered fixture
    test_cases =
      for {command, variation, fixture_path} <- fixtures do
        skip_file = Path.join(fixture_path, "skip")

        if File.exists?(skip_file) do
          # Generate skipped test
          quote do
            @tag :skip
            test unquote("#{command}/#{variation}") do
              :ok
            end
          end
        else
          # Generate active test
          quote do
            test unquote("#{command}/#{variation}") do
              Arca.Cli.Testing.CliCommandHelper.with_clean_config(fn ->
                Arca.Cli.Testing.CliCommandHelper.setup_test_env()

                Arca.Cli.Testing.CliFixturesTest.run_fixture(
                  unquote(fixture_path),
                  unquote(command),
                  unquote(variation)
                )
              end)
            end
          end
        end
      end

    # Fallback test if no fixtures found
    fallback_test =
      if fixtures == [] do
        quote do
          test "fixture discovery" do
            fixtures_dir = Path.join(["test", "cli", "fixtures"])

            IO.puts("""

            ⚠️  No CLI fixtures found!

            To create fixture tests:
            1. Create directory: #{fixtures_dir}/<command>/001/
            2. Add file: cmd.cli (the command to test)
            3. Optionally add: expected.out, setup.cli, teardown.cli
            4. Run: mix test

            See Arca.Cli.Testing.CliFixturesTest moduledoc for details.
            """)

            # Don't fail - just inform
            assert true
          end
        end
      end

    # Combine imports and generated tests
    quote do
      import Arca.Cli.Testing.CliCommandHelper
      import Arca.Cli.Testing.CliFixturesTest

      unquote_splicing(test_cases)
      unquote(fallback_test)
    end
  end

  @doc """
  Discover all CLI fixtures from the test/cli/fixtures/ directory.

  This function is called at compile time to find all fixture test cases.

  ## Returns

  List of tuples: `[{command_name, variation, fixture_path}, ...]`

  ## Discovery Rules

  - Searches `test/cli/fixtures/` directory
  - First level: command names (any valid directory name)
  - Second level: 3-digit variations matching `~r/^\\d{3}$/`
  - Variations are sorted numerically

  ## Example

      discover_fixtures()
      #=> [
      #  {"about", "001", "test/cli/fixtures/about/001"},
      #  {"config.set", "001", "test/cli/fixtures/config.set/001"},
      #  {"config.set", "002", "test/cli/fixtures/config.set/002"}
      #]
  """
  def discover_fixtures do
    base_dir = Path.join(["test", "cli", "fixtures"])

    if File.dir?(base_dir) do
      base_dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(base_dir, &1)))
      |> Enum.flat_map(fn command_dir ->
        command_path = Path.join(base_dir, command_dir)

        command_path
        |> File.ls!()
        |> Enum.filter(&Regex.match?(~r/^\d{3}$/, &1))
        |> Enum.sort()
        |> Enum.map(fn variation ->
          {command_dir, variation, Path.join(command_path, variation)}
        end)
      end)
    else
      []
    end
  end

  @doc """
  Run a single fixture test.

  This function orchestrates the test lifecycle:
  1. Run setup.exs (if exists) → returns bindings
  2. Run setup.cli (if exists, with interpolation, output ignored)
  3. Run cmd.cli (with interpolation, output captured)
  4. Compare output with expected.out (with interpolation, if exists)
  5. Run teardown.cli (always, with interpolation, even on failure, output ignored)
  6. Run teardown.exs (always, with bindings, even on failure)

  ## Parameters

  - `fixture_path` - Path to fixture directory
  - `command` - Command name (for error messages)
  - `variation` - Variation number (for error messages)
  """
  def run_fixture(fixture_path, command, variation) do
    setup_file = Path.join(fixture_path, "setup.cli")
    cmd_file = Path.join(fixture_path, "cmd.cli")
    expected_file = Path.join(fixture_path, "expected.out")
    teardown_file = Path.join(fixture_path, "teardown.cli")

    # 1. Run setup.exs if exists → get bindings
    {:ok, bindings} = run_setup_script(fixture_path)

    try do
      # 2. Run setup.cli with interpolation (output ignored)
      if File.exists?(setup_file) do
        run_cli_file(setup_file, bindings)
      end

      # 3. Check that cmd.cli exists
      assert File.exists?(cmd_file),
             "Missing cmd.cli for #{command}/#{variation}"

      # 4. Run the actual command with interpolation - only this output is tested
      cmd_output = run_cli_file(cmd_file, bindings)

      # 5. Check expected output if file exists (with interpolation)
      if File.exists?(expected_file) do
        expected = File.read!(expected_file)
        compare_output(cmd_output, expected, "#{command}/#{variation}", bindings)
      else
        # If no expected.out, just ensure command runs without error
        assert is_binary(cmd_output),
               "Command should produce output for #{command}/#{variation}"
      end
    after
      # 6. Always run teardown.cli with interpolation (output ignored)
      if File.exists?(teardown_file) do
        run_cli_file(teardown_file, bindings)
      end

      # 7. Always run teardown.exs with bindings
      run_teardown_script(fixture_path, bindings)
    end
  end

  @doc """
  Run all commands in a .cli file and return combined output.

  ## CLI File Format

  - One command per line
  - Blank lines ignored
  - Lines starting with `#` are comments
  - Supports `{{variable}}` interpolation from bindings
  - Example:

        # Setup config
        config.reset
        config.set theme dark

        # Load data with interpolation
        data.load {{filename}}

  ## Parameters

  - `file_path` - Path to .cli file
  - `bindings` - Optional map of bindings for interpolation (default: `%{}`)

  ## Returns

  Combined output from all commands, joined with newlines.
  """
  def run_cli_file(file_path, bindings \\ %{}) do
    content = File.read!(file_path)

    # Interpolate bindings before parsing commands
    interpolated = interpolate_bindings(content, bindings)

    # Parse and run commands
    commands =
      interpolated
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))

    # Run all commands and collect output
    Enum.map_join(commands, "\n", &Arca.Cli.Testing.CliCommandHelper.run_command/1)
  end

  @doc """
  Compare actual output with expected output.

  Supports two modes:
  1. **Exact match** - if expected contains no patterns
  2. **Pattern match** - if expected contains `{{` patterns

  ## Parameters

  - `actual` - Actual output from command
  - `expected` - Expected output (may contain patterns and variables)
  - `test_name` - Name for error messages
  - `bindings` - Optional map of bindings for variable interpolation (default: `%{}`)

  ## Normalization

  Both actual and expected are normalized before comparison:
  - Leading/trailing whitespace trimmed
  - CRLF → LF conversion
  - Multiple spaces/tabs collapsed to single space
  - Newlines preserved
  """
  def compare_output(actual, expected, test_name, bindings \\ %{}) do
    # Interpolate bindings in expected output
    interpolated_expected = interpolate_bindings(expected, bindings)

    # Check if expected contains patterns (after interpolation)
    if String.contains?(interpolated_expected, "{{") do
      compare_with_patterns(actual, interpolated_expected, test_name)
    else
      # Exact match (with normalization)
      actual_normalized = normalize_output(actual)
      expected_normalized = normalize_output(interpolated_expected)

      if actual_normalized != expected_normalized do
        flunk("""
        Output mismatch for #{test_name}

        Expected:
        #{interpolated_expected}

        Actual:
        #{actual}
        """)
      end
    end
  end

  @doc """
  Compare output using pattern matching.

  Converts patterns in expected output to regex and matches against actual.

  ## Pattern Syntax

  - `{{*}}` → `.*?` (non-greedy wildcard)
  - `{{??}}` → `\\d+` (digits shorthand)
  - `{{\d+}}` → `\\d+` (explicit digits)
  - `{{\w+}}` → `\\w+` (word characters)
  - `{{.*}}` → `.*` (greedy wildcard)

  ## Example

      expected = "Status: {{*}}\\nID: {{\d+}}"
      actual = "Status: active\\nID: 12345"
      # Matches!

  """
  def compare_with_patterns(actual, expected, test_name) do
    # Normalize both actual and expected
    expected_normalized = normalize_output(expected)
    actual_normalized = normalize_output(actual)

    # Convert expected pattern to regex
    pattern =
      expected_normalized
      # Replace our patterns with placeholders BEFORE escaping
      |> String.replace("{{*}}", "<<<STAR>>>")
      |> String.replace("{{??}}", "<<<QUESTION>>>")
      # ~S is required: in a normal double-quoted string "\d" is the DEL escape and
      # "\w" silently drops the backslash, so both of these documented patterns
      # were being matched against keys no fixture file could ever contain.
      |> String.replace(~S"{{\d+}}", "<<<DIGIT>>>")
      |> String.replace(~S"{{\w+}}", "<<<WORD>>>")
      |> String.replace("{{.*}}", "<<<GREEDY>>>")
      # Now escape everything else
      |> Regex.escape()
      # Replace placeholders with actual regex patterns
      |> String.replace("<<<STAR>>>", ".*?")
      |> String.replace("<<<QUESTION>>>", "\\d+")
      |> String.replace("<<<DIGIT>>>", "\\d+")
      |> String.replace("<<<WORD>>>", "\\w+")
      |> String.replace("<<<GREEDY>>>", ".*")
      # Match entire string
      |> then(&("\\A" <> &1 <> "\\z"))

    case Regex.compile(pattern, "s") do
      {:ok, regex} ->
        unless Regex.match?(regex, actual_normalized) do
          flunk("""
          Output mismatch for #{test_name}

          Expected pattern:
          #{expected}

          Actual:
          #{actual}
          """)
        end

      {:error, _} ->
        flunk("Invalid pattern in expected.out for #{test_name}: #{expected}")
    end
  end

  @doc """
  Normalize output for comparison.

  Applies consistent formatting to both expected and actual output:
  - Trim leading/trailing whitespace
  - Convert CRLF to LF
  - Collapse multiple spaces/tabs to single space
  - Preserve newlines
  """
  def normalize_output(output) do
    output
    |> String.trim()
    |> String.replace(~r/\r\n/, "\n")
    # Only collapse spaces and tabs, not newlines
    |> String.replace(~r/[ \t]+/, " ")
  end

  @doc """
  Interpolate bindings into content containing {{key}} placeholders.

  Preserves pattern matchers like {{*}}, {{??}}, {{\d+}}, etc.

  ## Parameters

  - `content` - String with {{key}} placeholders
  - `bindings` - Map of values to interpolate

  ## Returns

  String with placeholders replaced

  ## Examples

      iex> interpolate_bindings("User: {{name}}", %{name: "Alice"})
      "User: Alice"

      iex> interpolate_bindings("ID: {{id}}", %{id: 42})
      "ID: 42"

      iex> interpolate_bindings("Status: {{*}}", %{})
      "Status: {{*}}"  # Pattern preserved

  """
  def interpolate_bindings(content, bindings) when bindings == %{} do
    # No bindings, return as-is (optimization)
    content
  end

  def interpolate_bindings(content, bindings) do
    # Pattern matchers to preserve (don't interpolate these)
    # These are literal strings that should be preserved exactly
    pattern_matchers = ["{{*}}", "{{??}}", "{{.*}}", "{{\\d+}}", "{{\\w+}}"]

    # Replace pattern matchers with placeholders
    {content_with_placeholders, replacements} = preserve_patterns(content, pattern_matchers)

    # Now interpolate variable bindings
    interpolated =
      Regex.replace(~r/\{\{([a-z_][a-z0-9_]*)\}\}/i, content_with_placeholders, fn _match, key ->
        atom_key = String.to_atom(key)

        case Map.fetch(bindings, atom_key) do
          {:ok, value} -> to_string(value)
          # Leave as-is if not found
          :error -> "{{#{key}}}"
        end
      end)

    # Restore pattern matchers
    restore_patterns(interpolated, replacements)
  end

  # Helper to preserve pattern matchers during interpolation
  defp preserve_patterns(content, patterns) do
    patterns
    |> Enum.with_index()
    |> Enum.reduce({content, %{}}, fn {pattern, idx}, {text, map} ->
      placeholder = "<<<PATTERN_#{idx}>>>"
      replaced = String.replace(text, pattern, placeholder)
      {replaced, Map.put(map, placeholder, pattern)}
    end)
  end

  defp restore_patterns(content, replacements) do
    Enum.reduce(replacements, content, fn {placeholder, original}, text ->
      String.replace(text, placeholder, original)
    end)
  end

  @doc """
  Run setup.exs script and return bindings for interpolation.

  This function evaluates a setup.exs file in the fixture directory and returns
  a map of bindings that can be used for interpolation in CLI commands and expected output.

  ## Parameters

  - `fixture_path` - Path to fixture directory

  ## Returns

  - `{:ok, %{}}` - Map of bindings (empty if no setup.exs exists)

  ## Raises

  - Raises if setup.exs returns a non-map value
  - Raises if setup.exs has syntax or runtime errors
  - Raises if not running in test environment

  ## Examples

      # No setup.exs file
      {:ok, bindings} = run_setup_script("/path/to/fixture")
      #=> {:ok, %{}}

      # With setup.exs returning bindings
      {:ok, bindings} = run_setup_script("/path/to/fixture")
      #=> {:ok, %{user_id: 42, api_key: "laksa_abc"}}

  """
  def run_setup_script(fixture_path) do
    setup_exs = Path.join(fixture_path, "setup.exs")

    if File.exists?(setup_exs) do
      # Verify we're in test environment for safety
      unless Mix.env() == :test do
        raise "setup.exs can only run in test environment, current environment: #{Mix.env()}"
      end

      code = File.read!(setup_exs)

      # Evaluate the script
      {result, _bindings} = Code.eval_string(code, [], file: setup_exs)

      # Validate result is a map
      unless is_map(result) do
        raise """
        setup.exs must return a map, got: #{inspect(result)}

        Example:
        %{user_id: 123, api_key: "laksa_abc"}
        """
      end

      {:ok, result}
    else
      {:ok, %{}}
    end
  end

  @doc """
  Run teardown.exs script with bindings from setup.

  This function evaluates a teardown.exs file with access to bindings from setup.exs.
  Errors are logged but do not fail the test (best-effort cleanup).

  ## Parameters

  - `fixture_path` - Path to fixture directory
  - `bindings` - Map of bindings from setup.exs

  ## Returns

  - `:ok` - Always succeeds (logs errors instead of raising)

  ## Examples

      run_teardown_script("/path/to/fixture", %{user_id: 42})
      #=> :ok

  """
  def run_teardown_script(fixture_path, bindings) do
    teardown_exs = Path.join(fixture_path, "teardown.exs")

    if File.exists?(teardown_exs) do
      code = File.read!(teardown_exs)

      try do
        Code.eval_string(code, [bindings: bindings], file: teardown_exs)
        :ok
      rescue
        e ->
          # Log but don't fail - teardown is best-effort
          IO.warn("""
          Teardown script failed: #{Exception.message(e)}
          File: #{teardown_exs}
          """)

          :ok
      end
    else
      :ok
    end
  end
end
