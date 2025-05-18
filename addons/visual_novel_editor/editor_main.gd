## Exemplo de Código para visual_novel_editor.tscn
@tool
extends Panel

# Referências aos nós da UI
@onready var chapter_list = $VBoxContainer/HSplitContainer/ChapterList/ItemList
@onready var chapter_name_edit = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/ChapterNameEdit
@onready var chapter_description_edit = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/ChapterDescriptionEdit
@onready var graph_edit = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/HSplitContainer/GraphEdit
@onready var block_editor = $VBoxContainer/HSplitContainer/TabContainer/ChapterEditor/HSplitContainer/BlockEditor

# Capítulo atual sendo editado
var current_chapter: ChapterResource = null
# Bloco atual sendo editado
var current_block_id = ""

func _ready():
	# Conectar sinais
	$VBoxContainer/Toolbar/AddChapterButton.pressed.connect(_on_add_chapter_button_pressed)
	$VBoxContainer/Toolbar/DeleteChapterButton.pressed.connect(_on_delete_chapter_button_pressed)
	$VBoxContainer/Toolbar/SaveButton.pressed.connect(_on_save_button_pressed)
	$VBoxContainer/Toolbar/LoadButton.pressed.connect(_on_load_button_pressed)
	
	chapter_list.item_selected.connect(_on_chapter_selected)
	graph_edit.node_selected.connect(_on_graph_node_selected)
	
	# Adicionar botões de contexto
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "Add Dialogue"
	add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	graph_edit.get_menu_hbox().add_child(add_dialogue_btn)
	
	var add_choice_btn = Button.new()
	add_choice_btn.text = "Add Choice"
	add_choice_btn.pressed.connect(_on_add_choice_pressed)
	graph_edit.get_menu_hbox().add_child(add_choice_btn)
	
	_load_chapters()

# Métodos para interação com a UI
func _on_add_chapter_button_pressed():
	if not Engine.is_editor_hint():
		return
	
	var new_chapter = ChapterResource.new()
	new_chapter.chapter_name = "Novo Capítulo " + str(chapter_list.item_count + 1)
	new_chapter.chapter_description = "Descrição do capítulo"
	
	# Adicionar um bloco inicial
	var block_id = "start_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "dialogue",
		"character_name": "Narrator",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Começo da história...",
		"next_block_id": "",
		"graph_position": Vector2(100, 100)
	}
	new_chapter.add_block(block_id, block_data)
	new_chapter.start_block_id = block_id
	
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
		_update_chapter_editor()
	else:
		current_chapter = null
		_clear_chapter_editor()

func _on_graph_node_selected(node):
	# Quando um nó é selecionado no grafo, atualizar o editor de blocos
	current_block_id = node.name
	_update_block_editor()

# Métodos para atualizar a UI
func _refresh_chapter_list():
	chapter_list.clear()
	
	for chapter_name in VisualNovelSingleton.chapters:
		chapter_list.add_item(chapter_name)

#func _update_chapter_editor():
	#if current_chapter:
		#chapter_name_edit.text = current_chapter.chapter_name
		#chapter_description_edit.text = current_chapter.chapter_description
		#
		## Limpar o grafo existente
		#for child in graph_edit.get_children():
			#if child is GraphNode:
				#graph_edit.remove_child(child)
				#child.queue_free()
		#
		## Adicionar blocos ao grafo
		#for block_id in current_chapter.blocks:
			#var block = current_chapter.blocks[block_id]
			#_add_block_to_graph(block_id, block)
		#
		## Adicionar conexões entre os blocos
		#for block_id in current_chapter.blocks:
			#var block = current_chapter.blocks[block_id]
			#if block.has("next_block_id") and not block.next_block_id.is_empty():
				#graph_edit.connect_node(block_id, 0, block.next_block_id, 0)
			#
			#if block.has("choices"):
				#for i in range(block.choices.size()):
					#var choice = block.choices[i]
					#if not choice.next_block_id.is_empty():
						#graph_edit.connect_node(block_id, i + 1, choice.next_block_id, 0)
