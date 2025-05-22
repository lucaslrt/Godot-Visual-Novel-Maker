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
	chapters[chapter.chapter_name] = chapter
	
	# CORRIGIDO: Debug adicional
	print("Total de capítulos após registro: ", chapters.size())
	print("Chaves no dicionário: ", chapters.keys())
	
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
	print("Salvando capítulos...")
	
	# Cria a pasta se ela não existir
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
	for chapter_name in chapters:
		var chapter = chapters[chapter_name]
		
		if not chapter:
			continue
		
		# Converter o resource para um formato serializável
		var chapter_data = {
			"chapter_name": chapter.chapter_name,
			"chapter_description": chapter.chapter_description,
			"start_block_id": chapter.start_block_id,
			"blocks": chapter.blocks
		}
		
		save_data[chapter_name] = chapter_data
	
	# Salvar os dados em um arquivo JSON
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.WRITE)
	
	if not file:
		push_error("Erro ao abrir arquivo para escrita: chapters.json")
		return
	
	file.store_string(json_string)
	file.close()
	
	print("Capítulos salvos com sucesso! Total: ", save_data.size())

func load_chapters():
	print("Carregando capítulos...")
	
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/chapters.json"):
		print("Arquivo de capítulos não encontrado. Iniciando com lista vazia.")
		# CORRIGIDO: Inicializar com dicionário vazio ao invés de retornar
		chapters = {}
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.READ)
	if not file:
		push_error("Erro ao abrir arquivo de capítulos para leitura")
		chapters = {}
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		print("Arquivo de capítulos está vazio")
		chapters = {}
		return
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Erro ao analisar JSON: " + json.get_error_message() + " na linha " + str(json.get_error_line()))
		chapters = {}
		return
	
	var chapters_data = json.get_data()
	if not chapters_data is Dictionary:
		push_error("Dados de capítulos inválidos")
		chapters = {}
		return
	
	# Limpar os capítulos existentes
	chapters.clear()
	
	# Criar objetos ChapterResource para cada capítulo carregado
	for chapter_name in chapters_data:
		var chapter_data = chapters_data[chapter_name]
		
		var chapter = ChapterResource.new()
		chapter.chapter_name = chapter_data.get("chapter_name", "")
		chapter.chapter_description = chapter_data.get("chapter_description", "")
		chapter.start_block_id = chapter_data.get("start_block_id", "")
		chapter.blocks = chapter_data.get("blocks", {})
		
		chapters[chapter_name] = chapter
		
	print("Capítulos carregados com sucesso! Total: ", chapters.size())
	# ADICIONADO: Debug das chaves carregadas
	print("Chaves carregadas: ", chapters.keys())

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
