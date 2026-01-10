# API Reference

Complete API reference for all managers in the Godot Game Framework.

## Table of Contents

- [AudioManager](#audiomanager)
- [GameManager](#gamemanager)
- [SaveManager](#savemanager)
- [InputManager](#inputmanager)
- [SceneManager](#scenemanager)
- [UIManager](#uimanager)
- [SettingsManager](#settingsmanager)
- [EventManager](#eventmanager)
- [ResourceManager](#resourcemanager)
- [PoolManager](#poolmanager)
- [TimeManager](#timemanager)
- [NotificationManager](#notificationmanager)

---

## AudioManager

### Properties

- `master_volume: float` (0.0-1.0) - Master volume level
- `music_volume: float` (0.0-1.0) - Music volume level
- `sfx_volume: float` (0.0-1.0) - Sound effects volume level
- `music_bus_name: String` - Name of music audio bus
- `sfx_bus_name: String` - Name of SFX audio bus
- `master_bus_name: String` - Name of master audio bus

### Signals

- `music_changed(track: AudioStream)` - Emitted when music changes
- `sound_effect_played(effect: AudioStream)` - Emitted when SFX plays
- `volume_changed(bus_name: String, volume: float)` - Emitted when volume changes

### Methods

#### Music Control

- `play_music(stream: AudioStream, fade_in: bool = false, fade_duration: float = 1.0) -> void`
- `stop_music(fade_out: bool = false, fade_duration: float = 1.0) -> void`
- `get_current_music() -> AudioStream`
- `is_music_playing() -> bool`

#### Sound Effects

- `play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> AudioStreamPlayer`

#### Volume Control

- `set_master_volume(volume: float) -> void`
- `set_music_volume(volume: float) -> void`
- `set_sfx_volume(volume: float) -> void`

### Virtual Methods (Override)

- `_on_music_started(stream: AudioStream) -> void`
- `_on_music_ended(stream: AudioStream) -> void`
- `_on_sfx_played(stream: AudioStream, player: AudioStreamPlayer) -> void`

---

## GameManager

### Enums

```gdscript
enum GameState {
    MENU,
    PLAYING,
    PAUSED,
    GAME_OVER,
    VICTORY,
    LOADING
}
```

### Properties

- `current_state: GameState` - Current game state
- `is_paused: bool` - Pause state
- `current_scene_path: String` - Current scene path

### Signals

- `game_state_changed(old_state: String, new_state: String)`
- `scene_changed(scene_path: String)`
- `game_paused(is_paused: bool)`
- `game_quit()`

### Methods

#### State Management

- `change_state(new_state: GameState) -> void`
- `get_state_name() -> String`
- `is_in_state(state: GameState) -> bool`

#### Pause Control

- `pause_game() -> void`
- `unpause_game() -> void`
- `toggle_pause() -> void`

#### Scene Management

- `change_scene(scene_path: String, transition_type: String = "") -> void`
- `reload_current_scene() -> void`

#### Game Lifecycle

- `quit_game() -> void`
- `restart_game() -> void`

### Virtual Methods (Override)

- `_on_game_ready() -> void`
- `_on_state_changed(old_state: String, new_state: String) -> void`
- `_on_pause_changed(is_paused: bool) -> void`
- `_on_game_over() -> void`
- `_on_victory() -> void`
- `_on_menu_entered() -> void`
- `_on_loading_started() -> void`
- `_on_game_quit() -> void`
- `_on_game_restart() -> void`

---

## SaveManager

### Properties

- `save_directory: String` - Directory for save files
- `max_save_slots: int` - Maximum number of save slots
- `save_file_prefix: String` - Prefix for save file names
- `save_file_extension: String` - Extension for save files
- `auto_save_enabled: bool` - Enable auto-save
- `auto_save_interval: float` - Auto-save interval in seconds
- `current_save_slot: int` - Current save slot (-1 if none)
- `save_data: Dictionary` - Current save data

### Signals

- `save_created(slot: int, metadata: Dictionary)`
- `save_loaded(slot: int, data: Dictionary)`
- `save_deleted(slot: int)`
- `save_failed(slot: int, error: String)`

### Methods

#### Save/Load

- `save_game(slot: int = 0, metadata: Dictionary = {}) -> bool`
- `load_game(slot: int = 0) -> bool`
- `delete_save(slot: int) -> bool`
- `quick_save() -> bool`
- `quick_load() -> bool`

#### Save Information

- `save_exists(slot: int) -> bool`
- `get_save_metadata(slot: int) -> Dictionary`
- `get_available_saves() -> Array[int]`
- `get_current_save_data() -> Dictionary`
- `set_save_data(data: Dictionary) -> void`

### Virtual Methods (Override)

- `_on_save_manager_ready() -> void`
- `_on_game_saved(slot: int, data: Dictionary) -> void`
- `_on_game_loaded(slot: int, data: Dictionary) -> void`
- `_on_save_deleted(slot: int) -> void`
- `_collect_game_data() -> Dictionary`
- `_collect_player_data() -> Dictionary`
- `_collect_world_data() -> Dictionary`
- `_apply_save_data(data: Dictionary) -> void`
- `_apply_player_data(player_data: Dictionary) -> void`
- `_apply_world_data(world_data: Dictionary) -> void`

---

## InputManager

### Enums

```gdscript
enum InputMode {
    KEYBOARD_MOUSE,
    GAMEPAD,
    TOUCH,
    AUTO
}
```

### Properties

- `current_input_mode: InputMode` - Current input mode
- `remap_file_path: String` - Path for remap file

### Signals

- `input_action_pressed(action: String)`
- `input_action_released(action: String)`
- `input_remapped(action: String, old_event: InputEvent, new_event: InputEvent)`
- `input_mode_changed(mode: String)`

### Methods

#### Input Checking

- `is_action_pressed(action: String) -> bool`
- `is_action_just_pressed(action: String) -> bool`
- `is_action_just_released(action: String) -> bool`
- `get_action_strength(action: String) -> float`
- `get_action_raw_strength(action: String, exact: bool = false) -> float`
- `get_action_vector(negative_x: String, positive_x: String, negative_y: String, positive_y: String, exact: bool = false) -> Vector2`

#### Input Remapping

- `remap_action(action: String, event: InputEvent, remove_old: bool = true) -> bool`
- `reset_action(action: String) -> bool`
- `reset_all_actions() -> void`
- `get_action_remaps(action: String) -> Array`
- `has_remaps(action: String) -> bool`

#### Device Information

- `get_input_device_name() -> String`
- `is_using_gamepad() -> bool`
- `is_using_keyboard_mouse() -> bool`
- `is_using_touch() -> bool`

### Virtual Methods (Override)

- `_on_input_manager_ready() -> void`
- `_on_input_mode_changed(mode: InputMode) -> void`
- `_on_action_pressed(action: String) -> void`
- `_on_action_just_pressed(action: String) -> void`
- `_on_action_just_released(action: String) -> void`
- `_on_action_remapped(action: String, old_event: InputEvent, new_event: InputEvent) -> void`
- `_on_action_reset(action: String) -> void`
- `_restore_default_action(action: String) -> void`

---

## SceneManager

### Properties

- `default_transition_duration: float` - Default transition duration
- `enable_scene_caching: bool` - Enable scene caching
- `max_cached_scenes: int` - Maximum cached scenes

### Signals

- `scene_loaded(scene_path: String, scene_instance: Node)`
- `scene_unloaded(scene_path: String)`
- `scene_preloaded(scene_path: String, packed_scene: PackedScene)`
- `transition_started(from_scene: String, to_scene: String, transition_type: String)`
- `transition_completed(scene_path: String)`

### Methods

#### Scene Loading

- `load_scene(scene_path: String, parent: Node = null, make_current: bool = false) -> Node`
- `unload_scene(scene_path: String, remove_from_cache: bool = true) -> bool`
- `change_scene(scene_path: String, transition_type: String = "") -> void`
- `reload_current_scene() -> void`

#### Scene Preloading

- `preload_scene(scene_path: String) -> PackedScene`
- `unpreload_scene(scene_path: String) -> bool`

#### Scene Information

- `get_loaded_scene(scene_path: String) -> Node`
- `is_scene_loaded(scene_path: String) -> bool`
- `is_scene_preloaded(scene_path: String) -> bool`
- `get_current_scene_path() -> String`
- `get_loaded_scene_paths() -> Array[String]`
- `get_preloaded_scene_paths() -> Array[String]`

#### Cache Management

- `clear_loaded_scenes() -> void`
- `clear_preloaded_scenes() -> void`

### Virtual Methods (Override)

- `_on_scene_manager_ready() -> void`
- `_on_scene_loaded(scene_path: String, scene_instance: Node) -> void`
- `_on_scene_unloaded(scene_path: String) -> void`
- `_on_scene_preloaded(scene_path: String, packed_scene: PackedScene) -> void`
- `_on_transition_started(from_scene: String, to_scene: String, transition_type: String) -> void`
- `_on_transition_completed(scene_path: String) -> void`
- `_perform_transition(from_scene: String, to_scene: String, transition_type: String) -> void`
- `_fade_transition(from_scene: String, to_scene: String) -> void`
- `_slide_transition(from_scene: String, to_scene: String) -> void`

---

## UIManager

### Properties

- `background_layer: int` - Background UI layer
- `game_layer: int` - Game UI layer
- `ui_layer: int` - Main UI layer
- `menu_layer: int` - Menu layer
- `dialog_layer: int` - Dialog layer
- `overlay_layer: int` - Overlay layer

### Signals

- `ui_element_shown(element_name: String)`
- `ui_element_hidden(element_name: String)`
- `menu_opened(menu_name: String)`
- `menu_closed(menu_name: String)`
- `dialog_opened(dialog_name: String)`
- `dialog_closed(dialog_name: String)`
- `focus_changed(old_element: Control, new_element: Control)`

### Methods

#### UI Element Management

- `register_ui_element(name: String, element: Control, layer: int = -1) -> void`
- `unregister_ui_element(name: String) -> void`
- `show_ui_element(name: String, fade_in: bool = false) -> void`
- `hide_ui_element(name: String, fade_out: bool = false) -> void`
- `toggle_ui_element(name: String) -> void`
- `get_ui_element(name: String) -> Control`
- `is_ui_element_visible(name: String) -> bool`

#### Menu Management

- `open_menu(menu_name: String, close_others: bool = false) -> void`
- `close_menu(menu_name: String) -> void`
- `close_all_menus() -> void`
- `is_menu_open(menu_name: String) -> bool`
- `get_open_menus() -> Array[String]`

#### Dialog Management

- `open_dialog(dialog_name: String, modal: bool = true) -> void`
- `close_dialog(dialog_name: String) -> void`
- `close_all_dialogs() -> void`
- `is_dialog_open(dialog_name: String) -> bool`
- `get_open_dialogs() -> Array[String]`

#### Focus Management

- `set_focus(element: Control) -> void`
- `restore_previous_focus() -> void`
- `clear_focus() -> void`
- `get_current_focus() -> Control`

### Virtual Methods (Override)

- `_on_ui_manager_ready() -> void`
- `_on_ui_element_registered(name: String, element: Control) -> void`
- `_on_ui_element_shown(name: String, element: Control) -> void`
- `_on_ui_element_hidden(name: String, element: Control) -> void`
- `_on_menu_opened(menu_name: String) -> void`
- `_on_menu_closed(menu_name: String) -> void`
- `_on_dialog_opened(dialog_name: String) -> void`
- `_on_dialog_closed(dialog_name: String) -> void`
- `_on_focus_changed(old_element: Control, new_element: Control) -> void`

---

## SettingsManager

### Properties

- `settings_file_path: String` - Path to settings file
- `auto_save: bool` - Auto-save settings on change
- `fullscreen: bool` - Fullscreen mode
- `vsync_mode: DisplayServer.VSyncMode` - VSync mode
- `resolution: Vector2i` - Window resolution
- `window_mode: DisplayServer.WindowMode` - Window mode
- `master_volume: float` (0.0-1.0) - Master volume
- `music_volume: float` (0.0-1.0) - Music volume
- `sfx_volume: float` (0.0-1.0) - SFX volume
- `difficulty: String` - Game difficulty
- `language: String` - Game language

### Signals

- `setting_changed(category: String, key: String, value: Variant)`
- `graphics_settings_changed(settings: Dictionary)`
- `audio_settings_changed(settings: Dictionary)`
- `gameplay_settings_changed(settings: Dictionary)`
- `settings_loaded()`
- `settings_saved()`

### Methods

#### Settings Management

- `set_setting(category: String, key: String, value: Variant) -> void`
- `get_setting(category: String, key: String, default_value: Variant = null) -> Variant`
- `load_settings() -> bool`
- `save_settings() -> bool`
- `reset_to_defaults() -> void`

#### Settings Retrieval

- `get_all_settings() -> Dictionary`
- `get_graphics_settings() -> Dictionary`
- `get_audio_settings() -> Dictionary`
- `get_gameplay_settings() -> Dictionary`

### Virtual Methods (Override)

- `_on_settings_manager_ready() -> void`
- `_on_settings_loaded() -> void`
- `_on_settings_saved() -> void`
- `_on_setting_changed(category: String, key: String, value: Variant) -> void`
- `_on_settings_reset() -> void`

---

## EventManager

### Properties

- `enable_event_history: bool` - Enable event history
- `max_history_size: int` - Maximum history size

### Signals

- `event_emitted(event_name: String, data: Dictionary)`
- `listener_added(event_name: String)`
- `listener_removed(event_name: String)`

### Methods

#### Event Subscription

- `subscribe(event_name: String, callable: Callable) -> void`
- `unsubscribe(event_name: String, callable: Callable) -> void`
- `unsubscribe_all(event_name: String) -> void`
- `subscribe_method(event_name: String, target: Object, method: String) -> void`
- `unsubscribe_method(event_name: String, target: Object, method: String) -> void`

#### Event Emission

- `emit(event_name: String, data: Dictionary = {}) -> void`

#### Event Information

- `has_listeners(event_name: String) -> bool`
- `get_listener_count(event_name: String) -> int`
- `get_registered_events() -> Array[String]`

#### History

- `get_event_history() -> Array[Dictionary]`
- `clear_event_history() -> void`
- `clear_all_listeners() -> void`

### Virtual Methods (Override)

- `_on_event_manager_ready() -> void`
- `_on_event_emitted(event_name: String, data: Dictionary) -> void`
- `_on_listener_added(event_name: String, callable: Callable) -> void`
- `_on_listener_removed(event_name: String, callable: Callable) -> void`

---

## ResourceManager

### Properties

- `enable_caching: bool` - Enable resource caching
- `max_cache_size: int` - Maximum cache size
- `auto_unload_unused: bool` - Auto-unload unused resources
- `unload_check_interval: float` - Unload check interval

### Signals

- `resource_loaded(resource_path: String, resource: Resource)`
- `resource_unloaded(resource_path: String)`
- `resource_preloaded(resource_path: String, resource: Resource)`
- `cache_cleared()`

### Methods

#### Resource Loading

- `load_resource(resource_path: String, use_cache: bool = true) -> Resource`
- `load_resource_async(resource_path: String, use_cache: bool = true) -> Resource`
- `unload_resource(resource_path: String, force: bool = false) -> bool`

#### Resource Preloading

- `preload_resource(resource_path: String) -> Resource`
- `unpreload_resource(resource_path: String) -> bool`

#### Cache Management

- `get_cached_resource(resource_path: String) -> Resource`
- `is_resource_cached(resource_path: String) -> bool`
- `is_resource_preloaded(resource_path: String) -> bool`
- `get_cache_size() -> int`
- `get_cached_paths() -> Array[String]`
- `get_preloaded_paths() -> Array[String]`
- `clear_cache() -> void`
- `clear_preloaded() -> void`
- `get_ref_count(resource_path: String) -> int`

### Virtual Methods (Override)

- `_on_resource_manager_ready() -> void`
- `_on_resource_loaded(resource_path: String, resource: Resource) -> void`
- `_on_resource_loaded_from_cache(resource_path: String, resource: Resource) -> void`
- `_on_resource_unloaded(resource_path: String) -> void`
- `_on_resource_preloaded(resource_path: String, resource: Resource) -> void`
- `_on_cache_cleared() -> void`

---

## PoolManager

### Properties

- `default_pool_size: int` - Default pool size
- `auto_expand_pools: bool` - Auto-expand pools when exhausted
- `max_pool_size: int` - Maximum pool size

### Signals

- `object_spawned(pool_name: String, object: Node)`
- `object_despawned(pool_name: String, object: Node)`
- `pool_created(pool_name: String, size: int)`
- `pool_cleared(pool_name: String)`

### Methods

#### Pool Management

- `create_pool(pool_name: String, prefab: PackedScene, initial_size: int = -1) -> bool`
- `expand_pool(pool_name: String, count: int) -> void`
- `clear_pool(pool_name: String) -> void`
- `remove_pool(pool_name: String) -> void`
- `pool_exists(pool_name: String) -> bool`
- `get_pool_names() -> Array[String]`

#### Object Spawning

- `spawn(pool_name: String, position: Vector3 = Vector3.ZERO, parent: Node = null) -> Node`
- `despawn(pool_name: String, obj: Node) -> bool`

#### Pool Information

- `get_pool_stats(pool_name: String) -> Dictionary`
- `get_active_objects(pool_name: String) -> Array[Node]`
- `get_inactive_objects(pool_name: String) -> Array[Node]`
- `clear_all_pools() -> void`

### Virtual Methods (Override)

- `_on_pool_manager_ready() -> void`
- `_on_pool_created(pool_name: String, size: int) -> void`
- `_on_object_spawned(pool_name: String, obj: Node) -> void`
- `_on_object_despawned(pool_name: String, obj: Node) -> void`
- `_on_pool_cleared(pool_name: String) -> void`
- `_reset_object(obj: Node) -> void`
- `_initialize_object(obj: Node) -> void`
- `_cleanup_object(obj: Node) -> void`

---

## TimeManager

### Properties

- `time_scale: float` (0.0-10.0) - Time scale multiplier
- `pause_aware_timers: bool` - Timers respect pause state
- `enable_day_night_cycle: bool` - Enable day/night cycle
- `day_duration: float` - Day duration in seconds
- `night_duration: float` - Night duration in seconds
- `start_time: float` - Cycle start time (0.0-1.0)
- `game_time: float` - Total game time
- `real_time: float` - Total real time
- `delta_time: float` - Scaled delta time
- `unscaled_delta_time: float` - Unscaled delta time

### Signals

- `time_scale_changed(old_scale: float, new_scale: float)`
- `timer_completed(timer_id: String)`
- `day_night_changed(is_day: bool)`
- `time_cycle_changed(cycle_time: float)`

### Methods

#### Time Control

- `set_time_scale(scale: float) -> void`
- `pause_time() -> void`
- `resume_time() -> void`
- `slow_motion(scale: float = 0.5, duration: float = 0.0) -> void`
- `fast_forward(scale: float = 2.0, duration: float = 0.0) -> void`

#### Timers

- `create_timer(timer_id: String, duration: float, loop: bool = false) -> bool`
- `remove_timer(timer_id: String) -> bool`
- `pause_timer(timer_id: String) -> bool`
- `resume_timer(timer_id: String) -> bool`
- `reset_timer(timer_id: String) -> bool`
- `get_timer_progress(timer_id: String) -> float`
- `get_timer_remaining(timer_id: String) -> float`
- `timer_exists(timer_id: String) -> bool`
- `is_timer_paused(timer_id: String) -> bool`

#### Day/Night Cycle

- `get_cycle_time() -> float`
- `is_day() -> bool`
- `is_night() -> bool`

#### Time Information

- `get_game_time() -> float`
- `get_real_time() -> float`
- `get_delta_time() -> float`
- `get_unscaled_delta_time() -> float`
- `format_time(seconds: float, include_milliseconds: bool = false) -> String`

### Virtual Methods (Override)

- `_on_time_manager_ready() -> void`
- `_on_time_scale_changed(old_scale: float, new_scale: float) -> void`
- `_on_timer_created(timer_id: String, duration: float, loop: bool) -> void`
- `_on_timer_completed(timer_id: String) -> void`
- `_on_timer_removed(timer_id: String) -> void`
- `_on_day_night_changed(is_day: bool) -> void`

---

## NotificationManager

### Enums

```gdscript
enum NotificationType {
    INFO,
    SUCCESS,
    WARNING,
    ERROR,
    CUSTOM
}
```

### Properties

- `default_duration: float` - Default notification duration
- `max_notifications: int` - Maximum visible notifications
- `notification_spacing: float` - Spacing between notifications
- `position: Vector2` - Notification position
- `alignment: Vector2` - Notification alignment (0=top/left, 1=bottom/right)

### Signals

- `notification_shown(notification_id: String, data: Dictionary)`
- `notification_hidden(notification_id: String)`
- `notification_clicked(notification_id: String)`

### Methods

#### Notification Display

- `show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = -1.0, data: Dictionary = {}) -> String`
- `show_info(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
- `show_success(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
- `show_warning(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`
- `show_error(message: String, duration: float = -1.0, data: Dictionary = {}) -> String`

#### Notification Management

- `hide_notification(notification_id: String) -> bool`
- `hide_all_notifications() -> void`
- `get_active_count() -> int`
- `get_queued_count() -> int`

### Virtual Methods (Override)

- `_on_notification_manager_ready() -> void`
- `_on_notification_shown(notification_id: String, message: String, type: NotificationType, data: Dictionary) -> void`
- `_on_notification_hidden(notification_id: String) -> void`
- `_on_notification_clicked(notification_id: String, data: Dictionary) -> void`
- `_create_notification_node(message: String, type: NotificationType, data: Dictionary) -> Control`
- `_set_notification_style(panel: Panel, type: NotificationType) -> void`
- `_animate_notification_in(notification: Control) -> void`
- `_animate_notification_out(notification: Control, notification_id: String) -> void`

---

## Common Patterns

### Extending Managers

All managers follow a consistent pattern for extensibility:

1. **Virtual Methods** - Override `_on_*` methods to customize behavior
2. **Signals** - Connect to signals for reactive programming
3. **Export Variables** - Configure in the editor

### Manager Communication

Managers communicate through:
- **EventManager** - For decoupled event-based communication
- **Direct References** - For tight integration (e.g., SettingsManager → AudioManager)
- **Signals** - For reactive updates

### Initialization Order

Managers initialize in autoload order. Use `await get_tree().process_frame` if you need to wait for other managers.

---

For usage examples, see [USAGE.md](USAGE.md).