#
##func _add_block_to_graph(block_id, block_data):
	##var graph_node = GraphNode.new()
	##graph_node.name = block_id
	##graph_node.title = block_data.type.capitalize() + ": " + block_id
	##graph_node.resizable = true
	##graph_node.set_size(Vector2(200, 100))
	##
	### Adicionar conteúdo com base no tipo do bloco
	##var content = Label.new()
	##match block_data.type:
		##"dialogue":
			##content.text = block_data.character_name + ":\n" + block_data.text
		##"choice":
			##var choices_text = ""
			##for choice in block_data.choices:
				##choices_text += "- " + choice.text + "\n"
			##content.text = "Escolhas:\n" + choices_text
	##
	##graph_node.add_child(content)
	##
	### Configure os slots (para conectar blocos)
	##if block_data.type == "dialogue":
		##graph_node.set_slot(0, true, 0, Color.GREEN, true, 0, Color.RED)
	##elif block_data.type == "choice":
		##graph_node.set_slot(0, true, 0, Color.GREEN, false, 0, Color.RED)
		##
		### Adicionar slots adicionais para cada escolha
		##for i in range(block_data.choices.size()):
			##var slot = Label.new()
			##slot.text = "Escolha " + str(i + 1)
			##graph_node.add_child(slot)
			##graph_node.set_slot(i + 1, false, 0, Color.GREEN, true, 0, Color.RED)
	##
	##graph_edit.add_child(graph_node)

func _update_block_editor():
	if not current_chapter or current_block_id.is_empty():
		_clear_block_editor()
		return
	
	var block = current_chapter.get_block(current_block_id)
	if not block:
		_clear_block_editor()
		return
	
	# Limpar o editor atual
	for child in block_editor.get_children():
		block_editor.remove_child(child)
		child.queue_free()
	
	# Criar UI baseada no tipo de bloco
	var vbox = VBoxContainer.new()
	block_editor.add_child(vbox)
	
	# Adicionar campos comuns
	var type_label = Label.new()
	type_label.text = "Tipo: " + block.type
	vbox.add_child(type_label)
	
	match block.type:
		"dialogue":
			_create_dialogue_editor(vbox, block)
		"choice":
			_create_choice_editor(vbox, block)

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
			current_chapter.update_block(current_block_id, block_data)
			
			# Atualizar o grafo
			_update_chapter_editor()
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
			_update_block_editor()
			
			# Atualizar o bloco no capítulo
			if current_chapter:
				current_chapter.update_block(current_block_id, block_data)
				
				# Atualizar o grafo
				_update_chapter_editor()
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
		_update_block_editor()
		
		# Atualizar o bloco no capítulo
		if current_chapter:
			current_chapter.update_block(current_block_id, block_data)
			
			# Atualizar o grafo
			_update_chapter_editor()
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
			current_chapter.update_block(current_block_id, block_data)
			
			# Atualizar o grafo
			_update_chapter_editor()
	)
	parent.add_child(save_button)

func _clear_chapter_editor():
	chapter_name_edit.text = ""
	chapter_description_edit.text = ""
	
	# Limpar o grafo
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	
	# Limpar o editor de blocos
	_clear_block_editor()

func _clear_block_editor():
	for child in block_editor.get_children():
		block_editor.remove_child(child)
		child.queue_free()

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

func _update_chapter_editor():
	if current_chapter:
		chapter_name_edit.text = current_chapter.chapter_name
		chapter_description_edit.text = current_chapter.chapter_description
		
		# Limpar o grafo existente
		_clear_graph()
		
		# Adicionar blocos ao grafo
		for block_id in current_chapter.blocks:
			var block = current_chapter.blocks[block_id]
			_add_block_to_graph(block_id, block)
		
		# Adicionar conexões entre os blocos
		_update_connections()

func _clear_graph():
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()

