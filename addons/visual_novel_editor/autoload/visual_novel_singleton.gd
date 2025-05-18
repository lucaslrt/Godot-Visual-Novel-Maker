## autoload/visual_novel_singleton.gd
@tool
extends Node

# Lista de todos os capítulos disponíveis
var chapters = {}
# Lista de todos os personagens
var characters = {}
# Estado atual do jogo
var game_state = {}

var instance: VisualNovelSingleton

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	
	instance = self
	load_all_data()

func register_chapter(chapter: ChapterResource) -> void:
	if not Engine.is_editor_hint():
		return
	
	chapters[chapter.chapter_name] = chapter
	save_chapters()

func register_character(character: CharacterResource) -> void:
	if not Engine.is_editor_hint():
		return
	
	characters[character.character_id] = character
	save_characters()

func save_all_data():
	save_chapters()
	save_characters()
	save_game_state()

func load_all_data():
	load_chapters()
	load_characters()
	load_game_state()

func save_chapters():
	# Cria a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir("res://addons/visual_novel_editor/data")
	
	# Preparar os dados para salvar
	var save_data = {}
	for chapter_name in chapters:
		var chapter = chapters[chapter_name]
		
		# Converter o resource para um formato serializável
		var chapter_data = {
			"chapter_name": chapter.chapter_name,
			"chapter_description": chapter.chapter_description,
			"start_block_id": chapter.start_block_id,
			"blocks": chapter.blocks
		}
		
		save_data[chapter_name] = chapter_data
	
	# Salvar os dados em um arquivo JSON
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

func load_chapters():
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/chapters.json"):
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/chapters.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var chapters_data = json.get_data()
	
	# Limpar os capítulos existentes
	chapters.clear()
	
	# Criar objetos ChapterResource para cada capítulo carregado
	for chapter_name in chapters_data:
		var chapter_data = chapters_data[chapter_name]
		
		var chapter = ChapterResource.new()
		chapter.chapter_name = chapter_data["chapter_name"]
		chapter.chapter_description = chapter_data["chapter_description"]
		chapter.start_block_id = chapter_data["start_block_id"]
		chapter.blocks = chapter_data["blocks"]
		
		register_chapter(chapter)

func save_characters():
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir("res://addons/visual_novel_editor/data")
	
	# Preparar os dados para salvar
	var save_data = {}
	for character_id in characters:
		var character = characters[character_id]
		
		# Converter o resource para um formato serializável
		var character_data = {
			"character_id": character.character_id,
			"display_name": character.display_name,
			"description": character.description,
			"expressions": character.expressions
		}
		
		save_data[character_id] = character_data
	
	# Salvar os dados em um arquivo JSON
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open("res://addons/visual_novel_editor/data/characters.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

func load_characters():
	# Verificar se o arquivo existe
	if not FileAccess.file_exists("res://addons/visual_novel_editor/data/characters.json"):
		return
	
	# Carregar o arquivo JSON
	var file = FileAccess.open("res://addons/visual_novel_editor/data/characters.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var characters_data = json.get_data()
	
	# Limpar os personagens existentes
	characters.clear()
	
	# Criar objetos CharacterResource para cada personagem carregado
	for character_id in characters_data:
		var char_data = characters_data[character_id]
		
		var character = CharacterResource.new()
		character.character_id = char_data["character_id"]
		character.display_name = char_data["display_name"]
		character.description = char_data["description"]
		character.expressions = char_data["expressions"]
		
		register_character(character)

func save_game_state():
	# Criar a pasta se ela não existir
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://addons/visual_novel_editor/data"):
		dir.make_dir("res://addons/visual_novel_editor/data")
	
	# Salvar o estado atual do jogo
	var json_string = JSON.stringify(game_state)
	var file = FileAccess.open("res://addons/visual_novel_editor/data/game_state.json", FileAccess.WRITE)
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
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		game_state = {}
		return
	
	game_state = json.get_data()
