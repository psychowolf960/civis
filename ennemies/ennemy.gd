extends CharacterBody2D
class_name Enemy

signal destroyed()

@export_group("Stats")
@export var max_health: int = 10
@export var speed: float = 120.0
@export var damage: int = 2
@export var knockback_force: float = 300.0

@export_group("AI")
@export var chase_range: float = 300.0
@export var separation_force: float = 400.0

@onready var sprite = $Sprite2D
@onready var hit_sfx = $HitSFX
@onready var death_sfx = $DeathSFX

var current_health: int
var target: Node2D
var is_destroyed: bool = false
var can_attack: bool = true
var knockback: Vector2 = Vector2.ZERO
var scan_timer: float = 0.0

func _ready():
	current_health = max_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if is_destroyed: return

	# Knockback processing
	if knockback.length_squared() > 10:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 10 * delta)
		move_and_slide()
		return

	_scan_target(delta)
	
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= 25.0: # Attack range
			velocity = Vector2.ZERO
			if can_attack: _attack()
		else:
			var dir = global_position.direction_to(target.global_position)
			velocity = (dir * speed + _get_separation()).limit_length(speed)
			sprite.flip_h = velocity.x < 0
		move_and_slide()
	else:
		velocity = velocity.lerp(Vector2.ZERO, 10 * delta)

	_animate_proc(delta)

func _scan_target(delta: float):
	scan_timer -= delta
	if scan_timer > 0: return
	scan_timer = 0.5
	
	# Keep target if within lose range (500)
	if target and global_position.distance_squared_to(target.global_position) < 250000: return

	var nearest: Node2D
	var min_dist = chase_range * chase_range
	for p in get_tree().get_nodes_in_group("players"):
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	target = nearest

func _get_separation() -> Vector2:
	var force = Vector2.ZERO
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if count >= 5: break
		if enemy == self: continue
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < 1600: # 40px radius
			force += (global_position - enemy.global_position).normalized() * (separation_force / (dist_sq * 0.01 + 1))
			count += 1
	return force

func _animate_proc(delta: float):
	if velocity.length() > 10:
		var t = Time.get_ticks_msec() * 0.015
		sprite.scale = Vector2(1.0 - sin(t) * 0.05, 1.0 + sin(t) * 0.15)
		sprite.rotation_degrees = sin(t * 0.5) * 5
	else:
		sprite.scale = sprite.scale.lerp(Vector2.ONE, 10 * delta)
		sprite.rotation = lerp(sprite.rotation, 0.0, 10 * delta)

func _attack():
	can_attack = false
	if target.has_method("take_damage"): target.take_damage(damage)
	await get_tree().create_timer(1.0).timeout
	can_attack = true

@rpc("any_peer", "call_local")
func take_damage(amount: int, _attacker_id: int = 0):
	if is_destroyed: return
	current_health -= amount
	
	# FIXED: Calculate direction away from target instead of using world position
	if target and is_instance_valid(target):
		knockback = (global_position - target.global_position).normalized() * knockback_force
	else:
		knockback = Vector2.RIGHT.rotated(randf() * TAU) * knockback_force

	_play_fx.rpc()
	if current_health <= 0: _die()

@rpc("call_local")
func _play_fx():
	if hit_sfx: hit_sfx.play()
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2, 0.5, 0.5), 0.1)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _die():
	is_destroyed = true
	destroyed.emit()
	if death_sfx: death_sfx.play()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(1.5, 0), 0.3)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()
