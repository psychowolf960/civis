## ResourceSpawner.gd (Modified)
extends Node2D

# Scènes à spawner
@export var wood_scene: PackedScene
@export var stone_scene: PackedScene
@export var food_scene: PackedScene

# Zone de spawn
@export var spawn_area_size := Vector2(2000, 2000)
@export var spawn_center := Vector2.ZERO

# Nouvelle propriété : Distance minimale POISSON DISK
@export var min_resource_radius := 100.0 # Set this value higher for better separation

# Quantités par type
@export var wood_count := 50
@export var stone_count := 40
@export var food_count := 30
# ⚙️ Configuration des Probabilités de Taille (Required for get_random_size)
@export var size_probabilities := {
	"small": 0.4,   # 40% chance
	"normal": 0.35, # 35% chance
	"big": 0.2,     # 20% chance
	"large": 0.05   # 5% chance
}

# Stats par taille (Assumed to be already in your script)
var size_data := {
	"small": {"scale": 0.6, "health_mult": 0.5, "amount_mult": 0.5},
	"normal": {"scale": 1.0, "health_mult": 1.0, "amount_mult": 1.0},
	"big": {"scale": 1.4, "health_mult": 1.5, "amount_mult": 1.5},
	"large": {"scale": 2.0, "health_mult": 2.5, "amount_mult": 2.5}
}

var poisson_sampler: PoissonDiskSampler

@onready var multiplayer_spawner = $MultiplayerSpawner

func _ready():
	# Instantiate the sampler utility
	poisson_sampler = PoissonDiskSampler.new()
	
	if multiplayer.is_server():
		spawn_all_resources()

func spawn_all_resources():
	# 1. Calculate the total number of points needed (assuming one shared pool for density)
	var total_count = wood_count + stone_count + food_count
	
	# 2. Generate a single, uniform set of points using Poisson Disk Sampling
	# NOTE: The sampler might generate fewer points than 'total_count' if the area is too dense.
	var all_spawn_positions: Array[Vector2] = poisson_sampler.generate_points(
		min_resource_radius,
		spawn_area_size,
		spawn_center
	)
	
	# 3. Distribute the generated positions across resource types
	
	# Shuffle the positions to ensure resources are mixed, not clumped by type
	all_spawn_positions.shuffle()
	
	var current_index = 0
	
	# Spawn Wood
	var wood_positions_to_use = min(wood_count, all_spawn_positions.size() - current_index)
	spawn_resource_type_at_positions(wood_scene, wood_positions_to_use, all_spawn_positions, current_index)
	current_index += wood_positions_to_use
	
	# Spawn Stone
	var stone_positions_to_use = min(stone_count, all_spawn_positions.size() - current_index)
	spawn_resource_type_at_positions(stone_scene, stone_positions_to_use, all_spawn_positions, current_index)
	current_index += stone_positions_to_use
	
	# Spawn Food (uses the rest of the positions)
	var food_positions_to_use = min(food_count, all_spawn_positions.size() - current_index)
	spawn_resource_type_at_positions(food_scene, food_positions_to_use, all_spawn_positions, current_index)

# New function to handle spawning at pre-calculated positions
func spawn_resource_type_at_positions(scene: PackedScene, count: int, positions: Array[Vector2], start_index: int):
	if not scene:
		return
		
	for i in range(count):
		var resource = scene.instantiate()
		
		var pos = positions[start_index + i]
		resource.global_position = pos
		
		# Taille aléatoire basée sur rareté
		var size = get_random_size()
		apply_size_stats(resource, size)
		
		# Ajoute au monde
		add_child(resource)


# NOTE: get_random_position() is now redundant and can be removed.
# ... (get_random_size() and apply_size_stats() remain unchanged) ...

# Debug: Visualise la zone de spawn
func _draw():
	if Engine.is_editor_hint():
		var rect = Rect2(
			spawn_center - spawn_area_size / 2,
			spawn_area_size
		)
		draw_rect(rect, Color(0, 1, 0, 0.2))
		draw_rect(rect, Color(0, 1, 0, 0.8), false, 2)
# ResourceSpawner.gd (Insert these functions after spawn_resource_type_at_positions)

# Chooses a size based on predefined rarity probabilities
func get_random_size() -> String:
	var rand_val = randf()
	# size_probabilities is assumed to be defined as:
	# var size_probabilities := {"small": 0.4, "normal": 0.35, "big": 0.2, "large": 0.05}
	var cumulative_prob = 0.0
	for size in size_probabilities.keys():
		cumulative_prob += size_probabilities[size]
		if rand_val < cumulative_prob:
			return size
	return "normal" # Fallback

# Applies scale and stat multipliers based on the chosen size
func apply_size_stats(resource: Node2D, size: String):
	# size_data is assumed to be defined as:
	# var size_data := { ... }
	if size_data.has(size):
		var stats = size_data[size]
		resource.scale = Vector2.ONE * stats.scale
		
		# Check if the resource has the necessary properties (e.g., Health, Amount)
		if resource.has_method("set_health"):
			resource.set_health(resource.base_health * stats.health_mult)
		if resource.has_method("set_amount"):
			resource.set_amount(resource.base_amount * stats.amount_mult)
