@tool
extends VBoxContainer
class_name CharacterEditor

# Referências aos nós da UI
@onready var character_list = $HSplitContainer/CharacterList/ItemList
@onready var character_name_edit = $HSplitContainer/TabContainer/HBoxContainer/CharacterEditor/CharacterNameEdit
@onready var character_description_edit = $HSplitContainer/TabContainer/HBoxContainer/CharacterEditor/CharacterDescriptionEdit
@onready var texture_rect = $HSplitContainer/TabContainer/HBoxContainer/VBoxContainer/TextureRect
@onready var image_change_button = $HSplitContainer/TabContainer/HBoxContainer/VBoxContainer/TextureRect/Button
@onready var expression_list = $HSplitContainer/TabContainer/HBoxContainer/VBoxContainer/ExpressionsList

# Personagem atual sendo editado
var current_character: CharacterResource = null
var expressions_dir = "res://addons/visual_novel_editor/data/characters/expressions/"
var expression_selected_index = null

# Referência para o FileDialog
var file_dialog: FileDialog = null

func _ready():
	# Conectar sinais
	$Toolbar/AddCharacterButton.pressed.connect(_on_add_character_button_pressed)
	$Toolbar/DeleteCharacterButton.pressed.connect(_on_delete_character_button_pressed)
	$Toolbar/SaveButton.pressed.connect(_on_save_button_pressed)
	$Toolbar/LoadButton.pressed.connect(_on_load_button_pressed)
	$HSplitContainer/TabContainer/HBoxContainer/VBoxContainer/ExpressionsToolbar/AddExpressionButton.pressed.connect(_on_add_expression_pressed)
	$HSplitContainer/TabContainer/HBoxContainer/VBoxContainer/ExpressionsToolbar/RemoveExpressionButton.pressed.connect(_on_remove_expression_pressed)
	image_change_button.pressed.connect(_on_image_change_button_pressed)
	
	# Conectar sinal da lista de personagens
	if character_list:
		character_list.item_selected.connect(_on_character_selected)
	
	# Conectar sinal da lista de expressões
	if expression_list:
		expression_list.item_selected.connect(_on_expression_selected)
	
	# Aguardar alguns frames para garantir que tudo esteja inicializado
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verificar se o VisualNovelSingleton está disponível
	if not _check_singleton():
		print("VisualNovelSingleton não disponível durante _ready")
		get_tree().create_timer(0.1).timeout.connect(_delayed_initialization)
		return
	
	# Carregar e atualizar a lista de personagens
	_load_characters()
	_refresh_character_list()

func _delayed_initialization():
	print("Tentando inicialização atrasada...")
	if _check_singleton():
		_load_characters()
		_refresh_character_list()

func _on_add_character_button_pressed():
	# Verificar se o VisualNovelSingleton está disponível
	if not _check_singleton():
		return
	
	var new_character = CharacterResource.new()
	var character_name = "Novo Personagem " + str(character_list.item_count + 1)
	new_character.display_name = character_name
	new_character.description = "Descrição do personagem"
	
	# Adicionar expressão padrão
	new_character.add_expression("default", "res://icon.svg")
	
	# Registrar o personagem
	VisualNovelSingleton.register_character(new_character)
	
	# Atualizar a lista
	_refresh_character_list()
	
	# Selecionar o novo personagem
	var new_index = character_list.item_count - 1
	character_list.select(new_index)
	_on_character_selected(new_index)
	
	# Forçar salvamento imediato
	_on_save_button_pressed()

func _on_delete_character_button_pressed():
	if not _check_singleton():
		return
		
	var selected_items = character_list.get_selected_items()
	if selected_items.size() > 0:
		var character_name = character_list.get_item_text(selected_items[0])
		
		# Encontrar o personagem pelo nome
		var character_to_delete = null
		var character_id_to_delete = null
		for character_id in VisualNovelSingleton.characters:
			var character = VisualNovelSingleton.characters[character_id]
			if character.display_name == character_name:
				character_to_delete = character
				character_id_to_delete = character_id
				break
		
		if character_to_delete:
			# Remover do singleton
			VisualNovelSingleton.characters.erase(character_id_to_delete)
			_refresh_character_list()
			
			# Limpar editor se necessário
			if current_character and current_character.character_id == character_id_to_delete:
				current_character = null
				_clear_character_editor()

func _on_save_button_pressed():
	if not _check_singleton():
		return
	
	if not current_character:
		push_error("Nenhum personagem selecionado!")
		return
	
	# Atualizar dados
	current_character.display_name = character_name_edit.text
	current_character.description = character_description_edit.text
	
	# Forçar atualização do recurso
	current_character.notify_property_list_changed()
	
	# Salvar o recurso
	VisualNovelSingleton.save_characters()
	
	# Emitir sinal de atualização
	VisualNovelSingleton.characters_updated.emit()
	
	# Atualizar lista para refletir possíveis mudanças no nome
	_refresh_character_list()

