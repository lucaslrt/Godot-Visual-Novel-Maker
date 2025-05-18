## plugin.gd
@tool
extends EditorPlugin

const VisualNovelManager = preload("uid://d4gfbjfvb4ex8")
const VisualNovelEditorScene = preload("uid://b785ufb0f238e")

var visual_novel_editor_instance

func _enter_tree():
	# Carregar o singleton primeiro
	add_autoload_singleton("VisualNovelSingleton", "res://addons/visual_novel_editor/autoload/visual_novel_singleton.gd")
	
	# Esperar um frame para garantir que o singleton foi carregado
	await get_tree().process_frame
	
	# Registrar os tipos customizados
	add_custom_type("VisualNovelManager", "Node", VisualNovelManager, null)
	
	# Criar a instância do editor
	visual_novel_editor_instance = VisualNovelEditorScene.instantiate()
	add_control_to_bottom_panel(visual_novel_editor_instance, "Visual Novel")

func _exit_tree():
	# Remover autoload
	remove_autoload_singleton("VisualNovelSingleton")
	# Remover tipos customizados
	remove_custom_type("VisualNovelManager")
	
	# Remover o editor
	if visual_novel_editor_instance:
		remove_control_from_bottom_panel(visual_novel_editor_instance)
		visual_novel_editor_instance.queue_free()
