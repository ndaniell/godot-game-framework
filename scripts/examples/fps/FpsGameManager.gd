extends "res://scripts/autoload/GameManager.gd"

const SCENE_FPS_MAIN := "res://scenes/fps/FpsMain.tscn"
const SCENE_ARENA := "res://scenes/fps/levels/Arena01.tscn"
const SCENE_TEST := "res://scenes/test/TestScene.tscn"

# Late-join queueing during arena loading transitions
var _arena_loading_in_progress: bool = false
var _queued_late_joiners: Array[int] = []

func _is_test_run() -> bool:
	var tree := get_tree()
	if tree == null:
		return _is_test_run_from_cmdline()
	var current := tree.current_scene
	if current != null and current.scene_file_path == SCENE_TEST:
		return true
	return _is_test_run_from_cmdline()

func _is_test_run_from_cmdline() -> bool:
	# `ggf test` launches Godot with `--script /tmp/ggf_test_runner.gd`.
	# At that point the current scene may still be the project's configured main scene,
	# so we use the command line as the reliable detection signal.
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if str(args[i]) == "--script" and i + 1 < args.size():
			var script_path := str(args[i + 1])
			if script_path.ends_with("ggf_test_runner.gd"):
				return true
	return false

func _ready() -> void:
	LogManager.info("FpsGameManager", "FpsGameManager initializing...")
	super._ready()
	LogManager.info("FpsGameManager", "FpsGameManager ready")

func _on_game_ready() -> void:
	if _is_test_run():
		LogManager.debug("FpsGameManager", "Detected TestScene run; skipping FPS scene forcing")
		return

	if EventManager:
		EventManager.subscribe("fps_match_start", _on_match_start)
		EventManager.subscribe("network_disconnected", _on_network_disconnected)
		EventManager.subscribe("peer_joined", _on_peer_joined)

	# Ensure we start on the example main scene.
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != SCENE_FPS_MAIN:
		change_state("MENU")
		change_scene(SCENE_FPS_MAIN, "fade")

func _exit_tree() -> void:
	if EventManager:
		EventManager.unsubscribe("fps_match_start", _on_match_start)
		EventManager.unsubscribe("network_disconnected", _on_network_disconnected)
		EventManager.unsubscribe("peer_joined", _on_peer_joined)

func _on_menu_entered() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_state_changed(old_state: String, new_state: String) -> void:
	super._on_state_changed(old_state, new_state)
	if _is_test_run():
		return
	match new_state:
		"MENU":
			if current_scene_path != SCENE_FPS_MAIN:
				change_scene(SCENE_FPS_MAIN, "fade")
		"PLAYING":
			if current_scene_path != SCENE_ARENA:
				# Mark that arena loading is in progress
				_arena_loading_in_progress = true
				change_scene(SCENE_ARENA, "fade")

func _on_scene_changed(scene_path: String) -> void:
	super._on_scene_changed(scene_path)

	# If the arena just finished loading, process any queued late joiners
	if scene_path == SCENE_ARENA and _arena_loading_in_progress:
		_arena_loading_in_progress = false
		_process_queued_late_joiners()

func _on_match_start(_data: Dictionary) -> void:
	# Fired by NetworkManager.broadcast_session_event from the host; all peers receive it.
	change_state("PLAYING")

func _on_network_disconnected(_data: Dictionary) -> void:
	change_state("MENU")

func _on_peer_joined(data: Dictionary) -> void:
	# Late-join support: if the match is already running, tell the new peer to load Arena01.
	if not multiplayer.is_server():
		return
	if current_state != "PLAYING":
		return
	var peer_id := int(data.get("peer_id", 0))
	if peer_id <= 0:
		return

	# If arena is still loading, queue the peer for later
	if _arena_loading_in_progress:
		_queued_late_joiners.append(peer_id)
		LogManager.debug("FpsGameManager", "Queued late joiner " + str(peer_id) + " (arena loading in progress)")
	else:
		# Arena is ready, send match start immediately
		if NetworkManager:
			NetworkManager.send_session_event_to_peer(peer_id, &"fps_match_start", {})

func _process_queued_late_joiners() -> void:
	if not multiplayer.multiplayer_peer or not multiplayer.is_server() or not NetworkManager:
		return

	LogManager.debug("FpsGameManager", "Processing " + str(_queued_late_joiners.size()) + " queued late joiners")
	for peer_id in _queued_late_joiners:
		NetworkManager.send_session_event_to_peer(peer_id, &"fps_match_start", {})

	_queued_late_joiners.clear()
