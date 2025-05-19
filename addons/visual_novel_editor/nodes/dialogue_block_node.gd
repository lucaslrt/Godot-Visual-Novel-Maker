@tool
extends GraphNode
class_name DialogueBlockNode

signal block_updated(block_data)

var block_data = {}
var editing := false

func setup(initial_data: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	
	block_data = initial_data
	_update_ui()

func _update_ui() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Limpar filhos existentes
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	# Container principal com scroll para conteúdo longo
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(500, 550)  # Tamanho mínimo aumentado
	add_child(scroll_container)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(vbox)
	
	# Configurar slots baseado no tipo
	_configure_slots()
	
	if editing and block_data["type"] != "start" and block_data["type"] != "end":
		_setup_edit_ui(vbox)
	else:
		_setup_preview_ui(vbox)
	
	# Botão de edição (exceto para start/end)
	if block_data["type"] != "start" and block_data["type"] != "end":
		var toggle_btn = Button.new()
		toggle_btn.text = "Editar" if not editing else "Visualizar"
		toggle_btn.pressed.connect(_toggle_edit_mode)
		add_child(toggle_btn)

func _configure_slots():
	# Limpar todos os slots primeiro
	clear_all_slots()
	
	match block_data["type"]:
		"start":
			title = "INÍCIO"
			set_slot(0, 
				false,  # Habilitar slot de entrada? 
				0, Color(0, 0, 0, 0),  # Cor entrada (transparente)
				true,   # Habilitar slot de saída
				0, Color(0.2, 0.8, 0.2)  # Cor saída (verde)
			)
		
		"end":
			title = "FIM"
			set_slot(0, 
				true,   # Habilitar slot de entrada
				0, Color(0.8, 0.2, 0.2),  # Cor entrada (vermelho)
				false,  # Habilitar slot de saída?
				0, Color(0, 0, 0, 0)  # Cor saída (transparente)
			)
		
		"dialogue":
			title = "Diálogo"
			set_slot(0, 
				true,   # Entrada
				0, Color(0.3, 0.3, 0.8),  # Azul
				true,   # Saída
				0, Color(0.8, 0.3, 0.3)   # Vermelho
			)
		
		"choice":
			title = "Escolha"
			# Configurar slot de entrada no topo
			set_slot(0, 
				true,  # Entrada
				0, Color(0.3, 0.3, 0.8),  # Azul
				false, # Sem saída no slot principal
				0, Color(0, 0, 0, 0)
			)
			
			# Configurar slots para cada escolha
			for i in range(block_data.get("choices", []).size()):
				var slot_index = i + 1  # +1 porque o slot 0 é para entrada
				set_slot(slot_index, 
					false,  # Sem entrada nos slots de escolha
					0, Color(0, 0, 0, 0),
					true,   # Saída para cada escolha
					0, Color(0.8, 0.8, 0.2)  # Amarelo
				)

func _setup_preview_ui(parent: Control) -> void:
	match block_data["type"]:
		"start":
			var label = Label.new()
			label.text = "Início do capítulo"
			parent.add_child(label)
			
		"end":
			var label = Label.new()
			label.text = "Fim do capítulo"
			parent.add_child(label)
			
		"dialogue":
			var content = TextEdit.new()
			content.text = "%s: %s" % [
				block_data.get("character_name", ""), 
				block_data.get("text", "")
			]
			content.editable = false
			content.fit_content_height = true
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(content)
			
			# Mostrar expressão e posição se existirem
			if block_data.has("character_expression"):
				var expr_label = Label.new()
				expr_label.text = "Expressão: " + block_data.character_expression
				parent.add_child(expr_label)
			
			if block_data.has("character_position"):
				var pos_label = Label.new()
				pos_label.text = "Posição: %.1f, %.1f" % [
					block_data.character_position.x,
					block_data.character_position.y
				]
				parent.add_child(pos_label)
		
		"choice":
			# Adicionar um espaçador para o slot de entrada
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 20
			parent.add_child(spacer)
			
			var choice_vbox = VBoxContainer.new()
			parent.add_child(choice_vbox)
			
			for choice in block_data.get("choices", []):
				var hbox = HBoxContainer.new()
				choice_vbox.add_child(hbox)
				
				var label = Label.new()
				label.text = "• " + choice.get("text", "")
				hbox.add_child(label)
				
				var next_label = Label.new()
				next_label.text = "→ " + choice.get("next_block_id", "")
				hbox.add_child(next_label)

func _setup_edit_ui(parent: Control) -> void:
	match block_data["type"]:
		"dialogue":
			# Personagem
			var char_hbox = HBoxContainer.new()
			parent.add_child(char_hbox)
			
			var char_label = Label.new()
			char_label.text = "Personagem:"
			char_hbox.add_child(char_label)
			
			var char_edit = LineEdit.new()
			char_edit.text = block_data.get("character_name", "")
			char_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			char_edit.text_changed.connect(func(text):
				block_data["character_name"] = text
				_emit_update()
			)
			char_hbox.add_child(char_edit)
			
			# Expressão
			var expr_hbox = HBoxContainer.new()
			parent.add_child(expr_hbox)
			
			var expr_label = Label.new()
			expr_label.text = "Expressão:"
			expr_hbox.add_child(expr_label)
			
			var expr_edit = LineEdit.new()
			expr_edit.text = block_data.get("character_expression", "default")
			expr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			expr_edit.text_changed.connect(func(text):
				block_data["character_expression"] = text
				_emit_update()
			)
			expr_hbox.add_child(expr_edit)
			
			# Posição
			var pos_hbox = HBoxContainer.new()
			parent.add_child(pos_hbox)
			
			var pos_label = Label.new()
			pos_label.text = "Posição:"
			pos_hbox.add_child(pos_label)
			
			var pos_x = SpinBox.new()
			pos_x.min_value = 0
			pos_x.max_value = 1
			pos_x.step = 0.1
			pos_x.value = block_data.get("character_position", Vector2(0.5, 1.0)).x
			pos_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pos_x.value_changed.connect(func(val):
				if not block_data.has("character_position"):
					block_data["character_position"] = Vector2(0.5, 1.0)
				block_data["character_position"].x = val
				_emit_update()
			)
			pos_hbox.add_child(pos_x)
			
			var pos_y = SpinBox.new()
			pos_y.min_value = 0
			pos_y.max_value = 1
			pos_y.step = 0.1
			pos_y.value = block_data.get("character_position", Vector2(0.5, 1.0)).y
			pos_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pos_y.value_changed.connect(func(val):
				if not block_data.has("character_position"):
					block_data["character_position"] = Vector2(0.5, 1.0)
				block_data["character_position"].y = val
				_emit_update()
			)
			pos_hbox.add_child(pos_y)
			
			# Texto
			var text_label = Label.new()
			text_label.text = "Texto:"
			parent.add_child(text_label)
			
			var text_edit = TextEdit.new()
			text_edit.text = block_data.get("text", "")
			text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
			text_edit.custom_minimum_size.y = 100  # Altura mínima maior
			text_edit.text_changed.connect(func():
				block_data["text"] = text_edit.text
				_emit_update()
			)
			parent.add_child(text_edit)
		
		"choice":
			# Adicionar um espaçador para o slot de entrada
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 20
			parent.add_child(spacer)
			
			var choices_scroll = ScrollContainer.new()
			choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			choices_scroll.custom_minimum_size.y = 150
			parent.add_child(choices_scroll)
			
			var choices_vbox = VBoxContainer.new()
			choices_scroll.add_child(choices_vbox)
			
			for i in range(block_data.choices.size()):
				var choice = block_data.choices[i]
				var hbox = HBoxContainer.new()
				choices_vbox.add_child(hbox)
				
				var text_edit = LineEdit.new()
				text_edit.text = choice.get("text", "")
				text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text_edit.text_changed.connect(func(text, idx=i):
					block_data.choices[idx]["text"] = text
					_emit_update()
				)
				hbox.add_child(text_edit)
				
				var next_edit = LineEdit.new()
				next_edit.text = choice.get("next_block_id", "")
				next_edit.placeholder_text = "Próximo bloco"
				next_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				next_edit.text_changed.connect(func(text, idx=i):
					block_data.choices[idx]["next_block_id"] = text
					_emit_update()
				)
				hbox.add_child(next_edit)
				
				var delete_btn = Button.new()
				delete_btn.text = "X"
				delete_btn.pressed.connect(func(idx=i):
					block_data.choices.remove_at(idx)
					_update_ui()
					_emit_update()
				)
				hbox.add_child(delete_btn)
			
			var add_btn = Button.new()
			add_btn.text = "Adicionar Escolha"
			add_btn.pressed.connect(func():
				block_data.choices.append({"text": "Nova escolha", "next_block_id": ""})
				_update_ui()
				_emit_update()
			)
			parent.add_child(add_btn)

func _toggle_edit_mode():
	editing = not editing
	_update_ui()

func _emit_update():
	block_updated.emit(block_data)
