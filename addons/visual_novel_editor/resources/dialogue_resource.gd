## resources/dialogue_resource.gd
@tool
extends Resource
class_name DialogueResource

@export var block_id: String = ""
@export var type: String = "dialogue"  # dialogue, choice, etc
@export var character_name: String = ""
@export var character_expression: String = "default"
@export var character_position: Vector2 = Vector2(0.5, 1.0)  # Posição normalizada (x: 0-1, y: 0-1)
@export var text: String = ""
@export var next_block_id: String = ""

# Para blocos do tipo "choice"
@export var choices: Array = []

# Método para adicionar uma escolha
func add_choice(text, next_block):
	choices.append({
		"text": text,
		"next_block_id": next_block
	})
	
# Método para remover uma escolha
func remove_choice(index):
	if index >= 0 and index < choices.size():
		choices.remove_at(index)

# Obter uma representação como dicionário
func to_dict():
	var dict = {
		"block_id": block_id,
		"type": type,
		"character_name": character_name,
		"character_expression": character_expression,
		"character_position": {
			"x": character_position.x,
			"y": character_position.y
		},
		"text": text,
		"next_block_id": next_block_id
	}
	
	if type == "choice":
		dict["choices"] = choices
	
	return dict
