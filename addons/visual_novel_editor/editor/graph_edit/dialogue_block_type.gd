# dialogue_block_type.gd
class_name DialogueBlockType
extends BlockType

var _minimized_dialogues = {}

func configure_slots():
	block_node.title = "Diálogo (" + str(block_data["dialogues"].size()) + ")"
	block_node.set_slot(0, 
		true, 0, Color(0.3, 0.3, 0.8),
		true, 0, Color(0.8, 0.3, 0.3)
	)

func setup_preview_ui(parent: Control):
	var content_vbox = VBoxContainer.new()
	parent.add_child(content_vbox)
	
	if block_data.has("background") and not block_data.background.is_empty():
		var bg_label = Label.new()
		bg_label.text = "Background: " + block_data.background.get_file()
		content_vbox.add_child(bg_label)
	
	if block_data.has("music") and not block_data.music.is_empty():
		var music_label = Label.new()
		music_label.text = "Música: " + block_data.music.get_file()
		content_vbox.add_child(music_label)
	
	for i in range(block_data.get("dialogues", []).size()):
		var dialogue = block_data["dialogues"][i]
		var minimized = _minimized_dialogues.get(i, false)
		
		var dialogue_box = VBoxContainer.new()
		content_vbox.add_child(dialogue_box)
		
		var header = HBoxContainer.new()
		dialogue_box.add_child(header)
		
		var toggle_btn = Button.new()
		toggle_btn.toggle_mode = true
		toggle_btn.button_pressed = minimized
		toggle_btn.icon = block_node.get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
		toggle_btn.pressed.connect(_toggle_dialogue_minimized.bind(i))
		header.add_child(toggle_btn)
		
		var char_label = Label.new()
		char_label.text = dialogue.get("character_name", "") + " (" + dialogue.get("character_expression", "") + ")"
		header.add_child(char_label)
		
		if minimized:
			var arrow_label = Label.new()
			arrow_label.text = " →"
			arrow_label.modulate = Color(0.7, 0.7, 0.7)
			header.add_child(arrow_label)
		
		if not minimized:
			var text_label = Label.new()
			text_label.text = dialogue.get("text", "")
			text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dialogue_box.add_child(text_label)
			
			var pos = dialogue.get("character_position", Vector2(0.5, 1.0))
			if typeof(pos) != TYPE_VECTOR2:
				pos = Vector2(0.5, 1.0)
			var pos_label = Label.new()
			pos_label.text = "Pos: (%.1f, %.1f)" % [pos.x, pos.y]
			pos_label.modulate = Color(0.7, 0.7, 0.7)
			dialogue_box.add_child(pos_label)

func setup_edit_ui(parent: Control):
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(300, 200)
	parent.add_child(scroll_container)
	
	var edit_vbox = VBoxContainer.new()
	edit_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(edit_vbox)
	
	for i in range(block_data["dialogues"].size()):
		var dialogue = block_data["dialogues"][i]
		var minimized = _minimized_dialogues.get(i, false)
		var dialogue_group = _create_dialogue_edit_group(i, dialogue, minimized)
		edit_vbox.add_child(dialogue_group)
	
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "+ Adicionar Diálogo"
	add_dialogue_btn.pressed.connect(_add_dialogue_entry)
	edit_vbox.add_child(add_dialogue_btn)
	
	var bg_hbox = HBoxContainer.new()
	parent.add_child(bg_hbox)
	
	var bg_label = Label.new()
	bg_label.text = "Background:"
	bg_hbox.add_child(bg_label)
	
	var bg_edit = LineEdit.new()
	bg_edit.text = block_data.get("background", "")
	bg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_edit.text_changed.connect(func(text):
		block_data["background"] = text
		block_node._emit_update()
	)
	bg_hbox.add_child(bg_edit)
	
	var bg_btn = Button.new()
	bg_btn.text = "Procurar"
	bg_btn.pressed.connect(_browse_background.bind(bg_edit))
	bg_hbox.add_child(bg_btn)
	
	var music_hbox = HBoxContainer.new()
	parent.add_child(music_hbox)
	
	var music_label = Label.new()
	music_label.text = "Música:"
	music_hbox.add_child(music_label)
	
	var music_edit = LineEdit.new()
	music_edit.text = block_data.get("music", "")
	music_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_edit.text_changed.connect(func(text):
		block_data["music"] = text
		block_node._emit_update()
	)
	music_hbox.add_child(music_edit)
	
	var music_btn = Button.new()
	music_btn.text = "Procurar"
	music_btn.pressed.connect(_browse_music.bind(music_edit))
	music_hbox.add_child(music_btn)

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
	collapse_btn.icon = block_node.get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
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
		var char_names = block_node.characters_cache.keys()
		
		for i in range(char_names.size()):
			char_dropdown.add_item(char_names[i])
			if char_names[i] == current_char:
				char_index = i
		
		char_dropdown.selected = char_index
		char_dropdown.item_selected.connect(func(idx):
			block_data["dialogues"][index]["character_name"] = char_dropdown.get_item_text(idx)
			block_node._emit_update()
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
			block_node._emit_update()
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
			block_node._emit_update()
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
			block_node._emit_update()
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
			block_node._emit_update()
		)
		group.add_child(text_edit)
	
	return group

func _toggle_dialogue_minimized(index: int):
	var current_size = block_node.size
	_minimized_dialogues[index] = not _minimized_dialogues.get(index, false)
	block_node._update_ui()
	block_node.size = current_size

func _add_dialogue_entry():
	if not block_data.has("dialogues"):
		block_data["dialogues"] = []
	
	block_data["dialogues"].append({
		"character_name": "Personagem",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Novo diálogo..."
	})
	block_node._emit_update()
	block_node._update_ui()

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
		block_node._emit_update()
		block_node._update_ui()

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
	
	block_node.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _update_expression_dropdown(dropdown: OptionButton, char_name: String):
	dropdown.clear()
	
	if char_name.is_empty() or not block_node.characters_cache.has(char_name):
		return
	
	var expressions = block_node.characters_cache[char_name]
	var current_expr = block_data.get("character_expression", "")
	var expr_index = 0
	
	for i in range(expressions.size()):
		dropdown.add_item(expressions[i])
		if expressions[i] == current_expr:
			expr_index = i
	
	dropdown.selected = expr_index
	dropdown.item_selected.connect(func(index):
		block_data["character_expression"] = dropdown.get_item_text(index)
		block_node._emit_update()
	)
