# Godot Game Framework (GGF)

Reusable managers and systems for Godot **4.5+**.

## Install

- Copy the `addons/godot_game_framework/` folder into your project’s `addons/` folder.
- In Godot: **Project → Project Settings → Plugins** → enable **Godot Game Framework**.

## Use

The framework registers `GGF` as an autoload. You can access managers via:

```gdscript
GGF.get_manager(&"AudioManager")
GGF.get_manager(&"GameManager")
GGF.get_manager(&"SaveManager")
```

## Documentation

See the repository’s `docs/` folder for manager-specific guides.

## License

MIT. See `LICENSE` in this folder.

