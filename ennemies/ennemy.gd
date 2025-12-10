extends CharacterBody2D
class_name Enemy

signal destroyed()

@export_group("Stats")
@export var max_health: int = 4
@export var speed: float = 30.0
@export var damage: int = 2

@export_group("AI")
@export var chase_range: float = 300.0
@export var lose_range: float = 500.0 # Stop chasing if player gets this far
@export var attack_range: float = 25.0 # Increased slightly for reliability
@export var separation_force: float = 400.0 # Force to push away from other enemies

@export_group("Visuals")
@export var bounce_speed: float = 15.0
@export var bounce_amplitude: float = 0.15

var current_health: int
var target: Node2D = null
var is_destroyed: bool = false
var can_attack: bool = true
var knockback: Vector2 = Vector2.ZERO
var walk_time: float = 0.0

# Optimization: Only scan for players occasionally
var target_scan_interval: float = 0.5
var target_scan_timer: float = 0.0

@onready var sprite = $Sprite2D
@onready var hit_sfx = $HitSFX
@onready var death_sfx = $DeathSFX
@onready var original_scale = sprite.scale if sprite else Vector2.ONE

func _ready():
	current_health = max_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_destroyed: return

	# Handle Knockback
	if knockback.length_squared() > 10:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 10 * delta)
		move_and_slide()
		return

	_handle_targeting(delta)
	_handle_movement_and_attack(delta)
	_handle_proc_animation(delta)

func _handle_targeting(delta: float):
	target_scan_timer -= delta
	if target_scan_timer > 0: return
	
	target_scan_timer = target_scan_interval
	
	# If we have a target, check if we should lose it
	if target and is_instance_valid(target):
		var dist = global_position.distance_squared_to(target.global_position)
		if dist > lose_range * lose_range:
			target = null
		return

	# Find new target
	var nearest: Node2D = null
	var min_dist = chase_range * chase_range
	
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	
	target = nearest

func _handle_movement_and_attack(delta: float):
	if not target or not is_instance_valid(target):
		velocity = velocity.lerp(Vector2.ZERO, 10 * delta)
		move_and_slide()
		return

	var dist = global_position.distance_to(target.global_position)

	if dist <= attack_range:
		velocity = Vector2.ZERO
		if can_attack: _attack()
	else:
		# Movement with Separation (Soft Collision)
		var direction = global_position.direction_to(target.global_position)
		var separation = _get_separation_vector()
		
		# Combine chase direction with separation force
		var final_dir = (direction * speed + separation).limit_length(speed)
		velocity = final_dir
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	elif target:
		sprite.flip_h = target.global_position.x < global_position.x
	move_and_slide()

func _get_separation_vector() -> Vector2:
	var separation = Vector2.ZERO
	var nearby = get_tree().get_nodes_in_group("enemies")
	# Limit check to a small number or use an Area2D for better performance
	var count = 0
	for enemy in nearby:
		if count > 5: break # Optimization: check only first few neighbors
		if enemy == self or not is_instance_valid(enemy): continue
		
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		# Only separate if very close (e.g. 40 pixels)
		if dist_sq < 1600: 
			var push = global_position - enemy.global_position
			separation += push.normalized() * (separation_force / (dist_sq / 100.0 + 1.0))
			count += 1
	return separation

func _handle_proc_animation(delta: float):
	if not sprite: return
	
	if velocity.length() > 10:
		walk_time += delta * bounce_speed
		var stretch = sin(walk_time) * bounce_amplitude
		sprite.scale = original_scale + Vector2(stretch, -stretch)
		sprite.rotation_degrees = sin(walk_time * 0.5) * 5
	else:
		walk_time = 0.0
		sprite.scale = sprite.scale.lerp(original_scale, 10 * delta)
		sprite.rotation = lerp(sprite.rotation, 0.0, 10 * delta)

func _attack():
	can_attack = false
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	await get_tree().create_timer(1.0).timeout
	can_attack = true

@rpc("any_peer", "call_remote", "reliable")
func request_damage(amount: int, id: int):
	if multiplayer.is_server() and not is_destroyed:
		take_damage(amount, id)

func take_damage(amount: int, attacker_id: int):
	if is_destroyed: return
	
	current_health -= amount
	if sprite.flip_h:
		knockback = target.global_position * 1.0
	else:
		knockback = target.global_position * -1.0
	play_hit_fx.rpc()
	
	if current_health <= 0:
		die()

@rpc("call_local")
func play_hit_fx():
	if hit_sfx: hit_sfx.play()
	if not sprite: return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 0.5, 0.5), 0.1) # Flash bright red
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func die():
	is_destroyed = true
	destroyed.emit()
	play_death_fx.rpc()

@rpc("call_local")
func play_death_fx():
	if death_sfx: death_sfx.play()
	set_physics_process(false) # Stop calculating immediately
	
	if sprite:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 0.0), 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
	
	queue_free()
