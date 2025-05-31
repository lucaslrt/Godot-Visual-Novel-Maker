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

# Referência injetada pelo nó pai
var game_scene_ref: Node = null

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	close_menu_button.pressed.connect(_on_close_menu_pressed)

# Método para injeção de dependência
func initialize(game_scene: Node) -> void:
	game_scene_ref = game_scene

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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _show_confirmation_dialog(message: String, callback: Callable):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Confirmação"
	
	# Criar botões personalizados
	dialog.get_ok_button().text = "Sim"
	var cancel_button = dialog.add_cancel_button("Cancelar")
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Conectar sinais
	dialog.confirmed.connect(func(): 
		callback.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	cancel_button.pressed.connect(func(): dialog.queue_free())

# Métodos para acesso direto quando necessário (via injeção de dependência)
func save_game_state():
	if not game_scene_ref:
		print("Referência da cena principal não disponível")
		return
	
	var visual_novel_manager = game_scene_ref.get_node("VisualNovelManager")
	if not visual_novel_manager:
		print("VisualNovelManager não encontrado")
		return
		
	if not visual_novel_manager.current_chapter_resource:
		print("Nenhum capítulo ativo para salvar")
		return
	
	var save_data = {
		"chapter_id": visual_novel_manager.current_chapter_resource.chapter_id,
		"block_id": visual_novel_manager.current_block_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"chapter_name": visual_novel_manager.current_chapter_resource.chapter_name
	}
	
	# Salvar no singleton
	VisualNovelSingleton.game_state["current_save"] = save_data
	VisualNovelSingleton.save_game_state()
	
	print("Jogo salvo: ", save_data)
	_show_notification("Jogo salvo com sucesso!")

func load_game_state():
	if not game_scene_ref:
		print("Referência da cena principal não disponível")
		return
	
	var visual_novel_manager = game_scene_ref.get_node("VisualNovelManager")
	if not visual_novel_manager:
		print("VisualNovelManager não encontrado")
		return
	
	# Carregar do singleton
	VisualNovelSingleton.load_game_state()
	
	var save_data = VisualNovelSingleton.game_state.get("current_save", {})
	
	if save_data.is_empty():
		print("Nenhum save encontrado")
		_show_notification("Nenhum jogo salvo encontrado!")
		return
	
	var chapter_id = save_data.get("chapter_id", "")
	var block_id = save_data.get("block_id", "")
	
	if chapter_id.is_empty() or block_id.is_empty():
		print("Dados de save inválidos")
		_show_notification("Dados de save corrompidos!")
		return
	
	# Encontrar e carregar o capítulo
	var chapter = VisualNovelSingleton.chapters.get(chapter_id)
	if not chapter:
		print("Capítulo não encontrado: ", chapter_id)
		_show_notification("Capítulo do save não encontrado!")
		return
	
	# Restaurar estado via método da cena principal
	if game_scene_ref.has_method("restore_game_state"):
		game_scene_ref.restore_game_state(chapter, block_id)
		_show_notification("Jogo carregado com sucesso!")
	else:
		print("Método restore_game_state não encontrado na cena principal")

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
