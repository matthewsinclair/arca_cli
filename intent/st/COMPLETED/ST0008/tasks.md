# Tasks - ST0008: Orthogonalised formatting and outputting

## Progress Summary

**Overall Status**: 80% Complete (8 of 10 work packages)

- ✅ Completed: WP1 (Context Module), WP2 (Plain Renderer), WP3 (ANSI Renderer), WP4 (Output Pipeline), WP5 (Callback Integration), WP6 (Command Execution Integration), WP7 (Environment Variables), WP8 (Command Migration) - See done.md
- 🎯 Ready to Start: WP9 (Test Infrastructure Updates)
- ⏸️ Blocked: WP10 (Documentation - waiting on WP9)

## Remaining Work Packages

### WP9: Test Infrastructure Updates

**Status**: Ready to Start
**Size**: M
**Description**: Update test helpers and fixtures to support both output styles.

**Tasks**:

- [ ] Create test helper for asserting Ctx output
- [ ] Add matcher for plain text output
- [ ] Add matcher for structured output items
- [ ] Update existing test helpers to handle Ctx
- [ ] Create fixture comparison utilities
- [ ] Add environment variable test helpers
- [ ] Document testing patterns for command authors

---

### WP10: Documentation Package

**Status**: Blocked (requires all other WPs)
**Size**: S
**Description**: Create comprehensive documentation for command authors.

**Tasks**:

- [ ] Write migration guide from string to Ctx returns
- [ ] Create output type reference documentation
- [ ] Add cookbook examples for common patterns
- [ ] Update BaseCommand documentation
- [ ] Add troubleshooting guide
- [ ] Create quick reference card
- [ ] Update README with new features

---

## Dependencies Graph

```
WP1 ✅ ──┬──> WP3 ✅ ──> WP4 ✅ ──┬──> WP5 ✅
        │                      ├──> WP6 ✅ ──┬──> WP8 ✅
WP2 ✅ ──┘                      │          └──> WP9 🎯
                               └──> WP10
WP7 ✅ (completed)
```

## Next Steps

1. **Start WP9 (Test Infrastructure Updates)** - Create test helpers for Context assertions
2. **Then WP10 (Documentation Package)** - Create comprehensive documentation for command authors

## Success Metrics

- [x] All existing tests pass without modification (337 tests passing)
- [x] New commands can use Ctx with structured output (3 commands migrated)
- [x] Plain mode produces no ANSI codes (verified in tests)
- [ ] Test fixtures work in both modes (WP9 pending)
- [x] Performance regression < 5% (no noticeable regression)
- [x] Zero breaking changes for existing commands (full compatibility maintained)
- [ ] Documentation coverage for all new APIs (WP10 pending)
