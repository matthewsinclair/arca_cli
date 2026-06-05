# Completion Criteria - ST0009: Elixir-based setup and teardown for CLI fixtures

## Definition of Done

This steel thread is complete when all of the following criteria are met:

### 1. Functional Requirements

- [ ] `setup.exs` files are discovered and executed before test fixtures
- [ ] `setup.exs` returns a map of bindings that are available for interpolation
- [ ] `teardown.exs` files receive bindings and execute cleanup
- [ ] Interpolation works in `setup.cli`, `cmd.cli`, `teardown.cli` files
- [ ] Interpolation works in `expected.out` files
- [ ] Pattern matchers (`{{*}}`, `{{??}}`, etc.) are preserved during interpolation
- [ ] Missing bindings are handled gracefully (left as literal `{{key}}`)
- [ ] All values are converted to strings using `to_string/1`
- [ ] Teardown always runs, even if test fails
- [ ] Teardown errors are logged but don't fail tests

### 2. Backward Compatibility

- [ ] Existing fixtures without `.exs` files continue working unchanged
- [ ] No breaking changes to existing API
- [ ] Optional bindings parameter defaults to `%{}`
- [ ] CLI-only fixtures (no .exs) run as before

### 3. Error Handling

- [ ] `setup.exs` returning non-map raises clear error message
- [ ] `setup.exs` syntax errors show file and line number
- [ ] `setup.exs` runtime errors fail the test appropriately
- [ ] `teardown.exs` errors are logged but don't fail tests
- [ ] Environment check prevents .exs execution outside test env
- [ ] Invalid interpolation patterns don't crash (graceful degradation)

### 4. Testing

- [ ] Unit tests for `interpolate_bindings/2` cover all cases
  - Simple replacement
  - Pattern matcher preservation
  - Type conversion
  - Missing bindings
  - Edge cases

- [ ] Unit tests for `run_setup_script/1` cover:
  - Valid map return
  - Invalid return raises error
  - File not found
  - Syntax errors
  - Runtime errors

- [ ] Unit tests for `run_teardown_script/2` cover:
  - Successful execution
  - Error handling
  - Missing file

- [ ] Integration tests with real fixtures demonstrating:
  - Basic .exs flow
  - Mixed .exs and .cli files
  - Bindings in all file types
  - Pattern matchers + bindings
  - Teardown cleanup

- [ ] All tests pass in CI
- [ ] No regressions in existing fixture tests

### 5. Documentation

- [ ] Moduledoc updated with "Elixir Setup/Teardown" section
- [ ] Execution order documented clearly
- [ ] File format specifications documented
- [ ] Interpolation syntax and rules documented
- [ ] Complete working examples included
- [ ] Function docs for new functions:
  - `run_setup_script/1`
  - `run_teardown_script/2`
  - `interpolate_bindings/2`

- [ ] Troubleshooting section added
- [ ] Common patterns documented
- [ ] Example fixtures created and documented

### 6. Code Quality

- [ ] Code follows project style guidelines
- [ ] All functions have clear, descriptive names
- [ ] Complex logic has explanatory comments
- [ ] No compiler warnings
- [ ] Credo passes (if used in project)
- [ ] Dialyzer passes (if used in project)

### 7. Performance

- [ ] Interpolation performance is acceptable (< 1ms per fixture)
- [ ] Pattern preservation doesn't cause significant overhead
- [ ] No memory leaks in repeated test runs

### 8. Examples

- [ ] At least 3 example fixtures created demonstrating:
  1. Basic database setup with user/API key
  2. Multi-resource setup with relationships
  3. Complex scenario with mixed .exs and .cli

- [ ] Examples are self-documenting
- [ ] Examples demonstrate best practices

## Acceptance Tests

### Test 1: Basic Setup and Interpolation

**Fixture**: `test/cli/fixtures/_test_basic_exs/001/`

```elixir
# setup.exs
%{value: "hello"}
```

```bash
# cmd.cli
echo {{value}}
```

```
# expected.out
hello
```

**Expected**: Test passes, value is interpolated correctly

### Test 2: Database Setup with Teardown

**Fixture**: `test/cli/fixtures/_test_db_exs/001/`

```elixir
# setup.exs
{:ok, user} = create_user("test@example.com")
%{user_id: user.id, email: user.email}
```

```bash
# cmd.cli
laksa.user.show {{user_id}}
```

```
# expected.out
Email: {{email}}
```

```elixir
# teardown.exs
if user_id = bindings[:user_id] do
  delete_user(user_id)
end
```

**Expected**: Test passes, user created then cleaned up

### Test 3: Pattern Matchers + Bindings

**Fixture**: `test/cli/fixtures/_test_patterns_exs/001/`

```elixir
# setup.exs
%{name: "Alice"}
```

```
# expected.out
User: {{name}}
Created: {{*}}
ID: {{\d+}}
```

**Expected**: Test passes, name interpolated, patterns preserved

### Test 4: Error Handling - Invalid Return

**Fixture**: `test/cli/fixtures/_test_error_exs/001/`

```elixir
# setup.exs
"not a map"
```

**Expected**: Test fails with clear error: "setup.exs must return a map"

### Test 5: Missing Binding Graceful Degradation

**Fixture**: `test/cli/fixtures/_test_missing_exs/001/`

```elixir
# setup.exs
%{foo: "bar"}
```

```
# expected.out
Foo: {{foo}}
Missing: {{baz}}
```

**Expected**: Test compares `"Foo: bar\nMissing: {{baz}}"` (literal `{{baz}}`)

## Verification Checklist

Before marking this steel thread as complete:

- [ ] All tasks in tasks.md are completed
- [ ] All acceptance tests pass
- [ ] All unit and integration tests pass
- [ ] Documentation is reviewed and accurate
- [ ] Examples run successfully
- [ ] Code review completed
- [ ] No known bugs or issues
- [ ] CHANGELOG updated
- [ ] README updated (if needed)

## Success Metrics

- **Performance**: .exs setup is 10x+ faster than .cli for database operations
- **Usability**: Creating a new .exs fixture takes < 5 minutes
- **Reliability**: 100% backward compatibility with existing fixtures
- **Adoption**: At least 3 real fixtures migrated to use .exs (in Laksa project)

## Known Limitations (Documented)

These limitations are acceptable and should be documented:

1. Variable names must be valid Elixir atoms (`[a-z_][a-z0-9_]*`)
2. Pattern matcher names (`*`, `??`, etc.) should not be used as binding names
3. Multi-line interpolation values not supported (use JSON encoding)
4. Bindings are string-converted (use explicit formatting for complex types)
5. .exs files are evaluated in test environment only

## Post-Completion

After this steel thread is complete:

1. **Share examples** with team
2. **Migrate** 2-3 Laksa fixtures to .exs as proof-of-concept
3. **Document** best practices based on real usage
4. **Monitor** for issues or usability problems
5. **Iterate** on design if needed

## Sign-off

Completed by: ********\_********

Date: ********\_********

Reviewed by: ********\_********

Notes:
