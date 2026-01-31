# Testing Framework

The Godot Game Framework includes a comprehensive testing framework for verifying manager functionality.

## Overview

The test framework provides:
- **TestFramework** - Core testing utilities and assertions
- **TestRunner** - Main test runner that executes all manager tests
- **ManagerTests** - Comprehensive test suite for all managers
- **Test Scene** - Scene file for running tests in Godot

## Running Tests

### Method 1: Create a Test Scene

Run the addon’s test scene:

1. Open `res://addons/godot_game_framework/tests/TestScene.tscn`
2. Run the scene (F5)
3. Tests will automatically run and display results in the output console

### Method 2: Programmatic Execution

```gdscript
# In any script
var test_runner = load("res://addons/godot_game_framework/tests/TestRunner.gd").new()
add_child(test_runner)
test_runner.run_all_tests()
```

### Method 3: Using TestFramework Directly

```gdscript
var test_framework = TestFramework.new()
add_child(test_framework)

# Run individual test
test_framework.run_test("my_test", my_test_function)

# Run test suite
var tests = {
    "test1": test_function_1,
    "test2": test_function_2
}
test_framework.run_test_suite("MySuite", tests)
```

## Writing Tests

### Basic Test Structure

```gdscript
func my_test() -> bool:
    # Use assertions
    test_framework.assert_not_null(GGF.get_manager(&"MyManager"), "Manager should exist")
    test_framework.assert_equal(value1, value2, "Values should match")
    test_framework.assert_true(condition, "Condition should be true")
    return true  # Test passes
```

### Available Assertions

- `assert_true(condition, message)` - Assert condition is true
- `assert_false(condition, message)` - Assert condition is false
- `assert_equal(actual, expected, message)` - Assert values are equal
- `assert_not_equal(actual, expected, message)` - Assert values differ
- `assert_null(value, message)` - Assert value is null
- `assert_not_null(value, message)` - Assert value is not null
- `assert_almost_equal(actual, expected, tolerance, message)` - Assert floats are approximately equal
- `fail(message)` - Explicitly fail test
- `pass_test(message)` - Explicitly pass test

### Test Example

```gdscript
func test_audio_volume() -> bool:
    var audio = GGF.get_manager(&"AudioManager")
    var original = audio.master_volume
    
    # Test setting volume
    audio.set_master_volume(0.5)
    test_framework.assert_almost_equal(audio.master_volume, 0.5, 0.01)
    
    # Test clamping
    audio.set_master_volume(2.0)
    test_framework.assert_almost_equal(audio.master_volume, 1.0, 0.01)
    
    # Restore original
    audio.set_master_volume(original)
    return true
```

## Test Structure

```
addons/godot_game_framework/tests/
├── TestFramework.gd      # Core testing utilities
├── TestRunner.gd         # Main test runner
└── ManagerTests.gd       # Addon manager tests
```

## Test Output

Tests output results in the following format:

```
==================================================
Running test suite: AudioManager
==================================================
[TEST] Starting: test_audio_volume_setting
[PASS] test_audio_volume_setting (5ms)
[TEST] Starting: test_audio_music_playback
[PASS] test_audio_music_playback (2ms)
...

==================================================
TEST SUMMARY
==================================================
Total tests: 36
Passed: 35
Failed: 1
Success rate: 97.2%
==================================================
```

## Adding New Tests

### Adding Tests to Existing Suite

Edit `addons/godot_game_framework/tests/ManagerTests.gd` and add your test function:

```gdscript
func run_audio_manager_tests() -> void:
    var tests := {
        "AudioManager exists": test_audiomanager_exists,
        "Volume setting works": test_audio_volume_setting,
        "Your new test": test_your_new_test,  # Add here
    }
    test_framework.run_test_suite("AudioManager", tests)

func test_your_new_test() -> bool:
    # Your test code here
    return true
```

### Creating New Test Suite

```gdscript
func run_my_custom_tests() -> void:
    var tests := {
        "Test 1": test_one,
        "Test 2": test_two,
    }
    test_framework.run_test_suite("MyCustomSuite", tests)
```

## Test Configuration

### TestFramework Options

- `stop_on_first_failure: bool` - Stop running tests on first failure
- `verbose_output: bool` - Print detailed test output

### TestRunner Options

- `auto_run_on_ready: bool` - Automatically run tests when scene loads
- `stop_on_first_failure: bool` - Stop on first test failure

## Best Practices

1. **Isolation** - Each test should be independent
2. **Cleanup** - Restore original state after tests
3. **Descriptive Names** - Use clear test function names
4. **Assertions** - Use appropriate assertions for each check
5. **Error Messages** - Provide helpful error messages

## Example: Complete Test Suite

```gdscript
extends Node

var test_framework: TestFramework

func _ready() -> void:
    test_framework = TestFramework.new()
    add_child(test_framework)
    run_my_tests()

func run_my_tests() -> void:
    var tests := {
        "Manager exists": test_manager_exists,
        "Basic functionality": test_basic_functionality,
        "Edge cases": test_edge_cases,
    }
    test_framework.run_test_suite("MyManager", tests)

func test_manager_exists() -> bool:
    return test_framework.assert_not_null(MyManager, "Manager should exist")

func test_basic_functionality() -> bool:
    MyManager.doSomething()
    return test_framework.assert_true(MyManager.is_done(), "Should be done")

func test_edge_cases() -> bool:
    # Test edge cases
    return true
```

## Integration with CI/CD

The test framework can be integrated into CI/CD pipelines:

```bash
# Run tests using the ggf script
./ggf test
```

## Troubleshooting

### Tests Not Running

- Ensure `GGF` is present as the single autoload (it bootstraps all managers)
- Verify test functions return `bool`

### Linter Warnings for Managers

Managers are instantiated by `GGF`; access them via `GGF.get_manager(...)` to avoid “not declared” lints.

### False Positives

- Check that assertions are actually being evaluated
- Ensure test functions return `true` on success
- Verify cleanup is restoring original state

### Async Tests

For async operations, use `await`:

```gdscript
func test_async_operation() -> bool:
    await some_async_function()
    return test_framework.assert_true(result, "Async operation should complete")
```

## Contributing Tests

When adding new managers or features:
1. Add corresponding tests in `ManagerTests.gd`
2. Follow existing test patterns
3. Test both success and failure cases
4. Include edge case tests
