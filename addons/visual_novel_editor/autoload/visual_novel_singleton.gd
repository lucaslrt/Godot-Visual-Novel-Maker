@tool
extends Node

signal characters_updated

# Lista de todos os capítulos disponíveis
var chapters = {}
# Lista de todos os personagens
var characters = {}

var chapter_order = []  # Array com os IDs dos capítulos na ordem desejada

# Singleton instance (não necessário em autoload, mas pode ser útil)
var instance: VisualNovelSingleton

func _enter_tree():
	print("VisualNovelSingleton: _enter_tree chamado")
	instance = self
	
	# Sempre carregar dados, independente do contexto
	call_deferred("load_all_data")

func _ready():
	print("VisualNovelSingleton: _ready chamado")
	print("Engine.is_editor_hint(): ", Engine.is_editor_hint())

func register_chapter(chapter: ChapterResource) -> void:
	if not chapter:
		push_error("Tentativa de registrar capítulo nulo!")
		return
	
	if chapters == null:
		chapters = {}
	
	print("Registrando capítulo: ", chapter.chapter_name)
	chapters[chapter.chapter_id] = chapter  # Usando ID como chave
	
	if chapter_order == null:
		chapter_order = []
	
	# Adicionar à ordem se não existir
	if not chapter_order.has(chapter.chapter_id):
		chapter_order.push_back(chapter.chapter_id)
	
	# Salvar automaticamente apenas se estivermos no editor
	if Engine.is_editor_hint():
		save_chapters()
		_save_chapter_order()

func register_character(character: CharacterResource) -> void:
	if not character:
		push_error("Tentativa de registrar personagem nulo!")
		return
	
	characters[character.character_id] = character
	characters_updated.emit()
	
	# Salvar automaticamente apenas se estivermos no editor
	if Engine.is_editor_hint():
		save_characters()

func save_all_data():
	save_chapters()
	save_characters()
	_save_chapter_order()

func load_all_data():
	print("Carregando todos os dados...")
	load_chapters()
	load_characters()
	_load_chapter_order()
	print("Dados carregados. Capítulos: ", chapters.size(), " Personagens: ", characters.size())

func save_chapters():
	print("Salvando capítulos no formato Flowchart...")
	
	# Cria a pasta se não existir
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://addons/visual_novel_editor/data/flowcharts"):
		dir.make_dir_recursive("res://addons/visual_novel_editor/data/flowcharts")
	
	for chapter_id in chapters:
		var chapter = chapters[chapter_id]
		if not chapter:
			continue
		
		var flowchart_content = _convert_chapter_to_flowchart(chapter)
		var file_path = "res://addons/visual_novel_editor/data/flowcharts/%s.flowchart" % chapter_id
		
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(flowchart_content)
		file.close()
	
	print("Capítulos salvos no formato Flowchart!")

func _convert_chapter_to_flowchart(chapter: ChapterResource) -> String:
	var flowchart = "flowchart TD\n"
	var node_definitions = []
	var connections = []
	
	# Metadados
	flowchart += "    %%% Título: %s\n" % chapter.chapter_name
	flowchart += "    %%% ID: %s\n" % chapter.chapter_id
	flowchart += "    %%% Início: %s\n\n" % chapter.start_block_id
	
	# Processar blocos
	for block_id in chapter.blocks:
		var block = chapter.blocks[block_id]
		var node_def = ""
		
		match block.get("type"):
			"start":
				node_def = '    %s(("Início"))' % block_id
				if block.has("next_block_id") and block.next_block_id:
					connections.append('    %s --> %s' % [block_id, block.next_block_id])
			
			"end":
				node_def = '    %s(("Fim"))' % block_id
			
			"dialogue", "text":
				var content = "Diálogo\n"
				if block.has("dialogues"):
					for dialogue in block["dialogues"]:
						var line = "      - %s" % dialogue.get("character_name", "???")
						if dialogue.get("character_expression", ""):
							line += ":%s" % dialogue.character_expression
						line += ": %s" % dialogue.get("text", "")
						content += line + "\n"
				else:
					content += "      " + block.get("text", "").replace("\n", "\n      ")
				
				node_def = '    %s["%s"]' % [block_id, content.strip_edges()]
			
			"choice":
				var content = "Escolha\n"
				if block.has("choices"):
					for i in range(block.choices.size()):
						content += "      %d. %s\n" % [i+1, block.choices[i].get("text", "")]
				
				node_def = '    %s{"%s"}' % [block_id, content.strip_edges()]
		
		node_definitions.append(node_def)
	
	# Adicionar conexões
	for block_id in chapter.blocks:
		var block = chapter.blocks[block_id]
		
		if block.get("type") == "choice" and block.has("choices"):
			for i in range(block.choices.size()):
				var choice = block.choices[i]
				if choice.get("next_block_id", ""):
					connections.append('    %s -->|%d| %s' % [block_id, i+1, choice.next_block_id])
		elif block.has("next_block_id") and block.next_block_id:
			connections.append('    %s --> %s' % [block_id, block.next_block_id])
	
	# Combinar tudo
	flowchart += "\n".join(node_definitions) + "\n\n"
	flowchart += "\n".join(connections)
	
	return flowchart

