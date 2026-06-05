# Arca.Cli Circular Dependency Fixes

This document describes the changes made to fix circular dependency issues during application initialization, particularly between `Arca.Cli` and `Arca.Config`.

## Problem Summary

The primary issue was that `Arca.Cli` was attempting to load settings from and register callbacks with `Arca.Config` during application startup, which could cause circular dependencies if `Arca.Config` was dependent on `Arca.Cli`.

## Solution Architecture

We implemented a delayed initialization pattern using a GenServer that starts configuration-related tasks after the main application services are running. This approach ensures that:

1. Core services start without configuration dependencies
2. Configuration-related operations occur after all applications have been initialized
3. Commands have safety guards to prevent circular calls during initialization
4. The application uses conservative defaults during initialization

## Key Components

### 1. Delayed Initializer

A new module `Arca.Cli.Configurator.Initializer` handles delayed initialization:

- Starts as part of the application supervision tree
- Schedules a delayed initialization task (~500ms after startup)
- Safely loads settings and registers callbacks once the delay passes
- Provides a status API for checking initialization progress
- Uses proper error handling to ensure application stability

### 2. Safe Configuration Access

Modified `load_settings/0`, `get_setting/1`, and `save_settings/1` to:

- Detect if called during initialization phase
- Return appropriate defaults during initialization
- Add checks for circular dependency prevention
- Include process identity safeguards
- Handle errors gracefully without propagating them

### 3. Safe Callback Registration

Updated `register_config_callbacks/0` to:

- Check if `Arca.Config` is available before registration
- Verify all required functionality exists
- Handle errors during callback registration
- Provide graceful degradation when services aren't available

### 4. Initialization Phase Detection

Added utility functions to:

- Determine if code is executing during the initialization phase
- Check if required services are available
- Provide appropriate default values based on context
- Prevent circular service calls

## Implementation Pattern

The pattern follows these steps:

1. Start core services first with the application supervisor
2. Add a delayed initializer to the supervision tree
3. Have the initializer schedule initialization for after startup
4. Implement safety checks in all configuration-related functions
5. Provide conservative defaults during initialization
6. Use process identity checks to prevent circular calls

## Benefits

This implementation:

- Prevents circular dependencies between applications
- Makes startup more robust to timing issues
- Ensures commands work even during initialization
- Provides graceful degradation with sensible defaults
- Reduces risk of deadlocks during application startup
- Makes the system more testable and maintainable

## Testing

A new test module `Arca.Cli.Configurator.InitializerTest` verifies:

- The initializer starts and schedules delayed tasks
- Settings can be accessed before, during, and after initialization
- The system remains stable regardless of initialization state

## Usage Guidelines

When extending the CLI with new commands:

1. Do not rely on configuration being available during initialization
2. Use the provided safety functions for configuration access
3. Implement resilient designs with conservative defaults
4. Check initialization status when needed with `Initializer.status/0`
5. Avoid synchronous calls to `Arca.Config` during startup
