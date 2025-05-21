@tool
extends Panel

# Referências aos nós da UI
@onready var chapter_list = $VBoxContainer/HSplitContainer/ChapterList/ItemList
@onready var chapter_name_edit = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/ChapterNameEdit
@onready var chapter_description_edit = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/ChapterDescriptionEdit
@onready var graph_edit: ChapterEditor = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/HSplitContainer/GraphEdit
@onready var block_editor: BlockEditor = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/HSplitContainer/BlockEditor

# Capítulo atual sendo editado
var current_chapter: ChapterResource = null

func _ready():
	# Conectar sinais
	$VBoxContainer/Toolbar/AddChapterButton.pressed.connect(_on_add_chapter_button_pressed)
	$VBoxContainer/Toolbar/DeleteChapterButton.pressed.connect(_on_delete_chapter_button_pressed)
	$VBoxContainer/Toolbar/SaveButton.pressed.connect(_on_save_button_pressed)
	$VBoxContainer/Toolbar/LoadButton.pressed.connect(_on_load_button_pressed)
	
	#EventBus.register_event("_update_chapter_editor")
	#EventBus.register_event("update_block_editor")
	
	chapter_list.item_selected.connect(_on_chapter_selected)
	graph_edit.connect("change_chapter_ui", _on_chapter_data_changed)
	
	_load_chapters()

func _process(delta):
	if Engine.is_editor_hint():
		graph_edit.queue_redraw()

# Métodos para interação com a UI
func _on_add_chapter_button_pressed():
	if not Engine.is_editor_hint():
		return
	
	var new_chapter = ChapterResource.new()
	new_chapter.chapter_name = "Novo Capítulo " + str(chapter_list.item_count + 1)
	new_chapter.chapter_description = "Descrição do capítulo"
	
	# Adicionar bloco inicial
	var start_block_id = "start_" + str(Time.get_unix_time_from_system())
	var start_block_data = {
		"type": "start",
		"graph_position": Vector2(100, 300)
	}
	new_chapter.add_block(start_block_id, start_block_data)
	new_chapter.start_block_id = start_block_id
	
	# Adicionar bloco final
	var end_block_id = "end_" + str(Time.get_unix_time_from_system())
	var end_block_data = {
		"type": "end",
		"graph_position": Vector2(800, 300)
	}
	new_chapter.add_block(end_block_id, end_block_data)
	
	# Registrar o capítulo
	if VisualNovelSingleton.has_method("register_chapter"):
		VisualNovelSingleton.register_chapter(new_chapter)
	else:
		push_error("VisualNovelSingleton não está carregado corretamente!")
	
	_refresh_chapter_list()
	chapter_list.select(chapter_list.item_count - 1)
	_on_chapter_selected(chapter_list.item_count - 1)

func _on_delete_chapter_button_pressed():
	var selected_index = chapter_list.get_selected_items()
	if selected_index.size() > 0:
		var chapter_name = chapter_list.get_item_text(selected_index[0])
		if VisualNovelSingleton.chapters.has(chapter_name):
			VisualNovelSingleton.chapters.erase(chapter_name)
			_refresh_chapter_list()
			
			# Limpar o editor se o capítulo atual foi excluído
			if current_chapter and current_chapter.chapter_name == chapter_name:
				current_chapter = null
				_clear_chapter_editor()

func _on_chapter_data_changed(chapter_name:String, chapter_description: String):
	chapter_description_edit.text = chapter_description
	chapter_name_edit.text = chapter_name

func _on_save_button_pressed():
	if current_chapter:
		current_chapter.chapter_name = chapter_name_edit.text
		current_chapter.chapter_description = chapter_description_edit.text
		
		# Atualizar a lista de capítulos
		_refresh_chapter_list()
		
		# Salvar todos os capítulos
		_save_chapters()

func _on_load_button_pressed():
	_load_chapters()
	_refresh_chapter_list()

func _on_chapter_selected(index):
	var chapter_name = chapter_list.get_item_text(index)
	if VisualNovelSingleton.chapters.has(chapter_name):
		current_chapter = VisualNovelSingleton.chapters[chapter_name]
		graph_edit._update_chapter_editor(current_chapter)
	else:
		current_chapter = null
		_clear_chapter_editor()

# Métodos para atualizar a UI
func _refresh_chapter_list():
	chapter_list.clear()
	
	for chapter_name in VisualNovelSingleton.chapters:
		chapter_list.add_item(chapter_name)

