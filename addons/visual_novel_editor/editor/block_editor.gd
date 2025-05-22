@tool
extends Panel
class_name BlockEditor

var current_block_id = ""
var _current_chapter_ref: WeakRef
var _event_connection: Callable
var _is_ready: bool = false

func set_current_chapter(chapter: ChapterResource):
	_current_chapter_ref = weakref(chapter)

func get_current_chapter() -> ChapterResource:
	if _current_chapter_ref and is_instance_valid(_current_chapter_ref.get_ref()):
		return _current_chapter_ref.get_ref()
	return null

func _ready() -> void:
	_is_ready = true
	
	# Registrar evento antes de conectar
	EventBus.register_event("update_block_editor")
	
	# Criar callable seguro
	_event_connection = _create_safe_callable()
	EventBus.connect_event("update_block_editor", _event_connection)

func _create_safe_callable() -> Callable:
	return func(params): 
		if is_instance_valid(self) and _is_ready and params.size() >= 2:
			_update_block_editor(params[0], params[1])
		else:
			# Auto-desconectar se inválido
			if _event_connection and _event_connection.is_valid():
				EventBus.disconnect_event("update_block_editor", _event_connection)

func _update_block_editor(node_name: String, current_chapter: ChapterResource):
	if not is_instance_valid(self) or not _is_ready:
		return
		
	current_block_id = node_name
	set_current_chapter(current_chapter)
	
	if not current_chapter or current_block_id.is_empty():
		_clear_block_editor()
		return
	
	var block = current_chapter.get_block(current_block_id)
	if not block:
		_clear_block_editor()
		return
	
	# Limpar o editor atual
	_clear_block_editor()
	
	# Criar UI baseada no tipo de bloco
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Adicionar campos comuns
	var type_label = Label.new()
	type_label.text = "Tipo: " + str(block.get("type", "unknown"))
	vbox.add_child(type_label)
	
	match block.get("type", ""):
		"dialogue":
			_create_dialogue_editor(vbox, block)
		"choice":
			_create_choice_editor(vbox, block)

func _create_dialogue_editor(parent, block_data):
	# Verificar se ainda somos válidos
	if not is_instance_valid(self) or not _is_ready:
		return
		
	var char_label = Label.new()
	char_label.text = "Personagem:"
	parent.add_child(char_label)
	
	var char_edit = LineEdit.new()
	char_edit.text = str(block_data.get("character_name", ""))
	char_edit.placeholder_text = "Nome do personagem"
	parent.add_child(char_edit)
	
	var expr_label = Label.new()
	expr_label.text = "Expressão:"
	parent.add_child(expr_label)
	
	var expr_edit = LineEdit.new()
	expr_edit.text = str(block_data.get("character_expression", ""))
	expr_edit.placeholder_text = "Expressão do personagem"
	parent.add_child(expr_edit)
	
	var pos_label = Label.new()
	pos_label.text = "Posição (X, Y):"
	parent.add_child(pos_label)
	
	var pos_container = HBoxContainer.new()
	parent.add_child(pos_container)
	
	var character_pos = block_data.get("character_position", Vector2(0.5, 1.0))
	
	var pos_x_edit = SpinBox.new()
	pos_x_edit.min_value = 0.0
	pos_x_edit.max_value = 1.0
	pos_x_edit.step = 0.1
	pos_x_edit.value = character_pos.x
	pos_container.add_child(pos_x_edit)
	
	var pos_y_edit = SpinBox.new()
	pos_y_edit.min_value = 0.0
	pos_y_edit.max_value = 1.0
	pos_y_edit.step = 0.1
	pos_y_edit.value = character_pos.y
	pos_container.add_child(pos_y_edit)
	
	var text_label = Label.new()
	text_label.text = "Texto:"
	parent.add_child(text_label)
	
	var text_edit = TextEdit.new()
	text_edit.text = str(block_data.get("text", ""))
	text_edit.placeholder_text = "Digite o texto do diálogo aqui"
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(text_edit)
	
	var next_label = Label.new()
	next_label.text = "Próximo bloco:"
	parent.add_child(next_label)
	
	var next_edit = LineEdit.new()
	next_edit.text = str(block_data.get("next_block_id", ""))
	next_edit.placeholder_text = "ID do próximo bloco"
	parent.add_child(next_edit)
	
	# Botão para salvar alterações
	var save_button = Button.new()
	save_button.text = "Salvar Alterações"
	
	# Criar callable seguro para o botão
	var save_callable = func():
		if not is_instance_valid(self) or not _is_ready:
			return
			
		var chapter = get_current_chapter()
		if not chapter:
			return
			
		# Atualizar dados do bloco
		block_data["character_name"] = char_edit.text
		block_data["character_expression"] = expr_edit.text
		block_data["character_position"] = Vector2(pos_x_edit.value, pos_y_edit.value)
		block_data["text"] = text_edit.text
		block_data["next_block_id"] = next_edit.text
		
		# Atualizar o bloco no capítulo
		chapter.update_block(current_block_id, block_data)
		
		# Atualizar o grafo
		EventBus.emit("_update_chapter_editor", [chapter])
	
	save_button.pressed.connect(save_callable)
	parent.add_child(save_button)

