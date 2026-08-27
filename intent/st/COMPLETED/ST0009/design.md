# Design - ST0009: Elixir-based setup and teardown for CLI fixtures

## Approach

Extend the existing `Arca.Cli.Testing.CliFixturesTest` module to support optional `.exs` files alongside existing `.cli` files. The core approach:

1. **Execution order** becomes:
   - `setup.exs` (if exists) → returns `%{bindings}`
   - `setup.cli` (if exists, with `{{interpolation}}`)
   - `cmd.cli` (required, with `{{interpolation}}`)
   - Compare output against `expected.out` (with `{{interpolation}}`)
   - `teardown.cli` (if exists, with `{{interpolation}}`)
   - `teardown.exs` (if exists, receives `bindings`)

2. **Bindings flow**: Values from `setup.exs` are available for interpolation in all `.cli` and `.out` files

3. **Backward compatibility**: Existing fixtures without `.exs` files continue working unchanged

4. **Test isolation**: Each fixture runs in isolated environment with clean state

## Design Decisions

### 1. File Format and Requirements

**`setup.exs`:**

- Must return a map: `%{atom_key: value}`
- Has access to all application modules and repos
- Runs in test environment with test database
- Should use `authorize?: false` for Ash operations to bypass policies
- Example return: `%{user_id: 123, api_key: "laksa_abc123"}`

**`teardown.exs`:**

- Receives `bindings` variable from `setup.exs`
- No return value required (any return ignored)
- Always runs, even if test fails
- Should handle missing data gracefully (nil checks)

**Rationale**: Maps are the natural Elixir data structure, atom keys are idiomatic, and making `setup.exs` return bindings explicitly ensures clarity.

### 2. Interpolation Syntax

Use `{{key}}` syntax for interpolation, consistent with existing pattern matchers:

```
# In .cli files
laksa.auth.login --api-key "{{api_key}}"
laksa.site.show {{site_id}}

# In expected.out
User: {{user_email}}
Site count: {{site_count}}
```

**Interpolation Rules:**

- `{{identifier}}` where identifier matches `[a-z_][a-z0-9_]*` (atom-compatible)
- Values converted to strings via `to_string/1`
- Non-matching keys left as literal `{{key}}` (graceful degradation)
- Pattern matchers (`{{*}}`, `{{??}}`, etc.) take precedence - checked first before variable interpolation

**Rationale**: Reuses existing syntax, simple to implement, graceful handling of missing keys prevents cryptic errors.

### 3. Code Evaluation Strategy

Use `Code.eval_string/3` to execute `.exs` files:

```elixir
{result, _bindings} = Code.eval_string(code, [], file: setup_exs)
```

**Security considerations:**

- Only runs in test environment
- Code is from project's own test fixtures (not user input)
- Same trust model as regular ExUnit tests
- Add validation that result is a map

**Rationale**: `Code.eval_string/3` is standard for evaluating Elixir scripts, provides file tracking for errors, and matches Elixir's own `mix run` behavior.

### 4. Error Handling

**`setup.exs` failures:**

- Raise with clear error message showing file and line
- Test marked as failed (standard ExUnit behavior)
- Teardown still runs (via `try/after`)

**`teardown.exs` failures:**

- Log warning but don't fail test
- Cleanup is best-effort
- Prevent one test's teardown from breaking others

**Invalid return from `setup.exs`:**

- Raise immediately with descriptive error
- Show received value and expected format