func _create_dialogue_editor(parent, block_data):
	# Adicionar editor para blocos de diálogo
	var char_label = Label.new()
	char_label.text = "Personagem:"
	parent.add_child(char_label)
	
	var char_edit = LineEdit.new()
	char_edit.text = block_data.character_name
	char_edit.placeholder_text = "Nome do personagem"
	parent.add_child(char_edit)
	
	var expr_label = Label.new()
	expr_label.text = "Expressão:"
	parent.add_child(expr_label)
	
	var expr_edit = LineEdit.new()
	expr_edit.text = block_data.character_expression
	expr_edit.placeholder_text = "Expressão do personagem"
	parent.add_child(expr_edit)
	
	var pos_label = Label.new()
	pos_label.text = "Posição (X, Y):"
	parent.add_child(pos_label)
	
	var pos_container = HBoxContainer.new()
	parent.add_child(pos_container)
	
	var pos_x_edit = SpinBox.new()
	pos_x_edit.min_value = 0.0
	pos_x_edit.max_value = 1.0
	pos_x_edit.step = 0.1
	pos_x_edit.value = block_data.character_position.x
	pos_container.add_child(pos_x_edit)
	
	var pos_y_edit = SpinBox.new()
	pos_y_edit.min_value = 0.0
	pos_y_edit.max_value = 1.0
	pos_y_edit.step = 0.1
	pos_y_edit.value = block_data.character_position.y
	pos_container.add_child(pos_y_edit)
	
	var text_label = Label.new()
	text_label.text = "Texto:"
	parent.add_child(text_label)
	
	var text_edit = TextEdit.new()
	text_edit.text = block_data.text
	text_edit.placeholder_text = "Digite o texto do diálogo aqui"
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(text_edit)
	
	var next_label = Label.new()
	next_label.text = "Próximo bloco:"
	parent.add_child(next_label)
	
	var next_edit = LineEdit.new()
	next_edit.text = block_data.next_block_id
	next_edit.placeholder_text = "ID do próximo bloco"
	parent.add_child(next_edit)
	
	# Botão para salvar alterações
	var save_button = Button.new()
	save_button.text = "Salvar Alterações"
	save_button.pressed.connect(func():
		# Atualizar dados do bloco
		block_data.character_name = char_edit.text
		block_data.character_expression = expr_edit.text
		block_data.character_position = Vector2(pos_x_edit.value, pos_y_edit.value)
		block_data.text = text_edit.text
		block_data.next_block_id = next_edit.text
		
		# Atualizar o bloco no capítulo
		if current_chapter:
			current_chapter.update_block(block_editor.current_block_id, block_data)
			
			# Atualizar o grafo
			graph_edit._update_chapter_editor(current_chapter)
	)
	parent.add_child(save_button)

func _create_choice_editor(parent, block_data):
	# Adicionar editor para blocos de escolha
	var choices_label = Label.new()
	choices_label.text = "Escolhas:"
	parent.add_child(choices_label)
	
	var choices_container = VBoxContainer.new()
	parent.add_child(choices_container)
	
	# Adicionar as escolhas existentes
	for i in range(block_data.choices.size()):
		var choice = block_data.choices[i]
		var choice_container = HBoxContainer.new()
		choices_container.add_child(choice_container)
		
		var choice_text = LineEdit.new()
		choice_text.text = choice.text
		choice_text.placeholder_text = "Texto da escolha"
		choice_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.add_child(choice_text)
		
		var next_id = LineEdit.new()
		next_id.text = choice.next_block_id
		next_id.placeholder_text = "Próximo bloco"
		next_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.add_child(next_id)
		
		var delete_button = Button.new()
		delete_button.text = "X"
		delete_button.pressed.connect(func():
			# Remover a escolha
			block_data.choices.remove_at(i)
			
			# Atualizar o editor
			block_editor._update_block_editor(graph_edit.name, current_chapter)
			
			# Atualizar o bloco no capítulo
			if current_chapter:
				current_chapter.update_block(block_editor.current_block_id, block_data)
				
				# Atualizar o grafo
				graph_edit._update_chapter_editor(current_chapter)
		)
		choice_container.add_child(delete_button)
	
	# Botão para adicionar nova escolha
	var add_choice_button = Button.new()
	add_choice_button.text = "Adicionar Escolha"
	add_choice_button.pressed.connect(func():
		# Adicionar nova escolha
		block_data.choices.append({
			"text": "Nova escolha",
			"next_block_id": ""
		})
		
		# Atualizar o editor
		block_editor._update_block_editor(graph_edit.name, current_chapter)
		
		# Atualizar o bloco no capítulo
		if current_chapter:
			current_chapter.update_block(block_editor.current_block_id, block_data)
			
			# Atualizar o grafo
			graph_edit._update_chapter_editor(current_chapter)
	)
	parent.add_child(add_choice_button)
	
	# Botão para salvar alterações
	var save_button = Button.new()
	save_button.text = "Salvar Alterações"
	save_button.pressed.connect(func():
		# Atualizar dados das escolhas
		for i in range(block_data.choices.size()):
			var choice_container = choices_container.get_child(i)
			var choice_text = choice_container.get_child(0)
			var next_id = choice_container.get_child(1)
			
			block_data.choices[i].text = choice_text.text
			block_data.choices[i].next_block_id = next_id.text
		
		# Atualizar o bloco no capítulo
		if current_chapter:
			current_chapter.update_block(block_editor.current_block_id, block_data)
			
			# Atualizar o grafo
			graph_edit._update_chapter_editor(current_chapter)
	)
	parent.add_child(save_button)

