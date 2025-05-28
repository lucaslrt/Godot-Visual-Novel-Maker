## resources/chapter_resource.gd
@tool
extends Resource
class_name ChapterResource


@export var chapter_id: String = ""  # ID único do capítulo
@export var chapter_name: String = "New Chapter"
@export var chapter_description: String = ""
@export var start_block_id: String = ""
@export var blocks: Dictionary = {}

func _init():
	# Gerar um UUID se não existir
	if chapter_id.is_empty():
		chapter_id = UUID.v4()

# Adicionar um novo bloco ao capítulo
func add_block(block_id, block_data):
	# Verificar duplicação
	if blocks.has(block_id):
		push_error("ID de bloco já existe: ", block_id)
		return null
	
	# Validar estrutura do bloco
	if not block_data.has("type"):
		push_error("Bloco sem tipo definido")
		return null
	
	# Inicializar next_block_id conforme o tipo
	match block_data["type"]:
		"start", "dialogue":
			if not block_data.has("next_block_id"):
				block_data["next_block_id"] = ""
		
		"choice":
			if not block_data.has("choices"):
				block_data["choices"] = []
			# Garantir que cada escolha tem next_block_id
			for choice in block_data["choices"]:
				if not choice.has("next_block_id"):
					choice["next_block_id"] = ""
	
	blocks[block_id] = block_data
	notify_property_list_changed()
	return block_id

func _parse_vector2_string(vector_str: String) -> Vector2:
	# Remove parênteses e espaços
	var cleaned = vector_str.replace("(", "").replace(")", "").replace(" ", "")
	var components = cleaned.split(",")
	if components.size() == 2:
		return Vector2(float(components[0]), float(components[1]))
	return Vector2.ZERO
	
func has_start_block():
	for block in blocks.values():
		if block["type"] == "start":
			return true
	return false

# Remover um bloco do capítulo
func remove_block(block_id: String):
	if blocks.has(block_id):
		# Verificar se este bloco é referenciado por outros
		var referenced_by = []
		
		for other_block_id in blocks:
			var other_block = blocks[other_block_id]
			
			match other_block["type"]:
				"start", "dialogue":
					if other_block.get("next_block_id", "") == block_id:
						referenced_by.append(other_block_id)
				
				"choice":
					for choice in other_block.get("choices", []):
						if choice.get("next_block_id", "") == block_id:
							referenced_by.append(other_block_id)
		
		# Se for referenciado, limpar as referências
		for ref_id in referenced_by:
			var ref_block = blocks[ref_id]
			
			match ref_block["type"]:
				"start", "dialogue":
					ref_block["next_block_id"] = ""
				
				"choice":
					for choice in ref_block.get("choices", []):
						if choice.get("next_block_id", "") == block_id:
							choice["next_block_id"] = ""
		
		# Remover o bloco
		blocks.erase(block_id)
		
		# Se era o bloco inicial, definir outro como inicial (se existir)
		if start_block_id == block_id and not blocks.is_empty():
			start_block_id = blocks.keys()[0]
		elif blocks.is_empty():
			start_block_id = ""
		
		notify_property_list_changed()

# Obter um bloco específico
func get_block(block_id):
	if blocks.has(block_id):
		return blocks[block_id]
	return null

# Atualizar um bloco existente
func update_block(block_id, new_data):
	if blocks.has(block_id):
		blocks[block_id] = new_data

# Definir o bloco inicial
func set_start_block(block_id):
	if blocks.has(block_id):
		start_block_id = block_id
