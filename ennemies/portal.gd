extends Node2D
class_name SpawnPortal

@export_group("Spawn Settings")
@export var spawn_interval: float = 5.0
@export var max_active_enemies: int = 10
@export var spawn_radius: float = 50.0

@export_group("Enemy Types")
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[float] = [1.0] # Probability weights for each enemy type

@export_group("Visuals")
@export var portal_color: Color = Color.PURPLE

var spawn_timer: float = 0.0
var active_enemies: Array[Enemy] = []

@onready var sprite = $Sprite2D
@onready var particles = $GPUParticles2D
@onready var spawn_sfx = $SpawnSFX
@onready var multiplayer_spawner = $MultiplayerSpawner

func _ready():
	if multiplayer.is_server():
		spawn_timer = spawn_interval
	
	# Setup visual effects
	if sprite:
		sprite.modulate = portal_color
	if particles:
		particles.modulate = portal_color
	
	# Normalize weights if needed
	if enemy_weights.size() != enemy_scenes.size():
		enemy_weights.resize(enemy_scenes.size())
		enemy_weights.fill(1.0)

func _process(delta: float):
	if not multiplayer.is_server():
		return
	
	# Clean up destroyed enemies from tracking
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_destroyed)
	
	# Spawn logic
	spawn_timer -= delta
	if spawn_timer <= 0 and active_enemies.size() < max_active_enemies:
		spawn_enemy()
		spawn_timer = spawn_interval

func spawn_enemy():
	if enemy_scenes.is_empty():
		push_error("SpawnPortal: No enemy scenes assigned!")
		return
	
	# Pick random enemy type based on weights
	var enemy_scene = _get_weighted_random_enemy()
	if not enemy_scene:
		return
	
	# Calculate spawn position with random offset
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * randf_range(0, spawn_radius)
	var spawn_pos = global_position + offset
	
	# Spawn enemy using MultiplayerSpawner
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy))
	
	# Add to scene through MultiplayerSpawner's parent
	get_parent().add_child(enemy, true)
	active_enemies.append(enemy)
	
	# Play effects
	play_spawn_fx.rpc(spawn_pos)

func _get_weighted_random_enemy() -> PackedScene:
	# Calculate total weight
	var total_weight = 0.0
	for weight in enemy_weights:
		total_weight += weight
	
	# Pick random value
	var random_value = randf() * total_weight
	
	# Find which enemy this corresponds to
	var cumulative = 0.0
	for i in enemy_scenes.size():
		cumulative += enemy_weights[i]
		if random_value <= cumulative:
			return enemy_scenes[i]
	
	# Fallback to first enemy
	return enemy_scenes[0]

func _on_enemy_destroyed(enemy: Enemy):
	active_enemies.erase(enemy)

@rpc("call_local", "reliable")
func play_spawn_fx(pos: Vector2):
	if spawn_sfx:
		spawn_sfx.play()
	
	# Create spawn effect
	if particles:
		var effect = particles.duplicate()
		get_parent().add_child(effect)
		effect.global_position = pos
		effect.emitting = true
		effect.finished.connect(effect.queue_free)
