# ============================================================================
# UPGRADEABLE BASE CLASS
# ============================================================================
extends Area2D
class_name Upgradeable

@export var upgrade_tiers: Array[UpgradeTier] = []
@export var interaction_range := 50.0

var current_tier := 0
var player_in_range: Player = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var upgrade_prompt: UpgradePrompt = $UpgradePrompt
@onready var multiplayer_sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Configurer le rayon d'interaction
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = interaction_range
	
	_update_visual()
	upgrade_prompt.hide()
	
	# Sync multiplayer
	if multiplayer.is_server():
		sync_tier.rpc(current_tier)

func _process(_delta):
	if player_in_range and player_in_range.is_multiplayer_authority():
		if Input.is_action_just_pressed("interact"):
			if multiplayer.is_server():
				# Mode solo ou serveur : appel direct
				_try_upgrade_local()
			else:
				# Client multiplayer : demande au serveur
				request_upgrade.rpc_id(1)

func _on_body_entered(body):
	if body is Player and body.is_multiplayer_authority():
		player_in_range = body
		_show_upgrade_prompt()

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		upgrade_prompt.hide()

func _try_upgrade_local():
	"""Appel direct pour le serveur/solo"""
	if current_tier >= upgrade_tiers.size():
		return
	
	var next_tier = upgrade_tiers[current_tier]
	
	if player_in_range and _consume_resources_server(player_in_range, next_tier):
		_do_upgrade()
		sync_tier.rpc(current_tier)

func _show_upgrade_prompt():
	if current_tier >= upgrade_tiers.size():
		return
	
	var next_tier = upgrade_tiers[current_tier]
	var can_upgrade = _check_resources(next_tier)
	
	upgrade_prompt.show_requirements(next_tier, can_upgrade)
	upgrade_prompt.show()

@rpc("any_peer", "call_remote", "reliable")
func request_upgrade():
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_player = _find_player_by_id(sender_id)
	
	if not sender_player or current_tier >= upgrade_tiers.size():
		return
	
	var next_tier = upgrade_tiers[current_tier]
	
	if _consume_resources_server(sender_player, next_tier):
		_do_upgrade()
		sync_tier.rpc(current_tier)

	
	if _consume_resources_server(sender_player, next_tier):
		_do_upgrade()
		sync_tier.rpc(current_tier)

func _find_player_by_id(peer_id: int) -> Player:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer_id:
			return player
	return null

func _check_resources(tier: UpgradeTier) -> bool:
	if not player_in_range:
		return false
	
	for res_type in tier.cost.keys():
		if player_in_range.get_resource(res_type) < tier.cost[res_type]:
			return false
	return true

func _consume_resources_server(player: Player, tier: UpgradeTier) -> bool:
	# Vérifier
	for res_type in tier.cost.keys():
		if player.get_resource(res_type) < tier.cost[res_type]:
			return false
	
	# Consommer
	for res_type in tier.cost.keys():
		if not player.spend_resource(res_type, tier.cost[res_type]):
			return false
	return true

@rpc("authority", "call_local", "reliable")
func sync_tier(new_tier: int):
	current_tier = new_tier
	_update_visual()
	_unlock_functionality()
	
	if player_in_range:
		upgrade_prompt.hide()
		_show_upgrade_prompt()

func _do_upgrade():
	current_tier += 1
	_update_visual()
	_unlock_functionality()

func _update_visual():
	if current_tier < upgrade_tiers.size():
		var tier = upgrade_tiers[current_tier]
		if tier.sprite_texture:
			sprite.texture = tier.sprite_texture

func _unlock_functionality():
	# Override dans les classes enfants
	pass
