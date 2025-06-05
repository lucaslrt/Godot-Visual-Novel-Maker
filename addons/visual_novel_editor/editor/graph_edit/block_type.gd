# block_type.gd
class_name BlockType
extends RefCounted

# Referência ao nó pai
var block_node: DialogueBlockNode
var block_data: Dictionary

# Estados de minimização
var _minimized_actions = {}
var _minimized_conditionals = {}

func _init(node: DialogueBlockNode, data: Dictionary):
	block_node = node
	block_data = data

func configure_slots():
	pass

func setup_preview_ui(parent: Control):
	pass

func setup_edit_ui(parent: Control):
	# Adicionar seções padrão para todos os blocos
	_add_actions_section(parent)
	_add_conditionals_section(parent)

func update_data():
	pass

# Métodos para ações e condicionais (compartilhados por todos os blocos)
func _add_actions_section(parent: Control):
	var group = VBoxContainer.new()
	parent.add_child(group)
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var title = Label.new()
	title.text = "Ações"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Adicionar Ação"
	add_btn.pressed.connect(_add_action)
	header.add_child(add_btn)
	
	# Carregar ações existentes
	var actions = block_data.get("actions", [])
	for i in range(actions.size()):
		_add_action_ui(i, actions[i], group)

func _add_conditionals_section(parent: Control):
	var group = VBoxContainer.new()
	parent.add_child(group)
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var title = Label.new()
	title.text = "Condicionais"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var add_btn = Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Adicionar Condicional"
	add_btn.pressed.connect(_add_conditional)
	header.add_child(add_btn)
	
	# Carregar condicionais existentes
	var conditionals = block_data.get("conditionals", [])
	for i in range(conditionals.size()):
		_add_conditional_ui(i, conditionals[i], group)

func _add_action():
	if not block_data.has("actions"):
		block_data["actions"] = []
	
	block_data["actions"].append({
		"type": "set",
		"target": "",
		"value": ""
	})
	block_node._emit_update()
	block_node._update_ui()

func _add_conditional():
	if not block_data.has("conditionals"):
		block_data["conditionals"] = []
	
	block_data["conditionals"].append({
		"expression": "",
		"target_block": ""
	})
	block_node._emit_update()
	block_node._update_ui()

func _add_action_ui(index: int, action: Dictionary, parent: Control):
	var minimized = _minimized_actions.get(index, false)
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var collapse_btn = Button.new()
	collapse_btn.toggle_mode = true
	collapse_btn.button_pressed = minimized
	collapse_btn.icon = block_node.get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
	collapse_btn.pressed.connect(func(): 
		_minimized_actions[index] = not minimized
		block_node._update_ui()
	)
	header.add_child(collapse_btn)
	
	var title = Label.new()
	title.text = "Ação #%d" % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(_remove_action.bind(index))
	header.add_child(remove_btn)
	
	if not minimized:
		var type_hbox = HBoxContainer.new()
		group.add_child(type_hbox)
		
		var type_label = Label.new()
		type_label.text = "Tipo:"
		type_hbox.add_child(type_label)
		
		var type_dropdown = OptionButton.new()
		type_dropdown.add_item("Definir (set)")
		type_dropdown.set_item_metadata(type_dropdown.get_item_count() - 1, "set")

		type_dropdown.add_item("Modificar (modify)")
		type_dropdown.set_item_metadata(type_dropdown.get_item_count() - 1, "modify")

		type_dropdown.add_item("Chamar Método (call)")
		type_dropdown.set_item_metadata(type_dropdown.get_item_count() - 1, "call")
		
		var current_type = action.get("type", "set")
		for i in type_dropdown.get_item_count():
			if type_dropdown.get_item_metadata(i) == current_type:
				type_dropdown.select(i)
				break
		
		type_dropdown.item_selected.connect(func(idx):
			action["type"] = type_dropdown.get_item_metadata(idx)
			block_node._emit_update()
		)
		type_hbox.add_child(type_dropdown)
		
		var target_hbox = HBoxContainer.new()
		group.add_child(target_hbox)
		
		var target_label = Label.new()
		target_label.text = "Alvo:"
		target_hbox.add_child(target_label)
		
		var target_edit = LineEdit.new()
		target_edit.text = action.get("target", "")
		target_edit.placeholder_text = "Nome da variável/método"
		target_edit.text_changed.connect(func(text):
			action["target"] = text
			block_node._emit_update()
		)
		target_hbox.add_child(target_edit)
		
		var value_hbox = HBoxContainer.new()
		group.add_child(value_hbox)
		
		var value_label = Label.new()
		value_label.text = "Valor:"
		value_hbox.add_child(value_label)
		
		var value_edit = LineEdit.new()
		value_edit.text = str(action.get("value", ""))
		value_edit.placeholder_text = "Valor numérico ou texto"
		value_edit.text_changed.connect(func(text):
			action["value"] = text
			block_node._emit_update()
		)
		value_hbox.add_child(value_edit)

