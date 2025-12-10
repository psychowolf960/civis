# ResourceNode.gd
extends StaticBody2D
class_name ResourceNode

signal destroyed()

@export var resource_type: String = "wood"
@export var resource_amount: int = 10
@export var max_health: int = 5

var resource_id: int = -1
var health: int
var last_attacker_id: int = -1
var is_destroyed: bool = false
var is_animating := false

@onready var sprite = $RessourceSprite
var original_position: Vector2

func _ready():
	health = max_health
	if sprite:
		original_position = sprite.position
	add_to_group("resources")

@rpc("any_peer", "call_remote", "reliable")
func request_damage(player_id: int):
	if multiplayer.is_server() and not is_destroyed:
		take_damage(1, player_id)

func take_damage(amount: int, attacker_id: int):
	if is_destroyed:
		return
	
	last_attacker_id = attacker_id
	health -= amount
	
	play_damage_animation.rpc()
	
	if health <= 0:
		harvest()

@rpc("any_peer", "call_local", "reliable")
func play_damage_animation():
	if is_animating or not sprite or is_destroyed:
		return
	
	is_animating = true
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_position + Vector2(5, 0), 0.05)
	tween.tween_property(sprite, "position", original_position + Vector2(-5, 0), 0.05)
	tween.tween_property(sprite, "position", original_position, 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.finished.connect(func(): is_animating = false)
func harvest():
	if not multiplayer.is_server() or is_destroyed:
		return
	
	is_destroyed = true
	
	# Give resources
	if last_attacker_id == 1:
		give_resources(resource_type, resource_amount)
	else:
		give_resources.rpc_id(last_attacker_id, resource_type, resource_amount)
	
	# Notify Spawner to remove from database (Server only)
	destroyed.emit()
	
	# Tell EVERYONE to animate and then delete themselves
	play_harvest_animation.rpc()
@rpc("any_peer", "call_remote", "reliable")
func give_resources(type: String, amount: int):
	var player = get_tree().get_first_node_in_group("local_player")
	if player and player.has_method("add_resource"):
		player.add_resource(type, amount)

@rpc("any_peer", "call_local", "reliable")
func play_harvest_animation():
	# Prevent double execution
	if not is_instance_valid(self) or not is_inside_tree(): 
		return

	is_destroyed = true
	
	
	if not sprite:
		queue_free()
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(sprite, "position", original_position + Vector2(0, -30), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0, 0), 0.3).set_delay(0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	
	# FIX: Delete on ALL peers when animation finishes
	tween.finished.connect(queue_free)