func import_flowchart(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Falha ao abrir arquivo: " + file_path)
		return
	
	var content = file.get_as_text()
	var parsed = FlowchartParser.parse_flowchart(content)
	
	var chapter = ChapterResource.new()
	chapter.chapter_id = parsed.id
	chapter.chapter_name = parsed.title
	chapter.start_block_id = parsed.start_block
	
	for block_id in parsed.blocks:
		var block_data = parsed.blocks[block_id]
		var block = {"type": block_data.type}
		
		match block_data.type:
			"dialogue":
				block["dialogues"] = []
				for dialogue in block_data.content.split("\\n"):
					if dialogue.begins_with("-"):
						var parts = dialogue.substr(1).split(":", false, 2)
						var char_name = ""
						var expression = ""
						var text = ""
						
						if parts.size() == 2:
							char_name = parts[0].strip_edges()
							text = parts[1].strip_edges()
						elif parts.size() == 3:
							char_name = parts[0].strip_edges()
							expression = parts[1].strip_edges()
							text = parts[2].strip_edges()
						
						if char_name != "":
							block["dialogues"].append({
								"character_name": char_name,
								"character_expression": expression,
								"text": text
							})
			
			"choice":
				block["choices"] = []
				for choice in block_data.choices:
					block["choices"].append({
						"text": choice.text,
						"next_block_id": choice.next
					})
		
		chapter.blocks[block_id] = block
	
	# Adicionar conexões
	for connection in parsed.connections:
		var from_block = chapter.blocks.get(connection.from)
		if from_block:
			match from_block["type"]:
				"dialogue", "start":
					from_block["next_block_id"] = connection.to
				
				"choice":
					for choice in from_block.get("choices", []):
						if choice["text"] == connection.label:
							choice["next_block_id"] = connection.to
	
	chapters[chapter.chapter_id] = chapter
	save_chapters()
	print("Flowchart importado com sucesso!")

func _load_chapter_order():
	# Carregar chapter_order do .tres
	var chapter_order_path = "res://addons/visual_novel_editor/data/chapter_order.tres"
	
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir_recursive("res://addons/visual_novel_editor/data")
	
	if ResourceLoader.exists(chapter_order_path):
		var chapter_order_res = load(chapter_order_path) as ChapterOrderResource
		if chapter_order_res:
			chapter_order = chapter_order_res.chapter_order
		else:
			push_error("Falha ao carregar chapter_order.tres")
			# Criar novo se falhar ao carregar
			chapter_order = chapters.keys()
			_save_chapter_order()
	else:
		print("Nenhum arquivo chapter_order.tres encontrado, criando novo...")
		# Se não existe arquivo, inicializar chapter_order com os capítulos existentes
		chapter_order = chapters.keys()
		_save_chapter_order()  # Salvar a nova ordem

func _save_chapter_order():
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir:
		push_error("Não foi possível acessar o diretório res://")
		return
		
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		var error = dir.make_dir_recursive("res://addons/visual_novel_editor/data")
		if error != OK:
			push_error("Erro ao criar diretório: " + str(error))
			return
	
	# Salvar chapter_order como .tres
	var chapter_order_path = "res://addons/visual_novel_editor/data/chapter_order.tres"
	var chapter_order_res = ChapterOrderResource.new()
	chapter_order_res.chapter_order = chapter_order.duplicate()  # Usar duplicata para evitar referência
	
	var error = ResourceSaver.save(chapter_order_res, chapter_order_path)
	if error != OK:
		push_error("Erro ao salvar chapter_order.tres: " + str(error))
	else:
		print("ChapterOrder salvo como .tres")

func _serialize_blocks(blocks):
	var serialized = {}
	for block_id in blocks:
		var block = blocks[block_id].duplicate()
		# Converter Vector2 para formato serializável
		if block.has("graph_position"):
			block["graph_position"] = {"x": block["graph_position"].x, "y": block["graph_position"].y}
		serialized[block_id] = block
	return serialized

func load_chapters():
	print("Carregando capítulos...")
	
	# Limpar os capítulos existentes
	chapters.clear()
	
	# Carregar dos arquivos .tres
	var chapters_dir = "res://addons/visual_novel_editor/data/chapters/"
	var dir = DirAccess.open(chapters_dir)
	
	if not dir:
		print("Pasta de capítulos não encontrada: ", chapters_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = chapters_dir + file_name
			var chapter = load(file_path) as ChapterResource
			
			if chapter:
				print("Carregando capítulo .tres: ", chapter.chapter_name)
				chapters[chapter.chapter_id] = chapter  # Usar ID como chave
			else:
				print("Erro ao carregar: ", file_path)
		
		file_name = dir.get_next()
	
	_load_chapter_order()
	print("Capítulos carregados com sucesso! Total: ", chapters.size())

func save_characters():
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir:
		push_error("Não foi possível acessar o diretório res://")
		return
		
	if not dir.dir_exists("res://addons/visual_novel_editor/data/characters"):
		var error = dir.make_dir_recursive("res://addons/visual_novel_editor/data/characters")
		if error != OK:
			push_error("Erro ao criar diretório: " + str(error))
			return
	
	# Salvar cada personagem como um arquivo .tres separado
	for character_id in characters:
		var character = characters[character_id]
		if not character:
			continue
		
		# Garantir que o character_id está definido
		if character.character_id.is_empty():
			character.character_id = character_id
		
		# Definir o caminho do recurso
		var file_path = "res://addons/visual_novel_editor/data/characters/%s.tres" % character.character_id
		
		# Salvar o recurso
		var error = ResourceSaver.save(character, file_path)
		if error != OK:
			push_error("Erro ao salvar personagem %s: %s" % [character_id, error])
		else:
			print("Personagem salvo: ", file_path)
			
	characters_updated.emit()

func set_chapter_order(new_order: Array):
	chapter_order = new_order
	
	_save_chapter_order()

func get_chapter_order() -> Array:
	if chapter_order == null:
		chapter_order = chapters.keys() if chapters != null else []
	return chapter_order.duplicate()

func move_chapter_in_order(chapter_id: String, new_index: int):
	if chapter_order.has(chapter_id):
		chapter_order.erase(chapter_id)
		chapter_order.insert(new_index, chapter_id)
		_save_chapter_order()

func load_characters():
	# Limpar os personagens existentes
	characters.clear()
	
	# Verificar se o diretório existe
	var dir = DirAccess.open("res://addons/visual_novel_editor/data/characters/")
	if not dir:
		print("Diretório de personagens não encontrado")
		return
	
	# Listar todos os arquivos .tres no diretório
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = "res://addons/visual_novel_editor/data/characters/" + file_name
			
			# Carregar o recurso
			var character = load(file_path) as CharacterResource
			if character:
				# Usar o nome do arquivo como ID se o character_id estiver vazio
				if character.character_id.is_empty():
					character.character_id = file_name.get_basename()
				
				characters[character.character_id] = character
				print("Personagem carregado: ", character.display_name)
			else:
				push_error("Falha ao carregar personagem: " + file_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func import_script(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Falha ao abrir arquivo: " + file_path)
		return
	
	var content = file.get_as_text()
	var parsed = ScriptParser.parse_script(content)
	
	var chapter = ChapterResource.new()
	chapter.chapter_id = parsed.id
	chapter.chapter_name = parsed.title
	chapter.start_block_id = parsed.start_block
	
	for block_id in parsed.blocks:
		var block_data = parsed.blocks[block_id]
		var block = {
			"type": "text",
			"text": block_data.text
		}
		
		if block_data.choices.size() > 0:
			block["type"] = "choice"
			block["choices"] = []
			for choice in block_data.choices:
				block["choices"].append({
					"text": choice.text,
					"next_block_id": choice.next
				})
		else:
			block["next_block_id"] = block_data.next
		
		chapter.blocks[block_id] = block
	
	chapters[chapter.chapter_id] = chapter
	save_chapters()
	print("Roteiro importado com sucesso!")

func create_test_chapters():
	print("Criando capítulos de teste...")
	
	for i in range(1, 4):
		var chapter = ChapterResource.new()
		chapter.chapter_name = "Capítulo de Teste " + str(i)
		chapter.chapter_description = "Descrição do capítulo de teste " + str(i)
		
		# Adicionar um bloco start básico
		var start_id = "start_test_" + str(i)
		chapter.blocks[start_id] = {
			"type": "start",
			"graph_position": Vector2(100, 100)
		}
		chapter.start_block_id = start_id
		
		chapters[chapter.chapter_name] = chapter
	
	print("Capítulos de teste criados. Total: ", chapters.size())

# Função para debug
func debug_info():
	print("=== VisualNovelSingleton Debug ===")
	print("Chapters: ", chapters.size())
	for name in chapters:
		print("  - ", name)
	print("Characters: ", characters.size())
	print("======================================")
