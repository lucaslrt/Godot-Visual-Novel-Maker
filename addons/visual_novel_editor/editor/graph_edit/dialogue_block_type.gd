# dialogue_block_type.gd
class_name DialogueBlockType
extends BlockType

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
		var minimized = block_node._minimized_dialogues.get(i, false)
		
		var dialogue_box = VBoxContainer.new()
		content_vbox.add_child(dialogue_box)
		
		var header = HBoxContainer.new()
		dialogue_box.add_child(header)
		
		var toggle_btn = Button.new()
		toggle_btn.toggle_mode = true
		toggle_btn.button_pressed = minimized
		toggle_btn.icon = block_node.get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
		toggle_btn.pressed.connect(block_node._toggle_dialogue_minimized.bind(i))
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
		var minimized = block_node._minimized_dialogues.get(i, false)
		var dialogue_group = block_node._create_dialogue_edit_group(i, dialogue, minimized)
		edit_vbox.add_child(dialogue_group)
	
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "+ Adicionar Diálogo"
	add_dialogue_btn.pressed.connect(block_node._add_dialogue_entry)
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
	bg_btn.pressed.connect(block_node._browse_background.bind(bg_edit))
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
	music_btn.pressed.connect(block_node._browse_music.bind(music_edit))
	music_hbox.add_child(music_btn)
