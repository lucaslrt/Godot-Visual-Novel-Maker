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
	# REMOVIDO: Verificação que impedia execução no editor
	# O plugin DEVE executar no editor
	
	# Conectar sinais
	$VBoxContainer/Toolbar/AddChapterButton.pressed.connect(_on_add_chapter_button_pressed)
	$VBoxContainer/Toolbar/DeleteChapterButton.pressed.connect(_on_delete_chapter_button_pressed)
	$VBoxContainer/Toolbar/SaveButton.pressed.connect(_on_save_button_pressed)
	$VBoxContainer/Toolbar/LoadButton.pressed.connect(_on_load_button_pressed)
	
	# Conectar sinal da lista de capítulos
	if chapter_list:
		chapter_list.item_selected.connect(_on_chapter_selected)
	
	# Conectar sinal do graph_edit se existir
	if graph_edit:
		graph_edit.connect("change_chapter_ui", _on_chapter_data_changed)
	
	# Aguardar alguns frames para garantir que tudo esteja inicializado
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verificar se o VisualNovelSingleton está disponível
	if not _check_singleton():
		print("VisualNovelSingleton não disponível durante _ready")
		# Tentar novamente após um pequeno delay
		get_tree().create_timer(0.1).timeout.connect(_delayed_initialization)
		return
	
	# Carregar e atualizar a lista de capítulos
	_load_chapters()
	_refresh_chapter_list()

func _delayed_initialization():
	print("Tentando inicialização atrasada...")
	if _check_singleton():
		_load_chapters()
		_refresh_chapter_list()
	else:
		print("VisualNovelSingleton ainda não disponível")

func _process(delta):
	# CORRIGIDO: Verificar se graph_edit existe antes de tentar usar
	if graph_edit:
		graph_edit.queue_redraw()

# Métodos para interação com a UI
func _on_add_chapter_button_pressed():
	# REMOVIDO: Verificação desnecessária do editor
	
	# Verificar se o VisualNovelSingleton está disponível
	if not _check_singleton():
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
	VisualNovelSingleton.register_chapter(new_chapter)
	
	# Atualizar a lista
	_refresh_chapter_list()
	
	# Selecionar o novo capítulo
	var new_index = chapter_list.item_count - 1
	chapter_list.select(new_index)
	_on_chapter_selected(new_index)

func _on_delete_chapter_button_pressed():
	if not _check_singleton():
		return
		
	var selected_items = chapter_list.get_selected_items()
	if selected_items.size() > 0:
		var chapter_name = chapter_list.get_item_text(selected_items[0])
		if VisualNovelSingleton.chapters.has(chapter_name):
			VisualNovelSingleton.chapters.erase(chapter_name)
			_refresh_chapter_list()
			
			# Limpar o editor se o capítulo atual foi excluído
			if current_chapter and current_chapter.chapter_name == chapter_name:
				current_chapter = null
				_clear_chapter_editor()

func _on_chapter_data_changed(chapter_name:String, chapter_description: String):
	if chapter_description_edit:
		chapter_description_edit.text = chapter_description
	if chapter_name_edit:
		chapter_name_edit.text = chapter_name

func _on_save_button_pressed():
	if not _check_singleton():
		return
		
	if current_chapter and chapter_name_edit and chapter_description_edit:
		# CORRIGIDO: Atualizar o nome no dicionário de capítulos se mudou
		var old_name = current_chapter.chapter_name
		var new_name = chapter_name_edit.text
		
		current_chapter.chapter_name = new_name
		current_chapter.chapter_description = chapter_description_edit.text
		
		# Se o nome mudou, atualizar a chave no dicionário
		if old_name != new_name and VisualNovelSingleton.chapters.has(old_name):
			VisualNovelSingleton.chapters.erase(old_name)
			VisualNovelSingleton.chapters[new_name] = current_chapter
		
		# Atualizar a lista de capítulos
		_refresh_chapter_list()
		
		# Salvar todos os capítulos
		VisualNovelSingleton.save_chapters()
		print("Capítulos salvos!")

func _on_load_button_pressed():
	if not _check_singleton():
		return
		
	VisualNovelSingleton.load_chapters()
	_refresh_chapter_list()
	print("Capítulos carregados!")

func _on_chapter_selected(index):
	if not _check_singleton():
		return
		
	if index < 0 or index >= chapter_list.item_count:
		return
		
	var chapter_name = chapter_list.get_item_text(index)
	if VisualNovelSingleton.chapters.has(chapter_name):
		current_chapter = VisualNovelSingleton.chapters[chapter_name]
		_update_chapter_ui()
		
		if graph_edit and graph_edit.has_method("_update_chapter_editor"):
			graph_edit._update_chapter_editor(current_chapter)
	else:
		current_chapter = null
		_clear_chapter_editor()

