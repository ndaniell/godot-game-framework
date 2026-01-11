# Example: Multiplayer FPS (ENet, Desktop)

This repository includes a small **multiplayer FPS example** intended to exercise the framework managers and serve as a starting point.

## How to run

1. Open the project in Godot 4.5+.
2. Run the project (it boots into `res://scenes/fps/FpsMain.tscn`).

### Host

- Click **Host**.
- In Lobby, click **Host** again (or just use the Host button there).
- Click **Start Match**.

### Join

- Run a second instance of the game.
- Click **Join**.
- Enter the host IP + port (default `8910`).
- Click **Join**.

## Controls

- **W/A/S/D**: Move
- **Mouse**: Look
- **Space**: Jump
- **Left mouse**: Shoot
- **V**: Toggle first-person / third-person

## What this demonstrates

- **`GameManager`**: overridden by `res://scripts/examples/fps/FpsGameManager.gd` to boot into the example and drive MENU/PLAYING scene changes.
- **`InputManager`**: overridden by `res://scripts/examples/fps/FpsInputManager.gd` to define FPS actions and default bindings.
- **`UIManager`**: `FpsMain` registers the menu + lobby; `Arena01` registers the HUD.
- **`EventManager`**: menu/lobby/hud are wired with events (`fps_lobby_open`, `network_connected`, `match_started`, etc.).
- **`NetworkManager`**: `res://scripts/autoload/NetworkManager.gd` hosts/joins ENet and provides a generic `broadcast_session_event(...)` helper.

## Files to explore

- `scenes/fps/FpsMain.tscn`
- `scenes/fps/ui/MainMenu.tscn`
- `scenes/fps/ui/Lobby.tscn`
- `scenes/fps/levels/Arena01.tscn`
- `scenes/fps/player/Player.tscn`
- `scripts/autoload/NetworkManager.gd`

