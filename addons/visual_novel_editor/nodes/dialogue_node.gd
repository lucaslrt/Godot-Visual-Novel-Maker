@tool
extends GraphNode

@onready var character_name_edit = $VBoxContainer/CharacterNameEdit
@onready var expression_edit = $VBoxContainer/ExpressionEdit
@onready var text_edit = $VBoxContainer/TextEdit

func set_dialogue_data(data):
	character_name_edit.text = data.character_name
	expression_edit.text = data.character_expression
	text_edit.text = data.text

func get_dialogue_data():
	return {
		"character_name": character_name_edit.text,
		"character_expression": expression_edit.text,
		"text": text_edit.text
	}
