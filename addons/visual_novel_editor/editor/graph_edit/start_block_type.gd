# start_block_type.gd
class_name StartBlockType
extends BlockType

func configure_slots():
	block_node.title = "INÍCIO"
	block_node.set_slot(0, 
		false, 0, Color(0, 0, 0, 0),
		true, 0, Color(0.2, 0.8, 0.2)
	)

func setup_preview_ui(parent: Control):
	var label = Label.new()
	label.text = "Início do capítulo"
	parent.add_child(label)

func setup_edit_ui(parent: Control):
	super.setup_edit_ui(parent)
