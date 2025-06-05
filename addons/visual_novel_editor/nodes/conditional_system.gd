# conditional_system.gd
class_name ConditionalSystem
extends RefCounted

var game_state: GameState
var method_registry: MethodRegistry

func _init(state: GameState, registry: MethodRegistry):
	game_state = state
	method_registry = registry

func evaluate(expression: String) -> bool:
	var result = false
	
	# Tipos de expressões:
	if expression.begins_with("match:"):
		return _evaluate_match(expression.substr(6))
	
	# Expressões simples: var > value
	var parts = expression.split(" ")
	if parts.size() >= 3:
		var var_name = parts[0]
		var op = parts[1]
		var value = parts[2]
		
		var actual_value = game_state.get_variable(var_name)
		
		match op:
			"==": result = actual_value == value
			"!=": result = actual_value != value
			">": result = actual_value > value
			">=": result = actual_value >= value
			"<": result = actual_value < value
			"<=": result = actual_value <= value
			"has": result = game_state.has_flag(value)
			"!has": result = !game_state.has_flag(value)
			"call": 
				if method_registry.has_registered_method(value):
					result = method_registry.execute_method(value)
	
	return result

func _evaluate_match(match_str: String) -> bool:
	# Formato: var;case1:block1;case2:block2;default:block_default
	var parts = match_str.split(";")
	if parts.size() < 2: return false
	
	var var_name = parts[0]
	var var_value = game_state.get_variable(var_name)
	
	for i in range(1, parts.size()):
		var case_parts = parts[i].split(":")
		if case_parts.size() != 2: continue
		
		var case_value = case_parts[0]
		var target_block = case_parts[1]
		
		if case_value == "default":
			return target_block
		
		if var_value == case_value:
			return target_block
	
	return false
