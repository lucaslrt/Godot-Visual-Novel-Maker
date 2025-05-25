@tool
extends GraphEdit
class_name ChapterEditor

signal change_chapter_ui(chapter_name:String, chapter_description: String)

var current_chapter: ChapterResource = null
var _event_bus_connection: Callable
var _is_ready: bool = false

func _ready() -> void:
	_is_ready = true
	node_selected.connect(_on_graph_node_selected)
	
	# Registrar eventos antes de conectar
	EventBus.register_event("_update_chapter_editor")
	
	# Criar callable com verificação de validade
	_event_bus_connection = _create_safe_callable()
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
	_setup_theme()

func _create_safe_callable() -> Callable:
	# Criar um callable que verifica a validade do objeto
	return func(params): 
		if is_instance_valid(self) and _is_ready:
			if params.size() > 0:
				_update_chapter_editor(params[0])
		else:
			# Se o objeto não é mais válido, desconectar automaticamente
			if _event_bus_connection.is_valid():
				EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)

func _setup_theme():
	var curr_theme = Theme.new()
	
	# Estilo para nós
	var node_style = StyleBoxFlat.new()
	node_style.bg_color = Color(0.15, 0.15, 0.15)
	node_style.border_color = Color(0.5, 0.5, 0.5)
	node_style.border_width_top = 2
	node_style.border_width_bottom = 2
	node_style.border_width_left = 2
	node_style.border_width_right = 2
	
	curr_theme.set_stylebox("panel", "GraphNode", node_style)
	
	# Estilo para nó de início
	var start_style = node_style.duplicate()
	start_style.bg_color = Color(0.2, 0.8, 0.2, 0.8)
	curr_theme.set_stylebox("panel", "GraphNodeStart", start_style)
	
	# Estilo para nó de fim
	var end_style = node_style.duplicate()
	end_style.bg_color = Color(0.8, 0.2, 0.2, 0.8)
	curr_theme.set_stylebox("panel", "GraphNodeEnd", end_style)
	
	# Estilo para nó de diálogo
	var dialogue_style = node_style.duplicate()
	dialogue_style.bg_color = Color(0.2, 0.2, 0.8, 0.8)
	curr_theme.set_stylebox("panel", "GraphNodeDialogue", dialogue_style)
	
	# Estilo para nó de escolha
	var choice_style = node_style.duplicate()
	choice_style.bg_color = Color(0.8, 0.8, 0.2, 0.8)
	curr_theme.set_stylebox("panel", "GraphNodeChoice", choice_style)
	
	# Aplicar tema
	theme = curr_theme

func _on_graph_node_selected(node):
	# Verificar se os objetos são válidos antes de emitir
	if not is_instance_valid(self) or not is_instance_valid(node):
		return
		
	# Registrar o evento se necessário
	EventBus.register_event("update_block_editor")
	EventBus.emit("update_block_editor", [node.name, current_chapter])

func _on_add_dialogue_pressed():
	if not current_chapter or not is_instance_valid(self):
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
		"graph_position": _get_new_block_position()
	}
	
	current_chapter.add_block(block_id, block_data)
	_add_block_to_graph(block_id, block_data)

func _on_add_choice_pressed():
	if not current_chapter or not is_instance_valid(self):
		return
	
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var block_id = "choice_" + timestamp
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

