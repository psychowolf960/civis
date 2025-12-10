extends CharacterBody2D
class_name Player
# Resources
var resources := {"wood": 0, "stone": 0, "food": 0}

# Health
@export var max_health := 100
var health := max_health

# Signals
signal resource_changed(type: String, amount: int)
signal health_changed(current: int, maximum: int)

@onready var state_machine = $StateMachine
@onready var camera = $Camera2D
@onready var animation_player = $AnimationPlayer

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready():
	state_machine.init(self)
	
	var is_local := is_multiplayer_authority()
	camera.enabled = is_local
	
	if is_local:
		add_to_group("local_player")
	
	health_changed.emit(health, max_health)

func _physics_process(delta):
	if is_multiplayer_authority():
		state_machine.physics_process(delta)
# === DAMAGE SYSTEM ===
func take_damage(amount: int):
	if multiplayer.is_server():
		_apply_damage(amount)
		sync_health.rpc(health)  # Synchroniser sur tous les clients
	else:
		request_damage.rpc_id(1, amount)

@rpc("any_peer", "call_remote", "reliable")
func request_damage(amount: int):
	if multiplayer.is_server():
		_apply_damage(amount)
		sync_health.rpc(health)

@rpc("any_peer", "call_local", "reliable")  # Changé de "authority" à "any_peer"
func sync_health(new_health: int):
	health = new_health
	_emit_health()
	_damage_flash()

func _apply_damage(amount: int):
	health = clampi(health - amount, 0, max_health)
	_emit_health()
	
	if health <= 0:
		die()

func _damage_flash():
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE

func die():
	if not is_multiplayer_authority():
		return
	
	state_machine.change_state("Dead")
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn():
	health = max_health
	position = Vector2.ZERO
	_emit_health()
	state_machine.change_state("Idle")
	
	if multiplayer.is_server():
		sync_health(health)

func heal(amount: int):
	health = mini(health + amount, max_health)
	_emit_health()
	
	if multiplayer.is_server():
		sync_health(health)

# === RESOURCE SYSTEM ===
func add_resource(type: String, amount: int):
	if type in resources:
		resources[type] += amount
		resource_changed.emit(type, resources[type])
		_update_ui()

func get_resource(type: String) -> int:
	return resources.get(type, 0)

func spend_resource(type: String, amount: int) -> bool:
	if resources.get(type, 0) >= amount:
		resources[type] -= amount
		resource_changed.emit(type, resources[type])
		_update_ui()
		return true
	return false

# === UI UPDATES ===
func _emit_health():
	health_changed.emit(health, max_health)
	if is_multiplayer_authority() and Hud:
		Hud.update_health(health, max_health)

func _update_ui():
	if is_multiplayer_authority() and Hud:
		Hud.update_display(resources.wood, resources.stone, resources.food)
