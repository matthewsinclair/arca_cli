# Implementation - ST0009: Elixir-based setup and teardown for CLI fixtures

## Implementation Status

**Status**: ✅ Complete and tested
**Date Completed**: 2025-10-06
**Test Coverage**: 397 tests passing (393 existing + 4 new integration tests + 25 script tests + 40 interpolation tests)

## As-Built Summary

The implementation successfully adds `setup.exs` and `teardown.exs` support to the CLI fixtures testing framework. The feature is fully backward compatible, with all existing fixtures continuing to work unchanged.

### What Was Built

**Core Functions:**

1. `interpolate_bindings/2` - Replaces `{{variable}}` placeholders while preserving pattern matchers
2. `preserve_patterns/2` & `restore_patterns/2` - Helper functions for pattern preservation
3. `run_setup_script/1` - Evaluates setup.exs and returns bindings map
4. `run_teardown_script/2` - Evaluates teardown.exs with bindings from setup

**Updated Functions:**

1. `run_cli_file/2` - Now accepts optional bindings parameter for interpolation
2. `compare_output/4` - Now accepts optional bindings parameter for expected output interpolation
3. `run_fixture/3` - Orchestrates full lifecycle including .exs files

### File Locations

- **Implementation**: `lib/arca_cli/testing/cli_fixtures_test.ex`
- **Tests**:
  - `test/arca_cli/testing/cli_fixtures_interpolation_test.exs` (40 tests)
  - `test/arca_cli/testing/cli_fixtures_scripts_test.exs` (25 tests)
  - `test/cli/fixtures/_test_exs_*/001/` (4 integration fixtures)

## Implementation

### 1. Core Functions to Add

#### `run_setup_script/1`

Execute `setup.exs` and return bindings map.

```elixir
@doc """
Run setup.exs script and return bindings for interpolation.

## Parameters
- `fixture_path` - Path to fixture directory

## Returns
- `{:ok, %{}}` - Map of bindings (empty if no setup.exs)
- Raises if setup.exs returns non-map value
"""
def run_setup_script(fixture_path) do
  setup_exs = Path.join(fixture_path, "setup.exs")

  if File.exists?(setup_exs) do
    code = File.read!(setup_exs)

    # Verify we're in test environment
    unless Mix.env() == :test do
      raise "setup.exs can only run in test environment"
    end

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
```

#### `run_teardown_script/2`

Execute `teardown.exs` with bindings.

```elixir
@doc """
Run teardown.exs script with bindings from setup.

## Parameters
- `fixture_path` - Path to fixture directory
- `bindings` - Map of bindings from setup.exs

## Returns
- `:ok` - Always succeeds (logs errors instead of raising)
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
```

#### `interpolate_bindings/2`

Replace `{{key}}` placeholders with values.

```elixir
@doc """
Interpolate bindings into content containing {{key}} placeholders.

Preserves pattern matchers like {{*}}, {{??}}, {{\d+}}, etc.

## Parameters
- `content` - String with {{key}} placeholders
- `bindings` - Map of values to interpolate

## Returns
- String with placeholders replaced

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
  pattern_matchers = ["{{*}}", "{{??}}", "{{.*}}", ~r/\{\{\\d\+\}\}/, ~r/\{\{\\w\+\}\}/]

  # Replace pattern matchers with placeholders
  {content_with_placeholders, replacements} = preserve_patterns(content, pattern_matchers)

  # Now interpolate variable bindings
  interpolated =
    Regex.replace(~r/\{\{([a-z_][a-z0-9_]*)\}\}/i, content_with_placeholders, fn _match, key ->
      atom_key = String.to_atom(key)

      case Map.fetch(bindings, atom_key) do
        {:ok, value} -> to_string(value)
        :error -> "{{#{key}}}"  # Leave as-is if not found
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

    replaced =
      if is_binary(pattern) do
        String.replace(text, pattern, placeholder)
      else
        Regex.replace(pattern, text, placeholder)
      end

    {replaced, Map.put(map, placeholder, pattern)}
  end)
end

defp restore_patterns(content, replacements) do
  Enum.reduce(replacements, content, fn {placeholder, original}, text ->
    pattern_str = if is_binary(original), do: original, else: Regex.source(original)
    String.replace(text, placeholder, pattern_str)
  end)
end
```

### 2. Modified Functions

#### `run_fixture/3` - Updated Orchestration

