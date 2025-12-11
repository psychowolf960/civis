# MoveState.gd
extends State

@export var speed := 200.0

func enter():
	player = get_player()
	if player.animation_player:
		player.animation_player.play("walk")

func physics_process(_delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	if input_dir.length() < 0.1:
		state_machine.change_state("Idle")
		return
	
	if Input.is_action_just_pressed("attack"):
		state_machine.change_state("Attack")
		return
	
	if Input.is_action_just_pressed("roll"):
		state_machine.change_state("Roll")
		return

	# Mouvement
	player.velocity = input_dir.normalized() * speed
		
	if player.velocity.x != 0:
		player.sprite.flip_h = player.velocity.x > 0
		
	player.move_and_slide()
