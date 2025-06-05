@tool
extends GraphNode
class_name DialogueBlockNode

signal block_updated(block_data)
signal delete_requested(block_id)

var block_data = {}
var characters_cache = {}
var editing := false
var block_type: BlockType = null

func _ready():
	connect("dragged", _on_dragged)
	_load_characters()
	resizable = true

func _load_characters():
	if not VisualNovelSingleton:
		return
	
	characters_cache.clear()
	for character_id in VisualNovelSingleton.characters:
		var character = VisualNovelSingleton.characters[character_id]
		characters_cache[character.display_name] = character.expressions.keys()

func _on_dragged(from: Vector2, to: Vector2):
	block_data["graph_position"] = Vector2(position_offset)
	_emit_update()

func setup(initial_data: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Conversão de blocos antigos
	if initial_data.has("character_name") && !initial_data.has("dialogues"):
		initial_data["dialogues"] = [{
			"character_name": initial_data.get("character_name", "Personagem"),
			"character_expression": initial_data.get("character_expression", "default"),
			"character_position": initial_data.get("character_position", Vector2(0.5, 1.0)),
			"text": initial_data.get("text", "Digite o texto aqui...")
		}]
		initial_data.erase("character_name")
		initial_data.erase("character_expression")
		initial_data.erase("character_position")
		initial_data.erase("text")
	
	if not initial_data.has("actions"):
		initial_data["actions"] = []
	
	if not initial_data.has("conditionals"):
		initial_data["conditionals"] = []
	
	block_data = initial_data
	
	# Criar o tipo de bloco apropriado
	match block_data["type"]:
		"start":
			block_type = StartBlockType.new(self, block_data)
		"end":
			block_type = EndBlockType.new(self, block_data)
		"dialogue":
			block_type = DialogueBlockType.new(self, block_data)
		"choice":
			block_type = ChoiceBlockType.new(self, block_data)
		_:
			push_error("Tipo de bloco desconhecido: " + block_data["type"])
			return
	
	_update_ui()

func _update_ui() -> void:
	if not Engine.is_editor_hint() or block_type == null:
		return
	
	var current_size = size
	
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	_load_characters()
	
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(600, 200)
	add_child(scroll_container)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(vbox)
	
	# Delegar para o tipo específico
	block_type.configure_slots()
	
	if editing and block_data["type"] != "start" and block_data["type"] != "end":
		block_type.setup_edit_ui(vbox)
	else:
		block_type.setup_preview_ui(vbox)
	
	if block_data["type"] != "start" and block_data["type"] != "end":
		var toggle_btn = Button.new()
		toggle_btn.text = "Editar" if not editing else "Visualizar"
		toggle_btn.pressed.connect(_toggle_edit_mode)
		add_child(toggle_btn)
	
	_add_delete_button()
	size = current_size

func _update_minimum_size():
	if size == Vector2.ZERO or size == get_combined_minimum_size():
		var min_size = Vector2(0, 0)
		for child in get_children():
			if child is Control:
				min_size = min_size.max(child.get_combined_minimum_size())
		min_size += Vector2(20, 20)
		size = min_size

func _add_delete_button():
	if block_data["type"] == "start":
		return
		
	var delete_btn = Button.new()
	delete_btn.text = "X"
	delete_btn.flat = true
	delete_btn.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	delete_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	delete_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	delete_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.pressed.connect(_on_delete_pressed)
	delete_btn.position = Vector2(get_size().x - 25, 5)
	delete_btn.size = Vector2(20, 20)
	add_child(delete_btn)
	delete_btn.z_index = 100

func _on_delete_pressed():
	delete_requested.emit(name)

func _toggle_edit_mode():
	editing = not editing
	_update_ui()

func _emit_update():
	block_updated.emit(block_data)

func clear_all_slots():
	for child in get_children():
		if child.name.begins_with("InputSpacer") or child.name.begins_with("OutputSpacer_"):
			remove_child(child)
			child.queue_free()
