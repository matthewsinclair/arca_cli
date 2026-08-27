---
verblock: "22 Sep 2025:v0.1: Matthew Sinclair - Initial version"
intent_version: 2.2.0
status: Completed
created: 20250922
completed: 20251006
---

# ST0008: Orthogonalised formatting and outputting

## Objective

Implement an orthogonal output system for Arca.Cli that cleanly separates data processing, styling, and formatting concerns while maintaining full backwards compatibility with existing commands.

## Context

Currently, Arca.Cli commands directly output formatted strings, mixing data processing with presentation logic. This creates several issues:

- Commands are tightly coupled to their output format
- Testing is difficult due to ANSI codes and formatting in output
- No consistent way to disable colors/formatting for non-TTY environments
- Commands cannot easily support multiple output formats (JSON, plain text, etc.)

The ST0003 work already established a callback system for REPL output formatting. This steel thread extends that foundation to create a comprehensive output system that works for all commands, not just REPL mode.

## Related Steel Threads

- ST0003: REPL Output Callback System - Provides the callback infrastructure we'll leverage
- ST0002: REPL Tab Completion Improvements - Related REPL functionality

## Context for LLM

This document represents a single steel thread - a self-contained unit of work focused on implementing a specific piece of functionality. When working with an LLM on this steel thread, start by sharing this document to provide context about what needs to be done.

### How to update this document

1. Update the status as work progresses
2. Update related documents (design.md, impl.md, etc.) as needed
3. Mark the completion date when finished

The LLM should assist with implementation details and help maintain this document as work progresses.
