# Test Framework (Addon)

This directory contains a lightweight test harness for the Godot Game Framework addon.

## Key points

- **Only `GGF` is an autoload**. Managers are created by `GGF` at runtime.
- Prefer **GGF manager accessors** in tests when they exist (e.g. `GGF.ui()`, `GGF.state()`, `GGF.network()`, `GGF.scene()`, `GGF.settings()`, etc.).
- If no accessor exists (e.g. a project-specific manager), use `GGF.get_manager(&"ManagerName")`.
- `GGF.log()`, `GGF.events()`, and `GGF.notifications()` are also valid access points.

## Running tests

1. Open the project in Godot 4.5+
2. Run `res://addons/godot_game_framework/tests/TestScene.tscn`

## Running tests programmatically (same entry point as scripts)

Use the CLI entrypoint script (boots `GGF`, adds `TestRunner`, exits with CI-friendly code):

```bash
godot --headless --path . --script res://addons/godot_game_framework/tests/TestEntryPoint.gd
```

