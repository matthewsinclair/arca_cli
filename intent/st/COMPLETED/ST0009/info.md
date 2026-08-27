---
verblock: "06 Oct 2025:v0.2: Claude - Implementation complete, tested, and documented
06 Oct 2025:v0.1: Matthew Sinclair - Initial version"
intent_version: 2.2.0
status: Completed
created: 20251006
completed:
---

# ST0009: Elixir-based setup and teardown for CLI fixtures

## Objective

Add support for `setup.exs` and `teardown.exs` files to the CLI fixtures testing framework, enabling programmatic test data creation with better performance, flexibility, and data sharing capabilities compared to CLI-based setup/teardown.

## Context

The current CLI fixtures framework (`Arca.Cli.Testing.CliFixturesTest`) uses `setup.cli` and `teardown.cli` files containing CLI commands for test setup and teardown. While this works, it has several limitations:

**Current Limitations:**

1. **Performance**: Creating test data via CLI requires full command parsing, validation, and execution
2. **Verbosity**: Complex setup requires many sequential CLI commands
3. **Data isolation**: Cannot easily return computed values (IDs, tokens) for use in tests
4. **Debugging**: Harder to debug than native Elixir code
5. **API coupling**: Must use public CLI interface, cannot access internal APIs directly

**Proposed Enhancement:**
Add optional `setup.exs` and `teardown.exs` files that:

- Run native Elixir code for fast, direct database/API access
- Return bindings map (`%{key: value}`) for interpolation into `.cli` and `.out` files
- Coexist with existing `.cli` files (backward compatible)
- Enable complex test scenarios with dynamic data

**Example Use Case:**

```elixir
# setup.exs - Fast database setup
{:ok, user} = create_user("test@example.com")
{:ok, api_key} = generate_api_key(user.id)
%{api_key: api_key.plaintext, user_id: user.id}

# cmd.cli - Use interpolated values
laksa.auth.login --api-key "{{api_key}}"

# expected.out - Assert on dynamic data
User ID: {{user_id}}
```

## Related Steel Threads

- None identified yet

## Implementation Status

**✅ IMPLEMENTATION COMPLETE** (2025-10-06)

- All core functions implemented and tested (397 tests passing)
- Full backward compatibility maintained (all 393 existing tests still pass)
- Comprehensive documentation added to user and reference guides
- Integration fixtures created and verified
- Feature ready for production use

See `impl.md` for as-built documentation and technical details.

## Context for LLM

This steel thread extends the existing CLI fixtures testing framework. The implementation requires:

- Understanding of ExUnit test lifecycle and macros
- Familiarity with Elixir's `Code.eval_string/3` for dynamic code execution
- String interpolation and pattern matching integration
- Careful handling of test isolation and cleanup

The design must maintain backward compatibility with existing fixtures while adding powerful new capabilities for complex test scenarios.
