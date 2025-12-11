# IdleState.gd
extends State

func enter():
	player = get_player()
	if player.animation_player:
		player.animation_player.play("idle")

func physics_process(_delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	if input_dir.length() > 0.1:
		state_machine.change_state("Move")
	
	if Input.is_action_just_pressed("attack"):
		state_machine.change_state("Attack")
	
	if Input.is_action_just_pressed("roll"):
		state_machine.change_state("Roll")
	
	player.velocity = Vector2.ZERO
	player.move_and_slide()
