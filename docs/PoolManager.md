# PoolManager

Object pooling system for improved performance by reusing objects instead of constantly creating and destroying them.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Signals](#signals)
- [Methods](#methods)
- [Virtual Methods](#virtual-methods)
- [Usage Examples](#usage-examples)

## Overview

Features:
- **Object pooling** to reduce garbage collection
- **Auto-expansion** when pools are exhausted
- **Pool statistics** for monitoring
- **Customizable** reset/cleanup behavior

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `default_pool_size` | int | 10 | Default pool size |
| `auto_expand_pools` | bool | true | Auto-expand when exhausted |
| `max_pool_size` | int | 100 | Maximum pool size |

## Signals

```gdscript
signal object_spawned(pool_name: String, object: Node)
signal object_despawned(pool_name: String, object: Node)
signal pool_created(pool_name: String, size: int)
signal pool_cleared(pool_name: String)
```

## Methods

### Pool Management

#### `create_pool(pool_name: String, prefab: PackedScene, initial_size: int = -1) -> bool`
Create a new object pool.

#### `expand_pool(pool_name: String, count: int) -> void`
Manually expand a pool.

#### `clear_pool(pool_name: String) -> void`
Despawn all objects in a pool.

#### `remove_pool(pool_name: String) -> void`
Remove a pool entirely.

#### `pool_exists(pool_name: String) -> bool`
Check if a pool exists.

#### `get_pool_names() -> Array[String]`
Get all pool names.

### Object Spawning

#### `spawn(pool_name: String, position: Vector3 = Vector3.ZERO, parent: Node = null) -> Node`
Spawn an object from a pool.

#### `despawn(pool_name: String, obj: Node) -> bool`
Despawn an object back to the pool.

### Pool Information

#### `get_pool_stats(pool_name: String) -> Dictionary`
Get statistics for a pool.

Returns:
```gdscript
{
    "active_count": int,    # Currently spawned
    "inactive_count": int,  # Available in pool
    "total_count": int,     # Total objects
    "size": int            # Initial pool size
}
```

#### `get_active_objects(pool_name: String) -> Array[Node]`
Get all active objects in a pool.

#### `get_inactive_objects(pool_name: String) -> Array[Node]`
Get all inactive objects in a pool.

#### `clear_all_pools() -> void`
Clear all pools.

## Virtual Methods

### `_reset_object(obj: Node) -> void`
Override to reset object state when spawning.

### `_initialize_object(obj: Node) -> void`
Override to initialize object when added to pool.

### `_cleanup_object(obj: Node) -> void`
Override to cleanup object when despawning.

### `_on_pool_created(pool_name: String, size: int) -> void`
Called when a pool is created.

### `_on_pool_expanded(pool_name: String, count: int) -> void`
Called when a pool is expanded.

### `_on_pool_cleared(pool_name: String) -> void`
Called when a pool is cleared.

### `_on_pool_removed(pool_name: String) -> void`
Called when a pool is removed.

### `_on_object_spawned(pool_name: String, obj: Node) -> void`
Called when an object is spawned from a pool.

### `_on_object_despawned(pool_name: String, obj: Node) -> void`
Called when an object is despawned back to the pool.

## Usage Examples

### Basic Bullet Pool

```gdscript
# Create bullet pool
func _ready() -> void:
    var bullet_scene = preload("res://scenes/bullet.tscn")
    GGF.get_manager(&"PoolManager").create_pool("bullets", bullet_scene, 20)

# Spawn bullets
func shoot() -> void:
    var bullet = GGF.get_manager(&"PoolManager").spawn("bullets", gun_barrel.global_position)
    if bullet:
        bullet.direction = gun_barrel.global_transform.basis.z

# Despawn on collision
func _on_bullet_hit(bullet: Node) -> void:
    GGF.get_manager(&"PoolManager").despawn("bullets", bullet)
```

### Custom Bullet with Reset

```gdscript
# Bullet.gd
extends CharacterBody3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var lifetime: float = 5.0
var elapsed: float = 0.0

func _process(delta: float) -> void:
    if not visible:
        return
    
    velocity = direction * speed
    move_and_slide()
    
    elapsed += delta
    if elapsed >= lifetime:
        GGF.get_manager(&"PoolManager").despawn("bullets", self)

# Called by PoolManager when spawning
func reset() -> void:
    elapsed = 0.0
    direction = Vector3.FORWARD
    global_position = Vector3.ZERO

# Called by PoolManager when despawning
func cleanup() -> void:
    velocity = Vector3.ZERO
```

### Enemy Pool System

```gdscript
class_name EnemySpawner extends Node3D

var enemy_types: Dictionary = {
    "grunt": preload("res://enemies/grunt.tscn"),
    "elite": preload("res://enemies/elite.tscn"),
    "boss": preload("res://enemies/boss.tscn")
}

func _ready() -> void:
    # Create pools for each enemy type
    for type_name in enemy_types:
        GGF.get_manager(&"PoolManager").create_pool(
            "enemy_" + type_name,
            enemy_types[type_name],
            10
        )
    
    # Monitor pool stats
    _print_pool_stats()

func spawn_enemy(type: String, position: Vector3) -> Node:
    var pool_name = "enemy_" + type
    var enemy = GGF.get_manager(&"PoolManager").spawn(pool_name, position, self)
    
    if enemy:
        enemy.died.connect(_on_enemy_died.bind(enemy, pool_name))
    
    return enemy

func _on_enemy_died(enemy: Node, pool_name: String) -> void:
    # Wait for death animation
    await get_tree().create_timer(1.0).timeout
    GGF.get_manager(&"PoolManager").despawn(pool_name, enemy)

func _print_pool_stats() -> void:
    for type_name in enemy_types:
        var pool_name = "enemy_" + type_name
        var stats = GGF.get_manager(&"PoolManager").get_pool_stats(pool_name)
        print("%s: %d active, %d inactive" % [
            pool_name,
            stats.active_count,
            stats.inactive_count
        ])
```

### Particle Effect Pool

```gdscript
class_name VFXManager extends Node

func _ready() -> void:
    # Create pools for common effects
    GGF.get_manager(&"PoolManager").create_pool(
        "explosion",
        preload("res://vfx/explosion.tscn"),
        5
    )
    GGF.get_manager(&"PoolManager").create_pool(
        "smoke",
        preload("res://vfx/smoke.tscn"),
        10
    )
    
    GGF.events().subscribe("explosion", _on_explosion)

func _on_explosion(data: Dictionary) -> void:
    var pos = data.get("position", Vector3.ZERO)
    spawn_effect("explosion", pos)

func spawn_effect(effect_name: String, position: Vector3) -> void:
    var effect = GGF.get_manager(&"PoolManager").spawn(effect_name, position)
    if effect and effect.has_signal("finished"):
        effect.finished.connect(
            func(): GGF.get_manager(&"PoolManager").despawn(effect_name, effect)
        )
```

### Custom PoolManager

```gdscript
extends GGF_PoolManager

# Custom reset for game-specific objects
func _reset_object(obj: Node) -> void:
    # Call base reset if object has reset() method
    if obj.has_method("reset"):
        obj.reset()
    
    # Custom reset logic
    if obj is CharacterBody3D:
        obj.velocity = Vector3.ZERO
    
    if obj.has_method("set_health"):
        obj.set_health(100)

# Custom initialization
func _initialize_object(obj: Node) -> void:
    if obj.has_method("set_pool_manager"):
        obj.set_pool_manager(self)

# Enhanced cleanup
func _cleanup_object(obj: Node) -> void:
    if obj.has_method("cleanup"):
        obj.cleanup()
    
    # Disconnect all signals
    for connection in obj.get_incoming_connections():
        connection.signal.disconnect(connection.callable)
```

### Performance Monitoring

```gdscript
extends GGF_PoolManager

var _stats_timer: Timer

func _ready() -> void:
    super._ready()
    
    # Setup performance monitoring
    _stats_timer = Timer.new()
    _stats_timer.wait_time = 5.0
    _stats_timer.timeout.connect(_print_pool_statistics)
    _stats_timer.autostart = true
    add_child(_stats_timer)

func _print_pool_statistics() -> void:
    print("=== Pool Statistics ===")
    for pool_name in get_pool_names():
        var stats = get_pool_stats(pool_name)
        print("%s: Active=%d, Inactive=%d, Total=%d" % [
            pool_name,
            stats.active_count,
            stats.inactive_count,
            stats.total_count
        ])
        
        # Warn if pool is mostly exhausted
        if stats.inactive_count == 0:
            push_warning("Pool '%s' is exhausted!" % pool_name)
```

## Best Practices

1. **Create pools at startup** for frequently used objects
2. **Size pools appropriately** - too small causes expansion, too large wastes memory
3. **Reset object state** properly to avoid bugs
4. **Implement reset() and cleanup()** methods in pooled objects
5. **Monitor pool stats** during development to tune sizes
6. **Auto-despawn** objects after use (timers, animations, etc.)

## Performance Benefits

Object pooling is beneficial for:
- **Projectiles** (bullets, arrows, spells)
- **Enemies** (spawning/despawning frequently)
- **Particle effects** (explosions, smoke, sparks)
- **UI elements** (damage numbers, notifications)
- **Audio players** (one-shot sounds)

## See Also

- [ResourceManager](ResourceManager.md) - Resource caching
- [EventManager](EventManager.md) - For spawn events
