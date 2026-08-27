# Tasks - ST0009: Elixir-based setup and teardown for CLI fixtures

## Tasks

### Phase 1: Core Implementation

- [ ] Add `run_setup_script/1` function
  - Read and evaluate setup.exs
  - Validate return value is a map
  - Add environment safety check (test only)
  - Return `{:ok, bindings}` or `{:ok, %{}}`

- [ ] Add `run_teardown_script/2` function
  - Read and evaluate teardown.exs
  - Pass bindings from setup
  - Catch and log errors (don't fail test)
  - Always return `:ok`

- [ ] Add `interpolate_bindings/2` function
  - Preserve pattern matchers (`{{*}}`, `{{??}}`, etc.)
  - Replace `{{identifier}}` with binding values
  - Handle missing bindings gracefully (leave as-is)
  - Convert values to strings via `to_string/1`

- [ ] Update `run_fixture/3` orchestration
  - Call `run_setup_script/1` first
  - Pass bindings to all downstream functions
  - Call `run_teardown_script/2` in after block
  - Ensure teardown always runs

- [ ] Update `run_cli_file/1` to accept bindings
  - Change signature to `run_cli_file/2` with optional bindings
  - Interpolate content before parsing commands
  - Maintain backward compatibility (default to `%{}`)

- [ ] Update `compare_output/3` to accept bindings
  - Change signature to `compare_output/4` with optional bindings
  - Interpolate expected output before comparison
  - Preserve pattern matching behavior

### Phase 2: Testing

- [ ] Write unit tests for `interpolate_bindings/2`
  - Test simple variable replacement
  - Test pattern matcher preservation
  - Test type conversion (integers, booleans, atoms)
  - Test missing bindings
  - Test edge cases (empty string, special characters)

- [ ] Write unit tests for `run_setup_script/1`
  - Test valid map return
  - Test invalid return (non-map) raises error
  - Test file not found returns `{:ok, %{}}`
  - Test syntax errors in script
  - Test runtime errors in script

- [ ] Write unit tests for `run_teardown_script/2`
  - Test successful execution
  - Test error handling (logs, doesn't raise)
  - Test with and without bindings
  - Test file not found

- [ ] Create integration test fixtures
  - Basic setup.exs → cmd.cli → expected.out flow
  - Setup.exs with teardown.exs
  - Mixed .exs and .cli files
  - Bindings used in all file types
  - Pattern matchers + bindings in expected.out

- [ ] Test error scenarios
  - setup.exs returns non-map
  - setup.exs raises exception
  - teardown.exs raises exception (should log, not fail)
  - Missing interpolation keys
  - Reserved pattern names as bindings

### Phase 3: Documentation

- [ ] Update moduledoc for `Arca.Cli.Testing.CliFixturesTest`
  - Add "Elixir Setup/Teardown (Advanced)" section
  - Document setup.exs file format and requirements
  - Document teardown.exs file format
  - Document interpolation syntax and rules
  - Add complete examples

- [ ] Add function documentation
  - `run_setup_script/1` - full @doc with examples
  - `run_teardown_script/2` - full @doc
  - `interpolate_bindings/2` - @doc with examples

- [ ] Create example fixtures demonstrating .exs usage
  - Simple authentication example
  - Database record creation example
  - Multi-resource setup example
  - Pattern matchers + interpolation example

- [ ] Add troubleshooting section
  - Common errors and solutions
  - Debugging tips
  - When to use .exs vs .cli

### Phase 4: Polish

- [ ] Add helpful error messages
  - Non-map return from setup.exs
  - Evaluation errors with file context
  - Type conversion issues
  - Missing binding warnings (optional)

- [ ] Code review and refactoring
  - Extract helper functions if needed
  - Add typespecs where helpful
  - Ensure consistent code style
  - Optimize performance (avoid unnecessary regex operations)

- [ ] Performance testing
  - Benchmark .exs vs .cli setup
  - Verify interpolation performance is acceptable
  - Profile pattern preservation logic

- [ ] Update CHANGELOG
  - Add entry for new .exs support
  - Document breaking changes (none expected)
  - Note new features and examples

## Task Notes

### Dependencies

1. Core implementation must complete before testing
2. Integration tests depend on core implementation
3. Documentation should be written alongside implementation
4. Examples should be created after documentation is complete

### Estimated Effort

- **Phase 1** (Core Implementation): 4-6 hours
  - Most complex: interpolation logic with pattern preservation
  - Straightforward: setup/teardown script execution

- **Phase 2** (Testing): 3-4 hours
  - Unit tests are straightforward
  - Integration tests require creating fixtures

- **Phase 3** (Documentation): 2-3 hours
  - Moduledoc updates
  - Examples and guides

- **Phase 4** (Polish): 1-2 hours
  - Error messages
  - Code review
  - Performance check

**Total**: 10-15 hours

### Testing Priorities

1. **Critical**: Interpolation logic (core feature)
2. **Critical**: Setup script execution and validation
3. **Important**: Integration with existing fixtures
4. **Important**: Error handling
5. **Nice to have**: Performance benchmarks

### Documentation Priorities

1. **Critical**: Moduledoc update with examples
2. **Critical**: Function documentation
3. **Important**: Example fixtures
4. **Nice to have**: Best practices guide

## Dependencies

### External Dependencies

None - uses only Elixir standard library (`Code`, `Regex`, `File`)

### Internal Dependencies

- Existing `Arca.Cli.Testing.CliFixturesTest` module
- Existing `Arca.Cli.Testing.CliCommandHelper` module

### Test Environment Dependencies

- ExUnit (already present)
- Test fixtures directory structure

## Risks & Mitigations

### Risk: Breaking existing fixtures

**Mitigation**:

- Make all changes backward compatible
- Default bindings to `%{}` when not provided
- Test with existing fixtures before release

### Risk: Pattern matcher collision

**Mitigation**:

- Process pattern matchers first with placeholder technique
- Document reserved names
- Add tests for edge cases

### Risk: Security concerns with Code.eval_string

**Mitigation**:

- Only evaluate in test environment
- Add explicit environment check
- Document that .exs files are trusted code
- Same security model as regular test files

### Risk: Poor error messages for evaluation failures

**Mitigation**:

- Use `file:` option in `Code.eval_string/3`
- Catch and re-raise with context
- Add examples to error messages
- Test error scenarios explicitly
