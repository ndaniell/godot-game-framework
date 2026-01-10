# Test Framework

## Overview

The test framework is **generic and extensible**, designed to test any part of the framework, not just managers.

## Architecture

### Core Components

1. **TestFramework** - Core testing utilities and assertions
2. **TestRegistry** - Dynamic test suite registration system
3. **TestSuite** - Base class for creating test suites
4. **TestRunner** - Discovers and runs all registered tests
5. **ManagerTests** - Example test suite for managers

## Key Features

- **Generic** - Can test any part of the framework
- **Extensible** - Easy to add new test suites
- **Dynamic Registration** - Tests registered at runtime
- **Discovery** - Automatically finds and runs tests
- **Isolated** - Each test suite is independent

## Usage

### Basic Usage

```gdscript
# Create test runner
var test_runner = load("res://scripts/test/TestRunner.gd").new()
add_child(test_runner)
# Tests run automatically
```

### Registering Custom Tests

```gdscript
# Get test runner
var test_runner = get_node("TestRunner")

# Register a test suite
test_runner.register_suite("MySuite", {
    "test1": my_test_function,
    "test2": another_test_function
})

# Or register with setup/teardown
test_runner.register_suite("MySuite", {
    "test1": my_test_function
}, setup_function, teardown_function)
```

### Creating Test Suites

```gdscript
extends FrameworkTestSuite

func _init():
    super._init("MySuite", test_framework)

func get_tests() -> Dictionary:
    return {
        "test1": test_one,
        "test2": test_two
    }

func setup() -> void:
    # Suite-level setup
    pass

func teardown() -> void:
    # Suite-level teardown
    pass
```

## Testing Any Framework Component

The framework can test:
- Managers (AudioManager, GameManager, etc.)
- Utilities
- Helper functions
- Integration between components
- Custom extensions

## Note on Linter Warnings

Manager references (AudioManager, GameManager, etc.) are autoload singletons available at runtime. The linter may show warnings about these - this is expected and safe to ignore.
