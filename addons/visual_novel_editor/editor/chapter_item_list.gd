@tool
extends ItemList
class_name ChapterItemList

# Referência ao singleton
var visual_novel_singleton: VisualNovelSingleton

# Variáveis para controle do drag and drop
var dragging_item_index: int = -1
var dragging_item_text: String = ""
var dragging_item_icon: Texture2D = null
var dragging_item_metadata = null

func _ready():
	# Configurar o ItemList para permitir drag and drop
	set_drag_forwarding(_forward_drag, _can_drop_data, _drop_data)
	
	# Obter referência ao singleton
	visual_novel_singleton = get_node_or_null("/root/VisualNovelSingleton")
	if not visual_novel_singleton:
		push_error("VisualNovelSingleton não encontrado!")
		return
	
	# Carregar capítulos inicialmente
	refresh_chapters()

func _forward_drag(at_position: Vector2):
	# Retorna os dados que serão arrastados
	var item_index = get_item_at_position(at_position)
	if item_index != -1:
		dragging_item_index = item_index
		dragging_item_text = get_item_text(item_index)
		dragging_item_icon = get_item_icon(item_index)
		dragging_item_metadata = get_item_metadata(item_index)
		return {
			"type": "chapter_item",
			"index": item_index,
			"text": dragging_item_text,
			"icon": dragging_item_icon,
			"metadata": dragging_item_metadata
		}
	return null

func _can_drop_data(at_position: Vector2, data) -> bool:
	# Verifica se o item pode ser solto na posição
	return data != null and data.has("type") and data["type"] == "chapter_item"

func _drop_data(at_position: Vector2, data):
	# Obtém o índice onde o item será solto
	var drop_index = get_item_at_position(at_position)
	if drop_index == -1:
		drop_index = item_count  # Soltar no final se não estiver sobre um item
	
	# Se estiver arrastando para a mesma posição, não faz nada
	if dragging_item_index == drop_index or (dragging_item_index + 1) == drop_index:
		return
	
	# Remove o item da posição original
	var item_text = get_item_text(dragging_item_index)
	var item_icon = get_item_icon(dragging_item_index)
	var item_metadata = get_item_metadata(dragging_item_index)
	
	remove_item(dragging_item_index)
	
	# Ajusta o drop_index se o item removido estava antes da posição de soltar
	if dragging_item_index < drop_index:
		drop_index -= 1
	
	# Adiciona o item na nova posição
	add_item(item_text, item_icon)
	set_item_metadata(item_count - 1, item_metadata)
	
	# Move o item para a posição correta (Godot 4 não tem insert_item, então precisamos rearranjar)
	for i in range(item_count - 1, drop_index, -1):
		swap_items(i, i - 1)
	
	# Atualiza a ordem no singleton
	update_chapter_order()
	
	# Seleciona o item movido
	select(drop_index)
	ensure_current_is_visible()

func swap_items(index1: int, index2: int):
	# Troca dois itens de posição
	var text1 = get_item_text(index1)
	var icon1 = get_item_icon(index1)
	var meta1 = get_item_metadata(index1)
	
	var text2 = get_item_text(index2)
	var icon2 = get_item_icon(index2)
	var meta2 = get_item_metadata(index2)
	
	set_item_text(index1, text2)
	set_item_icon(index1, icon2)
	set_item_metadata(index1, meta2)
	
	set_item_text(index2, text1)
	set_item_icon(index2, icon1)
	set_item_metadata(index2, meta1)

func update_chapter_order():
	if not visual_novel_singleton:
		return
	
	var new_order = []
	for i in range(item_count):
		var chapter_name = get_item_text(i)
		var chapter_id = find_chapter_id_by_name(chapter_name)
		if not chapter_id.is_empty():
			new_order.append(chapter_id)
	
	visual_novel_singleton.set_chapter_order(new_order)

func refresh_chapters():
	clear()
	
	if not visual_novel_singleton or not visual_novel_singleton.chapters:
		return
	
	# Garantir que chapter_order está inicializado
	if visual_novel_singleton.chapter_order == null:
		visual_novel_singleton.chapter_order = visual_novel_singleton.chapters.keys()
	
	for chapter_id in visual_novel_singleton.chapter_order:
		if visual_novel_singleton.chapters.has(chapter_id):
			var chapter = visual_novel_singleton.chapters[chapter_id]
			add_item(chapter.chapter_name)
			set_item_metadata(item_count - 1, chapter_id)
	
	# Resetar estado de arrasto
	dragging_item_index = -1

func find_chapter_id_by_name(chapter_name: String) -> String:
	if not visual_novel_singleton:
		return ""
	
	for chapter_id in visual_novel_singleton.chapters:
		var chapter = visual_novel_singleton.chapters[chapter_id]
		if chapter.chapter_name == chapter_name:
			return chapter_id
	return ""
