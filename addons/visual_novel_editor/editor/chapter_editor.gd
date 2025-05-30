@tool
extends Control
class_name ChapterEditor

# Referências aos nós da UI
@onready var chapter_list = $HSplitContainer/ChapterList/ItemList
@onready var chapter_name_edit = $HSplitContainer/TabContainer/ChapterEditor/ChapterNameEdit
@onready var chapter_description_edit = $HSplitContainer/TabContainer/ChapterEditor/ChapterDescriptionEdit
@onready var graph_edit: ChapterGraphEdit = $HSplitContainer/TabContainer/ChapterEditor/HSplitContainer/GraphEdit

# Capítulo atual sendo editado
var current_chapter: ChapterResource = null

func _ready():
	# Conectar sinais
	$Toolbar/AddChapterButton.pressed.connect(_on_add_chapter_button_pressed)
	$Toolbar/DeleteChapterButton.pressed.connect(_on_delete_chapter_button_pressed)
	$Toolbar/SaveButton.pressed.connect(_on_save_button_pressed)
	$Toolbar/LoadButton.pressed.connect(_on_load_button_pressed)
	
	# Conectar sinal da lista de capítulos
	if chapter_list:
		chapter_list.item_selected.connect(_on_chapter_selected)
	
	# Conectar sinal do graph_edit se existir
	if graph_edit:
		graph_edit.connect("change_chapter_ui", _on_chapter_data_changed)

func _delayed_initialization():
	print("Tentando inicialização atrasada...")
	if _check_singleton():
		_load_chapters()
		chapter_list.refresh_chapters()
	else:
		print("VisualNovelSingleton ainda não disponível")

func _process(delta):
	# Verificar se graph_edit existe antes de tentar usar
	if graph_edit:
		graph_edit.queue_redraw()

# Métodos para interação com a UI
func _on_add_chapter_button_pressed():
	# Verificar se o VisualNovelSingleton está disponível
	if not _check_singleton():
		return
	
	var new_chapter = ChapterResource.new()  # O ID é gerado automaticamente no _init
	var chapter_name = "Novo Capítulo " + str(chapter_list.item_count + 1)
	new_chapter.chapter_name = chapter_name
	new_chapter.chapter_description = "Descrição do capítulo"
	
	# Definir o resource_path baseado no ID
	_ensure_chapter_resource_path(new_chapter)
	
	# Adicionar bloco inicial
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var start_block_id = "start_%s" % timestamp
	
	var start_block_data = {
		"type": "start",
		"graph_position": Vector2(100, 300)
	}
	new_chapter.add_block(start_block_id, start_block_data)
	new_chapter.start_block_id = start_block_id
	
	# Adicionar bloco final
	var end_block_id = "end_%s" % timestamp
	var end_block_data = {
		"type": "end",
		"graph_position": Vector2(800, 300)
	}
	new_chapter.add_block(end_block_id, end_block_data)
	
	# Registrar o capítulo
	VisualNovelSingleton.register_chapter(new_chapter)
	
	# Atualizar a lista
	chapter_list.refresh_chapters()
	
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
		
		# Encontrar o capítulo pelo nome
		var chapter_to_delete = null
		var chapter_id_to_delete = null
		for chapter_id in VisualNovelSingleton.chapters:
			var chapter = VisualNovelSingleton.chapters[chapter_id]
			if chapter.chapter_name == chapter_name:
				chapter_to_delete = chapter
				chapter_id_to_delete = chapter_id
				break
		
		if chapter_to_delete:
			# Remover arquivo .tres
			if chapter_to_delete.resource_path and not chapter_to_delete.resource_path.is_empty():
				if FileAccess.file_exists(chapter_to_delete.resource_path):
					DirAccess.remove_absolute(chapter_to_delete.resource_path)
			
			# Remover do singleton
			VisualNovelSingleton.chapters.erase(chapter_id_to_delete)
			chapter_list.refresh_chapters()
			
			# Limpar editor se necessário
			if current_chapter and current_chapter.chapter_id == chapter_id_to_delete:
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
	
	if not current_chapter:
		push_error("Nenhum capítulo selecionado!")
		return
	
	# Garantir que o resource_path existe antes de tentar salvar
	_ensure_chapter_resource_path(current_chapter)
	
	# Atualizar posições antes de salvar
	if graph_edit:
		for child in graph_edit.get_children():
			if child is GraphNode and is_instance_valid(child):
				var block_id = child.name
				if current_chapter.blocks.has(block_id):
					current_chapter.blocks[block_id]["graph_position"] = Vector2(child.position_offset)
					print("Salvando posição para ", block_id, ": ", child.position_offset)
	
	# Salvar metadados
	var old_chapter_name = current_chapter.chapter_name
	current_chapter.chapter_name = chapter_name_edit.text
	current_chapter.chapter_description = chapter_description_edit.text
	
	if old_chapter_name != current_chapter.chapter_name:
		if VisualNovelSingleton.chapters.has(old_chapter_name):
			VisualNovelSingleton.chapters.erase(old_chapter_name)
		VisualNovelSingleton.chapters[current_chapter.chapter_name] = current_chapter
		chapter_list.refresh_chapters()
	
	# Salvar o recurso como arquivo .tres
	var save_result = ResourceSaver.save(current_chapter, current_chapter.resource_path)
	if save_result != OK:
		push_error("Falha ao salvar capítulo: ", save_result)
	else:
		print("Capítulo salvo com sucesso em: ", current_chapter.resource_path)
		
		VisualNovelSingleton.save_chapters()
	
	# Debug detalhado
	_print_chapter_debug_info()

