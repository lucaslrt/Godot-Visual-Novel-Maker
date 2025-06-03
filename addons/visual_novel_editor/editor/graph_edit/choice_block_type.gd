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
