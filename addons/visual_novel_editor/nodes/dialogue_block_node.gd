@tool
extends GraphNode
class_name DialogueBlockNode

signal block_updated(block_data)
signal delete_requested(block_id)

var block_data = {}
var editing := false
var characters_cache = {}  # Cache de personagens e expressões

func _ready():
	# Conectar sinal de arraste
	connect("dragged", _on_dragged)
	# Carregar personagens
	_load_characters()

func _load_characters():
	if not VisualNovelSingleton:
		return
	
	characters_cache.clear()
	for character_id in VisualNovelSingleton.characters:
		var character = VisualNovelSingleton.characters[character_id]
		characters_cache[character.display_name] = character.expressions.keys()

func _on_dragged(from: Vector2, to: Vector2):
	# Atualizar posição nos dados
	block_data["graph_position"] = Vector2(position_offset)
	_emit_update()

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
	
	# Carregar personagens atualizados
	_load_characters()
	
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
	
	# Adicionar botão de exclusão
	_add_delete_button()

func _configure_slots():
	clear_all_slots()
	
	match block_data["type"]:
		"start":
			title = "INÍCIO"
			set_slot(0, 
				false, 0, Color(0, 0, 0, 0),       # Sem entrada para start
				true, 0, Color(0.2, 0.8, 0.2)     # Saída verde
			)
		
		"end":
			title = "FIM"
			set_slot(0, 
				true, 0, Color(0.8, 0.2, 0.2),    # Entrada vermelha (permite múltiplas)
				false, 0, Color(0, 0, 0, 0)       # Sem saída
			)
		
		"dialogue":
			title = "Diálogo: " + block_data.get("character_name", "Nenhum")
			set_slot(0, 
				true, 0, Color(0.3, 0.3, 0.8),    # Entrada azul (permite múltiplas)
				true, 0, Color(0.8, 0.3, 0.3)     # Saída vermelha
			)
		
		"choice":
			title = "Escolha"
			var choices = block_data.get("choices", [])
			var num_choices = choices.size()
			
			# Limpar todos os slots existentes
			clear_all_slots()
			
			# CORREÇÃO: Configurar slot 0 apenas como entrada (para receber conexões)
			set_slot(0,
				true, 0, Color.CADET_BLUE,     # Entrada azul
				true, 0, Color(0, 0, 0, 0)    # Sem saída no slot 0
			)
			
			# Cores do gradiente amarelo->escuro para os slots de saída
			var base_yellow = Color(0.95, 0.95, 0.3)
			var dark_yellow = Color(0.5, 0.5, 0.1)
			var color_step = 1.0 / max(num_choices, 1)
			
			# Criar espaçadores e slots de saída no meio do bloco
			for i in range(num_choices):
				# Interpolação linear entre as cores
				var slot_color = base_yellow.lerp(dark_yellow, color_step * i)
				
				# CORREÇÃO: Configurar slots de saída (índices i+1) apenas como saída
				set_slot(i + 1,
					false, 0, Color(0, 0, 0, 0),   # Sem entrada nos slots de saída
					true, 0, slot_color            # Saída colorida
				)
				
				var spacer = Control.new()
				spacer.name = "OutputSpacer_%d" % (i+1)
				spacer.custom_minimum_size = Vector2(0, 25)  # Espaçamento entre slots
				add_child(spacer)

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
			content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content.custom_minimum_size.y = 0  # Permite que o TextEdit encolha
			content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			parent.add_child(content)
			
			# Mostrar expressão e posição se existirem
			if block_data.has("character_expression"):
				var expr_label = Label.new()
				expr_label.text = "Expressão: " + block_data.character_expression
				parent.add_child(expr_label)
			
			if block_data.has("character_position"):
				var pos = block_data.character_position
				# Verificar se é Vector2, caso contrário usar valor padrão
				if typeof(pos) != TYPE_VECTOR2:
					pos = Vector2(0.5, 1.0)
					block_data["character_position"] = pos
				
				var pos_label = Label.new()
				pos_label.text = "Posição: %.1f, %.1f" % [pos.x, pos.y]
				parent.add_child(pos_label)
		
		"choice":
			var choice_vbox = VBoxContainer.new()
			parent.add_child(choice_vbox)
			
			var choices = block_data.get("choices", [])
			
			# Cores do gradiente amarelo->escuro
			var base_yellow = Color(0.95, 0.95, 0.3)  # Amarelo bem claro
			var dark_yellow = Color(0.5, 0.5, 0.1)    # Amarelo escuro
			var color_step = 1.0 / max(choices.size(), 1)
			
			for i in range(choices.size()):
				var choice = choices[i]
				var hbox = HBoxContainer.new()
				choice_vbox.add_child(hbox)
				
				# Interpolação linear entre as cores
				var slot_color = base_yellow.lerp(dark_yellow, color_step * i)
				
				# Indicador visual do slot de saída
				var slot_indicator = ColorRect.new()
				slot_indicator.color = slot_color
				slot_indicator.custom_minimum_size = Vector2(10, 10)
				hbox.add_child(slot_indicator)
				
				var label = Label.new()
				label.text = "• " + choice.get("text", "")
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(label)
				
				var next_label = Label.new()
				next_label.text = "→ " + choice.get("next_block_id", "Nenhum")
				next_label.modulate = Color(0.7, 0.7, 0.7)
				hbox.add_child(next_label)

