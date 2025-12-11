# State.gd
extends Node
class_name State

var state_machine: StateMachine
var player: CharacterBody2D

func enter():
	pass

func exit():
	pass

func physics_process(_delta):
	pass

func get_player() -> CharacterBody2D:
	return state_machine.player
