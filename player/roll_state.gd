# RollState.gd
extends State

@export var roll_speed := 400.0
@export var roll_duration := 0.5

var roll_timer := 0.0
var roll_direction := Vector2.ZERO

func enter():
	player = get_player()
	roll_timer = 0.0
	
	# Direction de la roulade
	var input_dir = Input.get_vector("left", "right", "up", "down")
	if input_dir.length() > 0.1:
		roll_direction = input_dir.normalized()
	else:
		# Roulade vers la direction actuelle
		roll_direction = Vector2.RIGHT.rotated(player.rotation)
	
	if player.animation_player:
		player.animation_player.play("roll")

func physics_process(delta):
	roll_timer += delta
	
	if roll_timer >= roll_duration:
		state_machine.change_state("Idle")
		return
	
	# Mouvement rapide
	player.velocity = roll_direction * roll_speed
	player.move_and_slide()
