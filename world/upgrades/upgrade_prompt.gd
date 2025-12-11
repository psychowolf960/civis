# ============================================================================
# UPGRADE PROMPT UI
# ============================================================================
extends Control
class_name UpgradePrompt

@onready var label = $Panel/Label
@onready var wood_label = $Panel/VBoxContainer/Wood
@onready var stone_label = $Panel/VBoxContainer/Stone
@onready var food_label = $Panel/VBoxContainer/Food

func show_requirements(tier: UpgradeTier, can_afford: bool):
	label.text = "Upgrade to: " + tier.tier_name
	
	wood_label.text = "Wood: %d" % tier.cost.get("wood", 0)
	stone_label.text = "Stone: %d" % tier.cost.get("stone", 0)
	food_label.text = "Food: %d" % tier.cost.get("food", 0)
	
	modulate = Color.GREEN if can_afford else Color.RED