func _on_connection_request(from_node, from_port, to_node, to_port):
	if not current_chapter:
		push_error("Nenhum capítulo carregado!")
		return
	
	# Converter para String explícito se necessário
	var from_node_str = str(from_node)
	var to_node_str = str(to_node)
	
	print("Tentando conectar: ", from_node_str, ":", from_port, " -> ", to_node_str, ":", to_port)
	print("Blocos disponíveis: ", current_chapter.blocks.keys())
	
	# Verificar existência dos nós
	if not current_chapter.blocks.has(from_node_str):
		push_error("Bloco origem não encontrado: ", from_node_str)
		return
	
	if not current_chapter.blocks.has(to_node_str):
		push_error("Bloco destino não encontrado: ", to_node_str)
		return
	
	# Verificar se os nós existem no GraphEdit
	if not has_node(NodePath(from_node_str)):
		push_error("Nó origem não encontrado no GraphEdit: ", from_node_str)
		return
	
	if not has_node(NodePath(to_node_str)):
		push_error("Nó destino não encontrado no GraphEdit: ", to_node_str)
		return
	
	# Obter os blocos envolvidos
	var from_block = current_chapter.blocks[from_node_str]
	var to_block = current_chapter.blocks[to_node_str]
	
	# Validações de tipo
	if to_block["type"] == "start":
		push_error("Não é possível conectar ao bloco inicial!")
		return
	
	if from_block["type"] == "end":
		push_error("Não é possível conectar a partir do bloco final!")
		return
	
	# Conectar visualmente primeiro
	if connect_node(from_node, from_port, to_node, to_port) != OK:
		push_error("Falha ao conectar visualmente")
		return
	
	# Atualizar os dados do capítulo
	match from_block["type"]:
		"start", "dialogue":
			from_block["next_block_id"] = to_node_str
			print("Conexão simples atualizada: ", from_node_str, " -> ", to_node_str)
		
		"choice":
			# IMPORTANTE: No bloco choice, from_port 0 é a entrada, ports 1+ são as escolhas
			if from_port > 0:  # Se for uma escolha (porta >= 1)
				var choice_index = from_port - 1  # Converter porta para índice da escolha
				if choice_index < from_block.get("choices", []).size():
					from_block["choices"][choice_index]["next_block_id"] = to_node_str
					print("Conexão de escolha atualizada: ", from_node_str, 
						  "[", choice_index, "] -> ", to_node_str)
				else:
					push_error("Índice de escolha inválido: ", choice_index)
					disconnect_node(from_node, from_port, to_node, to_port)
					return
			else:
				push_error("Tentativa de conectar a partir da porta de entrada do bloco choice")
				disconnect_node(from_node, from_port, to_node, to_port)
				return
	
	# Forçar atualização
	current_chapter.notify_property_list_changed()
	print("Conexão estabelecida com sucesso!")

func _force_chapter_update():
	if current_chapter:
		current_chapter.notify_property_list_changed()
		# Emitir sinal para atualizar UI se necessário
		emit_signal("change_chapter_ui", current_chapter.chapter_name, current_chapter.chapter_description)

func _on_disconnection_request(from_node, from_port, to_node, to_port):
	if not current_chapter:
		return
	
	# Verificar se os nós existem no capítulo
	if not current_chapter.blocks.has(from_node):
		push_error("Tentativa de desconectar bloco não existente!")
		return
	
	var from_block = current_chapter.blocks[from_node]
	
	# Atualizar os dados do bloco
	match from_block["type"]:
		"start", "dialogue":
			from_block["next_block_id"] = ""
			print("Desconectado: ", from_node)
		
		"choice":
			if from_port < from_block.get("choices", []).size():
				from_block["choices"][from_port]["next_block_id"] = ""
				print("Desconectado choice: ", from_node, " porta ", from_port)
	
	# Forçar atualização imediata do recurso
	disconnect_node(from_node, from_port, to_node, to_port)
	current_chapter.notify_property_list_changed()
	ResourceSaver.save(current_chapter, current_chapter.resource_path)
	

func _on_connection_to_empty(from_node, from_port, release_position):
	if not current_chapter:
		return
	
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var new_block_id = "dialogue_" + timestamp
	var new_block_data = {
		"type": "dialogue",
		"character_name": "Personagem",
		"text": "Novo diálogo...",
		"next_block_id": "",
		"graph_position": release_position
	}
	
	current_chapter.add_block(new_block_id, new_block_data)
	_on_connection_request(from_node, from_port, new_block_id, 0)
	_update_chapter_editor(current_chapter)