func _create_choice_editor(parent, block_data):
	if not is_instance_valid(self) or not _is_ready:
		return
		
	var choices_label = Label.new()
	choices_label.text = "Escolhas:"
	parent.add_child(choices_label)
	
	var choices_container = VBoxContainer.new()
	parent.add_child(choices_container)
	
	var choices = block_data.get("choices", [])
	
	# Adicionar as escolhas existentes
	for i in range(choices.size()):
		var choice = choices[i]
		var choice_container = HBoxContainer.new()
		choices_container.add_child(choice_container)
		
		var choice_text = LineEdit.new()
		choice_text.text = str(choice.get("text", ""))
		choice_text.placeholder_text = "Texto da escolha"
		choice_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.add_child(choice_text)
		
		var next_id = LineEdit.new()
		next_id.text = str(choice.get("next_block_id", ""))
		next_id.placeholder_text = "Próximo bloco"
		next_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.add_child(next_id)
		
		var delete_button = Button.new()
		delete_button.text = "X"
		
		# Criar callable seguro para deletar
		var delete_callable = func(choice_index = i):
			if not is_instance_valid(self) or not _is_ready:
				return
				
			var chapter = get_current_chapter()
			if chapter and chapter.blocks.has(current_block_id):
				var current_block = chapter.blocks[current_block_id]
				if current_block.has("choices") and choice_index < current_block.choices.size():
					current_block.choices.remove_at(choice_index)
					chapter.update_block(current_block_id, current_block)
					_update_block_editor(current_block_id, chapter)
					EventBus.emit("_update_chapter_editor", [chapter])
		
		delete_button.pressed.connect(delete_callable)
		choice_container.add_child(delete_button)
	
	# Botão para adicionar nova escolha
	var add_choice_button = Button.new()
	add_choice_button.text = "Adicionar Escolha"
	
	var add_choice_callable = func():
		if not is_instance_valid(self) or not _is_ready:
			return
			
		var chapter = get_current_chapter()
		if not chapter:
			return
			
		if not block_data.has("choices"):
			block_data["choices"] = []
			
		block_data.choices.append({
			"text": "Nova escolha",
			"next_block_id": ""
		})
		
		chapter.update_block(current_block_id, block_data)
		_update_block_editor(current_block_id, chapter)
		EventBus.emit("_update_chapter_editor", [chapter])
	
	add_choice_button.pressed.connect(add_choice_callable)
	parent.add_child(add_choice_button)
	
	# Botão para salvar alterações
	var save_button = Button.new()
	save_button.text = "Salvar Alterações"
	
	var save_callable = func():
		if not is_instance_valid(self) or not _is_ready:
			return
			
		var chapter = get_current_chapter()
		if not chapter:
			return
			
		# Atualizar dados das escolhas
		for i in range(block_data.get("choices", []).size()):
			if i < choices_container.get_child_count():
				var choice_container = choices_container.get_child(i)
				if choice_container.get_child_count() >= 2:
					var choice_text = choice_container.get_child(0)
					var next_id = choice_container.get_child(1)
					
					if is_instance_valid(choice_text) and is_instance_valid(next_id):
						block_data.choices[i]["text"] = choice_text.text
						block_data.choices[i]["next_block_id"] = next_id.text
		
		chapter.update_block(current_block_id, block_data)
		EventBus.emit("_update_chapter_editor", [chapter])
	
	save_button.pressed.connect(save_callable)
	parent.add_child(save_button)

func _clear_block_editor():
	for child in get_children():
		if is_instance_valid(child):
			remove_child(child)
			child.queue_free()

func _exit_tree():
	_is_ready = false
	if _event_connection and _event_connection.is_valid():
		EventBus.disconnect_event("update_block_editor", _event_connection)
