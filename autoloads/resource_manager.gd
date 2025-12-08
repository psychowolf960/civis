# ResourceManager.gd (Autoload - Singleton)
extends Node

var resources := {
	"wood": 0,
	"stone": 0,
	"food": 0
}

signal resource_changed(type: String, amount: int)

func add_resource(type: String, amount: int):
	if type in resources:
		resources[type] += amount
		resource_changed.emit(type, resources[type])
		print("%s: %d (+%d)" % [type, resources[type], amount])

func spend_resource(type: String, amount: int) -> bool:
	if type in resources and resources[type] >= amount:
		resources[type] -= amount
		resource_changed.emit(type, resources[type])
		return true
	return false

func get_resource(type: String) -> int:
	return resources.get(type, 0)
