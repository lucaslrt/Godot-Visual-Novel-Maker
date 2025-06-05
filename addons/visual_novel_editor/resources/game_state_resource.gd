# game_state.gd
class_name GameState
extends Resource

@export var variables: Dictionary = {
	"player": {},
	"flags": {}
}

func get_variable(name: String, default = null):
	return variables.get(name, default)

func set_variable(name: String, value):
	variables[name] = value

func modify_variable(name: String, amount: float):
	if variables.has(name):
		variables[name] += amount
	else:
		variables[name] = amount

func has_flag(flag: String) -> bool:
	return variables["flags"].get(flag, false)

func set_flag(flag: String, value: bool = true):
	variables["flags"][flag] = value
