@tool
extends Panel
class_name BlockEditor

var current_block_id = ""
var _current_chapter_ref: WeakRef

func set_current_chapter(chapter: ChapterResource):
	_current_chapter_ref = weakref(chapter)

func get_current_chapter() -> ChapterResource:
	if _current_chapter_ref and _current_chapter_ref.get_ref():
		return _current_chapter_ref.get_ref()
	return null

func _ready() -> void:
	EventBus.connect_event("update_block_editor", 
		 func(params): _update_block_editor(params[0], params[1]))

func _update_block_editor(node_name: String, current_chapter: ChapterResource):
	current_block_id = node_name
	if not current_chapter or current_block_id.is_empty():
		_clear_block_editor()
		return
	
	var block = current_chapter.get_block(current_block_id)
	if not block:
		_clear_block_editor()
		return
	
	# Limpar o editor atual
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	# Criar UI baseada no tipo de bloco
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
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
		
		# Atualizar o editor
		var chapter = get_current_chapter()
		if chapter:
			# Atualizar o bloco no capítulo
			chapter.update_block(current_block_id, block_data)
			
			# Atualizar o grafo
			EventBus.emit("_update_chapter_editor", [chapter])
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
				if not is_instance_valid(self):
					return

				# Usar get_current_chapter() em vez de current_chapter direto
				var chapter = get_current_chapter()
				if chapter:
					block_data.choices.remove_at(i)
					_update_block_editor(self.name, chapter)
					chapter.update_block(current_block_id, block_data)
					EventBus.emit("_update_chapter_editor", [chapter])
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
		var chapter = get_current_chapter()
		if chapter:
			_update_block_editor(self.name, chapter)
			
			# Atualizar o bloco no capítulo
			chapter.update_block(current_block_id, block_data)
			
			# Atualizar o grafo
			EventBus.emit("_update_chapter_editor", [chapter])
	)
	parent.add_child(add_choice_button)
	
	# Botão para salvar alterações
	var save_button = Button.new()
	save_button.text = "Salvar Alterações"
	save_button.pressed.connect(func():
		if not is_instance_valid(self):
			return
			
		var chapter = get_current_chapter()
		if chapter:
			# Atualizar dados das escolhas
			for i in range(block_data.choices.size()):
				var choice_container = choices_container.get_child(i)
				var choice_text = choice_container.get_child(0)
				var next_id = choice_container.get_child(1)
				
				block_data.choices[i].text = choice_text.text
				block_data.choices[i].next_block_id = next_id.text
			
			chapter.update_block(current_block_id, block_data)
			EventBus.emit("_update_chapter_editor", [chapter])
	)
	parent.add_child(save_button)

func _clear_block_editor():
	for child in get_children():
		remove_child(child)
		child.queue_free()