func _is_connection_valid(from_block, to_block, from_port) -> bool:
	# Não permitir conectar a um bloco start
	if to_block["type"] == "start":
		return false
	
	# Não permitir conectar de um bloco end
	if from_block["type"] == "end":
		return false
	
	# Validações específicas para blocos choice
	if from_block["type"] == "choice":
		if from_port >= from_block.get("choices", []).size():
			return false
	
	return true

func _on_connection_to_empty(from_node, from_port, release_position):
	# Criar um novo bloco quando arrastar conexão para área vazia
	var new_block_id = "dialogue_" + str(Time.get_unix_time_from_system())
	var new_block_data = {
		"type": "dialogue",
		"character_name": "Personagem",
		"text": "Novo diálogo...",
		"next_block_id": "",
		"graph_position": release_position
	}
	
	current_chapter.add_block(new_block_id, new_block_data)
	
	# Conectar ao novo bloco
	graph_edit._on_connection_request(from_node, from_port, new_block_id, 0)
	graph_edit._update_chapter_editor(current_chapter)

func _clear_chapter_editor():
	chapter_name_edit.text = ""
	chapter_description_edit.text = ""
	
	# Limpar o grafo
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	
	# Limpar o editor de blocos
	block_editor._clear_block_editor()

# Métodos para persistência dos dados
func _save_chapters():
	# Cria a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir("res://addons/visual_novel_editor/data")
	
	# Preparar os dados para salvar
	var save_data = {}
	for chapter_name in VisualNovelSingleton.chapters:
		var chapter = VisualNovelSingleton.chapters[chapter_name]
		
		# Converter o resource para um formato serializável
		var chapter_data = {
			"chapter_name": chapter.chapter_name,
			"chapter_description": chapter.chapter_description,
			"start_block_id": chapter.start_block_id,
			"blocks": chapter.blocks
		}
		
		save_data[chapter_name] = chapter_data
	
	# Salvar os dados em um arquivo JSON
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()
	
	print("Chapters saved successfully!")

func _load_chapters():
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/chapters.json"):
		print("No chapters file found.")
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var chapters_data = json.get_data()
	
	# Limpar os capítulos existentes
	VisualNovelSingleton.chapters.clear()
	
	# Criar objetos ChapterResource para cada capítulo carregado
	for chapter_name in chapters_data:
		var chapter_data = chapters_data[chapter_name]
		
		var chapter = ChapterResource.new()
		chapter.chapter_name = chapter_data["chapter_name"]
		chapter.chapter_description = chapter_data["chapter_description"]
		chapter.start_block_id = chapter_data["start_block_id"]
		chapter.blocks = chapter_data["blocks"]
		
		VisualNovelSingleton.register_chapter(chapter)
	
	print("Chapters loaded successfully!")

func _update_connections() -> void:
	# Limpar todas as conexões visuais primeiro
	graph_edit.clear_connections()
	
	if not current_chapter:
		return
	
	# Reconectar todos os nós baseado nos dados do capítulo
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		
		if not graph_edit.has_node(block_id):
			continue
			
		match block["type"]:
			"start", "dialogue":
				if block.has("next_block_id") and not block.next_block_id.is_empty():
					if graph_edit.has_node(block.next_block_id):
						graph_edit.connect_node(block_id, 0, block.next_block_id, 0)
			
			"choice":
				if block.has("choices"):
					for i in range(block.choices.size()):
						var choice = block.choices[i]
						if choice.has("next_block_id") and not choice.next_block_id.is_empty():
							if graph_edit.has_node(choice.next_block_id):
								graph_edit.connect_node(block_id, i + 1, choice.next_block_id, 0)

func _on_delete_nodes_request(nodes):
	if not current_chapter:
		return
	
	for node_name in nodes:
		current_chapter.remove_block(node_name)
	
	graph_edit._update_chapter_editor(current_chapter)

# Métodos para adicionar novos blocos ao capítulo atual
func add_dialogue_block():
	if not current_chapter:
		return
		
	var block_id = "dialogue_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "dialogue",
		"character_name": "Personagem",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Digite o texto aqui...",
		"next_block_id": ""
	}
	
	current_chapter.add_block(block_id, block_data)
	graph_edit._update_chapter_editor(current_chapter)
	
	block_editor.current_block_id = block_id
	block_editor._update_block_editor(graph_edit.name, current_chapter)

func add_choice_block():
	if not current_chapter:
		return
		
	var block_id = "choice_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "choice",
		"choices": [
			{
				"text": "Opção 1",
				"next_block_id": ""
			},
			{
				"text": "Opção 2",
				"next_block_id": ""
			}
		]
	}
	
	current_chapter.add_block(block_id, block_data)
	graph_edit._update_chapter_editor(current_chapter)
	
	block_editor.current_block_id = block_id
	block_editor._update_block_editor(graph_edit.name, current_chapter)
