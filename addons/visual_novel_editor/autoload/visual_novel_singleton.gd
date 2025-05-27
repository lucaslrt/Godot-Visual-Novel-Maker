@tool
extends Node

# Lista de todos os capítulos disponíveis
var chapters = {}
# Lista de todos os personagens
var characters = {}
# Estado atual do jogo
var game_state = {}

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
	
	print("Registrando capítulo: ", chapter.chapter_name)
	chapters[chapter.chapter_id] = chapter  # Usando ID como chave
	
	# Salvar automaticamente apenas se estivermos no editor
	if Engine.is_editor_hint():
		save_chapters()

func register_character(character: CharacterResource) -> void:
	if not character:
		push_error("Tentativa de registrar personagem nulo!")
		return
	
	characters[character.character_id] = character
	
	# Salvar automaticamente apenas se estivermos no editor
	if Engine.is_editor_hint():
		save_characters()

func save_all_data():
	save_chapters()
	save_characters()
	save_game_state()

func load_all_data():
	print("Carregando todos os dados...")
	load_chapters()
	load_characters()
	load_game_state()
	print("Dados carregados. Capítulos: ", chapters.size(), " Personagens: ", characters.size())

func save_chapters():
	print("Salvando capítulos no formato VNScript...")
	
	# Cria a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir:
		push_error("Não foi possível acessar o diretório res://")
		return
		
	if not dir.dir_exists("res://addons/visual_novel_editor/data/scripts"):
		var error = dir.make_dir_recursive("res://addons/visual_novel_editor/data/scripts")
		if error != OK:
			push_error("Erro ao criar diretório: " + str(error))
			return
	
	# Salvar cada capítulo em um arquivo .vnscript separado
	for chapter_id in chapters:
		var chapter = chapters[chapter_id]
		if not chapter:
			continue
		
		var script_content = _convert_chapter_to_script(chapter)
		var file_path = "res://addons/visual_novel_editor/data/scripts/%s.vnscript" % chapter_id
		
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			push_error("Erro ao abrir arquivo para escrita: " + file_path)
			continue
		
		file.store_string(script_content)
		file.close()
		print("Capítulo salvo: ", file_path)
	
	print("Todos os capítulos foram salvos no formato VNScript!")

func _convert_chapter_to_script(chapter: ChapterResource) -> String:
	var script = "---\n"
	script += "title: %s\n" % chapter.chapter_name
	script += "id: %s\n" % chapter.chapter_id
	script += "start: %s\n" % chapter.start_block_id
	
	# Adicionar descrição se existir
	if not chapter.chapter_description.is_empty():
		script += "description: %s\n" % chapter.chapter_description
	
	script += "---\n\n"
	
	# Processar cada bloco
	for block_id in chapter.blocks:
		var block = chapter.blocks[block_id]
		
		# Cabeçalho do bloco
		script += ":: %s\n" % block_id
		
		# Processar conteúdo baseado no tipo
		match block.get("type", "text"):
			"text", "dialogue":
				if block.has("text"):
					script += block.text + "\n"
				
				if block.has("next_block_id") and not block.next_block_id.is_empty():
					script += "-> Continuar |> %s\n" % block.next_block_id
			
			"choice":
				if block.has("choices"):
					for choice in block.choices:
						var next = choice.get("next_block_id", "")
						script += "-> %s" % choice.text
						if not next.is_empty():
							script += " |> %s" % next
						script += "\n"
			
			"start":
				if block.has("next_block_id") and not block.next_block_id.is_empty():
					script += "-> Iniciar |> %s\n" % block.next_block_id
			
			"end":
				script += "(Fim do capítulo)\n"
		
		script += "\n"  # Espaço entre blocos
	
	return script

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
	
	print("Capítulos carregados com sucesso! Total: ", chapters.size())

func save_characters():
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
	
	# Preparar os dados para salvar
	var save_data = {}
	for character_id in characters:
		var character = characters[character_id]
		
		if not character:
			continue
		
		# Converter o resource para um formato serializável
		var character_data = {
			"character_id": character.character_id,
			"display_name": character.display_name,
			"description": character.description,
			"expressions": character.expressions
		}
		
		save_data[character_id] = character_data
	
	# Salvar os dados em um arquivo JSON
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open("res://addons/visual_novel_editor/data/characters.json", FileAccess.WRITE)
	
	if not file:
		push_error("Erro ao abrir arquivo para escrita: characters.json")
		return
	
	file.store_string(json_string)
	file.close()

func load_characters():
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/characters.json"):
		print("Arquivo de personagens não encontrado")
		characters = {}
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/characters.json", FileAccess.READ)
	if not file:
		push_error("Erro ao abrir arquivo de personagens para leitura")
		characters = {}
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		characters = {}
		return
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Erro ao analisar JSON de personagens: " + json.get_error_message() + " na linha " + str(json.get_error_line()))
		characters = {}
		return
	
	var characters_data = json.get_data()
	if not characters_data is Dictionary:
		push_error("Dados de personagens inválidos")
		characters = {}
		return
	
	# Limpar os personagens existentes
	characters.clear()
	
	# Criar objetos CharacterResource para cada personagem carregado
	for character_id in characters_data:
		var char_data = characters_data[character_id]
		
		var character = CharacterResource.new()
		character.character_id = char_data.get("character_id", "")
		character.display_name = char_data.get("display_name", "")
		character.description = char_data.get("description", "")
		character.expressions = char_data.get("expressions", {})
		
		characters[character_id] = character

func save_game_state():
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir:
		return
		
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir_recursive("res://addons/visual_novel_editor/data")
	
	# Salvar o estado atual do jogo
	var json_string = JSON.stringify(game_state, "\t")
	var file = FileAccess.open("res://addons/visual_novel_editor/data/game_state.json", FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()

func load_game_state():
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/game_state.json"):
		# Se não existir, iniciar com estado vazio
		game_state = {}
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/game_state.json", FileAccess.READ)
	if not file:
		game_state = {}
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		game_state = {}
		return
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Erro ao analisar JSON do estado do jogo: " + json.get_error_message())
		game_state = {}
		return
	
	var data = json.get_data()
	if data is Dictionary:
		game_state = data
	else:
		game_state = {}

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

# ADICIONADO: Função para criar capítulos de teste (útil para debug)
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