func _update_chapter_editor(chapter: ChapterResource):
	if not is_instance_valid(self) or not chapter:
		return
	
	print("=== INICIANDO ATUALIZAÇÃO DO EDITOR ===")
	print("Capítulo: ", chapter.chapter_name)
	print("Blocos a serem carregados: ", chapter.blocks.keys())
	
	self.current_chapter = chapter
	emit_signal("change_chapter_ui", current_chapter.chapter_name, current_chapter.chapter_description)
	
	# Limpar grafo existente
	_clear_graph()
	await get_tree().process_frame
	
	# Adicionar blocos preservando as posições salvas
	for block_id in current_chapter.blocks:
		var block_data = current_chapter.blocks[block_id].duplicate(true)
		var string_id = str(block_id)
		
		# DEBUG: Verificar posição antes de adicionar
		print("Bloco ", string_id, " - posição salva: ", block_data.get("graph_position", "NÃO ENCONTRADA"))
		print("Tipo da posição: ", typeof(block_data.get("graph_position", null)))
		
		# Corrigir posição se vier como Dictionary (problema de serialização)
		if block_data.has("graph_position"):
			var pos = block_data["graph_position"]
			if typeof(pos) == TYPE_DICTIONARY:
				if pos.has("x") and pos.has("y"):
					block_data["graph_position"] = Vector2(pos["x"], pos["y"])
					print("Convertendo posição de Dictionary para Vector2: ", block_data["graph_position"])
				else:
					print("Dictionary de posição inválido, usando nova posição")
					block_data["graph_position"] = _get_new_block_position()
			elif typeof(pos) != TYPE_VECTOR2:
				print("Tipo de posição inválido (", typeof(pos), "), usando nova posição")
				block_data["graph_position"] = _get_new_block_position()
		else:
			print("Posição não encontrada, usando nova posição para bloco ", string_id)
			block_data["graph_position"] = _get_new_block_position()
		
		_add_block_to_graph(string_id, block_data)
	
	await get_tree().process_frame
	
	print("Nós após carregamento: ", get_children().filter(func(c): return c is GraphNode).map(func(n): return n.name))
	
	# Restaurar conexões
	_update_connections()
	print("=== ATUALIZAÇÃO COMPLETA ===")

func _update_connections() -> void:
	if not current_chapter:
		return
		
	clear_connections()
	
	print("=== RESTAURANDO CONEXÕES ===")
	
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		var block_path = NodePath(str(block_id))
		
		if not has_node(block_path):
			print("Nó não encontrado: ", block_id)
			continue
			
		print("Verificando conexões para: ", block_id, " (", block["type"], ")")
			
		match block["type"]:
			"start", "dialogue":
				if block.has("next_block_id") and not block.next_block_id.is_empty():
					print(" - Conexão principal para: ", block.next_block_id)
					if has_node(NodePath(block.next_block_id)):
						connect_node(block_id, 0, block.next_block_id, 0)
					else:
						print("   - Nó destino não encontrado!")
			
			"choice":
				if block.has("choices"):
					for i in range(block.choices.size()):
						var choice = block.choices[i]
						if choice.has("next_block_id") and not choice.next_block_id.is_empty():
							print(" - Conexão de escolha ", i, " para: ", choice.next_block_id)
							if has_node(NodePath(choice.next_block_id)):
								connect_node(block_id, i + 1, choice.next_block_id, 0)  # i+1 porque a porta 0 é a entrada
							else:
								print("   - Nó destino não encontrado!")
	
	print("=== CONEXÕES RESTAURADAS ===")

func _add_block_to_graph(block_id: String, block_data: Dictionary) -> void:
	var block_scene = preload("uid://rj8arjvt7auh")
	if not block_scene:
		push_error("Failed to load dialogue block scene")
		return
	
	var node = block_scene.instantiate()
	if not node:
		push_error("Failed to instantiate dialogue block")
		return
	
	node.name = str(block_id)
	
	# Configurar tipo visual
	match block_data["type"]:
		"start": node.theme_type_variation = "GraphNodeStart"
		"end": node.theme_type_variation = "GraphNodeEnd"
		"dialogue": node.theme_type_variation = "GraphNodeDialogue"
		"choice": node.theme_type_variation = "GraphNodeChoice"

	node.setup(block_data.duplicate(true))
	
	if node.has_signal("block_updated"):
		node.block_updated.connect(_on_block_updated.bind(str(block_id)))
	
	# Definir posição - garantindo que é Vector2 e usando a posição salva
	var saved_position = block_data.get("graph_position", _get_new_block_position())
	
	# Garantir que temos uma posição válida como Vector2
	var final_position: Vector2
	if typeof(saved_position) == TYPE_VECTOR2:
		final_position = saved_position
		print("Definindo posição do bloco ", block_id, " para posição salva: ", final_position)
	elif typeof(saved_position) == TYPE_DICTIONARY and saved_position.has("x") and saved_position.has("y"):
		final_position = Vector2(saved_position["x"], saved_position["y"])
		print("Convertendo Dictionary para Vector2 no bloco ", block_id, ": ", final_position)
		# Atualizar imediatamente no resource com a posição correta
		current_chapter.blocks[block_id]["graph_position"] = final_position
	else:
		final_position = _get_new_block_position()
		print("Posição inválida, usando nova posição para bloco ", block_id, ": ", final_position)
		# Atualizar imediatamente no resource
		current_chapter.blocks[block_id]["graph_position"] = final_position
	
	node.position_offset = final_position
	add_child(node)
	
	# Conectar sinal de arraste
	if node.has_signal("dragged"):
		node.dragged.connect(_on_node_dragged.bind(node))
	else:
		push_error("Nó não tem sinal 'dragged'!")
		
