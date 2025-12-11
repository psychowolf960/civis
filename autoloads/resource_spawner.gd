# ResourceSpawner.gd
extends Node

@export var wood_scene: PackedScene
@export var stone_scene: PackedScene
@export var food_scene: PackedScene
@export var spawn_area_origin := Vector2(-800.0, -210.0)
@export var spawn_area_size := Vector2(2700.0, 1300.0)
@export var wood_count := 100
@export var stone_count := 50
@export var food_count := 40
@export var min_distance := 100.0
@export var cluster_chance := 0.3  # 30% chance de créer un cluster
@export var cluster_size := 5  # Nombre de ressources par cluster
@export var cluster_radius := 150.0  # Rayon du cluster
@export var world_seed := 12345

var resources := {} 
var next_resource_id := 0

func _ready():
	if multiplayer.is_server():
		spawn_all_resources()
	else:
		request_full_sync.rpc_id(1)

func spawn_all_resources():
	seed(world_seed)
	spawn_resource_type("wood", wood_scene, wood_count)
	spawn_resource_type("stone", stone_scene, stone_count)
	spawn_resource_type("food", food_scene, food_count)

func spawn_resource_type(type: String, scene: PackedScene, count: int):
	var spawned = 0
	while spawned < count:
		# Décider si on crée un cluster
		if randf() < cluster_chance and spawned + cluster_size <= count:
			spawn_cluster(type, scene, cluster_size)
			spawned += cluster_size
		else:
			var pos = get_valid_spawn_position()
			create_resource(type, scene, pos)
			spawned += 1

func spawn_cluster(type: String, scene: PackedScene, size: int):
	var center = get_valid_spawn_position()
	for i in range(size):
		var angle = randf() * TAU
		var distance = randf_range(0, cluster_radius)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var pos = center + offset
		# S'assurer que la position reste dans la zone de spawn
		pos.x = clamp(pos.x, spawn_area_origin.x, spawn_area_origin.x + spawn_area_size.x)
		pos.y = clamp(pos.y, spawn_area_origin.y, spawn_area_origin.y + spawn_area_size.y)
		create_resource(type, scene, pos)

func get_valid_spawn_position() -> Vector2:
	var max_attempts = 100
	for attempt in range(max_attempts):
		var pos = Vector2(
			randf_range(spawn_area_origin.x, spawn_area_origin.x + spawn_area_size.x),
			randf_range(spawn_area_origin.y, spawn_area_origin.y + spawn_area_size.y)
		)
		if is_position_valid(pos):
			return pos
	return Vector2(
		randf_range(spawn_area_origin.x, spawn_area_origin.x + spawn_area_size.x),
		randf_range(spawn_area_origin.y, spawn_area_origin.y + spawn_area_size.y)
	)

func is_position_valid(pos: Vector2) -> bool:
	for res_data in resources.values():
		if pos.distance_to(res_data.position) < min_distance:
			return false
	return true

func create_resource(type: String, scene: PackedScene, pos: Vector2):
	var resource_id = next_resource_id
	next_resource_id += 1
	
	resources[resource_id] = {
		"type": type,
		"position": pos,
		"health": 100
	}
	
	spawn_resource_instance(resource_id, type, scene, pos)
	rpc("sync_resource_spawn", resource_id, type, pos)

func spawn_resource_instance(id: int, type: String, scene: PackedScene, pos: Vector2):
	var resource = scene.instantiate()
	resource.name = "Resource_" + str(id) 
	resource.position = pos
	resource.resource_id = id
	resource.resource_type = type
	
	resource.destroyed.connect(_on_resource_destroyed.bind(id))
	add_child(resource)

@rpc("authority", "call_local", "reliable")
func sync_resource_spawn(id: int, type: String, pos: Vector2):
	if multiplayer.is_server(): return
	var scene = get_scene_for_type(type)
	if scene:
		spawn_resource_instance(id, type, scene, pos)

func get_scene_for_type(type: String) -> PackedScene:
	match type:
		"wood": return wood_scene
		"stone": return stone_scene
		"food": return food_scene
	return null

func _on_resource_destroyed(resource_id: int):
	if multiplayer.is_server():
		resources.erase(resource_id)

@rpc("any_peer", "call_local", "reliable")
func request_full_sync():
	if multiplayer.is_server():
		var peer_id = multiplayer.get_remote_sender_id()
		rpc_id(peer_id, "receive_full_sync", resources)

@rpc("authority", "call_local", "reliable")
func receive_full_sync(server_resources: Dictionary):
	for child in get_children():
		if child.name.begins_with("Resource_"):
			child.queue_free()
	
	for res_id in server_resources:
		var data = server_resources[res_id]
		var scene = get_scene_for_type(data.type)
		if scene:
			spawn_resource_instance(res_id, data.type, scene, data.position)
