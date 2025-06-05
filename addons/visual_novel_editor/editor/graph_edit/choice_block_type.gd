# choice_block_type.gd
class_name ChoiceBlockType
extends BlockType

func configure_slots():
	block_node.title = "Escolha"
	var choices = block_data.get("choices", [])
	var num_choices = choices.size()
	
	block_node.clear_all_slots()
	block_node.set_slot(0,
		true, 0, Color.CADET_BLUE,
		true, 0, Color(0, 0, 0, 0)
	)
	
	var base_yellow = Color(0.95, 0.95, 0.3)
	var dark_yellow = Color(0.5, 0.5, 0.1)
	var color_step = 1.0 / max(num_choices, 1)
	
	for i in range(num_choices):
		var slot_color = base_yellow.lerp(dark_yellow, color_step * i)
		block_node.set_slot(i + 1,
			false, 0, Color(0, 0, 0, 0),
			true, 0, slot_color
		)
		
		var spacer = Control.new()
		spacer.name = "OutputSpacer_%d" % (i+1)
		spacer.custom_minimum_size = Vector2(0, 25)
		block_node.add_child(spacer)

func setup_preview_ui(parent: Control):
	var choice_vbox = VBoxContainer.new()
	parent.add_child(choice_vbox)
	
	var choices = block_data.get("choices", [])
	var base_yellow = Color(0.95, 0.95, 0.3)
	var dark_yellow = Color(0.5, 0.5, 0.1)
	var color_step = 1.0 / max(choices.size(), 1)
	
	for i in range(choices.size()):
		var choice = choices[i]
		var hbox = HBoxContainer.new()
		choice_vbox.add_child(hbox)
		
		var slot_color = base_yellow.lerp(dark_yellow, color_step * i)
		var slot_indicator = ColorRect.new()
		slot_indicator.color = slot_color
		slot_indicator.custom_minimum_size = Vector2(10, 10)
		hbox.add_child(slot_indicator)
		
		var label = Label.new()
		label.text = "• " + choice.get("text", "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		var next_label = Label.new()
		next_label.text = "→ " + choice.get("next_block_id", "Nenhum")
		next_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(next_label)

func setup_edit_ui(parent: Control):
	# Chamar implementação da classe base para ações e condicionais
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(300, 200)
	parent.add_child(scroll_container)
	
	var edit_vbox = VBoxContainer.new()
	edit_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(edit_vbox)
	
	# Título
	var choices_label = Label.new()
	choices_label.text = "Opções:"
	edit_vbox.add_child(choices_label)
	
	# Adicionar botão para nova opção
	var add_choice_btn = Button.new()
	add_choice_btn.text = "+ Adicionar Opção"
	add_choice_btn.pressed.connect(_add_choice)
	edit_vbox.add_child(add_choice_btn)
	
	# Lista de opções
	for i in range(block_data.get("choices", []).size()):
		_add_choice_ui(i, block_data["choices"][i], edit_vbox)
	
	super.setup_edit_ui(parent)

func _add_choice():
	if not block_data.has("choices"):
		block_data["choices"] = []
	
	block_data["choices"].append({
		"text": "Nova opção",
		"next_block_id": "",
		"conditions": ""  # Novo campo de condição
	})
	block_node._emit_update()
	block_node._update_ui()

func _add_choice_ui(index: int, choice: Dictionary, parent: Control):
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var title = Label.new()
	title.text = "Opção #%d" % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(_remove_choice.bind(index))
	header.add_child(remove_btn)
	
	# Campo de texto da opção
	var text_hbox = HBoxContainer.new()
	group.add_child(text_hbox)
	
	var text_label = Label.new()
	text_label.text = "Texto:"
	text_hbox.add_child(text_label)
	
	var text_edit = LineEdit.new()
	text_edit.text = choice.get("text", "")
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(func(text):
		choice["text"] = text
		block_node._emit_update()
	)
	text_hbox.add_child(text_edit)
	
	# Campo de próximo bloco
	var next_hbox = HBoxContainer.new()
	group.add_child(next_hbox)
	
	var next_label = Label.new()
	next_label.text = "Próximo Bloco:"
	next_hbox.add_child(next_label)
	
	var next_edit = LineEdit.new()
	next_edit.text = choice.get("next_block_id", "")
	next_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_edit.placeholder_text = "ID do bloco destino"
	next_edit.text_changed.connect(func(text):
		choice["next_block_id"] = text
		block_node._emit_update()
	)
	next_hbox.add_child(next_edit)
	
	# Campo de condição
	var cond_hbox = HBoxContainer.new()
	group.add_child(cond_hbox)
	
	var cond_label = Label.new()
	cond_label.text = "Condição:"
	cond_hbox.add_child(cond_label)
	
	var cond_edit = LineEdit.new()
	cond_edit.text = choice.get("conditions", "")
	cond_edit.placeholder_text = "Ex: has_key"
	cond_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_edit.text_changed.connect(func(text):
		choice["conditions"] = text
		block_node._emit_update()
	)
	cond_hbox.add_child(cond_edit)

func _remove_choice(index: int):
	if block_data.has("choices") and block_data["choices"].size() > index:
		block_data["choices"].remove_at(index)
		block_node._emit_update()
		block_node._update_ui()

#func setup_edit_ui(parent: Control):
	#var choices_scroll = ScrollContainer.new()
	#choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#choices_scroll.custom_minimum_size.y = 150
	#
	#parent.add_child(choices_scroll)
	#
	#var choices_vbox = VBoxContainer.new()
	#choices_scroll.add_child(choices_vbox)
	#
	#var choices = block_data.get("choices", [])
	#
	#for i in range(choices.size()):
		#var choice = choices[i]
		#var hbox = HBoxContainer.new()
		#choices_vbox.add_child(hbox)
#
		## Indicador visual do slot
		#var slot_indicator = ColorRect.new()
		#slot_indicator.color = Color(0.8, 0.8, 0.2)
		#slot_indicator.custom_minimum_size = Vector2(15, 15)
		#
		#hbox.add_child(slot_indicator)
		#
		#var text_edit = LineEdit.new()
		#text_edit.text = choice.get("text", "")
		#text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#text_edit.text_changed.connect(func(text, idx=i):
			#block_data.choices[idx]["text"] = text
			#block_node._emit_update()
		#)
		#
		#hbox.add_child(text_edit)
		#
		#var delete_btn = Button.new()
		#delete_btn.text = "X"
		#delete_btn.pressed.connect(func(idx=i):
			#block_data.choices.remove_at(idx)
			#block_node._update_ui()
			#block_node._emit_update()
		#)
		#
		#hbox.add_child(delete_btn)
		#
	#var add_btn = Button.new()
	#add_btn.text = "Adicionar Escolha"
	#add_btn.pressed.connect(func():
		#block_data.choices.append({"text": "Nova escolha", "next_block_id": ""})
		#block_node._update_ui()
		#block_node._emit_update()
	#)
	#
	#parent.add_child(add_btn)
	#super.setup_edit_ui(parent)
