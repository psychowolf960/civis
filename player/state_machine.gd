# StateMachine.gd
extends Node
class_name StateMachine

var states := {}
var current_state: State
var player: CharacterBody2D

func _ready():
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self

func init(p: CharacterBody2D):
	player = p
	change_state("Idle")

func physics_process(delta):
	if not player.is_multiplayer_authority():
		return
	if current_state:
		current_state.physics_process(delta)

	if current_state:
		current_state.physics_process(delta)

func change_state(new_state_name: String):
	if current_state:
		current_state.exit()
	
	current_state = states.get(new_state_name)
	if current_state:
		current_state.enter()
