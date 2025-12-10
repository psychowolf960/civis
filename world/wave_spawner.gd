# EnemyWaveSpawner.gd
extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 800.0
@export var min_spawn_distance: float = 400.0

@onready var multiplayer_spawner = $MultiplayerSpawner

# Variables de vague
var current_wave: int = 0
var wave_active: bool = false
var time_until_next_wave: float = 0.0
var base_wave_delay: float = 10.0
var spawn_timer: float = 0.0
var enemies_alive: int = 0

func _ready():
	# Configure le MultiplayerSpawner
	if multiplayer_spawner:
		multiplayer_spawner.spawn_path = get_path()
		multiplayer_spawner.add_spawnable_scene(enemy_scene.resource_path)
	
	if multiplayer.is_server():
		start_next_wave()

func _process(delta):
	if not multiplayer.is_server():
		return
	
	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			spawn_timer = 8.0 - (current_wave * 0.3)
			spawn_timer = max(spawn_timer, 3.0)
	else:
		time_until_next_wave -= delta
		if time_until_next_wave <= 0:
			start_next_wave()
	
	# Sync HUD sur tous les clients
	if wave_active:
		rpc("update_hud_info", current_wave, enemies_alive)
	else:
		rpc("update_hud_countdown", int(time_until_next_wave))

func start_next_wave():
	if not multiplayer.is_server():
		return
	
	current_wave += 1
	wave_active = true
	spawn_timer = 1.0
	
	# Durée: 20 sec + 5 sec par wave
	var wave_duration = 20.0 + (current_wave * 5.0)
	get_tree().create_timer(wave_duration).timeout.connect(end_wave)
	
	# Sync la wave sur tous les clients
	rpc("sync_wave_start", current_wave)

func spawn_enemy():
	if not enemy_scene or not multiplayer_spawner:
		return
	
	var spawn_pos = get_random_spawn_position()
	
	# Utilise le MultiplayerSpawner pour créer l'ennemi
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_pos
	enemy.name = "Enemy_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	
	# Connecte le signal avant d'ajouter à l'arbre
	if enemy.has_signal("destroyed"):
		enemy.destroyed.connect(_on_enemy_died)
	
	# Ajoute l'ennemi comme enfant du spawner
	# Le MultiplayerSpawner s'occupera de la synchronisation
	add_child(enemy, true)
	
	enemies_alive += 1

func get_random_spawn_position() -> Vector2:
	var target_pos = Vector2.ZERO
	var players = get_tree().get_nodes_in_group("players")
	
	if players.size() > 0:
		# Spawn près d'un joueur aléatoire
		target_pos = players[randi() % players.size()].global_position
	
	var angle = randf() * TAU
	var distance = randf_range(min_spawn_distance, spawn_radius)
	return target_pos + Vector2(cos(angle), sin(angle)) * distance

func _on_enemy_died():
	if not multiplayer.is_server():
		return
	
	enemies_alive = max(0, enemies_alive - 1)

func end_wave():
	if not wave_active:
		return
	
	wave_active = false
	time_until_next_wave = base_wave_delay
	rpc("sync_wave_end")

@rpc("authority", "call_local", "reliable")
func sync_wave_start(wave: int):
	current_wave = wave
	wave_active = true

@rpc("authority", "call_local", "reliable")
func sync_wave_end():
	wave_active = false

@rpc("authority", "call_local", "reliable")
func update_hud_info(wave: int, alive: int):
	Hud.update_wave_info(wave, alive)

@rpc("authority", "call_local", "reliable")
func update_hud_countdown(seconds: int):
	Hud.update_wave_countdown(seconds)
