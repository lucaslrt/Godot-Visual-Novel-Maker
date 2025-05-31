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
@onready var save_slots_container = $LoadPanel/LoadContainer/ScrollContainer/SaveSlotsContainer
@onready var close_load_button = $LoadPanel/LoadContainer/ScrollContainer/VBoxContainer/CloseLoadButton

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

func _on_load_game_pressed():
	print("Load Game pressionado")
	_show_load_panel()

func _on_settings_pressed():
	print("Settings pressionado")
	settings_panel.visible = true

func _on_quit_pressed():
	print("Quit pressionado")
	get_tree().quit()

# Sistema de novo jogo
func _has_existing_save() -> bool:
	# Verificar se existe um save no VisualNovelSingleton
	if not VisualNovelSingleton:
		return false
	
	VisualNovelSingleton.load_game_state()
	return VisualNovelSingleton.game_state.has("current_save")

func _start_new_game():
	print("Iniciando novo jogo...")
	
	# Limpar save atual se existir
	if VisualNovelSingleton:
		VisualNovelSingleton.game_state.erase("current_save")
		VisualNovelSingleton.save_game_state()
	
	# Usar TransitionManager ao invés de change_scene_to_file diretamente
	transition_manager.transition_between_scenes(
		"res://scenes/main_menu.tscn",
		"res://scenes/game_scene.tscn",
		TransitionManager.TransitionType.FADE,
		1.5
	)

func _on_confirm_new_game_pressed():
	new_game_confirm_panel.visible = false
	_start_new_game()

func _on_cancel_new_game_pressed():
	new_game_confirm_panel.visible = false

# Sistema de load
func _show_load_panel():
	load_panel.visible = true
	_populate_save_slots()

func _populate_save_slots():
	# Limpar slots existentes
	for child in save_slots_container.get_children():
		child.queue_free()
	
	# Verificar se há saves disponíveis
	if not VisualNovelSingleton:
		_create_no_saves_label()
		return
	
	VisualNovelSingleton.load_game_state()
	var save_data = VisualNovelSingleton.game_state.get("current_save", {})
	
	if save_data.is_empty():
		_create_no_saves_label()
		return
	
	# Criar slot de save
	var save_slot = _create_save_slot(save_data, 0)
	save_slots_container.add_child(save_slot)

func _create_no_saves_label():
	var label = Label.new()
	label.text = "Nenhum save encontrado"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	save_slots_container.add_child(label)

func _create_save_slot(save_data: Dictionary, slot_index: int) -> Control:
	var slot_container = Panel.new()
	slot_container.custom_minimum_size = Vector2(500, 80)
	
	# Criar estilo para o painel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	slot_container.add_theme_stylebox_override("panel", style_box)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	slot_container.add_child(hbox)
	
	# Informações do save
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_container)
	
	# Data/hora do save
	var timestamp_label = Label.new()
	timestamp_label.text = "Salvo em: " + save_data.get("timestamp", "Desconhecido")
	timestamp_label.add_theme_font_size_override("font_size", 14)
	info_container.add_child(timestamp_label)
	
	# Capítulo atual
	var chapter_label = Label.new()
	chapter_label.text = "Capítulo: " + save_data.get("chapter_id", "Desconhecido")
	chapter_label.add_theme_font_size_override("font_size", 16)
	info_container.add_child(chapter_label)
	
	# Botão de carregar
	var load_button = Button.new()
	load_button.text = "Carregar"
	load_button.custom_minimum_size = Vector2(100, 60)
	load_button.pressed.connect(_on_load_save_pressed.bind(save_data))
	hbox.add_child(load_button)
	
	return slot_container

func _on_load_save_pressed(save_data: Dictionary):
	print("Carregando save: ", save_data)
	
	# Definir dados de save no singleton
	if VisualNovelSingleton:
		VisualNovelSingleton.game_state["current_save"] = save_data
		VisualNovelSingleton.save_game_state()
	
	# Usar transição personalizada para loads
	transition_manager.transition_between_scenes(
		"res://scenes/main_menu.tscn",
		"res://scenes/game_scene.tscn",
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