func _on_load_button_pressed():
	if not _check_singleton():
		return
		
	VisualNovelSingleton.load_characters()
	_refresh_character_list()
	print("Personagens carregados!")

func _on_character_selected(index):
	if not _check_singleton():
		return
		
	if index < 0 or index >= character_list.item_count:
		return
		
	var character_name = character_list.get_item_text(index)
	
	# Encontrar o personagem pelo nome na lista
	var character_ids = VisualNovelSingleton.characters.keys()
	for character_id in character_ids:
		var character = VisualNovelSingleton.characters[character_id]
		if character.display_name == character_name:
			current_character = character
			break
	
	if current_character:
		_update_character_ui()
	else:
		current_character = null
		_clear_character_editor()

# Método para verificar se o VisualNovelSingleton está disponível
func _check_singleton() -> bool:
	if not VisualNovelSingleton:
		push_error("VisualNovelSingleton não está disponível!")
		return false
	return true

# Métodos para atualizar a UI
func _refresh_character_list():
	print("_refresh_character_list chamado")
	
	if not character_list:
		print("character_list é null!")
		return
		
	if not _check_singleton():
		print("VisualNovelSingleton não disponível")
		return
	
	character_list.clear()
	
	print("Atualizando lista de personagens. Total: ", VisualNovelSingleton.characters.size())
	
	# Iterar pelos personagens e mostrar seus nomes
	for character_id in VisualNovelSingleton.characters:
		var character = VisualNovelSingleton.characters[character_id]
		character_list.add_item(character.display_name)
		print("Adicionado personagem à lista: ", character.display_name)
	
	print("Lista atualizada. Items na lista: ", character_list.item_count)

func _update_character_ui():
	if not current_character:
		return
		
	if character_name_edit:
		character_name_edit.text = current_character.display_name
	if character_description_edit:
		character_description_edit.text = current_character.description
	
	# Atualizar lista de expressões
	if expression_list:
		expression_list.clear()
		for expression_name in current_character.expressions:
			expression_list.add_item(expression_name)
		
		# Selecionar a primeira expressão se existir
		if expression_list.item_count > 0:
			expression_list.select(0)
			# Chamar diretamente a atualização da textura
			var texture_path = current_character.get_expression_texture(expression_list.get_item_text(0))
			if texture_path:
				texture_rect.texture = load(texture_path)
			else:
				texture_rect.texture = null
			texture_rect.queue_redraw()

func _clear_character_editor():
	if character_name_edit:
		character_name_edit.text = ""
	if character_description_edit:
		character_description_edit.text = ""
	if expression_list:
		expression_list.clear()
	if texture_rect:
		texture_rect.texture = null

# Métodos para persistência dos dados
func _save_characters():
	if _check_singleton():
		VisualNovelSingleton.save_characters()

func _load_characters():
	if not _check_singleton():
		return
		
	VisualNovelSingleton.load_characters()

func _on_image_change_button_pressed():
	 # Verificar se há uma expressão selecionada
	var selected_items = expression_list.get_selected_items()
	if selected_items.size() == 0:
		push_error("Selecione uma expressão primeiro!")
		return
	
	expression_selected_index = selected_items[0]
	var expression_name = expression_list.get_item_text(expression_selected_index)
	_show_file_dialog(expression_name)

func _on_add_expression_pressed():
	print("Botão de adicionar expressão pressionado") # Debug
	
	if not current_character:
		print("Nenhum personagem selecionado!")
		push_error("Selecione um personagem primeiro!")
		return
	
	# Primeiro, mostrar diálogo para nome da expressão
	_show_expression_name_dialog()

func _show_expression_name_dialog():
	# Criar AcceptDialog com LineEdit para o nome da expressão
	var name_dialog = AcceptDialog.new()
	name_dialog.title = "Nome da Expressão"
	name_dialog.size = Vector2(300, 120)
	
	# Criar VBoxContainer para organizar os elementos
	var vbox = VBoxContainer.new()
	
	# Adicionar label
	var label = Label.new()
	label.text = "Digite o nome da expressão:"
	vbox.add_child(label)
	
	# Adicionar LineEdit
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Nome da expressão"
	line_edit.text = "nova_expressao"
	vbox.add_child(line_edit)
	
	# Adicionar ao diálogo
	name_dialog.add_child(vbox)
	
	# Conectar sinais
	name_dialog.confirmed.connect(_on_expression_name_confirmed.bind(line_edit))
	name_dialog.canceled.connect(_on_expression_name_canceled.bind(name_dialog))
	
	# Adicionar à cena e mostrar
	add_child(name_dialog)
	name_dialog.popup_centered()
	
	# Focar no LineEdit
	line_edit.grab_focus()

