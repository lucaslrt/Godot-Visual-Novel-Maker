@tool
extends Node

# Dicionário para armazenar os perfis carregados {character_id: CharacterProfile}
var _characters: Dictionary = {}

# Sinal para notificar quando novos personagens são carregados
signal characters_loaded

func _ready() -> void:
	if Engine.is_editor_hint():
		load_all_characters()

# Carrega todos os personagens da pasta assets/characters
func load_all_characters() -> void:
	_characters.clear()
	
	if not DirAccess.dir_exists_absolute("res://assets/characters/"):
		push_error("Pasta de personagens não encontrada")
		return
	
	var dir = DirAccess.open("res://assets/characters/")
	dir.list_dir_begin()
	
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			var profile_path = "res://assets/characters/%s/profile.tres" % folder
			if ResourceLoader.exists(profile_path):
				var profile = load(profile_path)
				if profile is CharacterProfile:
					_characters[profile.character_id] = profile
					_load_expressions(profile)
		
		folder = dir.get_next()
	
	emit_signal("characters_loaded")
	print("Carregados %d personagens" % _characters.size())

# Carrega as expressões de um personagem
func _load_expressions(profile: CharacterProfile) -> void:
	var expressions_dir = "res://assets/characters/%s/expressions/" % profile.character_id
	if DirAccess.dir_exists_absolute(expressions_dir):
		var dir = DirAccess.open(expressions_dir)
		dir.list_dir_begin()
		
		var file = dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.get_extension() in ["png", "jpg", "webp"]:
				var expression_name = file.get_basename()
				var texture_path = "%s%s" % [expressions_dir, file]
				profile.expressions[expression_name] = texture_path
			
			file = dir.get_next()

# Métodos de acesso
func get_character(character_id: String) -> CharacterProfile:
	return _characters.get(character_id)

func get_character_list() -> Array:
	return _characters.values()

func register_character(profile: CharacterProfile) -> void:
	if not profile.is_valid():
		push_error("Perfil de personagem inválido")
		return
	
	_characters[profile.character_id] = profile
	ResourceSaver.save(profile)
