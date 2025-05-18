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

# Adicionar uma expressão
func add_expression(name, texture_path):
	expressions[name] = texture_path
	
# Remover uma expressão
func remove_expression(name):
	if expressions.has(name) and name != "default":
		expressions.erase(name)
		
# Obter o caminho de textura para uma expressão
func get_expression_texture(expression_name):
	if expressions.has(expression_name):
		return expressions[expression_name]
	return expressions["default"]  # Fallback para expressão padrão
