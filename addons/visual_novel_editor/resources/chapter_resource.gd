## resources/chapter_resource.gd
@tool
extends Resource
class_name ChapterResource

@export var chapter_name: String = "New Chapter"
@export var chapter_description: String = ""
@export var start_block_id: String = ""
@export var blocks: Dictionary = {}

# Adicionar um novo bloco ao capítulo
func add_block(block_id, block_data):
	blocks[block_id] = block_data
	
	# Se este for o primeiro bloco, defina-o como bloco inicial
	if blocks.size() == 1:
		start_block_id = block_id
	
	return block_id

# Remover um bloco do capítulo
func remove_block(block_id):
	if blocks.has(block_id):
		blocks.erase(block_id)
		
		# Se removemos o bloco inicial, definir outro como inicial (se existir)
		if start_block_id == block_id and not blocks.is_empty():
			start_block_id = blocks.keys()[0]
		elif blocks.is_empty():
			start_block_id = ""

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
