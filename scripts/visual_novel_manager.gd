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
var current_dialogue_index: int = 0
# Referência para o nó que exibe os personagens e diálogos
var dialogue_display = null
# Variável para armazenar o último capítulo concluído
var last_completed_chapter_id = ""

# Estado atual do jogo
var game_state = GameState.new()
var method_registry = MethodRegistry.new()
var conditional_system = ConditionalSystem.new(game_state, method_registry)
var game_save_state = {
	"current_save_slot": 0,  # Slot atualmente em uso
	"save_slots": {}         # Dicionário com todos os slots de save
}
const MAX_SAVE_SLOTS = 50    # Número máximo de slots de save

# Exemplo de chamada de métodos condicionais
#func _ready():
	## Registrar métodos comuns
	#method_registry.register_method("increase_sanity", Callable(self, "_increase_sanity"))
	#method_registry.register_method("decrease_sanity", Callable(self, "_decrease_sanity"))
	#method_registry.register_method("unlock_ending", Callable(self, "_unlock_ending"))

func save_game_state(slot_index: int = -1):
	# Determinar qual slot usar
	var save_slot = slot_index if slot_index != -1 else game_save_state["current_save_slot"]
	
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Não foi possível acessar o diretório user://")
		return
		
	if not dir.dir_exists("user://saves"):
		dir.make_dir_recursive("user://saves")
	
	# Salvar cada slot em um arquivo separado
	for slot in game_save_state["save_slots"]:
		var slot_data = game_save_state["save_slots"][slot]
		var file_path = "user://saves/save_slot_%d.json" % slot
		
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			push_error("Erro ao abrir arquivo para escrita: " + file_path)
			continue
		
		file.store_string(JSON.stringify(slot_data, "\t"))
		file.close()
	
	# Salvar também o slot atual
	var current_slot_path = "user://saves/current_slot.json"
	var current_slot_file = FileAccess.open(current_slot_path, FileAccess.WRITE)
	if current_slot_file:
		current_slot_file.store_string(JSON.stringify({"current_slot": game_save_state["current_save_slot"]}))
		current_slot_file.close()
	
	print("GameState salvo (slot %d)" % save_slot)

