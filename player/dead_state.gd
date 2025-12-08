# DeadState.gd
extends State

var respawn_timer := 0.0
@export var respawn_delay := 5.0

func enter():
	player = get_player()
	respawn_timer = 0.0
	
	if player.animation_player:
		player.animation_player.play("death")
	
	# Désactiver les collisions
	player.set_collision_layer_value(1, false)
	player.velocity = Vector2.ZERO

func physics_process(delta):
	respawn_timer += delta
	
	if respawn_timer >= respawn_delay:
		player.respawn()

func exit():
	# Réactiver les collisions
	player.set_collision_layer_value(1, true)
