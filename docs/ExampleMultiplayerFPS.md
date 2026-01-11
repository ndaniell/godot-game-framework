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
- **`NetworkManager`**: `res://scripts/autoload/NetworkManager.gd` provides generic networking foundation
- **`FPSNetworkManager`**: `res://scripts/examples/fps/FpsNetworkManager.gd` extends NetworkManager with FPS-specific features like arena ready coordination
- **`LogManager`**: enhanced with per-instance logging (PID-based instance tags, peer/role context, file output).

## Networking Architecture

### Server-Authoritative Movement with Client-Side Prediction

The FPS example implements a **server-authoritative movement system with client-side prediction and reconciliation**:

- **Server Authority**: The server simulates all physics and sends periodic snapshots to clients for reconciliation.
- **Client Prediction**: Owning clients predict movement locally for immediate responsiveness, then reconcile with server state.
- **Reconciliation**: Clients rewind to authoritative server state, replay unacked inputs, and apply the corrected state.

### Movement Flow

1. **Client Input**: Player presses movement keys → input sent to server with sequence number
2. **Local Prediction**: Client simulates movement immediately for responsive feel
3. **Server Simulation**: Server receives input, simulates authoritative physics, sends snapshots
4. **Reconciliation**: Client applies server snapshot, rewinds, replays inputs from corrected state

### Late-Join Handling

The example includes **robust late-join support** to prevent RPC errors when clients connect during level transitions:

- **Arena Ready Handshake**: Clients report when their level is loaded before spawning players via FPSNetworkManager
- **Transition Queueing**: Late-joining peers are queued during arena loading, sent match-start once ready
- **Stable RPC Paths**: Uses specialized FPSNetworkManager extending the generic NetworkManager

### Match Start Sequence

1. Host clicks "Start Match" → `NetworkManager.broadcast_session_event("fps_match_start")`
2. All peers (including late joiners) receive event → transition to PLAYING state
3. Each peer loads `Arena01.tscn` → reports arena ready via NetworkManager
4. Once arena is confirmed loaded, players are spawned via MultiplayerSpawner
5. Game begins with prediction/reconciliation active

## Logging Features

The example showcases **multi-instance logging** for development and debugging:

- **Instance Tags**: Each running game instance gets a unique PID-based identifier
- **Peer Context**: Logs include peer ID and server/client role when connected
- **File Output**: Logs are written to `user://logs/{project}_{instance}.log`
- **Console Output**: Instance/pier/role prefixes appear in Godot's output panel

## Files to explore

- `scenes/fps/FpsMain.tscn`
- `scenes/fps/ui/MainMenu.tscn`
- `scenes/fps/ui/Lobby.tscn`
- `scenes/fps/levels/Arena01.tscn`
- `scenes/fps/player/Player.tscn`
- `scripts/autoload/NetworkManager.gd`
- `scripts/examples/fps/FpsNetworkManager.gd`