func _setup_edit_ui(parent: Control) -> void:
	match block_data["type"]:
		"dialogue":
			# Personagem (Dropdown)
			var char_hbox = HBoxContainer.new()
			parent.add_child(char_hbox)
			
			var char_label = Label.new()
			char_label.text = "Personagem:"
			char_hbox.add_child(char_label)
			
			var char_dropdown = OptionButton.new()
			char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			char_hbox.add_child(char_dropdown)
			
			# Preencher dropdown de personagens
			var current_char = block_data.get("character_name", "")
			var char_index = 0
			var char_names = characters_cache.keys()
			
			for i in range(char_names.size()):
				char_dropdown.add_item(char_names[i])
				if char_names[i] == current_char:
					char_index = i
			
			char_dropdown.selected = char_index
			char_dropdown.item_selected.connect(_on_character_selected)
			
			# Expressão (Dropdown)
			var expr_hbox = HBoxContainer.new()
			parent.add_child(expr_hbox)
			
			var expr_label = Label.new()
			expr_label.text = "Expressão:"
			expr_hbox.add_child(expr_label)
			
			var expr_dropdown = OptionButton.new()
			expr_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			expr_hbox.add_child(expr_dropdown)
			
			# Atualizar dropdown de expressões
			_update_expression_dropdown(expr_dropdown, current_char)
			
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
			text_edit.custom_minimum_size.y = 100
			text_edit.text_changed.connect(func():
				block_data["text"] = text_edit.text
				_emit_update()
			)
			parent.add_child(text_edit)
		
		"choice":
			var choices_scroll = ScrollContainer.new()
			choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			choices_scroll.custom_minimum_size.y = 150
			parent.add_child(choices_scroll)
			
			var choices_vbox = VBoxContainer.new()
			choices_scroll.add_child(choices_vbox)
			
			var choices = block_data.get("choices", [])
			for i in range(choices.size()):
				var choice = choices[i]
				var hbox = HBoxContainer.new()
				choices_vbox.add_child(hbox)
				
				# Indicador visual do slot
				var slot_indicator = ColorRect.new()
				slot_indicator.color = Color(0.8, 0.8, 0.2)
				slot_indicator.custom_minimum_size = Vector2(15, 15)
				hbox.add_child(slot_indicator)
				
				var text_edit = LineEdit.new()
				text_edit.text = choice.get("text", "")
				text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text_edit.text_changed.connect(func(text, idx=i):
					block_data.choices[idx]["text"] = text
					_emit_update()
				)
				hbox.add_child(text_edit)
				
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

func _add_delete_button():
	if block_data["type"] == "start":
		return  # Não permitir excluir o bloco inicial
		
	var delete_btn = Button.new()
	delete_btn.text = "X"
	delete_btn.flat = true
	delete_btn.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	delete_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	delete_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	delete_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.pressed.connect(_on_delete_pressed)
	
	# Posicionar no canto superior direito
	delete_btn.position = Vector2(get_size().x - 25, 5)
	delete_btn.size = Vector2(20, 20)
	add_child(delete_btn)
	
	# Garantir que o botão fique acima de outros elementos
	delete_btn.z_index = 100

func _on_delete_pressed():
	# Emitir sinal para solicitar exclusão
	delete_requested.emit(name)

func _on_character_selected(index: int):
	var char_name = characters_cache.keys()[index]
	block_data["character_name"] = char_name
	
	# Atualizar expressão para a padrão do personagem
	if characters_cache[char_name].size() > 0:
		block_data["character_expression"] = characters_cache[char_name][0]
	
	_emit_update()
	_update_ui()  # Atualiza a UI para mostrar as novas expressões

func _update_expression_dropdown(dropdown: OptionButton, char_name: String):
	dropdown.clear()
	
	if char_name.is_empty() or not characters_cache.has(char_name):
		return
	
	var expressions = characters_cache[char_name]
	var current_expr = block_data.get("character_expression", "")
	var expr_index = 0
	
	for i in range(expressions.size()):
		dropdown.add_item(expressions[i])
		if expressions[i] == current_expr:
			expr_index = i
	
	dropdown.selected = expr_index
	dropdown.item_selected.connect(func(index):
		block_data["character_expression"] = dropdown.get_item_text(index)
		_emit_update()
	)

func _toggle_edit_mode():
	editing = not editing
	_update_ui()

func _emit_update():
	block_updated.emit(block_data)

func clear_all_slots():
	# Remove todos os espaçadores adicionados
	for child in get_children():
		if child.name.begins_with("InputSpacer") or child.name.begins_with("OutputSpacer_"):
			remove_child(child)
			child.queue_free()
