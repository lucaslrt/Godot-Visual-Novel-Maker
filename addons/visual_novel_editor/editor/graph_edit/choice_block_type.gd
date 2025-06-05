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
	var choices_scroll = ScrollContainer.new()
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.custom_minimum_size.y = 150
	
	parent.add_child(choices_scroll)
	
	var choices_vbox = VBoxContainer.new()
	choices_scroll.add_child(choices_vbox)
	
	var choices = block_data.get("choices", [])
	
	for i in range(choices.size()):
		var choice = choices[i]
		var hbox = HBoxContainer.new()
		choices_vbox.add_child(hbox)

		# Indicador visual do slot
		var slot_indicator = ColorRect.new()
		slot_indicator.color = Color(0.8, 0.8, 0.2)
		slot_indicator.custom_minimum_size = Vector2(15, 15)
		
		hbox.add_child(slot_indicator)
		
		var text_edit = LineEdit.new()
		text_edit.text = choice.get("text", "")
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.text_changed.connect(func(text, idx=i):
			block_data.choices[idx]["text"] = text
			block_node._emit_update()
		)
		
		hbox.add_child(text_edit)
		
		var delete_btn = Button.new()
		delete_btn.text = "X"
		delete_btn.pressed.connect(func(idx=i):
			block_data.choices.remove_at(idx)
			block_node._update_ui()
			block_node._emit_update()
		)
		
		hbox.add_child(delete_btn)
		
	var add_btn = Button.new()
	add_btn.text = "Adicionar Escolha"
	add_btn.pressed.connect(func():
		block_data.choices.append({"text": "Nova escolha", "next_block_id": ""})
		block_node._update_ui()
		block_node._emit_update()
	)
	
	parent.add_child(add_btn)
	super.setup_edit_ui(parent)
