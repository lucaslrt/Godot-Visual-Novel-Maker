@tool
extends GraphNode
class_name DialogueBlockNode

signal block_updated(block_data)
signal delete_requested(block_id)

var block_data = {}
var editing := false
var characters_cache = {}
var _minimized_dialogues = {}
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

func _create_dialogue_edit_group(index: int, dialogue: Dictionary, minimized: bool) -> Control:
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var collapse_btn = Button.new()
	collapse_btn.toggle_mode = true
	collapse_btn.button_pressed = minimized
	collapse_btn.icon = get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
	collapse_btn.pressed.connect(_toggle_dialogue_minimized.bind(index))
	header.add_child(collapse_btn)
	
	var title = Label.new()
	title.text = "Diálogo #%d" % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var remove_btn = Button.new()
	remove_btn.text = "Remover"
	remove_btn.pressed.connect(_remove_dialogue_entry.bind(index))
	header.add_child(remove_btn)
	
	if not minimized:
		var char_hbox = HBoxContainer.new()
		group.add_child(char_hbox)
		
		var char_label = Label.new()
		char_label.text = "Personagem:"
		char_hbox.add_child(char_label)
		
		var char_dropdown = OptionButton.new()
		char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		char_hbox.add_child(char_dropdown)
		
		var current_char = dialogue.get("character_name", "")
		var char_index = 0
		var char_names = characters_cache.keys()
		
		for i in range(char_names.size()):
			char_dropdown.add_item(char_names[i])
			if char_names[i] == current_char:
				char_index = i
		
		char_dropdown.selected = char_index
		char_dropdown.item_selected.connect(func(idx):
			block_data["dialogues"][index]["character_name"] = char_dropdown.get_item_text(idx)
			_emit_update()
		)
		
		var expr_hbox = HBoxContainer.new()
		group.add_child(expr_hbox)
		
		var expr_label = Label.new()
		expr_label.text = "Expressão:"
		expr_hbox.add_child(expr_label)
		
		var expr_dropdown = OptionButton.new()
		expr_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expr_hbox.add_child(expr_dropdown)
		
		_update_expression_dropdown(expr_dropdown, current_char)
		expr_dropdown.item_selected.connect(func(idx):
			block_data["dialogues"][index]["character_expression"] = expr_dropdown.get_item_text(idx)
			_emit_update()
		)
		
		var pos_hbox = HBoxContainer.new()
		group.add_child(pos_hbox)
		
		var pos_label = Label.new()
		pos_label.text = "Posição:"
		pos_hbox.add_child(pos_label)
		
		var pos_x = SpinBox.new()
		pos_x.min_value = 0
		pos_x.max_value = 1
		pos_x.step = 0.1
		pos_x.value = dialogue.get("character_position", Vector2(0.5, 1.0)).x
		pos_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pos_x.value_changed.connect(func(val):
			if not block_data["dialogues"][index].has("character_position"):
				block_data["dialogues"][index]["character_position"] = Vector2(0.5, 1.0)
			block_data["dialogues"][index]["character_position"].x = val
			_emit_update()
		)
		pos_hbox.add_child(pos_x)
		
		var pos_y = SpinBox.new()
		pos_y.min_value = 0
		pos_y.max_value = 1
		pos_y.step = 0.1
		pos_y.value = dialogue.get("character_position", Vector2(0.5, 1.0)).y
		pos_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pos_y.value_changed.connect(func(val):
			if not block_data["dialogues"][index].has("character_position"):
				block_data["dialogues"][index]["character_position"] = Vector2(0.5, 1.0)
			block_data["dialogues"][index]["character_position"].y = val
			_emit_update()
		)
		pos_hbox.add_child(pos_y)
		
		var text_label = Label.new()
		text_label.text = "Texto:"
		group.add_child(text_label)
		
		var text_edit = TextEdit.new()
		text_edit.text = dialogue.get("text", "")
		text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_edit.custom_minimum_size.y = 100
		text_edit.text_changed.connect(func():
			block_data["dialogues"][index]["text"] = text_edit.text
			_emit_update()
		)
		group.add_child(text_edit)
	
	return group

func _toggle_dialogue_minimized(index: int):
	var current_size = size
	_minimized_dialogues[index] = not _minimized_dialogues.get(index, false)
	_update_ui()
	size = current_size

func _add_dialogue_entry():
	if not block_data.has("dialogues"):
		block_data["dialogues"] = []
	
	block_data["dialogues"].append({
		"character_name": "Personagem",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Novo diálogo..."
	})
	_emit_update()
	_update_ui()

func _remove_dialogue_entry(index: int):
	if block_data["dialogues"].size() > index:
		block_data["dialogues"].remove_at(index)
		_minimized_dialogues.erase(index)
		var new_minimized = {}
		for idx in _minimized_dialogues.keys():
			if idx > index:
				new_minimized[idx - 1] = _minimized_dialogues[idx]
			elif idx < index:
				new_minimized[idx] = _minimized_dialogues[idx]
		_minimized_dialogues = new_minimized
		_emit_update()
		_update_ui()

func _browse_background(line_edit: LineEdit):
	_open_file_dialog("Selecione um Background", line_edit, ["*.png", "*.jpg"])

func _browse_music(line_edit: LineEdit):
	_open_file_dialog("Selecione uma Música", line_edit, ["*.ogg", "*.wav"])

func _open_file_dialog(title: String, target: LineEdit, filters: Array):
	var dialog = FileDialog.new()
	dialog.title = title
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	
	for filter in filters:
		dialog.add_filter(filter)
	
	dialog.file_selected.connect(func(path):
		target.text = path
		target.text_changed.emit(path)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

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

func _update_expression_dropdown(dropdown: OptionButton, char_name: String):
	dropdown.clear()
	
	if char_name.is_empty() or not characters_cache.has(char_name):
		return
	
	var expressions = characters_cache[char_name]
	var current_expr = block_data.get("character_expression", "")
	var expr_index = 0
	
	for i in range(expressions.size()):
		dropdown.add_item(expressions[i])
		if expressions[i] == current_expr:
			expr_index = i
	
	dropdown.selected = expr_index
	dropdown.item_selected.connect(func(index):
		block_data["character_expression"] = dropdown.get_item_text(index)
		_emit_update()
	)

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
