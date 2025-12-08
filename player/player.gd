extends CharacterBody2D

@export var max_health := 100
var health := max_health

@onready var state_machine = $StateMachine
@onready var animation_player = $AnimationPlayer
@onready var camera = $Camera2D

func _enter_tree() -> void:
	# Set the multiplayer authority to the correct peer
	set_multiplayer_authority(name.to_int())

func _ready():
	state_machine.init(self)

	# Only the local authority (this player) activates its camera
	if is_multiplayer_authority():
		camera.enabled = true
	else:
		camera.enabled = false

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	state_machine.physics_process(delta)

func take_damage(amount: int):
	if not is_multiplayer_authority():
		return
	
	health -= amount
	if health <= 0:
		die()

func die():
	state_machine.change_state("Dead")

func respawn():
	health = max_health
	position = Vector2.ZERO  # Votre spawn point
	state_machine.change_state("Idle")
