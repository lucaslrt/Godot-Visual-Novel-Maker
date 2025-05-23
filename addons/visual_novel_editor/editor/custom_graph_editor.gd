@tool
extends Control
class_name CustomGraphEditor

signal node_selected(node)
signal connection_request(from_node, from_port, to_node, to_port)
signal disconnection_request(from_node, from_port, to_node, to_port)
signal connection_to_empty(from_node, from_port, release_position)
signal change_chapter_ui(chapter_name: String, chapter_description: String)

var current_chapter: ChapterResource = null
var _event_bus_connection: Callable
var _is_ready: bool = false

# Propriedades de viewport e controle
var scroll_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var _is_dragging: bool = false
var _drag_start_position: Vector2
var _selected_node: Control = null

# Propriedades de conexão
var _connection_in_progress: bool = false
var _connection_from_node: String = ""
var _connection_from_port: int = 0
var _connection_line_start: Vector2
var _connection_line_end: Vector2
var _dragging_node: bool = false

# Container para os nós
var _nodes_container: Control
var _connections: Array[Dictionary] = []

# Toolbar
var _toolbar: HBoxContainer

func _ready() -> void:
	_is_ready = true
	
	# Configurar o controle principal
	set_clip_contents(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Criar container para os nós
	_nodes_container = Control.new()
	_nodes_container.name = "NodesContainer"
	_nodes_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nodes_container)
	
	# Criar toolbar
	_create_toolbar()
	
	# Registrar eventos
	EventBus.register_event("_update_chapter_editor")
	_event_bus_connection = _create_safe_callable()
	EventBus.connect_event("_update_chapter_editor", _event_bus_connection)
	
	# Conectar sinais de input
	gui_input.connect(_on_gui_input)

func _create_toolbar():
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	add_child(_toolbar)
	
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "Add Dialogue"
	add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	_toolbar.add_child(add_dialogue_btn)
	
	var add_choice_btn = Button.new()
	add_choice_btn.text = "Add Choice"
	add_choice_btn.pressed.connect(_on_add_choice_pressed)
	_toolbar.add_child(add_choice_btn)

func _create_safe_callable() -> Callable:
	return func(params): 
		if is_instance_valid(self) and _is_ready:
			if params.size() > 0:
				_update_chapter_editor(params[0])
		else:
			if _event_bus_connection.is_valid():
				EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Verificar se clicou em um nó primeiro
			var clicked_node = _get_node_at_position(event.position)
			if clicked_node:
				_select_node(clicked_node)
				# Não iniciar drag do background se clicou em um nó
				return
			else:
				_select_node(null)
				_is_dragging = true
				_drag_start_position = event.position
		else:
			_is_dragging = false
			_dragging_node = false
			
			# Se estava fazendo uma conexão e soltou em área vazia
			if _connection_in_progress:
				var release_pos = event.position + scroll_offset
				
				# Verificar se soltou em cima de um nó
				var target_node = _get_node_at_position(event.position)
				if target_node and target_node.name != _connection_from_node:
					# Tentar fazer a conexão
					_complete_connection(target_node.name, 0)
				else:
					connection_to_empty.emit(_connection_from_node, _connection_from_port, release_pos)
				
				_connection_in_progress = false
				queue_redraw()
	
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Scroll com botão direito
		_is_dragging = true
		_drag_start_position = event.position

func _handle_mouse_motion(event: InputEventMouseMotion):
	if _is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Scroll do viewport
		var delta = event.position - _drag_start_position
		scroll_offset -= delta
		_update_nodes_position()
		_drag_start_position = event.position
		queue_redraw()
	elif _is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _connection_in_progress and not _dragging_node:
		# Scroll com botão esquerdo quando não está conectando nem arrastando nó
		var delta = event.position - _drag_start_position
		scroll_offset -= delta
		_update_nodes_position()
		_drag_start_position = event.position
		queue_redraw()
	
	if _connection_in_progress:
		_connection_line_end = event.position
		queue_redraw()

