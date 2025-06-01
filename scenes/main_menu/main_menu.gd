# main_menu.gd
extends Control

# Referências aos nós da UI
@onready var title_label = $Background/MenuContainer/TitleLabel
@onready var new_game_button = $Background/MenuContainer/ButtonsContainer/NewGameButton
@onready var load_game_button = $Background/MenuContainer/ButtonsContainer/LoadGameButton
@onready var settings_button = $Background/MenuContainer/ButtonsContainer/SettingsButton
@onready var quit_button = $Background/MenuContainer/ButtonsContainer/QuitButton

# Painel de configurações
@onready var settings_panel = $SettingsPanel
@onready var master_volume_slider = $SettingsPanel/SettingsContainer/VolumeContainer/MasterVolumeSlider
@onready var sfx_volume_slider = $SettingsPanel/SettingsContainer/VolumeContainer/SFXVolumeSlider
@onready var music_volume_slider = $SettingsPanel/SettingsContainer/VolumeContainer/MusicVolumeSlider
@onready var fullscreen_check = $SettingsPanel/SettingsContainer/DisplayContainer/FullscreenCheck
@onready var close_settings_button = $SettingsPanel/SettingsContainer/CloseSettingsButton

# Painel de confirmação de novo jogo
@onready var new_game_confirm_panel = $NewGameConfirmPanel
@onready var confirm_new_game_button = $NewGameConfirmPanel/ConfirmContainer/ButtonsContainer/ConfirmButton
@onready var cancel_new_game_button = $NewGameConfirmPanel/ConfirmContainer/ButtonsContainer/CancelButton

# Painel de seleção de save
@onready var load_panel = $LoadPanel
@onready var save_slots_container = $LoadPanel/LoadContainer/VBoxContainer/ScrollContainer/SaveSlotsContainer
@onready var close_load_button = $LoadPanel/LoadContainer/VBoxContainer/CloseLoadButton

@onready var transition_manager = TransitionManager

# Configurações do jogo
var game_settings = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
	"fullscreen": false
}

func _ready():
	print("Menu principal inicializado")
	
	# Conectar sinais dos botões principais
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Conectar sinais do painel de configurações
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	# Conectar sinais do painel de confirmação
	confirm_new_game_button.pressed.connect(_on_confirm_new_game_pressed)
	cancel_new_game_button.pressed.connect(_on_cancel_new_game_pressed)
	
	load_panel.save_loaded.connect(_on_save_loaded)
	load_panel.panel_closed.connect(_on_load_panel_closed)
	
	# Conectar sinal do painel de load
	close_load_button.pressed.connect(_on_close_load_pressed)
	
	# Configurar interface inicial
	_setup_initial_ui()
	
	# Carregar configurações
	_load_settings()
	
	# Verificar se há saves disponíveis
	_check_save_availability()

func _setup_initial_ui():
	# Ocultar painéis secundários
	settings_panel.visible = false
	new_game_confirm_panel.visible = false
	load_panel.visible = false
	
	# Configurar título do jogo
	if title_label:
		title_label.text = "VISUAL NOVEL"
	
	# Adicionar efeito de hover aos botões
	_setup_button_effects()

func _setup_button_effects():
	var buttons = [new_game_button, load_game_button, settings_button, quit_button]
	
	for button in buttons:
		if button:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))

func _on_button_hover(button: Button):
	# Efeito visual quando o mouse passa sobre o botão
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_button_unhover(button: Button):
	# Restaurar cor normal quando o mouse sai do botão
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)

# Manipuladores dos botões principais
func _on_new_game_pressed():
	print("New Game pressionado")
	
	# Verificar se já existe um save
	if _has_existing_save():
		# Mostrar confirmação
		new_game_confirm_panel.visible = true
	else:
		# Iniciar novo jogo diretamente
		_start_new_game()

func _on_settings_pressed():
	print("Settings pressionado")
	settings_panel.visible = true

func _on_quit_pressed():
	print("Quit pressionado")
	get_tree().quit()

# Sistema de novo jogo
func _has_existing_save() -> bool:
	if not VisualNovelManager:
		return false
	
	VisualNovelManager.load_game_state()
	return not VisualNovelManager.game_state["save_slots"].is_empty()

func _start_new_game():
	print("Iniciando novo jogo...")
	
	# Encontrar slot disponível ou último slot
	var slot_to_use = _find_available_save_slot()
	
	if slot_to_use == -1:
		# Todos os slots cheios, perguntar se quer sobrescrever o último
		_show_confirmation_dialog(
			"Todos os slots de save estão ocupados. Deseja sobrescrever o último slot?",
			func():
				var last_slot = VisualNovelManager.MAX_SAVE_SLOTS - 1
				_create_new_game_in_slot(last_slot)
		)
	else:
		# Usar slot disponível encontrado
		_create_new_game_in_slot(slot_to_use)

func _find_available_save_slot() -> int:
	# Verificar se há slots vazios
	for i in range(VisualNovelManager.MAX_SAVE_SLOTS):
		if not VisualNovelManager.game_state["save_slots"].has(i):
			return i
	return -1

