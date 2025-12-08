## PoissonDiskSampler.gd (Utility Script)
extends RefCounted
class_name PoissonDiskSampler

# --- Configuration ---
const K = 30 # Number of candidates to check around an active point before rejection
var CELL_SIZE: float = 0.0

# --- Core Function ---
# Generates a list of Vector2 points using PDS within a defined region.
# @param radius: The minimum distance between any two generated points.
# @param area_size: The bounds (Vector2(width, height)) of the area.
# @param center: The center offset of the area.
func generate_points(radius: float, area_size: Vector2, center: Vector2 = Vector2.ZERO) -> Array[Vector2]:
	if radius <= 0.0:
		return []

	# 1. Setup Grid and Initialization
	CELL_SIZE = radius / sqrt(2.0)
	var grid_width = ceil(area_size.x / CELL_SIZE)
	var grid_height = ceil(area_size.y / CELL_SIZE)
	var grid: Array = []
	grid.resize(grid_width * grid_height)
	grid.fill(null) # Null indicates an empty cell

	var points: Array[Vector2] = []
	var active_list: Array[Vector2] = []

	# Helper function to convert a point's position to its grid index
	# Origin (0,0) is adjusted by area_size / 2 to handle coordinates around center
	var to_grid_index = func(p: Vector2) -> int:
		var local_p = p - (center - area_size / 2.0)
		var x = floor(local_p.x / CELL_SIZE)
		var y = floor(local_p.y / CELL_SIZE)
		return int(y * grid_width + x)
	
	# Helper function to add a point to the grid and active list
	var add_point = func(p: Vector2):
		points.append(p)
		active_list.append(p)
		var index = to_grid_index.call(p)
		if index >= 0 and index < grid.size():
			grid[index] = p

	# 2. Add initial random point
	var initial_x = randf_range(center.x - area_size.x / 2.0, center.x + area_size.x / 2.0)
	var initial_y = randf_range(center.y - area_size.y / 2.0, center.y + area_size.y / 2.0)
	add_point.call(Vector2(initial_x, initial_y))

	# 3. Iteration (Main Loop)
	var sq_radius = radius * radius
	
	while not active_list.is_empty():
		# Select random point from active list
		var p_index = randi() % active_list.size()
		var p = active_list[p_index]
		
		var found_new = false
		for i in range(K):
			# Generate candidate point in an annulus (ring) around p
			var candidate = generate_random_annulus_point(p, radius)
			
			# Check if candidate is within bounds
			if not is_in_bounds(candidate, area_size, center):
				continue

			# Check if candidate is far enough from existing points
			if is_valid_candidate(candidate, grid, grid_width, grid_height, sq_radius, to_grid_index):
				add_point.call(candidate)
				found_new = true
				break # Found one, move to the next active point
		
		# If no valid candidate was found after K attempts, deactivate p
		if not found_new:
			active_list.remove_at(p_index)
			
	return points

# --- Helper Functions ---

# Generates a point randomly between radius and 2 * radius from p.
func generate_random_annulus_point(p: Vector2, radius: float) -> Vector2:
	# 1. Distance between r and 2r (squared for uniform density over the annulus)
	var r1_sq = radius * radius
	var r2_sq = (2.0 * radius) * (2.0 * radius)
	var r_rand = sqrt(randf_range(r1_sq, r2_sq))
	
	# 2. Angle
	var angle = randf() * TAU # TAU = 2 * PI (360 degrees)
	
	# 3. Calculate offset and return
	var offset = Vector2(cos(angle), sin(angle)) * r_rand
	return p + offset

# Checks if a point is within the spawning boundaries.
func is_in_bounds(p: Vector2, area_size: Vector2, center: Vector2) -> bool:
	var half_size = area_size / 2.0
	var min_bound = center - half_size
	var max_bound = center + half_size
	
	return p.x >= min_bound.x and p.x <= max_bound.x and \
		p.y >= min_bound.y and p.y <= max_bound.y

# Checks if a candidate point is valid (not too close to existing points).
func is_valid_candidate(candidate: Vector2, grid: Array, grid_w: int, grid_h: int, sq_r: float, to_grid_index_func: Callable) -> bool:
	var index = to_grid_index_func.call(candidate)
	
	# Calculate grid coordinates
	var gx = index % grid_w
	var gy = floor(index / grid_w)
	
	# Check 3x3 neighborhood around the candidate's cell
	for y_offset in range(-2, 3):
		for x_offset in range(-2, 3):
			var neighbor_gx = gx + x_offset
			var neighbor_gy = gy + y_offset
			
			# Check boundaries
			if neighbor_gx >= 0 and neighbor_gx < grid_w and \
				neighbor_gy >= 0 and neighbor_gy < grid_h:
				
					var neighbor_index = neighbor_gy * grid_w + neighbor_gx
					var neighbor_p = grid[neighbor_index]
				
					if neighbor_p != null:
					# Check distance (using squared distance for performance)
						if candidate.distance_squared_to(neighbor_p) < sq_r:
							return false # Too close
						
	return true # Valid