func _add_block_to_graph(block_id: String, block_data: Dictionary) -> void:
	# Carregar a cena do nó de diálogo
	var block_scene = preload("uid://rj8arjvt7auh")
	
	# Verificar se a cena foi carregada corretamente
	if not block_scene:
		push_error("Failed to load dialogue block scene")
		return
	
	# Instanciar o nó
	var node = block_scene.instantiate()
	node.name = block_id
	
	# Configurar o nó
	node.setup(block_data.duplicate(true))
	node.block_updated.connect(_on_block_updated.bind(block_id))
	
	# Definir posição
	if block_data.has("graph_position"):
		node.position_offset = block_data["graph_position"]
	else:
		node.position_offset = Vector2(randi_range(0, 500), randi_range(0, 300))
	
	# Configurar slots de conexão
	match block_data["type"]:
		"dialogue":
			node.set_slot(0, false, 0, Color(0.5, 0.5, 1), true, 0, Color(1, 0.5, 0.5))
		"choice":
			for i in range(block_data["choices"].size()):
				node.set_slot(i, false, 0, Color(0.5, 0.5, 1), true, 0, Color(1, 0.5, 0.5))
	
	# Adicionar ao GraphEdit
	graph_edit.add_child(node)

func _on_block_updated(new_data, block_id):
	if current_chapter and current_chapter.blocks.has(block_id):
		# Salvar posição do nó
		var node = graph_edit.get_node_or_null(block_id)
		if node:
			new_data["graph_position"] = node.position_offset
		
		current_chapter.blocks[block_id] = new_data
		_update_connections()

func _update_connections():
	# Limpar todas as conexões
	for conn in graph_edit.get_connection_list():
		graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	if not current_chapter:
		return
	
	# Adicionar conexões baseadas nos dados
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		
		if block.type == "dialogue" and block.has("next_block_id") and not block.next_block_id.is_empty():
			graph_edit.connect_node(block_id, 0, block.next_block_id, 0)
		
		if block.type == "choice" and block.has("choices"):
			for i in range(block.choices.size()):
				var choice = block.choices[i]
				if not choice.next_block_id.is_empty():
					graph_edit.connect_node(block_id, i, choice.next_block_id, 0)

func _on_connection_request(from_node, from_port, to_node, to_port):
	if not current_chapter:
		return
	
	var from_block = current_chapter.blocks.get(from_node)
	var to_block = current_chapter.blocks.get(to_node)
	
	if not from_block or not to_block:
		return
	
	if from_block.type == "dialogue":
		from_block.next_block_id = to_node
	elif from_block.type == "choice" and from_port < from_block.choices.size():
		from_block.choices[from_port].next_block_id = to_node
	
	_update_connections()

func _on_disconnection_request(from_node, from_port, to_node, to_port):
	if not current_chapter:
		return
	
	var from_block = current_chapter.blocks.get(from_node)
	
	if not from_block:
		return
	
	if from_block.type == "dialogue":
		from_block.next_block_id = ""
	elif from_block.type == "choice" and from_port < from_block.choices.size():
		from_block.choices[from_port].next_block_id = ""
	
	_update_connections()

func _on_delete_nodes_request(nodes):
	if not current_chapter:
		return
	
	for node_name in nodes:
		current_chapter.remove_block(node_name)
	
	_update_chapter_editor()

func _on_add_dialogue_pressed():
	if not current_chapter:
		return
	
	var block_id = "dialogue_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "dialogue",
		"character_name": "Personagem",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Digite o texto aqui...",
		"next_block_id": "",
		"graph_position": graph_edit.scroll_offset + Vector2(100, 100)
	}
	
	current_chapter.add_block(block_id, block_data)
	_update_chapter_editor()

func _on_add_choice_pressed():
	if not current_chapter:
		return
	
	var block_id = "choice_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "choice",
		"choices": [
			{"text": "Opção 1", "next_block_id": ""},
			{"text": "Opção 2", "next_block_id": ""}
		],
		"graph_position": graph_edit.scroll_offset + Vector2(100, 100)
	}
	
	current_chapter.add_block(block_id, block_data)
	_update_chapter_editor()

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
	_update_chapter_editor()
	
	current_block_id = block_id
	_update_block_editor()

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
	_update_chapter_editor()
	
	current_block_id = block_id
	_update_block_editor()