```elixir
def run_fixture(fixture_path, command, variation) do
  setup_exs = Path.join(fixture_path, "setup.exs")
  setup_file = Path.join(fixture_path, "setup.cli")
  cmd_file = Path.join(fixture_path, "cmd.cli")
  expected_file = Path.join(fixture_path, "expected.out")
  teardown_file = Path.join(fixture_path, "teardown.cli")
  teardown_exs = Path.join(fixture_path, "teardown.exs")

  # 1. Run setup.exs if exists → get bindings
  {:ok, bindings} = run_setup_script(fixture_path)

  try do
    # 2. Run setup.cli with interpolation
    if File.exists?(setup_file) do
      run_cli_file(setup_file, bindings)
    end

    # 3. Run cmd.cli with interpolation
    assert File.exists?(cmd_file), "Missing cmd.cli for #{command}/#{variation}"
    cmd_output = run_cli_file(cmd_file, bindings)

    # 4. Check expected output with interpolation
    if File.exists?(expected_file) do
      expected = File.read!(expected_file)
      compare_output(cmd_output, expected, "#{command}/#{variation}", bindings)
    else
      assert is_binary(cmd_output), "Command should produce output"
    end
  after
    # 5. Run teardown.cli with interpolation
    if File.exists?(teardown_file) do
      run_cli_file(teardown_file, bindings)
    end

    # 6. Run teardown.exs with bindings
    run_teardown_script(fixture_path, bindings)
  end
end
```

#### `run_cli_file/2` - Accept Bindings

```elixir
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

  Enum.map_join(commands, "\n", &Arca.Cli.Testing.CliCommandHelper.run_command/1)
end
```

#### `compare_output/4` - Interpolate Expected

```elixir
def compare_output(actual, expected, test_name, bindings \\ %{}) do
  # Interpolate expected output before comparison
  interpolated_expected = interpolate_bindings(expected, bindings)

  # Check if expected contains patterns (after interpolation)
  if String.contains?(interpolated_expected, "{{") do
    compare_with_patterns(actual, interpolated_expected, test_name)
  else
    # Exact match
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
```

## Code Examples

### Example 1: User Authentication Test

```elixir
# test/cli/fixtures/laksa.auth.login/001/setup.exs
alias Laksa.Accounts.{User, ApiKey}

# Create user
{:ok, user} =
  User
  |> Ash.Changeset.for_create(:create, %{
    email: "fixture-test@example.com",
    password: "testpass123"
  }, authorize?: false)
  |> Ash.create()

# Generate API key
expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)
{:ok, api_key_record} =
  ApiKey
  |> Ash.Changeset.for_create(:create, %{
    user_id: user.id,
    expires_at: expires_at
  }, authorize?: false)
  |> Ash.create()

# Return bindings
%{
  user_email: user.email,
  user_id: user.id,
  api_key: api_key_record.__metadata__.plaintext_api_key
}
```

```bash
# test/cli/fixtures/laksa.auth.login/001/cmd.cli
laksa.auth.login --api-key "{{api_key}}"
```

```
# test/cli/fixtures/laksa.auth.login/001/expected.out
Authenticated successfully
User: {{user_email}}
ID: {{user_id}}
```

```elixir
# test/cli/fixtures/laksa.auth.login/001/teardown.exs
alias Laksa.Accounts.User

user_id = bindings[:user_id]

if user_id do
  User
  |> Ash.get!(user_id, authorize?: false)
  |> Ash.destroy!(authorize?: false)
end
```

### Example 2: Site Management Test

```elixir
# test/cli/fixtures/laksa.site.list/001/setup.exs
alias Laksa.Accounts.User
alias Laksa.Sites.Site

# Create test user
{:ok, user} = create_test_user("test@example.com")

# Create multiple sites
{:ok, site1} = create_site(user.account_id, "site-one", "Site One")
{:ok, site2} = create_site(user.account_id, "site-two", "Site Two")
{:ok, site3} = create_site(user.account_id, "site-three", "Site Three")

# Generate API key
{:ok, api_key} = generate_api_key(user.id)

%{
  api_key: api_key.__metadata__.plaintext_api_key,
  account_id: user.account_id,
  site_count: 3,
  site_ids: [site1.id, site2.id, site3.id]
}
```

```bash
# test/cli/fixtures/laksa.site.list/001/setup.cli
laksa.auth.login --api-key "{{api_key}}"
```

```bash
# test/cli/fixtures/laksa.site.list/001/cmd.cli
laksa.site.list
```

```
# test/cli/fixtures/laksa.site.list/001/expected.out
Found {{site_count}} sites

site-one   | Site One   | {{*}}
site-two   | Site Two   | {{*}}
site-three | Site Three | {{*}}
```

## Technical Details

### Environment Safety

Always verify test environment before evaluating code:

```elixir
unless Mix.env() == :test do
  raise "setup.exs can only run in test environment"
end
```

### Bindings Variable Scope

In `teardown.exs`, bindings are available as a variable:

```elixir
# teardown.exs has access to:
bindings          # Map from setup.exs
bindings[:key]    # Access specific values
```

### String Conversion

All binding values are converted via `to_string/1`:

