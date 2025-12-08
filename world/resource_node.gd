# ResourceNode.gd
extends StaticBody2D
class_name ResourceNode

@export var resource_type: String = "wood"
@export var resource_amount: int = 10
@export var max_health: int = 5

@export var health: int :
	set(value):
		var old = health
		health = value
		# Trigger animation sur les clients quand health change
		if old != value and value > 0:
			play_damage_animation()

@onready var sprite = $RessourceSprite
var original_position: Vector2
var is_animating := false

func _ready():
	health = max_health
	if sprite:
		original_position = sprite.position

func take_damage(amount: int):
	# Client demande au serveur
	if not multiplayer.is_server():
		take_damage_server.rpc_id(1, amount)
		return
	
	# Serveur applique
	health -= amount
	
	# Animation côté serveur aussi
	if health > 0:
		play_damage_animation()
	else:
		harvest()

@rpc("any_peer", "reliable")
func take_damage_server(amount: int):
	take_damage(amount)

func harvest():
	if multiplayer.is_server():
		ResourceManager.add_resource(resource_type, resource_amount)
		despawn.rpc()

@rpc("authority", "call_local", "reliable")
func despawn():
	play_harvest_animation()

func play_damage_animation():
	if is_animating or not sprite:
		return
	
	is_animating = true
	var tween = create_tween()
	
	tween.tween_property(sprite, "position", original_position + Vector2(5, 0), 0.05)
	tween.tween_property(sprite, "position", original_position + Vector2(-5, 0), 0.05)
	tween.tween_property(sprite, "position", original_position, 0.05)
	
	tween.parallel().tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	tween.finished.connect(func(): is_animating = false)

func play_harvest_animation():
	if not sprite:
		queue_free()
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(sprite, "position", original_position + Vector2(0, -30), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0, 0), 0.3).set_delay(0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	
	tween.finished.connect(func(): queue_free())