func _get_node_at_position(pos: Vector2) -> Control:
	# Converter posição para espaço do container
	var container_pos = pos + scroll_offset
	
	for child in _nodes_container.get_children():
		if child is Control:
			var node_rect = Rect2(child.position, child.size)
			if node_rect.has_point(container_pos):
				return child
	return null

func _select_node(node: Control):
	if _selected_node:
		_selected_node.modulate = Color.WHITE
	
	_selected_node = node
	if _selected_node:
		_selected_node.modulate = Color(1.2, 1.2, 1.2)
		node_selected.emit(node)

func _update_nodes_position():
	for child in _nodes_container.get_children():
		if child is Control and child.has_meta("graph_position"):
			var graph_pos = child.get_meta("graph_position")
			child.position = graph_pos - scroll_offset

func _draw():
	# Desenhar grid de fundo
	_draw_grid()
	
	# Desenhar conexões
	_draw_connections()
	
	# Desenhar linha de conexão em progresso
	if _connection_in_progress:
		draw_line(_connection_line_start, _connection_line_end, Color.YELLOW, 3.0)

func _draw_grid():
	var grid_size = 50
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)
	
	# Calcular offset do grid baseado no scroll
	var grid_offset = Vector2(
		fmod(scroll_offset.x, grid_size),
		fmod(scroll_offset.y, grid_size)
	)
	
	# Desenhar linhas verticais
	var x = -grid_offset.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += grid_size
	
	# Desenhar linhas horizontais
	var y = -grid_offset.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += grid_size

func _draw_connections():
	for conn in _connections:
		var from_node = _nodes_container.get_node_or_null(conn.from_node)
		var to_node = _nodes_container.get_node_or_null(conn.to_node)
		
		if from_node and to_node:
			var from_pos = _get_port_position(from_node, conn.from_port, true)
			var to_pos = _get_port_position(to_node, conn.to_port, false)
			
			# Desenhar curva bezier
			var control_offset = Vector2(100, 0)
			var from_control = from_pos + control_offset
			var to_control = to_pos - control_offset
			
			_draw_bezier_connection(from_pos, from_control, to_control, to_pos)

func _get_port_position(node: Control, port: int, is_output: bool) -> Vector2:
	if not node:
		return Vector2.ZERO
	
	var node_pos = node.position
	var node_size = node.size
	
	if is_output:
		# Porta de saída (direita do nó)
		return node_pos + Vector2(node_size.x, node_size.y * 0.5 + port * 30)
	else:
		# Porta de entrada (esquerda do nó)
		return node_pos + Vector2(0, node_size.y * 0.5)

func _draw_bezier_connection(from: Vector2, from_control: Vector2, to_control: Vector2, to: Vector2):
	var points = []
	var steps = 50
	
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var point = _bezier_point(from, from_control, to_control, to, t)
		points.append(point)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color.WHITE, 2.0)

func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	var tt = t * t
	var uu = u * u
	var uuu = uu * u
	var ttt = tt * t
	
	return uuu * p0 + 3 * uu * t * p1 + 3 * u * tt * p2 + ttt * p3

# Métodos para gerenciar conexões
func connect_node(from_node: String, from_port: int, to_node: String, to_port: int):
	var connection = {
		"from_node": from_node,
		"from_port": from_port,
		"to_node": to_node,
		"to_port": to_port
	}
	
	# Verificar se a conexão já existe
	for conn in _connections:
		if (conn.from_node == from_node and conn.from_port == from_port and 
			conn.to_node == to_node and conn.to_port == to_port):
			return # Conexão já existe
	
	_connections.append(connection)
	queue_redraw()

func disconnect_node(from_node: String, from_port: int, to_node: String, to_port: int):
	for i in range(_connections.size() - 1, -1, -1):
		var conn = _connections[i]
		if (conn.from_node == from_node and conn.from_port == from_port and 
			conn.to_node == to_node and conn.to_port == to_port):
			_connections.remove_at(i)
	queue_redraw()

