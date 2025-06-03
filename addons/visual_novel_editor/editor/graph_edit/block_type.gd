# block_type.gd
class_name BlockType
extends RefCounted

# Referência ao nó pai
var block_node: DialogueBlockNode
var block_data: Dictionary

func _init(node: DialogueBlockNode, data: Dictionary):
	block_node = node
	block_data = data

func configure_slots():
	pass

func setup_preview_ui(parent: Control):
	pass

func setup_edit_ui(parent: Control):
	pass

func update_data():
	pass