func _on_expression_name_confirmed(line_edit: LineEdit):
	var expression_name = line_edit.text.strip_edges()
	
	# Remover o diálogo
	var dialog = line_edit.get_parent().get_parent()
	dialog.queue_free()
	
	if expression_name.is_empty():
		push_error("Nome da expressão não pode estar vazio!")
		return
	
	# Verificar se já existe
	if current_character.expressions.has(expression_name):
		push_error("Expressão com este nome já existe!")
		return
	
	# Agora mostrar o FileDialog para selecionar a imagem
	_show_file_dialog(expression_name)

func _on_expression_name_canceled(dialog: AcceptDialog):
	dialog.queue_free()

func _show_file_dialog(expression_name: String):
	print("Abrindo FileDialog para expressão:", expression_name)
	
	# Limpar FileDialog anterior se existir
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
	
	# Criar novo FileDialog
	file_dialog = FileDialog.new()
	file_dialog.title = "Selecione uma imagem para a expressão"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.png; *.jpg; *.jpeg; *.webp", "Imagens")
	
	# Definir diretório inicial
	file_dialog.current_dir = "res://"
	file_dialog.size = Vector2(800, 600)
	
	# Conectar sinais
	if not file_dialog.file_selected.is_connected(_on_expression_file_selected):
		file_dialog.file_selected.connect(_on_expression_file_selected.bind(expression_name))
	if not file_dialog.canceled.is_connected(_on_expression_dialog_canceled):
		file_dialog.canceled.connect(_on_expression_dialog_canceled)
	
	# Adicionar à cena e mostrar
	add_child(file_dialog)
	file_dialog.popup_centered()
	
	print("FileDialog criado e mostrado")

func _on_expression_dialog_canceled():
	print("FileDialog cancelado")
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
	file_dialog = null

# dialogue_block_type.gd
func _on_expression_file_selected(path: String, expression_name: String):
	print("Arquivo selecionado:", path, "para expressão:", expression_name)
	
	# Limpar FileDialog
	if file_dialog and is_instance_valid(file_dialog):
		file_dialog.queue_free()
	file_dialog = null
	
	if not current_character:
		return
	
	# Armazenar o caminho original diretamente
	current_character.add_expression(expression_name, path)
	
	# Atualizar UI
	_update_character_ui()
	
	# Selecionar a expressão novamente
	for i in range(expression_list.item_count):
		if expression_list.get_item_text(i) == expression_name:
			expression_list.select(i)
			expression_selected_index = i
			_on_expression_selected(i)
			break
	
	print("Expressão atualizada com sucesso:", expression_name)
	_update_current_character()

func _on_remove_expression_pressed():
	if not current_character:
		return
	
	var selected_items = expression_list.get_selected_items()
	if selected_items.size() > 0:
		var expression_name = expression_list.get_item_text(selected_items[0])
		
		# Não remover expressão default
		if expression_name == "default":
			push_error("Não é possível remover a expressão padrão!")
			return
		
		# Remover apenas a referência, não o arquivo original
		current_character.remove_expression(expression_name)
		_update_character_ui()
	
	_update_current_character()

func _on_expression_selected(index):
	if not current_character or index < 0 or index >= expression_list.item_count:
		return
	
	var expression_name = expression_list.get_item_text(index)
	var texture_path = current_character.get_expression_texture(expression_name)
	
	print("Expressão selecionada:", expression_name, "Caminho:", texture_path)
	
	# Limpar textura atual primeiro
	texture_rect.texture = null
	
	if texture_path:
		# Carregar a textura de forma assíncrona para evitar travamentos
		var texture = load(texture_path)
		if texture:
			# Verificar se a textura foi carregada corretamente
			if texture is Texture2D:
				texture_rect.texture = texture
				print("Textura carregada com sucesso")
			else:
				push_error("O arquivo carregado não é uma textura válida: " + texture_path)
				texture_rect.texture = null
		else:
			push_error("Falha ao carregar textura: " + texture_path)
			texture_rect.texture = null
	
	# Forçar redesenho da textura
	texture_rect.queue_redraw()
	_update_current_character()
	
	print("Estado do TextureRect após atualização:")
	print(" - Texture: ", texture_rect.texture)
	print(" - Visible: ", texture_rect.visible)
	print(" - Size: ", texture_rect.size)
	print(" - Texture size: ", texture_rect.texture.get_size() if texture_rect.texture else "N/A")

func _update_current_character():
	if not current_character:
		return
	
	# Atualizar propriedades básicas
	current_character.display_name = character_name_edit.text
	current_character.description = character_description_edit.text
	
	# Forçar atualização do recurso
	current_character.notify_property_list_changed()
