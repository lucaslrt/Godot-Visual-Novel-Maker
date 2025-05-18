@tool
extends GraphNode
class_name DialogueBlockNode

signal block_updated(block_data)

var block_data = {}

func setup(initial_data: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	
	block_data = initial_data
	_update_ui()

func _update_ui() -> void:
	if not Engine.is_editor_hint():
		return
	# Limpar filhos existentes
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	# Criar UI baseada no tipo de bloco
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	match block_data["type"]:
		"dialogue":
			_setup_dialogue_ui(vbox)
		"choice":
			_setup_choice_ui(vbox)

func _setup_dialogue_ui(parent: Control) -> void:
	title = "Diálogo: " + block_data.get("character_name", "Nenhum")
	
	# Adicionar preview do conteúdo
	var content = Label.new()
	content.text = "%s: %s" % [block_data.get("character_name", ""), block_data.get("text", "")]
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(content)

func _setup_choice_ui(parent: Control) -> void:
	title = "Escolha"
	
	var vbox = VBoxContainer.new()
	parent.add_child(vbox)
	
	# Adicionar preview das escolhas
	for choice in block_data.get("choices", []):
		var label = Label.new()
		label.text = "• " + choice.get("text", "")
		vbox.add_child(label)