# Garantir que o capítulo tem um resource_path válido
func _ensure_chapter_resource_path(chapter: ChapterResource):
	if not chapter:
		return
		
	if chapter.resource_path.is_empty():
		# Criar pasta se não existir
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("res://addons/visual_novel_editor/data/chapters"):
			dir.make_dir_recursive("res://addons/visual_novel_editor/data/chapters")
		
		# Usar o ID do capítulo como nome do arquivo
		var file_path = "res://addons/visual_novel_editor/data/chapters/" + chapter.chapter_id + ".tres"
		chapter.resource_path = file_path
		print("Resource path definido para: ", file_path)

func _print_chapter_debug_info():
	print("=== DEBUG DO CAPÍTULO ===")
	print("Nome: ", current_chapter.chapter_name)
	print("Caminho: ", current_chapter.resource_path)
	print("Blocos: ", current_chapter.blocks.size())
	
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		print("\nBloco: ", block_id)
		print("Tipo: ", block.get("type", "desconhecido"))
		print("Posição: ", block.get("graph_position", "N/A"))
		print("Tipo da posição: ", typeof(block.get("graph_position")))
		
		match block.get("type"):
			"start", "dialogue":
				print("Próximo: ", block.get("next_block_id", ""))
			"choice":
				for i in range(block.get("choices", []).size()):
					print("Escolha ", i, " -> ", block["choices"][i].get("next_block_id", ""))
	print("========================")

func _debug_print_connections():
	if not current_chapter:
		return
	
	print("=== CONEXÕES DO CAPÍTULO ===")
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		match block["type"]:
			"start", "dialogue":
				if block.has("next_block_id"):
					print(block_id, " -> ", block.next_block_id)
			"choice":
				if block.has("choices"):
					for i in range(block.choices.size()):
						var choice = block.choices[i]
						if choice.has("next_block_id"):
							print(block_id, " [", i, "] -> ", choice.next_block_id)
	print("============================")

func _on_load_button_pressed():
	if not _check_singleton():
		return
		
	VisualNovelSingleton.load_chapters()
	chapter_list.refresh_chapters()
	print("Capítulos carregados!")