func _add_conditional_ui(index: int, conditional: Dictionary, parent: Control):
	var minimized = _minimized_conditionals.get(index, false)
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	parent.add_child(group)
	
	var header = HBoxContainer.new()
	group.add_child(header)
	
	var collapse_btn = Button.new()
	collapse_btn.toggle_mode = true
	collapse_btn.button_pressed = minimized
	collapse_btn.icon = block_node.get_theme_icon("GuiTreeArrowDown" if not minimized else "GuiTreeArrowRight", "EditorIcons")
	collapse_btn.pressed.connect(func(): 
		_minimized_conditionals[index] = not minimized
		block_node._update_ui()
	)
	header.add_child(collapse_btn)
	
	var title = Label.new()
	title.text = "Condicional #%d" % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(_remove_conditional.bind(index))
	header.add_child(remove_btn)
	
	if not minimized:
		var expr_hbox = HBoxContainer.new()
		group.add_child(expr_hbox)
		
		var expr_label = Label.new()
		expr_label.text = "Expressão:"
		expr_hbox.add_child(expr_label)
		
		var expr_edit = LineEdit.new()
		expr_edit.text = conditional.get("expression", "")
		expr_edit.placeholder_text = "Ex: sanity > 50"
		expr_edit.text_changed.connect(func(text):
			conditional["expression"] = text
			block_node._emit_update()
		)
		expr_hbox.add_child(expr_edit)
		
		var target_hbox = HBoxContainer.new()
		group.add_child(target_hbox)
		
		var target_label = Label.new()
		target_label.text = "Bloco Alvo:"
		target_hbox.add_child(target_label)
		
		var target_edit = LineEdit.new()
		target_edit.text = conditional.get("target_block", "")
		target_edit.placeholder_text = "ID do bloco destino"
		target_edit.text_changed.connect(func(text):
			conditional["target_block"] = text
			block_node._emit_update()
		)
		target_hbox.add_child(target_edit)
		
		# Adicionar botão de ajuda para expressões
		var help_btn = Button.new()
		help_btn.text = "?"
		help_btn.tooltip_text = "Ajuda com expressões"
		help_btn.pressed.connect(_show_conditional_help)
		target_hbox.add_child(help_btn)

func _show_conditional_help():
	var help_dialog = AcceptDialog.new()
	help_dialog.title = "Ajuda com Expressões Condicionais"
	help_dialog.dialog_text = """Formatos suportados:
	
1. Comparação simples:
   variavel operador valor
   Ex: sanity > 50, reputation <= 100

2. Verificação de flag:
   flag_name
   Ex: has_key, met_character

3. Expressão match:
   match: variavel;valor1:bloco1;valor2:bloco2;default:bloco_padrao
   Ex: match: ending;good:end_good;bad:end_bad;default:end_neutral

Operadores: ==, !=, >, >=, <, <="""
	
	block_node.add_child(help_dialog)
	help_dialog.popup_centered()

func _remove_action(index: int):
	if block_data.has("actions") and block_data["actions"].size() > index:
		block_data["actions"].remove_at(index)
		_minimized_actions.erase(index)
		block_node._emit_update()
		block_node._update_ui()

func _remove_conditional(index: int):
	if block_data.has("conditionals") and block_data["conditionals"].size() > index:
		block_data["conditionals"].remove_at(index)
		_minimized_conditionals.erase(index)
		block_node._emit_update()
		block_node._update_ui()
