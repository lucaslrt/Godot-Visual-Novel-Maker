@tool
extends GraphEdit
class_name ChapterEditor

signal change_chapter_ui(chapter_name:String, chapter_description: String)

var current_chapter: ChapterResource = null
var _event_bus_connection: Callable

func _ready() -> void:
	node_selected.connect(_on_graph_node_selected)
	
	# Armazenar a conexão para desconectar depois
	_event_bus_connection = func(params): 
		if is_instance_valid(self):
			_update_chapter_editor(params[0])
		else:
			EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)
	
	EventBus.connect_event("_update_chapter_editor", _event_bus_connection)
	
	
	# Adicionar botões de contexto
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "Add Dialogue"
	add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	get_menu_hbox().add_child(add_dialogue_btn)
	
	var add_choice_btn = Button.new()
	add_choice_btn.text = "Add Choice"
	add_choice_btn.pressed.connect(_on_add_choice_pressed)
	get_menu_hbox().add_child(add_choice_btn)
	
	# Configurar o GraphEdit
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	connection_to_empty.connect(_on_connection_to_empty)
	
	# Habilitar conexões entre slots
	set_connection_lines_antialiased(true)
	
	# Configurar tema
	var curr_theme = Theme.new()
	
	# Estilo para nó de início
	var start_style = StyleBoxFlat.new()
	start_style.bg_color = Color(0.2, 0.8, 0.2)
	curr_theme.set_stylebox("panel", "GraphNodeStart", start_style)
	
	# Estilo para nó de fim
	var end_style = StyleBoxFlat.new()
	end_style.bg_color = Color(0.8, 0.2, 0.2)
	curr_theme.set_stylebox("panel", "GraphNodeEnd", end_style)
	
	# Aplicar tema
	theme = curr_theme

func _on_graph_node_selected(node):
	# Quando um nó é selecionado no grafo, atualizar o editor de blocos
	EventBus.emit("update_block_editor", [node.name, current_chapter])

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
		"graph_position": _get_new_block_position()
	}
	
	current_chapter.add_block(block_id, block_data)
	# Adicionar apenas o novo bloco ao invés de recarregar tudo
	_add_block_to_graph(block_id, block_data)

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
		"graph_position": _get_new_block_position()
	}
	
	current_chapter.add_block(block_id, block_data)
	_update_chapter_editor(current_chapter)

#func _on_add_start_pressed():
	#if not current_chapter:
		#return
	#
	#var block_id = "start_" + str(Time.get_unix_time_from_system())
	#var block_data = {
		#"type": "start",
		#"graph_position": _get_new_block_position()
	#}
	#
	#current_chapter.add_block(block_id, block_data)
	#current_chapter.start_block_id = block_id  # Definir como bloco inicial
	##_update_chapter_editor(current_chapter)
#
#func _on_add_end_pressed():
	#if not current_chapter:
		#return
	#
	#var block_id = "end_" + str(Time.get_unix_time_from_system())
	#var block_data = {
		#"type": "end",
		#"graph_position": scroll_offset + Vector2(100, 100)
	#}
	#
	#current_chapter.add_block(block_id, block_data)
	#_update_chapter_editor(current_chapter)

func _on_connection_request(from_node, from_port, to_node, to_port):
	print("Tentando conectar: ", from_node, ":", from_port, " -> ", to_node, ":", to_port)
	
	# Permitir a conexão no GraphEdit
	connect_node(from_node, from_port, to_node, to_port)
	
	# Atualizar os dados do capítulo
	var from_block = current_chapter.blocks[from_node]
	var to_block = current_chapter.blocks.get(to_node, null)
	
	# Impedir conexões inválidas
	if to_block and to_block["type"] == "start":
		push_error("Não é possível conectar ao bloco inicial!")
		return
	
	if from_block["type"] == "end":
		push_error("Não é possível conectar a partir do bloco final!")
		return
	
	match from_block.type:
		"start", "dialogue":
			# Para nós simples, armazenar apenas o próximo bloco
			from_block["next_block_id"] = to_node
		
		"choice":
			# Para nós de escolha, atualizar a escolha específica
			# from_port - 1 porque o slot 0 é a entrada
			if from_port > 0 and from_block.has("choices") and from_block.choices.size() > from_port - 1:
				from_block.choices[from_port - 1]["next_block_id"] = to_node
	
	# Sinalizar que os dados foram alterados
	_update_connections()

func _on_disconnection_request(from_node, from_port, to_node, to_port):
	if not current_chapter:
		return
	
	var from_block = current_chapter.blocks.get(from_node)
	
	if not from_block:
		return
	
	# Atualizar os dados do bloco
	match from_block["type"]:
		"start":
			from_block["next_block_id"] = ""
		"dialogue":
			from_block["next_block_id"] = ""
		"choice":
			if from_port < from_block.get("choices", []).size():
				from_block["choices"][from_port]["next_block_id"] = ""
	
	# Atualizar visualmente
	disconnect_node(from_node, from_port, to_node, to_port)

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
	_on_connection_request(from_node, from_port, new_block_id, 0)
	_update_chapter_editor(current_chapter)

