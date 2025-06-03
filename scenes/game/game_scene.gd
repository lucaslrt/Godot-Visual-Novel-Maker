# game_scene.gd
extends Control

# Referências aos nós da UI
@onready var dialogue_container = $DialogueContainer
@onready var character_display = $CharacterDisplay
@onready var text_canvas = $DialogueContainer/DialoguePanel/TextCanvas
@onready var character_name_label = $DialogueContainer/DialoguePanel/CharacterName
@onready var dialogue_text = $DialogueContainer/DialoguePanel/DialogueText
@onready var continue_button = $DialogueContainer/DialoguePanel/ContinueButton
@onready var choices_container = $DialogueContainer/ChoicesPanel/ChoicesContainer
@onready var choices_panel = $DialogueContainer/ChoicesPanel

# Menu de sistema
@onready var system_menu = $SystemMenu
@onready var menu_button = $MenuButton

@onready var transition_manager = TransitionManager

# Sistema de jogo
@onready var visual_novel_manager = VisualNovelManager
var current_save_data = {}
var is_in_dialogue = false

# Cache de personagens
var character_sprites = {}

func _ready():
	# Conectar sinais do sistema
	visual_novel_manager.dialogue_started.connect(_on_dialogue_started)
	visual_novel_manager.dialogue_advanced.connect(_on_dialogue_advanced)
	visual_novel_manager.dialogue_ended.connect(_on_dialogue_ended)
	visual_novel_manager.choice_presented.connect(_on_choice_presented)
	visual_novel_manager.choice_selected.connect(_on_choice_selected)
	
	# Sinais de transição
	transition_manager.transition_started.connect(_on_transition_started)
	transition_manager.transition_middle.connect(_on_transition_middle)
	transition_manager.transition_finished.connect(_on_transition_finished)
	
	# Conectar botões
	continue_button.pressed.connect(_on_continue_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	
	# Conectar sinais do menu do sistema (padrão Observer)
	system_menu.save_requested.connect(_on_save_requested)
	system_menu.load_requested.connect(_on_load_requested)
	system_menu.settings_requested.connect(_on_settings_requested)
	system_menu.menu_closed.connect(_on_menu_closed)
	
	# Configurar interface inicial
	_setup_initial_ui()
	
	# Iniciar o primeiro capítulo (exemplo)
	_start_first_chapter()

func _setup_initial_ui():
	# Ocultar elementos inicialmente
	choices_panel.visible = false
	system_menu.visible = false
	dialogue_container.visible = false
	
	# Configurar text canvas
	if text_canvas:
		text_canvas.custom_minimum_size = Vector2(800, 200)

func _start_first_chapter():
	VisualNovelSingleton.load_all_data()
	
	var first_chapter = null
	var chapter_order = VisualNovelSingleton.get_chapter_order()
	
	# Verificar se há ordem definida
	if chapter_order.size() > 0:
		for chapter_id in chapter_order:
			if VisualNovelSingleton.chapters.has(chapter_id):
				first_chapter = VisualNovelSingleton.chapters[chapter_id]
				break
	
	# Se não encontrou pela ordem, pegar o primeiro disponível
	if not first_chapter and VisualNovelSingleton.chapters.size() > 0:
		first_chapter = VisualNovelSingleton.chapters.values()[0]
	
	if first_chapter:
		print("Iniciando capítulo: ", first_chapter.chapter_name)
		visual_novel_manager.start_chapter(first_chapter)
	else:
		push_error("Nenhum capítulo encontrado para iniciar!")

# ========== CALLBACKS DOS SINAIS DO VISUAL NOVEL MANAGER ==========
func _on_dialogue_started(chapter_name: String, block_id: String):
	print("Diálogo iniciado: ", chapter_name, " - ", block_id)
	is_in_dialogue = true
	dialogue_container.visible = true
	_update_dialogue_display()

func _on_dialogue_advanced(block_id: String, dialogue_index: int):
	print("Diálogo avançado para: ", block_id, " diálogo ", dialogue_index)
	_update_dialogue_display()

func _on_dialogue_ended(chapter_name: String):
	print("Diálogo encerrado: ", chapter_name)
	
	# IMPORTANTE: Obter informações do capítulo ANTES de limpar
	var chapter_info = visual_novel_manager.get_current_chapter_info()
	var has_next = visual_novel_manager.has_next_chapter()
	
	# Agora podemos limpar a interface
	is_in_dialogue = false
	dialogue_container.visible = false
	_clear_character_display()
	
	# Verificar se há próximo capítulo usando as informações obtidas
	if has_next:
		_show_chapter_end_options(chapter_info)
	else:
		_show_story_complete()

func _on_choice_presented(choices: Array):
	print("Escolhas apresentadas: ", choices)
	_show_choices(choices)

func _on_choice_selected(choice_index: int):
	print("Escolha selecionada: ", choice_index)
	_hide_choices()

# ========== CALLBACKS DOS SINAIS DO MENU DO SISTEMA ==========
func _on_save_requested():
	print("Salvamento solicitado via sinal")
	system_menu.save_game_state()

func _on_load_requested():
	print("Carregamento solicitado via sinal")
	system_menu.load_game_state()

func _on_settings_requested():
	print("Configurações solicitadas via sinal")
	_show_settings_menu()

func _on_menu_closed():
	print("Menu fechado via sinal")

# ========== MÉTODOS DE INTERFACE ==========
func _update_dialogue_display():
	if not visual_novel_manager.current_chapter_resource:
		return
	
	var current_block = visual_novel_manager.current_chapter_resource.get_block(
		visual_novel_manager.current_block_id
	)
	
	if not current_block:
		return
	
	match current_block.get("type", ""):
		"dialogue":
			_show_dialogue(current_block)
		"choice":
			_show_choices(current_block.get("choices", []))
		"start":
			# Avançar automaticamente do bloco start
			visual_novel_manager.advance_dialogue()
		"end":
			visual_novel_manager.end_dialogue()

func _show_dialogue(block_data: Dictionary):
	# Ocultar escolhas
	choices_panel.visible = false
	
	# Verificar se temos um índice de diálogo válido
	if visual_novel_manager.current_dialogue_index < 0 or visual_novel_manager.current_dialogue_index >= block_data.get("dialogues", []).size():
		push_error("Índice de diálogo inválido: ", visual_novel_manager.current_dialogue_index)
		visual_novel_manager.advance_dialogue()
		return
	
	# Obter diálogo atual
	var dialogue = block_data["dialogues"][visual_novel_manager.current_dialogue_index]
	
	# Mostrar nome do personagem
	var character_name = dialogue.get("character_name", "")
	if character_name_label:
		character_name_label.text = character_name
		character_name_label.visible = not character_name.is_empty()
	
	# Mostrar texto do diálogo
	var dialogue_content = dialogue.get("text", "")
	if dialogue_text:
		dialogue_text.text = dialogue_content
		print("Texto: ", dialogue_content)
	
	# Atualizar sprite do personagem (agora usando dados do diálogo)
	_update_character_sprite(dialogue)
	
	# Mostrar botão de continuar
	continue_button.visible = true

func _update_character_sprite(dialogue_data: Dictionary):
	var character_name = dialogue_data.get("character_name", "")
	var expression = dialogue_data.get("character_expression", "normal")
	
	if character_name.is_empty():
		_clear_character_display()
		return
	
	# Buscar personagem no sistema
	var character_data = null
	for char_id in VisualNovelSingleton.characters:
		var char = VisualNovelSingleton.characters[char_id]
		if char.display_name == character_name:
			character_data = char
			break
	
	if not character_data:
		print("Personagem não encontrado: ", character_name)
		return
	
	# Carregar sprite do personagem
	var sprite_path = character_data.expressions.get(expression, "")
	if sprite_path.is_empty():
		# Tentar expressão padrão
		sprite_path = character_data.expressions.get("normal", "")
	
	if not sprite_path.is_empty() and FileAccess.file_exists(sprite_path):
		var texture = load(sprite_path)
		if texture and character_display:
			# Criar ou atualizar sprite
			var sprite_node = character_display.get_node_or_null("CharacterSprite")
			if not sprite_node:
				sprite_node = TextureRect.new()
				sprite_node.name = "CharacterSprite"
				character_display.add_child(sprite_node)
			
			sprite_node.texture = texture
			sprite_node.visible = true
			
			# Posicionar personagem
			var position = dialogue_data.get("character_position", Vector2(0.5, 1.0))
			_position_character(sprite_node, position)

func _position_character(sprite_node: TextureRect, position: Vector2):
	# Posicionar o personagem baseado na posição relativa (0-1)
	var screen_size = get_viewport().get_visible_rect().size
	var char_pos = Vector2(
		screen_size.x * position.x,
		screen_size.y * position.y
	)
	
	# Ajustar para centralizar o sprite
	if sprite_node.texture:
		var texture_size = sprite_node.texture.get_size()
		char_pos.x -= texture_size.x * 0.5
		char_pos.y -= texture_size.y
	
	sprite_node.position = char_pos

func _clear_character_display():
	if character_display:
		var sprite_node = character_display.get_node_or_null("CharacterSprite")
		if sprite_node:
			sprite_node.visible = false

func _show_choices(choices: Array):
	if not choices_container:
		return
	
	# Limpar escolhas anteriores
	for child in choices_container.get_children():
		child.queue_free()
	
	# Ocultar botão de continuar
	continue_button.visible = false
	
	# Mostrar painel de escolhas
	choices_panel.visible = true
	
	# Criar botões para cada escolha
	for i in range(choices.size()):
		var choice = choices[i]
		var button = Button.new()
		button.text = choice.get("text", "Escolha " + str(i + 1))
		button.custom_minimum_size = Vector2(400, 50)
		
		# Conectar sinal do botão
		button.pressed.connect(_on_choice_button_pressed.bind(i))
		
		choices_container.add_child(button)

func _hide_choices():
	choices_panel.visible = false
	continue_button.visible = true

# ========== GERENCIAMENTO DE CAPÍTULOS ==========
func _show_chapter_end_options(chapter_info: Dictionary):
	var message = "Capítulo '%s' concluído!\n\nDeseja continuar para o próximo capítulo?" % chapter_info.chapter_name
	
	print(message)
	print("Avançando automaticamente para o próximo capítulo...")
	
	# Obter o próximo capítulo
	var chapter_order = VisualNovelSingleton.get_chapter_order()
	var next_index = chapter_info.current_index + 1
	
	if next_index < chapter_order.size():
		var next_chapter_id = chapter_order[next_index]
		var next_chapter = VisualNovelSingleton.chapters.get(next_chapter_id)
		
		if next_chapter:
			print("Próximo capítulo encontrado: ", next_chapter.chapter_name)
			
			# Usar TransitionManager para transição entre capítulos
			transition_manager.transition_between_chapters(
				visual_novel_manager.current_chapter_resource,
				next_chapter,
				TransitionManager.TransitionType.DISSOLVE,
				2.0
			)
			
			# Conectar sinal para iniciar o capítulo no meio da transição
			if not transition_manager.transition_middle.is_connected(_start_next_chapter):
				transition_manager.transition_middle.connect(_start_next_chapter.bind(next_chapter), CONNECT_ONE_SHOT)
		else:
			print("Erro: Próximo capítulo não encontrado: ", next_chapter_id)
			_show_story_complete()
	else:
		print("Este era o último capítulo")
		_show_story_complete()

func _start_next_chapter(chapter: Resource):
	"""Inicia o próximo capítulo durante a transição"""
	visual_novel_manager.start_chapter(chapter)

func _show_story_complete():
	print("História completa! Todos os capítulos foram concluídos.")
	
	# Criar diálogo de conclusão
	var completion_dialog = AcceptDialog.new()
	completion_dialog.dialog_text = "Parabéns! Você completou toda a história!\n\nObrigado por jogar!"
	completion_dialog.title = "História Completa"
	completion_dialog.get_ok_button().text = "Voltar ao Menu"
	
	add_child(completion_dialog)
	completion_dialog.popup_centered()
	
	completion_dialog.confirmed.connect(func():
		completion_dialog.queue_free()
		# Usar transição para voltar ao menu
		transition_manager.transition_between_scenes(
			transition_manager.GAME_SCENE_PATH,
			transition_manager.MAIN_MENU_PATH,
			TransitionManager.TransitionType.FADE,
			1.0
		)
	)

# ========== SISTEMA DE SAVE/LOAD ==========
func restore_game_state(chapter: Resource, block_id: String):
	"""Método chamado pelo menu do sistema para restaurar o estado do jogo"""
	# Restaurar estado
	visual_novel_manager.current_chapter_resource = chapter
	visual_novel_manager.current_block_id = block_id
	
	# Atualizar interface
	is_in_dialogue = true
	dialogue_container.visible = true
	_update_dialogue_display()
	
	print("Estado do jogo restaurado - Capítulo: ", chapter.chapter_name, " Bloco: ", block_id)

# ========== MENU DE CONFIGURAÇÕES ==========
func _show_settings_menu():
	"""Implementação básica do menu de configurações"""
	var settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Configurações"
	settings_dialog.get_ok_button().text = "Fechar"
	
	var vbox = VBoxContainer.new()
	settings_dialog.add_child(vbox)
	
	# Volume Master
	var volume_label = Label.new()
	volume_label.text = "Volume Master:"
	vbox.add_child(volume_label)
	
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.1
	volume_slider.value = AudioServer.get_bus_volume_db(0)
	volume_slider.custom_minimum_size = Vector2(200, 30)
	vbox.add_child(volume_slider)
	
	# Conectar slider
	volume_slider.value_changed.connect(func(value):
		AudioServer.set_bus_volume_db(0, value)
	)
	
	# Velocidade do texto
	var text_speed_label = Label.new()
	text_speed_label.text = "Velocidade do Texto:"
	vbox.add_child(text_speed_label)
	
	var text_speed_slider = HSlider.new()
	text_speed_slider.min_value = 0.5
	text_speed_slider.max_value = 3.0
	text_speed_slider.step = 0.1
	text_speed_slider.value = 1.0
	text_speed_slider.custom_minimum_size = Vector2(200, 30)
	vbox.add_child(text_speed_slider)
	
	add_child(settings_dialog)
	settings_dialog.popup_centered()
	settings_dialog.confirmed.connect(func(): settings_dialog.queue_free())

# ========== CALLBACKS DOS BOTÕES ==========
func _on_continue_pressed():
	if is_in_dialogue:
		visual_novel_manager.advance_dialogue()

func _on_choice_button_pressed(choice_index: int):
	if is_in_dialogue:
		visual_novel_manager.select_choice(choice_index)

func _on_menu_button_pressed():
	system_menu.visible = true

# ========== ANIMAÇOES ==========
func _on_transition_started(transition_type: TransitionManager.TransitionType):
	print("Transição iniciada: ", transition_type)
	# Pode pausar animações, ocultar UI temporariamente, etc.

func _on_transition_middle():
	print("Meio da transição - momento ideal para mudanças")
	# Aqui você pode atualizar estados, trocar sprites, etc.

func _on_transition_finished(transition_type: TransitionManager.TransitionType):
	print("Transição finalizada: ", transition_type)
	# Reativar controles, mostrar UI, etc.

# ========== DEBUG E UTILIDADES ==========
func _debug_chapter_info():
	var info = visual_novel_manager.get_current_chapter_info()
	if info.is_empty():
		print("Nenhum capítulo ativo")
		return
	
	print("=== Info do Capítulo Atual ===")
	print("ID: ", info.chapter_id)
	print("Nome: ", info.chapter_name)
	print("Posição: ", info.current_index + 1, "/", info.total_chapters)
	print("É o último: ", info.is_last_chapter)
	print("==============================")

func _input(event):
	if event.is_action_pressed("ui_accept") and is_in_dialogue:
		if continue_button.visible:
			_on_continue_pressed()
	elif event.is_action_pressed("ui_cancel"):
		system_menu.visible = not system_menu.visible
	# Debug: pressione F1 para ver info do capítulo atual
	elif event.is_action_pressed("ui_home"): # ou qualquer outra tecla
		_debug_chapter_info()