func clear_connections():
	_connections.clear()
	queue_redraw()

func get_connection_list() -> Array:
	return _connections.duplicate()

#func has_node_name(node_name: String) -> bool:
#	return _nodes_container.has_node(node_name)

#func has_node(node_name: String) -> bool:
#	return _nodes_container.get_node_or_null(node_name) != null

# Métodos para adicionar/remover nós
func add_child_to_graph(node: Control):
	_nodes_container.add_child(node)
	
	# Configurar o nó para ser arrastável
	_setup_draggable_node(node)

func _setup_draggable_node(node: Control):
	if not node.gui_input.is_connected(_on_node_input):
		node.gui_input.connect(_on_node_input.bind(node))

func _on_node_input(event: InputEvent, node: Control):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_select_node(node)
				
				# Verificar se clicou em uma porta de saída para iniciar conexão
				var port = _get_clicked_output_port(node, event.position)
				if port >= 0:
					_start_connection(node.name, port, event.position + node.global_position - global_position)
				else:
					# Iniciar arraste do nó
					_dragging_node = true
			else:
				_dragging_node = false
	
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _dragging_node and node == _selected_node and not _connection_in_progress:
				# Arrastar o nó
				var new_pos = node.position + event.relative
				node.position = new_pos
				
				# Atualizar metadados
				node.set_meta("graph_position", new_pos + scroll_offset)
				queue_redraw()

func _get_clicked_output_port(node: Control, local_pos: Vector2) -> int:
	# Melhor detecção de porta - verificar se clicou na área da porta de saída
	var port_area_width = 30  # Largura da área clicável da porta
	var node_width = node.size.x
	
	# Verificar se está na área da porta de saída (lado direito)
	if local_pos.x > (node_width - port_area_width):
		# Para nós de escolha, calcular qual porta baseado na posição Y
		if node.has_method("get_port_count"):
			var port_count = node.get_port_count()
			if port_count > 1:
				var port_height = node.size.y / port_count
				var clicked_port = int(local_pos.y / port_height)
				return min(clicked_port, port_count - 1)
		return 0  # Porta principal para nós simples
	
	return -1  # Não clicou em nenhuma porta

func _start_connection(from_node: String, from_port: int, screen_pos: Vector2):
	_connection_in_progress = true
	_connection_from_node = from_node
	_connection_from_port = from_port
	_connection_line_start = screen_pos
	_connection_line_end = screen_pos
	
	# Forçar o mouse_filter para capturar eventos durante a conexão
	mouse_filter = Control.MOUSE_FILTER_PASS

func _complete_connection(to_node: String, to_port: int):
	if not _connection_in_progress:
		return
	
	# Verificar se não está tentando conectar no mesmo nó
	if _connection_from_node == to_node:
		return
	
	# Emitir sinal de solicitação de conexão
	connection_request.emit(_connection_from_node, _connection_from_port, to_node, to_port)
	
	# Fazer a conexão diretamente (você pode remover isso se quiser controlar externamente)
	connect_node(_connection_from_node, _connection_from_port, to_node, to_port)
	
	# Atualizar o chapter se necessário
	if current_chapter:
		_update_chapter_connections(_connection_from_node, _connection_from_port, to_node)

func _update_chapter_connections(from_node: String, from_port: int, to_node: String):
	if not current_chapter or not current_chapter.blocks.has(from_node):
		return
	
	var from_block = current_chapter.blocks[from_node]
	
	match from_block["type"]:
		"start", "dialogue":
			from_block["next_block_id"] = to_node
		"choice":
			if from_block.has("choices") and from_port > 0:
				var choice_index = from_port - 1
				if choice_index < from_block["choices"].size():
					from_block["choices"][choice_index]["next_block_id"] = to_node

func remove_child_from_graph(node: Control):
	if node.is_inside_tree():
		_nodes_container.remove_child(node)

