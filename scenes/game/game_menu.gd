# system_menu.gd
extends Control

# Sinais para comunicação com a cena principal
signal save_requested
signal load_requested
signal settings_requested
signal menu_closed

@onready var save_button = $MenuPanel/VBoxContainer/SaveButton
@onready var load_button = $MenuPanel/VBoxContainer/LoadButton
@onready var settings_button = $MenuPanel/VBoxContainer/SettingsButton
@onready var main_menu_button = $MenuPanel/VBoxContainer/MainMenuButton
@onready var close_menu_button = $MenuPanel/VBoxContainer/CloseButton

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	close_menu_button.pressed.connect(_on_close_menu_pressed)

func _on_save_pressed():
	save_requested.emit()
	visible = false

func _on_load_pressed():
	load_requested.emit()
	visible = false

func _on_settings_pressed():
	settings_requested.emit()
	visible = false

func _on_main_menu_pressed():
	_show_confirmation_dialog("Deseja voltar ao menu principal? O progresso não salvo será perdido.", _go_to_main_menu)

func _on_close_menu_pressed():
	menu_closed.emit()
	visible = false

func _go_to_main_menu():
	get_tree().change_scene_to_file(TransitionManager.MAIN_MENU_PATH)

func save_game_state():
	# Verificar se há um capítulo ativo
	if not VisualNovelManager.current_chapter_resource:
		print("Nenhum capítulo ativo para salvar")
		_show_notification("Nenhum capítulo ativo para salvar!")
		return
	
	# Preparar dados do save
	var save_data = {
		"chapter_id": VisualNovelManager.current_chapter_resource.chapter_id,
		"block_id": VisualNovelManager.current_block_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"chapter_name": VisualNovelManager.current_chapter_resource.chapter_name,
		"player_stats": VisualNovelManager.game_state.get("player_stats", {}),
		"flags": VisualNovelManager.game_state.get("flags", {})
	}
	
	# Encontrar slot para salvar
	var slot_to_save = _find_available_save_slot()
	
	if slot_to_save == -1:
		# Todos os slots estão cheios, perguntar se quer sobrescrever o último
		_show_confirmation_dialog(
			"Todos os slots de save estão ocupados. Deseja sobrescrever o último slot?",
			func(): 
				var last_slot = VisualNovelManager.MAX_SAVE_SLOTS - 1
				VisualNovelManager.game_state["save_slots"][last_slot] = save_data
				VisualNovelManager.game_state["current_save_slot"] = last_slot
				VisualNovelManager.save_game_state(last_slot)
				_show_notification("Jogo salvo no slot %d" % (last_slot + 1))
		)
	else:
		# Salvar no slot disponível encontrado
		VisualNovelManager.game_state["save_slots"][slot_to_save] = save_data
		VisualNovelManager.game_state["current_save_slot"] = slot_to_save
		VisualNovelManager.save_game_state(slot_to_save)
		_show_notification("Jogo salvo no slot %d" % (slot_to_save + 1))

func _find_available_save_slot() -> int:
	# Encontrar o primeiro slot vazio
	for i in range(VisualNovelManager.MAX_SAVE_SLOTS):
		if not VisualNovelManager.game_state["save_slots"].has(i):
			return i
	
	# Se todos os slots estiverem ocupados, retornar -1
	return -1

func load_game_state():
	# Carregar o estado atual
	VisualNovelManager.load_game_state()
	
	# Verificar se há saves disponíveis
	if VisualNovelManager.game_state["save_slots"].is_empty():
		_show_notification("Nenhum jogo salvo encontrado!")
		return
	
	# Mostrar painel de seleção de save
	#var load_panel = preload("res://path_to_your_load_panel.tscn").instantiate()
	#load_panel.save_loaded.connect(_on_save_loaded)
	#add_child(load_panel)
	#load_panel.show_panel()

func _on_save_loaded(slot_index: int):
	var save_data = VisualNovelManager.game_state["save_slots"].get(slot_index, {})
	
	if save_data.is_empty():
		_show_notification("Dados de save corrompidos!")
		return
	
	var chapter_id = save_data.get("chapter_id", "")
	var block_id = save_data.get("block_id", "")
	
	if chapter_id.is_empty() or block_id.is_empty():
		_show_notification("Dados de save incompletos!")
		return
	
	# Carregar o capítulo
	var chapter = VisualNovelSingleton.chapters.get(chapter_id)
	if not chapter:
		_show_notification("Capítulo do save não encontrado!")
		return
	
	# Definir como slot atual
	VisualNovelManager.game_state["current_save_slot"] = slot_index
	VisualNovelManager.save_game_state()
	
	# Restaurar o estado do jogo
	VisualNovelManager.start_chapter(chapter)
	VisualNovelManager.current_block_id = block_id
	
	_show_notification("Jogo carregado do slot %d" % (slot_index + 1))

func _show_confirmation_dialog(message: String, callback: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "Confirmação"
	
	dialog.get_ok_button().text = "Sim"
	dialog.get_cancel_button().text = "Cancelar"
	
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func(): 
		callback.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

func _show_notification(message: String):
	var notification = AcceptDialog.new()
	notification.dialog_text = message
	notification.title = "Informação"
	notification.get_ok_button().text = "OK"
	
	add_child(notification)
	notification.popup_centered()
	notification.confirmed.connect(func(): notification.queue_free())
	
	# Auto-fechar após 3 segundos
	get_tree().create_timer(3.0).timeout.connect(func():
		if notification and is_instance_valid(notification):
			notification.queue_free()
	)