func _on_node_dragged(from: Vector2, to: Vector2, node: GraphNode):
	if not current_chapter or not node:
		return
	
	var block_id = node.name
	if current_chapter.blocks.has(block_id):
		# Salvar a nova posição imediatamente
		var new_position = Vector2(node.position_offset)
		current_chapter.blocks[block_id]["graph_position"] = new_position
		print("Posição atualizada para bloco ", block_id, ": ", new_position)
		
		# Forçar salvamento imediato
		current_chapter.notify_property_list_changed()
		if current_chapter.resource_path and not current_chapter.resource_path.is_empty():
			ResourceSaver.save(current_chapter, current_chapter.resource_path)

func _on_block_updated(new_data, block_id):
	if not current_chapter or not current_chapter.blocks.has(block_id):
		return
	
	print("=== ATUALIZANDO BLOCO ", block_id, " ===")
	
	var node = get_node_or_null(block_id)
	if node and is_instance_valid(node):
		# PRESERVAR A POSIÇÃO ATUAL DO NÓ
		var current_position = Vector2(node.position_offset)
		new_data["graph_position"] = current_position
		print("Preservando posição atual: ", current_position)
	else:
		# Se não conseguimos obter do nó, preservar do bloco antigo
		var old_block = current_chapter.blocks[block_id]
		if old_block.has("graph_position"):
			var old_pos = old_block["graph_position"]
			# Converter se necessário
			if typeof(old_pos) == TYPE_DICTIONARY and old_pos.has("x") and old_pos.has("y"):
				new_data["graph_position"] = Vector2(old_pos["x"], old_pos["y"])
				print("Convertendo e preservando posição do bloco antigo: ", new_data["graph_position"])
			elif typeof(old_pos) == TYPE_VECTOR2:
				new_data["graph_position"] = old_pos
				print("Preservando posição do bloco antigo: ", old_pos)
			else:
				new_data["graph_position"] = _get_new_block_position()
				print("Posição inválida, usando nova posição: ", new_data["graph_position"])
		else:
			new_data["graph_position"] = _get_new_block_position()
			print("Usando nova posição: ", new_data["graph_position"])
	
	# Garantir que o ID está preservado
	new_data["id"] = block_id
	
	var old_block = current_chapter.blocks[block_id]
	
	# Preservar informações de conexão
	if old_block["type"] == "dialogue" or old_block["type"] == "start":
		if old_block.has("next_block_id"):
			new_data["next_block_id"] = old_block["next_block_id"]
	elif old_block["type"] == "choice":
		if old_block.has("choices"):
			for i in range(min(old_block["choices"].size(), new_data["choices"].size())):
				new_data["choices"][i]["next_block_id"] = old_block["choices"][i].get("next_block_id", "")
	
	# Atualizar o bloco
	current_chapter.blocks[block_id] = new_data
	
	# Forçar salvamento imediato
	current_chapter.notify_property_list_changed()
	if current_chapter.resource_path and not current_chapter.resource_path.is_empty():
		ResourceSaver.save(current_chapter, current_chapter.resource_path)
		print("Recurso salvo com nova posição: ", new_data["graph_position"])
	
	_update_connections()

func _get_new_block_position() -> Vector2:
	# Obter o centro da viewport
	var viewport_size := get_viewport_rect().size if get_viewport() else Vector2(1920, 1080)
	var viewport_center := Vector2(viewport_size) / 2.0
	
	# Calcular posição baseada no scroll atual
	var base_position := Vector2(scroll_offset) + viewport_center
	
	# Adicionar um deslocamento aleatório para evitar sobreposição
	var random_offset := Vector2(
		randf_range(-100, 100),
		randf_range(-50, 50)
	)
	
	return base_position + random_offset

func _clear_graph():
	for child in get_children():
		if child is GraphNode and is_instance_valid(child):
			remove_child(child)
			child.queue_free()

func _exit_tree():
	_is_ready = false
	if _event_bus_connection and _event_bus_connection.is_valid():
		EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)