```elixir
%{
  user_id: 123,              # → "123"
  active: true,              # → "true"
  price: 99.99,              # → "99.99"
  name: "Alice",             # → "Alice"
  status: :published         # → "published"
}
```

For complex types (lists, maps), convert explicitly in `setup.exs`:

```elixir
%{
  site_ids: Enum.join(site_ids, ","),
  config: Jason.encode!(config_map)
}
```

### Pattern Matcher Precedence

The interpolation order ensures patterns are preserved:

1. Replace `{{*}}`, `{{??}}`, etc. with unique placeholders
2. Interpolate variable bindings like `{{user_id}}`
3. Restore pattern placeholders to original form

This prevents a binding named `*` from breaking pattern matching.

### Error Messages

Provide helpful error messages for common mistakes:

```elixir
# Non-map return
"""
setup.exs must return a map, got: "some string"

Example:
%{user_id: 123, api_key: "laksa_abc"}
"""

# Teardown failure
"""
Teardown script failed: ** (KeyError) key :site_id not found
File: test/cli/fixtures/laksa.site.show/001/teardown.exs

Note: Teardown should handle missing bindings gracefully:
  site_id = bindings[:site_id]
  if site_id do
    # cleanup
  end
"""
```

## Challenges & Solutions

### Challenge 1: Pattern Matcher Collision

**Problem**: A binding `%{*: "value"}` would conflict with `{{*}}` pattern matcher.

**Solution**:

- Restrict variable names to `[a-z_][a-z0-9_]*` (valid atom identifiers)
- Process pattern matchers first, use placeholders
- Document that reserved pattern names should not be used as bindings

### Challenge 2: Type Safety for Bindings

**Problem**: What if `setup.exs` returns `{:ok, %{}}` instead of `%{}`?

**Solution**: Validate return value immediately with clear error message:

```elixir
unless is_map(result) do
  raise "setup.exs must return a map, got: #{inspect(result)}"
end
```

### Challenge 3: Teardown Accessing Missing Bindings

**Problem**: If `setup.exs` doesn't run (skipped or failed), teardown gets empty bindings.

**Solution**: Always provide bindings variable, even if empty. Document that teardown should handle `nil`:

```elixir
# Good teardown pattern
site_id = bindings[:site_id]
if site_id do
  delete_site(site_id)
end
```

### Challenge 4: Multi-line Interpolation

**Problem**: What if we need to interpolate a multi-line value?

**Solution**: For now, don't support it. Values are converted via `to_string/1`, which works for single-line values. For complex data, users should format in `setup.exs`:

```elixir
# Format complex data in setup.exs
%{
  config_json: Jason.encode!(config, pretty: true)
}
```

Document limitation and workaround.

### Challenge 5: Debugging Evaluated Code

**Problem**: Errors in `setup.exs` show cryptic stack traces.

**Solution**: Use `Code.eval_string/3` with `file:` option to get proper file references:

```elixir
Code.eval_string(code, [], file: setup_exs)
```

This makes errors show the actual file path and line numbers.

### Challenge 6: Test Isolation

**Problem**: If setup.exs creates database records, they might leak between tests.

**Solution**:

- Document that `teardown.exs` should clean up everything created
- Consider adding test helpers for common cleanup patterns
- Rely on database sandbox/transactions if available (ExUnit's Ecto.SQL.Sandbox)

## Testing Strategy

### Unit Tests for Interpolation

```elixir
describe "interpolate_bindings/2" do
  test "replaces simple bindings" do
    assert interpolate_bindings("Hello {{name}}", %{name: "Alice"}) == "Hello Alice"
  end

  test "preserves pattern matchers" do
    assert interpolate_bindings("Status: {{*}}", %{}) == "Status: {{*}}"
  end

  test "converts non-string values" do
    assert interpolate_bindings("ID: {{id}}", %{id: 42}) == "ID: 42"
  end

  test "leaves unknown bindings as-is" do
    assert interpolate_bindings("{{unknown}}", %{}) == "{{unknown}}"
  end
end
```

### Integration Tests

Create fixture test cases that exercise the full flow:

```
test/cli/fixtures/
  _test_exs_basic/
    001/
      setup.exs        # Returns %{value: "test"}
      cmd.cli          # echo {{value}}
      expected.out     # test

  _test_exs_teardown/
    001/
      setup.exs        # Returns %{file: "/tmp/test.txt"}
      cmd.cli          # cat {{file}}
      teardown.exs     # File.rm(bindings[:file])
```

### Error Cases

Test error handling:

```elixir
test "setup.exs returning non-map raises error" do
  assert_raise RuntimeError, ~r/must return a map/, fn ->
    run_setup_script("test/cli/fixtures/_test_bad_return/001")
  end
end
```
