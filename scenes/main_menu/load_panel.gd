extends Control

const SAVE_SLOT_SCENE = preload("uid://dda44yj83pg1p")

@onready var save_slots_container = $LoadContainer/VBoxContainer/ScrollContainer/SaveSlotsContainer
@onready var close_button = $LoadContainer/VBoxContainer/CloseLoadButton

signal save_loaded(slot_index: int)
signal panel_closed

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)
	visible = false

func show_panel():
	_populate_save_slots()
	visible = true

func hide_panel():
	visible = false
	panel_closed.emit()

func _populate_save_slots():
	# Limpar slots existentes
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Criar slots para todos os saves possíveis
	for i in range(VisualNovelManager.MAX_SAVE_SLOTS):
		var save_data = VisualNovelManager.game_state["save_slots"].get(i, null)
		var save_slot = SAVE_SLOT_SCENE.instantiate()
		
		if save_data:
			save_slot.set_save_data(save_data, i)
		else:
			save_slot.set_empty_slot(i)
		
		save_slot.load_pressed.connect(_on_save_slot_loaded)
		save_slots_container.add_child(save_slot)

func _on_save_slot_loaded(slot_index: int):
	if VisualNovelManager.load_save(slot_index):
		save_loaded.emit(slot_index)
		hide_panel()

func _on_close_button_pressed():
	hide_panel()
