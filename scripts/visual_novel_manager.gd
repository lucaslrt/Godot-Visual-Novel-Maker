## nodes/visual_novel_manager.gd
@tool
extends Node

signal dialogue_started(chapter_name, block_id)
signal dialogue_advanced(block_id)
signal dialogue_ended(chapter_name)
signal choice_presented(choices)
signal choice_selected(choice_index)

# A referência para o capítulo atual sendo executado
var current_chapter_resource = null
# O bloco de diálogo atual
var current_block_id = ""
# Referência para o nó que exibe os personagens e diálogos
var dialogue_display = null

# Método para iniciar um capítulo
func start_chapter(chapter_resource):
	current_chapter_resource = chapter_resource
	current_block_id = chapter_resource.start_block_id
	
	emit_signal("dialogue_started", chapter_resource.chapter_name, current_block_id)
	_process_current_block()

# Método para avançar para o próximo bloco
func advance_dialogue():
	if current_chapter_resource == null:
		return
		
	var current_block = current_chapter_resource.get_block(current_block_id)
	
	if current_block == null:
		end_dialogue()
		return
		
	if current_block.has("next_block_id") and not current_block.next_block_id.is_empty():
		current_block_id = current_block.next_block_id
		emit_signal("dialogue_advanced", current_block_id)
		_process_current_block()
	else:
		end_dialogue()

# Método para processar o bloco atual
func _process_current_block():
	if current_chapter_resource == null:
		return
		
	var block = current_chapter_resource.get_block(current_block_id)
	
	if block == null:
		end_dialogue()
		return
		
	match block.type:
		"dialogue":
			# A UI será atualizada via sinal dialogue_advanced
			pass
		"choice":
			emit_signal("choice_presented", block.choices)
		_:
			advance_dialogue()

# Método para selecionar uma escolha
func select_choice(choice_index):
	if current_chapter_resource == null:
		return
		
	var block = current_chapter_resource.get_block(current_block_id)
	
	if block == null or block.type != "choice" or choice_index >= block.choices.size():
		return
		
	emit_signal("choice_selected", choice_index)
	
	# Atualiza o bloco atual e emite o sinal de avanço
	current_block_id = block.choices[choice_index].next_block_id
	emit_signal("dialogue_advanced", current_block_id)  # Adicionado este sinal
	_process_current_block()

# Método para encerrar o diálogo atual
func end_dialogue():
	if current_chapter_resource:
		emit_signal("dialogue_ended", current_chapter_resource.chapter_name)
	current_chapter_resource = null
	current_block_id = ""

# Método para definir o display de diálogo
func set_dialogue_display(display_node):
	dialogue_display = display_node