func load_game_state():
	# Inicializar estruturas
	game_save_state = {
		"current_save_slot": 0,
		"save_slots": {}
	}
	
	# Carregar o slot atual
	var current_slot_path = "user://saves/current_slot.json"
	if FileAccess.file_exists(current_slot_path):
		var file = FileAccess.open(current_slot_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				game_save_state["current_save_slot"] = json.data.get("current_slot", 0)
			file.close()
	
	# Carregar todos os slots de save
	for i in range(MAX_SAVE_SLOTS):
		var file_path = "user://saves/save_slot_%d.json" % i
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json = JSON.new()
				var error = json.parse(file.get_as_text())
				if error == OK:
					game_save_state["save_slots"][i] = json.data
				file.close()
	
	print("Dados de jogo carregados")

func get_current_save_data() -> Dictionary:
	return game_save_state["save_slots"].get(game_save_state["current_save_slot"], {})

func set_current_save_data(data: Dictionary):
	game_save_state["save_slots"][game_save_state["current_save_slot"]] = data

func create_new_save(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		return false
	
	# Criar dados iniciais do save
	var new_save = {
		"timestamp": Time.get_datetime_string_from_system(),
		"chapter_id": "",
		"block_id": "",
		"player_stats": {},
		"flags": {},
		"inventory": []
	}
	
	game_save_state["save_slots"][slot_index] = new_save
	game_save_state["current_save_slot"] = slot_index
	save_game_state(slot_index)
	return true

func load_save(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		return false
	
	if not game_save_state["save_slots"].has(slot_index):
		return false
	
	game_save_state["current_save_slot"] = slot_index
	return true

func delete_save(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		return false
	
	if game_save_state["save_slots"].erase(slot_index):
		# Apagar também o arquivo físico
		var file_path = "user://saves/save_slot_%d.json" % slot_index
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		
		save_game_state()
		return true
	
	return false

func update_current_save(chapter_id: String, block_id: String):
	var current_save = get_current_save_data()
	current_save["chapter_id"] = chapter_id
	current_save["block_id"] = block_id
	current_save["timestamp"] = Time.get_datetime_string_from_system()
	set_current_save_data(current_save)
	save_game_state()

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
		
	# Para blocos de diálogo, avance para o próximo diálogo ou próximo bloco
	if current_block.type == "dialogue":
		current_dialogue_index += 1
		
		# Verificar se ainda há diálogos neste bloco
		if current_dialogue_index < current_block["dialogues"].size():
			emit_signal("dialogue_advanced", current_block_id, current_dialogue_index)
		else:
			# Próximo bloco
			current_dialogue_index = 0
			if current_block.has("next_block_id") and not current_block.next_block_id.is_empty():
				current_block_id = current_block.next_block_id
				emit_signal("dialogue_advanced", current_block_id, current_dialogue_index)
				_process_current_block()
			else:
				end_dialogue()
	else:
		# Comportamento original para outros tipos
		if current_block.has("next_block_id") and not current_block.next_block_id.is_empty():
			current_block_id = current_block.next_block_id
			emit_signal("dialogue_advanced", current_block_id, current_dialogue_index)
			_process_current_block()
		else:
			end_dialogue()

# Modifique _process_current_block para resetar o índice
func _process_current_block():
	if current_chapter_resource == null:
		return
		
	var block = current_chapter_resource.get_block(current_block_id)
	
	if block == null:
		end_dialogue()
		return
		
	# Resetar índice de diálogo ao entrar em novo bloco
	current_dialogue_index = 0
	
	# Executar ações do bloco
	for action in block.get("actions", []):
		_execute_action(action)
	
	# Avaliar condicionais
	var next_block = _evaluate_conditionals(block)
	if next_block:
		current_block_id = next_block
		_process_current_block()
		return
	
	match block.type:
		"dialogue":
			# Filtrar diálogos por condições
			var visible_dialogues = []
			for dialogue in block.get("dialogues", []):
				if _is_condition_met(dialogue.get("conditions", "")):
					visible_dialogues.append(dialogue)
			
			# Se não houver diálogos visíveis, avançar
			if visible_dialogues.size() == 0:
				advance_dialogue()
				return
		
		"choice":
			# Filtrar escolhas por condições
			var visible_choices = []
			for choice in block.get("choices", []):
				if _is_condition_met(choice.get("conditions", "")):
					visible_choices.append(choice)
			
			# Se não houver escolhas visíveis, avançar
			if visible_choices.size() == 0:
				advance_dialogue()
				return
			
			emit_signal("choice_presented", visible_choices)
		_:
			advance_dialogue()

# Novo método para verificar condições
func _is_condition_met(condition: String) -> bool:
	if condition.strip_edges().is_empty():
		return true  # Sem condição, sempre visível
	
	# Usar nosso sistema condicional existente
	return conditional_system.evaluate(condition)

func _execute_action(action: Dictionary):
	match action.get("type"):
		"set":
			game_state.set_variable(action["target"], action["value"])
		"modify":
			game_state.modify_variable(action["target"], action["value"])
		"call":
			var args = action.get("args", [])
			method_registry.execute_method(action["target"], args)

func _evaluate_conditionals(block: Dictionary) -> String:
	for conditional in block.get("conditionals", []):
		var result = conditional_system.evaluate(conditional["expression"])
		if result is bool and result:
			return conditional["target_block"]
		elif result is String:
			return result
	return ""

# Método para selecionar uma escolha
func select_choice(choice_index):
	if current_chapter_resource == null:
		return
		
	var block = current_chapter_resource.get_block(current_block_id)
	
	if block == null or block.type != "choice" or choice_index >= block.choices.size():
		return
		
	emit_signal("choice_selected", choice_index)
	
	 # Resetar o índice de diálogo ao mudar de bloco
	current_dialogue_index = 0
	
	# Atualiza o bloco atual e emite o sinal de avanço
	current_block_id = block.choices[choice_index].next_block_id

	_process_current_block()
	
	emit_signal("dialogue_advanced", current_block_id, current_dialogue_index)

func start_next_chapter():
	var chapter_id_to_use = ""
	
	# Se temos um capítulo atual, usar ele
	if current_chapter_resource:
		chapter_id_to_use = current_chapter_resource.chapter_id
	# Se não, usar o último capítulo concluído
	elif not last_completed_chapter_id.is_empty():
		chapter_id_to_use = last_completed_chapter_id
	else:
		print("Nenhum capítulo de referência disponível")
		return false
	
	var chapter_order = VisualNovelSingleton.get_chapter_order()
	var current_index = chapter_order.find(chapter_id_to_use)
	
	if current_index == -1:
		print("Capítulo de referência não encontrado na ordem: ", chapter_id_to_use)
		return false
	
	var next_index = current_index + 1
	if next_index >= chapter_order.size():
		print("Este é o último capítulo")
		return false
	
	var next_chapter_id = chapter_order[next_index]
	var next_chapter = VisualNovelSingleton.chapters.get(next_chapter_id)
	
	if not next_chapter:
		print("Próximo capítulo não encontrado: ", next_chapter_id)
		return false
	
	print("Iniciando próximo capítulo: ", next_chapter.chapter_name)
	start_chapter(next_chapter)
	return true

# Método para iniciar um capítulo específico pelo ID
func start_chapter_by_id(chapter_id: String) -> bool:
	# Verificar se o capítulo existe
	if not VisualNovelSingleton.chapters.has(chapter_id):
		push_error("Capítulo não encontrado: ", chapter_id)
		return false
	
	var chapter = VisualNovelSingleton.chapters[chapter_id]
	
	# Verificar se tem bloco inicial
	if chapter.start_block_id.is_empty():
		push_error("Capítulo não tem bloco inicial definido: ", chapter_id)
		return false
	
	# Verificar se o bloco inicial existe
	if not chapter.blocks.has(chapter.start_block_id):
		push_error("Bloco inicial não encontrado: ", chapter.start_block_id)
		return false
	
	start_chapter(chapter)
	return true

# Método para obter informações do capítulo atual
func get_current_chapter_info() -> Dictionary:
	var chapter_to_use = null
	var chapter_id_to_use = ""
	
	# Se temos um capítulo atual, usar ele
	if current_chapter_resource:
		chapter_to_use = current_chapter_resource
		chapter_id_to_use = current_chapter_resource.chapter_id
	# Se não, usar o último capítulo concluído
	elif not last_completed_chapter_id.is_empty():
		chapter_id_to_use = last_completed_chapter_id
		chapter_to_use = VisualNovelSingleton.chapters.get(chapter_id_to_use)
	
	if not chapter_to_use:
		return {}
	
	var chapter_order = VisualNovelSingleton.get_chapter_order()
	var current_index = chapter_order.find(chapter_id_to_use)
	
	return {
		"chapter_id": chapter_to_use.chapter_id,
		"chapter_name": chapter_to_use.chapter_name,
		"current_index": current_index,
		"total_chapters": chapter_order.size(),
		"is_last_chapter": current_index == chapter_order.size() - 1
	}

# Método para verificar se há próximo capítulo
func has_next_chapter() -> bool:
	var chapter_id_to_use = ""
	
	# Se temos um capítulo atual, usar ele
	if current_chapter_resource:
		chapter_id_to_use = current_chapter_resource.chapter_id
	# Se não, usar o último capítulo concluído
	elif not last_completed_chapter_id.is_empty():
		chapter_id_to_use = last_completed_chapter_id
	else:
		return false
	
	var chapter_order = VisualNovelSingleton.get_chapter_order()
	var current_index = chapter_order.find(chapter_id_to_use)
	
	return current_index != -1 and current_index < chapter_order.size() - 1

# Método para encerrar o diálogo atual
func end_dialogue():
	if current_chapter_resource:
		# Armazenar o ID do capítulo antes de limpar
		last_completed_chapter_id = current_chapter_resource.chapter_id
		emit_signal("dialogue_ended", current_chapter_resource.chapter_name)
		
		# Agora limpar as referências
		current_chapter_resource = null
		current_block_id = ""

# Método para definir o display de diálogo
func set_dialogue_display(display_node):
	dialogue_display = display_node
