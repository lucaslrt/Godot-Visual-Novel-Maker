extends PanelContainer

@onready var chapter_label = $HBoxContainer/VBoxContainer/ChapterLabel
@onready var timestamp_label = $HBoxContainer/VBoxContainer/TimestampLabel
@onready var thumbnail = $HBoxContainer/TextureRect
@onready var load_button = $HBoxContainer/LoadButton
@onready var delete_button = $HBoxContainer/DeleteButton

signal load_pressed(slot_index: int)

var slot_index: int = -1

func set_save_data(data: Dictionary, index: int):
	slot_index = index
	chapter_label.text = "Capítulo: %s" % data.get("chapter_id", "Desconhecido")
	timestamp_label.text = "Salvo em: %s" % data.get("timestamp", "Data desconhecida")
	load_button.disabled = false
	delete_button.disabled = false
	
	# Você pode adicionar uma thumbnail aqui se quiser

func set_empty_slot(index: int):
	slot_index = index
	chapter_label.text = "Slot vazio"
	timestamp_label.text = ""
	load_button.text = "Novo Jogo"
	load_button.disabled = false
	delete_button.disabled = true

func _on_load_button_pressed():
	load_pressed.emit(slot_index)

func _on_delete_button_pressed():
	if VisualNovelManager.delete_save(slot_index):
		queue_free()
