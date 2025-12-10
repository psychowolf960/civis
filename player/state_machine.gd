# StateMachine.gd
extends Node
class_name StateMachine

var states := {}
var current_state: State
var player: CharacterBody2D

# Cooldown d'attaque
var attack_cooldown := 0.1  # secondes entre chaque attaque
var can_attack := true

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

func change_state(new_state_name: String):
	# Empêche l'attaque si en cooldown
	if new_state_name == "Attack" and not can_attack:
		return
	
	if current_state:
		current_state.exit()
	
	current_state = states.get(new_state_name)
	if current_state:
		current_state.enter()
	
	# Démarre le cooldown après une attaque
	if new_state_name == "Attack":
		start_attack_cooldown()

func start_attack_cooldown():
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
