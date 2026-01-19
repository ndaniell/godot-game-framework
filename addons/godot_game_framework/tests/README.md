# Test Framework (Addon)

This directory contains a lightweight test harness for the Godot Game Framework addon.

## Key points

- **Only `GGF` is an autoload**. Managers are created by `GGF` at runtime.
- Tests should access managers via `GGF.get_manager(&\"ManagerName\")` (or `GGF.log()`, `GGF.events()`, etc.).

## Running tests

1. Open the project in Godot 4.5+
2. Run `res://addons/godot_game_framework/tests/TestScene.tscn`

## Using TestRunner programmatically

```gdscript
var runner := load("res://addons/godot_game_framework/tests/TestRunner.gd").new()
add_child(runner)
runner.run_all_tests()
```

