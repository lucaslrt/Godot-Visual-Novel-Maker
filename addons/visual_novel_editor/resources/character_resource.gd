## resources/character_resource.gd
@tool
extends Resource
class_name CharacterResource

@export var character_id: String = ""
@export var display_name: String = "New Character"
@export var description: String = ""
@export var expressions: Dictionary = {
	"default": null  # A textura default
}
@export var actions: Array = [] # { "type": "set|modify|call", "target": "", "value": "" }
@export var conditionals: Array = [] # { "expression": "", "target_block": "" }

func _init():
	# Gerar ID único se estiver vazio
	if character_id.is_empty():
		character_id = _generate_simple_id()

# Gerar ID numérico simples baseado em timestamp
static func _generate_simple_id() -> String:
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var random_num = randi() % 1000
	return "char_%s_%03d" % [timestamp, random_num]

# Adicionar uma expressão
func add_expression(name: String, texture_path: String) -> void:
	expressions[name] = texture_path
	notify_property_list_changed()  # Forçar atualização do recurso

# Remover uma expressão
func remove_expression(name: String) -> void:
	if expressions.has(name) and name != "default":
		expressions.erase(name)
		notify_property_list_changed()  # Forçar atualização do recurso

# Obter o caminho de textura para uma expressão
func get_expression_texture(expression_name: String) -> String:
	return expressions.get(expression_name, expressions["default"])
