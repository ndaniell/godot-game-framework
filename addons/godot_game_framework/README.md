# Godot Game Framework (GGF)

Reusable managers and systems for Godot **4.5+**.

## Install

- Copy the `addons/godot_game_framework/` folder into your project’s `addons/` folder.
- In Godot: **Project → Project Settings → Plugins** → enable **Godot Game Framework**.

## Use

The framework registers `GGF` as an autoload.

Prefer the built-in manager accessors when they exist:

```gdscript
var audio := GGF.audio()
var save := GGF.save()
var ui := GGF.ui()
var net := GGF.network()
var sm := GGF.state()
var scene := GGF.scene()
```

If no accessor exists (e.g. a project-specific manager), use:

```gdscript
var my_manager := GGF.get_manager(&"MyManager")
```

## Documentation

See the repository’s `docs/` folder for manager-specific guides.

## License

MIT. See `LICENSE` in this folder.

