# end_block_type.gd
class_name EndBlockType
extends BlockType

func configure_slots():
	block_node.title = "FIM"
	block_node.set_slot(0, 
		true, 0, Color(0.8, 0.2, 0.2),
		false, 0, Color(0, 0, 0, 0)
	)

func setup_preview_ui(parent: Control):
	var label = Label.new()
	label.text = "Fim do capítulo"
	parent.add_child(label)

func setup_edit_ui(parent: Control):
	super.setup_edit_ui(parent)