# Método para verificar se o VisualNovelSingleton está disponível
func _check_singleton() -> bool:
	if not VisualNovelSingleton:
		push_error("VisualNovelSingleton não está disponível!")
		return false
	return true

# Métodos para atualizar a UI
func _refresh_chapter_list():
	print("_refresh_chapter_list chamado")
	
	if not chapter_list:
		print("chapter_list é null!")
		return
		
	if not _check_singleton():
		print("VisualNovelSingleton não disponível")
		return
	
	chapter_list.clear()
	
	print("Atualizando lista de capítulos. Total: ", VisualNovelSingleton.chapters.size())
	
	# CORRIGIDO: Garantir que estamos iterando corretamente
	var chapter_names = VisualNovelSingleton.chapters.keys()
	for chapter_name in chapter_names:
		chapter_list.add_item(chapter_name)
		print("Adicionado capítulo à lista: ", chapter_name)
	
	print("Lista atualizada. Items na lista: ", chapter_list.item_count)

func _update_chapter_ui():
	if not current_chapter:
		return
		
	if chapter_name_edit:
		chapter_name_edit.text = current_chapter.chapter_name
	if chapter_description_edit:
		chapter_description_edit.text = current_chapter.chapter_description

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
	
	if current_chapter:
		current_chapter.add_block(new_block_id, new_block_data)
		
		# Conectar ao novo bloco
		if graph_edit:
			graph_edit._on_connection_request(from_node, from_port, new_block_id, 0)
			graph_edit._update_chapter_editor(current_chapter)

func _clear_chapter_editor():
	if chapter_name_edit:
		chapter_name_edit.text = ""
	if chapter_description_edit:
		chapter_description_edit.text = ""
	
	# Limpar o grafo se existir
	if graph_edit:
		for child in graph_edit.get_children():
			if child is GraphNode:
				graph_edit.remove_child(child)
				child.queue_free()
	
	# Limpar o editor de blocos se existir
	if block_editor and block_editor.has_method("_clear_block_editor"):
		block_editor._clear_block_editor()

# Métodos para persistência dos dados
func _save_chapters():
	# Esta função duplica a funcionalidade do VisualNovelSingleton
	# Melhor usar diretamente o singleton
	if _check_singleton():
		VisualNovelSingleton.save_chapters()

func _load_chapters():
	if not _check_singleton():
		return
		
	VisualNovelSingleton.load_chapters()

func _update_connections() -> void:
	if not graph_edit:
		return
		
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
	
	if graph_edit:
		graph_edit._update_chapter_editor(current_chapter)

# Métodos para adicionar novos blocos ao capítulo atual
func add_dialogue_block():
	if not current_chapter:
		push_error("Nenhum capítulo selecionado!")
		return
		
	var block_id = "dialogue_" + str(Time.get_unix_time_from_system())
	var block_data = {
		"type": "dialogue",
		"character_name": "Personagem",
		"character_expression": "default",
		"character_position": Vector2(0.5, 1.0),
		"text": "Digite o texto aqui...",
		"next_block_id": "",
		"graph_position": Vector2(400, 200)
	}
	
	current_chapter.add_block(block_id, block_data)
	
	if graph_edit and graph_edit.has_method("_update_chapter_editor"):
		graph_edit._update_chapter_editor(current_chapter)
	
	if block_editor:
		block_editor.current_block_id = block_id
		if block_editor.has_method("_update_block_editor"):
			block_editor._update_block_editor(graph_edit.name if graph_edit else "", current_chapter)

func add_choice_block():
	if not current_chapter:
		push_error("Nenhum capítulo selecionado!")
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
		],
		"graph_position": Vector2(400, 200)
	}
	
	current_chapter.add_block(block_id, block_data)
	
	if graph_edit and graph_edit.has_method("_update_chapter_editor"):
		graph_edit._update_chapter_editor(current_chapter)
	
	if block_editor:
		block_editor.current_block_id = block_id
		if block_editor.has_method("_update_block_editor"):
			block_editor._update_block_editor(graph_edit.name if graph_edit else "", current_chapter)

# Função para debug - pode ser chamada para verificar o estado
func debug_chapters():
	print("=== DEBUG CHAPTERS ===")
	if not _check_singleton():
		print("VisualNovelSingleton não disponível")
		return
	
	print("Total de capítulos: ", VisualNovelSingleton.chapters.size())
	for chapter_name in VisualNovelSingleton.chapters:
		print("- ", chapter_name)
	
	print("Chapter list node: ", chapter_list)
	if chapter_list:
		print("Items na lista: ", chapter_list.item_count)
	print("======================")

# ADICIONADO: Função para forçar refresh manual (útil para debug)
func force_refresh():
	print("Forçando refresh da lista...")
	_refresh_chapter_list()