**Rationale**: Fail fast on setup errors (test can't proceed), but be lenient on teardown (cleanup is best-effort).

### 5. Pattern Matching Integration

When interpolating into `expected.out`, pattern matchers must take precedence:

**Processing order:**

1. First, identify pattern matchers: `{{*}}`, `{{??}}`, `{{\d+}}`, `{{\w+}}`, `{{.*}}`
2. Replace them with placeholders before interpolation
3. Then interpolate variable bindings: `{{user_id}}`, `{{api_key}}`
4. Finally restore pattern matchers

**Example:**

```
# expected.out
User: {{user_email}}        # Variable interpolation
Created: {{*}}              # Pattern matcher (preserved)
Status: {{\w+}}             # Pattern matcher (preserved)
```

**Rationale**: Pattern matchers are part of the test assertion logic and must not be treated as variables.

## Architecture

### Module Structure

```
Arca.Cli.Testing.CliFixturesTest
├── discover_fixtures/0           # Existing - no changes
├── run_fixture/3                 # MODIFIED - orchestrates .exs + .cli execution
├── run_cli_file/1                # MODIFIED - accepts bindings for interpolation
├── compare_output/3              # MODIFIED - interpolates before comparison
├── compare_with_patterns/3       # MODIFIED - careful pattern/variable handling
├── normalize_output/1            # Existing - no changes
└── NEW FUNCTIONS:
    ├── run_setup_script/1        # Execute setup.exs, return bindings
    ├── run_teardown_script/2     # Execute teardown.exs with bindings
    └── interpolate_bindings/2    # Replace {{key}} with values from bindings
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Test Lifecycle                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. run_setup_script(fixture_path)                         │
│     ├─ Read setup.exs                                      │
│     ├─ Code.eval_string(code)                              │
│     ├─ Validate result is map                              │
│     └─ Return bindings: %{user_id: 123, ...}              │
│                                                             │
│  2. run_cli_file(setup.cli, bindings)                      │
│     ├─ Read setup.cli                                      │
│     ├─ Interpolate {{key}} → value                         │
│     └─ Execute commands (output ignored)                   │
│                                                             │
│  3. run_cli_file(cmd.cli, bindings)                        │
│     ├─ Read cmd.cli                                        │
│     ├─ Interpolate {{key}} → value                         │
│     ├─ Execute command                                     │
│     └─ Capture output                                      │
│                                                             │
│  4. compare_output(actual, expected, bindings)             │
│     ├─ Read expected.out                                   │
│     ├─ Interpolate {{key}} → value                         │
│     │  (preserve pattern matchers!)                        │
│     ├─ Compare with patterns or exact match                │
│     └─ Assert match                                        │
│                                                             │
│  5. run_cli_file(teardown.cli, bindings)                   │
│     └─ (always runs, even on failure)                      │
│                                                             │
│  6. run_teardown_script(fixture_path, bindings)            │
│     ├─ Read teardown.exs                                   │
│     ├─ Code.eval_string(code, [bindings: bindings])       │
│     └─ (always runs, errors logged)                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### File Organization

No changes to fixture directory structure:

```
test/cli/fixtures/
  <command.name>/              # e.g., "laksa.site.show"
    001/                       # Variation number
      setup.exs                # NEW - Optional Elixir setup
      setup.cli                # Existing - Optional CLI setup
      cmd.cli                  # REQUIRED - Command to test
      expected.out             # Optional - Expected output
      teardown.cli             # Existing - Optional CLI teardown
      teardown.exs             # NEW - Optional Elixir teardown
      skip                     # Optional - Skip marker
```

## Alternatives Considered

### Alternative 1: Use context variable instead of return value

```elixir
# setup.exs
context = %{}
{:ok, user} = create_user()
context = Map.put(context, :user_id, user.id)
# Implicit: return context
```

**Rejected**: Too implicit, error-prone (forgot to assign), less clear than explicit return.

### Alternative 2: JSON file for bindings

```json
// bindings.json
{
  "user_id": 123,
  "api_key": "laksa_abc"
}
```

**Rejected**: Less powerful (can't compute values), requires separate file, no type safety, awkward workflow.

### Alternative 3: ERB-style interpolation `<%= key %>`

**Rejected**: Not Elixir-idiomatic, conflicts with existing `{{pattern}}` syntax, harder to implement.

### Alternative 4: Separate bindings file per stage

```
001/
  setup.exs      → returns %{setup_data: ...}
  bindings.exs   → combines all bindings
  cmd.cli        → uses bindings
```

**Rejected**: Over-engineered, unclear data flow, more files to manage.

### Alternative 5: Allow setup.exs to modify global test state

**Rejected**: Breaks test isolation, makes tests fragile, harder to reason about, violates ExUnit best practices.

## Migration Path

### Phase 1: Core Implementation (This Steel Thread)

- Implement `setup.exs` / `teardown.exs` support
- Add interpolation for `.cli` and `.out` files
- Add comprehensive tests
- Update documentation

### Phase 2: Example Fixtures (Future)

- Create example fixtures demonstrating `.exs` usage
- Document common patterns
- Identify which existing Laksa fixtures would benefit from migration

### Phase 3: Best Practices Guide (Future)

- When to use `.exs` vs `.cli`
- Performance guidelines
- Debugging techniques
- Common pitfalls

## Open Questions & Decisions

### Q1: Error handling for setup.exs - fail test or show error?

**Decision**: Fail the test immediately. Setup errors indicate the test cannot proceed, similar to raising in an ExUnit `setup` block.

### Q2: Should teardown.exs receive bindings from setup.exs?

**Decision**: Yes. Teardown needs to know what was created (IDs, names) to clean up properly. Pass via `Code.eval_string(code, [bindings: bindings])`.

### Q3: Type conversion for non-string bindings?

**Decision**: Use `to_string/1` for all interpolations. Handles integers, atoms, floats naturally. For complex types, users should convert in `setup.exs`.

### Q4: Collision between {{site_id}} binding and {{*}} pattern?

**Decision**: Pattern matchers take precedence. Document that variable names should not collide with pattern syntax (`*`, `??`, `\d+`, `\w+`, `.*`).

### Q5: Missing interpolation keys - error or leave literal?

**Decision**: Leave as literal `{{key}}`. This allows:

- Graceful degradation
- Clear visual indication in test output
- Easier debugging (see what's missing)
- Optional bindings (can provide some but not all)

### Q6: Should bindings be scoped per file or shared across all files?

**Decision**: Shared across all files in the fixture. This matches user mental model and enables data flow from setup → cmd → expected → teardown.

### Q7: Security implications of Code.eval_string?

**Decision**: Acceptable for test code. `.exs` files are:

- Part of the project's own codebase
- Not user input or external data
- Same trust level as regular test files
- Only executed in test environment

Add guard: Verify we're in test environment before eval'ing.

## Benefits

1. **Performance**: 10-100x faster setup for database-heavy fixtures
2. **Flexibility**: Use any Elixir/Ash API, not limited to CLI commands
3. **Debugging**: Standard Elixir debugging tools work (IEx.pry, stack traces)
4. **Data sharing**: Computed values (IDs, tokens) flow to commands and assertions
5. **Backward compatible**: Zero impact on existing fixtures
6. **Best of both worlds**: Use `.exs` for complex setup, `.cli` for simple cases

## Non-Goals

- Replacing `.cli` files entirely (they're still valuable for simple cases)
- Supporting multiple `.exs` files per fixture (one setup, one teardown)
- Cross-fixture data sharing (each fixture is isolated)
- Non-test usage (this is test-only infrastructure)