# NOVA FUNÇÃO: Carregar arquivos .tres individuais
func _load_individual_chapter_files():
	var chapters_dir = "res://addons/visual_novel_editor/data/chapters/"
	var dir = DirAccess.open(chapters_dir)
	
	if not dir:
		print("Pasta de capítulos não encontrada: ", chapters_dir)
		
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = chapters_dir + file_name
			var chapter = load(file_path) as ChapterResource
			
			if chapter:
				print("Carregando capítulo .tres: ", chapter.chapter_name)
				VisualNovelSingleton.chapters[chapter.chapter_name] = chapter
			else:
				print("Erro ao carregar: ", file_path)
		
		file_name = dir.get_next()

func _on_chapter_selected(index):
	if not _check_singleton():
		return
		
	if index < 0 or index >= chapter_list.item_count:
		return
		
	var chapter_name = chapter_list.get_item_text(index)
	
	# Encontrar o capítulo pelo nome na lista
	var chapter_ids = VisualNovelSingleton.chapters.keys()
	for chapter_id in chapter_ids:
		var chapter = VisualNovelSingleton.chapters[chapter_id]
		if chapter.chapter_name == chapter_name:
			current_chapter = chapter
			break
	
	if current_chapter:
		_update_chapter_ui()
		if graph_edit:
			graph_edit._clear_graph()
			await get_tree().process_frame
			graph_edit._update_chapter_editor(current_chapter)
	else:
		current_chapter = null
		_clear_chapter_editor()

func _verify_chapter_consistency():
	if not current_chapter or not graph_edit:
		return
	
	# Verificar se todos os blocos no resource existem no GraphEdit
	for block_id in current_chapter.blocks:
		if not graph_edit.has_node(block_id):
			push_error("Bloco no resource não encontrado no GraphEdit: ", block_id)
	
	# Verificar se todos os nós no GraphEdit existem no resource
	for child in graph_edit.get_children():
		if child is GraphNode:
			if not current_chapter.blocks.has(child.name):
				push_error("Nó no GraphEdit não encontrado no resource: ", child.name)

# Método para verificar se o VisualNovelSingleton está disponível
func _check_singleton() -> bool:
	if not VisualNovelSingleton:
		push_error("VisualNovelSingleton não está disponível!")
		return false
	return true

# Métodos para atualizar a UI

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
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var new_block_id = "dialogue_" + timestamp
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
		
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var block_id = "dialogue_" + timestamp
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

func add_choice_block():
	if not current_chapter:
		push_error("Nenhum capítulo selecionado!")
		return
		
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var block_id = "choice_" + timestamp
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

# Chamar esta função após carregar um capítulo
func _verify_block_sync():
	if not current_chapter or not graph_edit:
		return
	
	print("=== VERIFICAÇÃO DE SINCRONIZAÇÃO ===")
	
	# Verificar blocos no resource vs graph
	var resource_blocks = current_chapter.blocks.keys()
	var graph_blocks = []
	
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_blocks.append(child.name)
	
	print("Blocos no ChapterResource: ", resource_blocks)
	print("Blocos no GraphEdit: ", graph_blocks)
	
	# Verificar diferenças
	var missing_in_graph = []
	for block_id in resource_blocks:
		if not graph_blocks.has(str(block_id)):
			missing_in_graph.append(block_id)
	
	var missing_in_resource = []
	for block_name in graph_blocks:
		if not resource_blocks.has(block_name):
			missing_in_resource.append(block_name)
	
	if missing_in_graph.size() > 0:
		push_error("Blocos faltando no GraphEdit: ", missing_in_graph)
	
	if missing_in_resource.size() > 0:
		push_error("Blocos faltando no ChapterResource: ", missing_in_resource)
	
	print("=== FIM DA VERIFICAÇÃO ===")

func move_selected_chapter_up():
	chapter_list.move_selected_up()

func move_selected_chapter_down():
	chapter_list.move_selected_down()

func _find_chapter_id_by_name(chapter_name: String) -> String:
	for chapter_id in VisualNovelSingleton.chapters:
		var chapter = VisualNovelSingleton.chapters[chapter_id]
		if chapter.chapter_name == chapter_name:
			return chapter_id
	return ""
