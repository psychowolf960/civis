extends Resource
class_name UpgradeTier

@export var tier_name: String = ""
@export var sprite_texture: Texture2D
@export var cost: Dictionary = {
	"wood": 0,
	"stone": 0,
	"food": 0
}