func _create_new_game_in_slot(slot_index: int):
	if VisualNovelManager.create_new_save(slot_index):
		transition_manager.transition_between_scenes(
			transition_manager.MAIN_MENU_PATH,
			transition_manager.GAME_SCENE_PATH,
			TransitionManager.TransitionType.FADE,
			1.5
		)
	else:
		push_error("Falha ao criar novo save no slot %d" % slot_index)
		_show_notification("Falha ao criar novo jogo!")

func _on_confirm_new_game_pressed():
	new_game_confirm_panel.visible = false
	_start_new_game()

func _on_cancel_new_game_pressed():
	new_game_confirm_panel.visible = false

func _on_load_game_pressed():
	load_panel.show_panel()

func _on_save_loaded(slot_index: int):
	if VisualNovelManager.load_save(slot_index):
		transition_manager.transition_between_scenes(
			transition_manager.MAIN_MENU_PATH,
			transition_manager.GAME_SCENE_PATH,
			TransitionManager.TransitionType.DISSOLVE,
			2.0
		)
	else:
		_show_notification("Falha ao carregar o save!")

func _on_load_panel_closed():
	_check_save_availability()

func _on_load_save_pressed(save_data: Dictionary):
	print("Carregando save: ", save_data)
	
	# Definir dados de save no singleton
	if VisualNovelManager:
		VisualNovelManager.game_state["current_save"] = save_data
		VisualNovelManager.save_game_state()
	
	# Usar transição personalizada para loads
	transition_manager.transition_between_scenes(
		transition_manager.MAIN_MENU_PATH,
		transition_manager.GAME_SCENE_PATH,
		TransitionManager.TransitionType.DISSOLVE,
		2.0
	)

func _on_close_load_pressed():
	load_panel.visible = false

func _check_save_availability():
	# Verificar se há saves e habilitar/desabilitar botão de load
	var has_saves = _has_existing_save()
	if load_game_button:
		load_game_button.disabled = not has_saves
		if not has_saves:
			load_game_button.tooltip_text = "Nenhum save disponível"

# Sistema de configurações
func _on_close_settings_pressed():
	settings_panel.visible = false
	_save_settings()

func _on_master_volume_changed(value: float):
	game_settings["master_volume"] = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_sfx_volume_changed(value: float):
	game_settings["sfx_volume"] = value
	# Assumindo que você tem um bus de SFX
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))

func _on_music_volume_changed(value: float):
	game_settings["music_volume"] = value
	# Assumindo que você tem um bus de Music
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))

func _on_fullscreen_toggled(button_pressed: bool):
	game_settings["fullscreen"] = button_pressed
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings():
	var config_file = ConfigFile.new()
	
	# Salvar configurações
	for key in game_settings:
		config_file.set_value("settings", key, game_settings[key])
	
	# Salvar arquivo
	var error = config_file.save("user://settings.cfg")
	if error != OK:
		push_error("Erro ao salvar configurações: " + str(error))
	else:
		print("Configurações salvas com sucesso")

func _load_settings():
	var config_file = ConfigFile.new()
	
	# Tentar carregar o arquivo
	var error = config_file.load("user://settings.cfg")
	if error != OK:
		print("Nenhum arquivo de configurações encontrado, usando padrões")
		_apply_default_settings()
		return
	
	# Carregar configurações
	for key in game_settings:
		if config_file.has_section_key("settings", key):
			game_settings[key] = config_file.get_value("settings", key)
	
	_apply_loaded_settings()
	print("Configurações carregadas com sucesso")

func _apply_default_settings():
	if master_volume_slider:
		master_volume_slider.value = game_settings["master_volume"]
	if sfx_volume_slider:
		sfx_volume_slider.value = game_settings["sfx_volume"]
	if music_volume_slider:
		music_volume_slider.value = game_settings["music_volume"]
	if fullscreen_check:
		fullscreen_check.button_pressed = game_settings["fullscreen"]

func _apply_loaded_settings():
	# Aplicar configurações carregadas
	if master_volume_slider:
		master_volume_slider.value = game_settings["master_volume"]
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(game_settings["master_volume"]))
	
	if sfx_volume_slider:
		sfx_volume_slider.value = game_settings["sfx_volume"]
		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus != -1:
			AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(game_settings["sfx_volume"]))
	
	if music_volume_slider:
		music_volume_slider.value = game_settings["music_volume"]
		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus != -1:
			AudioServer.set_bus_volume_db(music_bus, linear_to_db(game_settings["music_volume"]))
	
	if fullscreen_check:
		fullscreen_check.button_pressed = game_settings["fullscreen"]
		if game_settings["fullscreen"]:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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

# Entrada do usuário
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Fechar painéis abertos com ESC
		if settings_panel.visible:
			_on_close_settings_pressed()
		elif load_panel.visible:
			_on_close_load_pressed()
		elif new_game_confirm_panel.visible:
			_on_cancel_new_game_pressed()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()
		get_tree().quit()