func _update_chapter_editor(current_chapter: ChapterResource):
	self.current_chapter = current_chapter
	if current_chapter:
		emit_signal("change_chapter_ui", current_chapter.chapter_name, current_chapter.chapter_description)
		
		# Salvar as posições ANTES de limpar
		var saved_positions = {}
		for child in get_children():
			if child is GraphNode:
				# Usar position_offset diretamente do nó visível
				saved_positions[child.name] = child.position_offset
		
		# Salvar conexões
		var saved_connections = get_connection_list()
		
		# Limpar o grafo
		_clear_graph()
		
		# Restaurar blocos com posições salvas
		for block_id in current_chapter.blocks:
			var block = current_chapter.blocks[block_id]
			
			# Priorizar posição salva se existir
			if saved_positions.has(block_id):
				block["graph_position"] = saved_positions[block_id]
			
			# Garantir tipo Vector2
			if typeof(block.get("graph_position", Vector2.ZERO)) != TYPE_VECTOR2:
				block["graph_position"] = Vector2.ZERO
			
			_add_block_to_graph(block_id, block)
		
		# Restaurar conexões
		for conn in saved_connections:
			if has_node(conn.from_node) and has_node(conn.to_node):
				connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
		
		# Atualizar conexões após pequeno delay
		await get_tree().process_frame
		_update_connections()

func _update_connections() -> void:
	# Limpar todas as conexões visuais primeiro
	clear_connections()
	
	if not current_chapter:
		return
	
	# Reconectar todos os nós baseado nos dados do capítulo
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		
		if not has_node(block_id):
			continue
			
		match block["type"]:
			"start", "dialogue":
				if block.has("next_block_id") and not block.next_block_id.is_empty():
					if has_node(block.next_block_id):
						connect_node(block_id, 0, block.next_block_id, 0)
			
			"choice":
				if block.has("choices"):
					for i in range(block.choices.size()):
						var choice = block.choices[i]
						if choice.has("next_block_id") and not choice.next_block_id.is_empty():
							if has_node(choice.next_block_id):
								connect_node(block_id, i + 1, choice.next_block_id, 0)

func _add_block_to_graph(block_id: String, block_data: Dictionary) -> void:
	var block_scene = preload("uid://rj8arjvt7auh")
	if not block_scene:
		push_error("Failed to load dialogue block scene")
		return
	
	var node = block_scene.instantiate()
	if not node:
		push_error("Failed to instantiate dialogue block")
		return
	
	node.name = block_id
	
	# Configurar aparência baseada no tipo
	match block_data["type"]:
		"start":
			node.theme_type_variation = "GraphNodeStart"
		"end":
			node.theme_type_variation = "GraphNodeEnd"
		"dialogue":
			node.theme_type_variation = "GraphNodeDialogue"
		"choice":
			node.theme_type_variation = "GraphNodeChoice"

	node.setup(block_data.duplicate(true))
	node.block_updated.connect(_on_block_updated.bind(block_id))

	# Manter a posição se existir
	if block_data.has("graph_position") && typeof(block_data["graph_position"]) == TYPE_VECTOR2:
		node.position_offset = block_data["graph_position"]
	else:
		# Posição padrão se não existir
		node.position_offset = _get_new_block_position()

	# Forçar atualização imediata
	node.set_deferred("position_offset", node.position_offset)

	add_child(node)
	# Debug
	_print_positions()

func _on_block_updated(new_data, block_id):
	if current_chapter and current_chapter.blocks.has(block_id):
		# Salvar posição do nó
		var node = get_node_or_null(block_id)
		if node:
			new_data["graph_position"] = node.position_offset
			# Garantir que é Vector2
			if typeof(new_data["graph_position"]) != TYPE_VECTOR2:
				new_data["graph_position"] = Vector2.ZERO
		
		# Atualizar os dados mantendo as conexões existentes
		var old_block = current_chapter.blocks[block_id]
		
		# Preservar informações de conexão
		if old_block["type"] == "dialogue" or old_block["type"] == "start":
			if old_block.has("next_block_id"):
				new_data["next_block_id"] = old_block["next_block_id"]
		elif old_block["type"] == "choice":
			if old_block.has("choices"):
				# Preservar next_block_id das escolhas
				for i in range(min(old_block["choices"].size(), new_data["choices"].size())):
					new_data["choices"][i]["next_block_id"] = old_block["choices"][i].get("next_block_id", "")
		
		current_chapter.blocks[block_id] = new_data
		_update_connections()

func _print_positions():
	print("=== Current Positions ===")
	for child in get_children():
		if child is GraphNode:
			print("Block: ", child.name, " Position: ", child.position_offset)
	print("========================")

func _get_new_block_position() -> Vector2:
	# Calcular posição baseada no centro da viewport
	var viewport_center = size / 2
	if get_viewport():
		viewport_center = get_viewport().size / 2
	return scroll_offset + viewport_center - Vector2(200, 100)

func _clear_graph():
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()

func _exit_tree():
	if _event_bus_connection:
		EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)