# Métodos do editor de capítulos
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

func _update_chapter_editor(chapter: ChapterResource):
	if not is_instance_valid(self) or not chapter:
		return
		
	self.current_chapter = chapter
	emit_signal("change_chapter_ui", current_chapter.chapter_name, current_chapter.chapter_description)
	
	# Salvar posições atuais
	var saved_positions = {}
	for child in _nodes_container.get_children():
		if child is Control and is_instance_valid(child):
			saved_positions[child.name] = child.position + scroll_offset
	
	# Salvar conexões
	var saved_connections = get_connection_list()
	
	# Limpar o grafo
	_clear_graph()
	
	# Restaurar blocos
	for block_id in current_chapter.blocks:
		var block = current_chapter.blocks[block_id]
		
		if saved_positions.has(block_id):
			block["graph_position"] = saved_positions[block_id]
		
		if typeof(block.get("graph_position", Vector2.ZERO)) != TYPE_VECTOR2:
			block["graph_position"] = Vector2.ZERO
		
		_add_block_to_graph(block_id, block)
	
	# Restaurar conexões
	await get_tree().process_frame
	for conn in saved_connections:
		if has_node(conn.from_node) and has_node(conn.to_node):
			connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	_update_connections()

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
	
	# Configurar tema baseado no tipo
	match block_data["type"]:
		"start":
			node.modulate = Color(0.2, 0.8, 0.2)
		"end":
			node.modulate = Color(0.8, 0.2, 0.2)
		"dialogue":
			node.modulate = Color(0.2, 0.2, 0.8)
		"choice":
			node.modulate = Color(0.8, 0.8, 0.2)

	node.setup(block_data.duplicate(true))
	
	# Conectar sinal
	if node.has_signal("block_updated"):
		node.block_updated.connect(_on_block_updated.bind(block_id))

	# Configurar posição
	if block_data.has("graph_position") && typeof(block_data["graph_position"]) == TYPE_VECTOR2:
		var graph_pos = block_data["graph_position"]
		node.position = graph_pos - scroll_offset
		node.set_meta("graph_position", graph_pos)
	else:
		var new_pos = _get_new_block_position()
		node.position = new_pos - scroll_offset
		node.set_meta("graph_position", new_pos)

	add_child_to_graph(node)

func _on_block_updated(new_data, block_id):
	if not current_chapter or not current_chapter.blocks.has(block_id):
		return
		
	var node = _nodes_container.get_node_or_null(block_id)
	if node and is_instance_valid(node):
		var graph_pos = node.position + scroll_offset
		new_data["graph_position"] = graph_pos
		node.set_meta("graph_position", graph_pos)
	
	var old_block = current_chapter.blocks[block_id]
	
	# Preservar informações de conexão
	if old_block["type"] == "dialogue" or old_block["type"] == "start":
		if old_block.has("next_block_id"):
			new_data["next_block_id"] = old_block["next_block_id"]
	elif old_block["type"] == "choice":
		if old_block.has("choices"):
			for i in range(min(old_block["choices"].size(), new_data["choices"].size())):
				new_data["choices"][i]["next_block_id"] = old_block["choices"][i].get("next_block_id", "")
	
	current_chapter.blocks[block_id] = new_data
	_update_connections()

func _update_connections() -> void:
	if not current_chapter:
		return
		
	clear_connections()
	
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

func _get_new_block_position() -> Vector2:
	var viewport_center = size / 2
	return scroll_offset + viewport_center - Vector2(100, 50)

func _clear_graph():
	for child in _nodes_container.get_children():
		if child is Control and is_instance_valid(child):
			remove_child_from_graph(child)
			child.queue_free()
	clear_connections()

func _exit_tree():
	_is_ready = false
	if _event_bus_connection and _event_bus_connection.is_valid():
		EventBus.disconnect_event("_update_chapter_editor", _event_bus_connection)
