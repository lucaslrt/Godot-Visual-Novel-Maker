@tool
extends EditorPlugin

const VisualNovelManager = preload("uid://d4gfbjfvb4ex8")
const VisualNovelEditorScene = preload("uid://b785ufb0f238e")

var visual_novel_editor_instance

func _enter_tree():
	# Configurar o EventBus primeiro
	if Engine.is_editor_hint():
		# Cria instância manual para o editor
		EventBus.get_instance()
	
	# Registrar autoloads (só no jogo)
	add_autoload_singleton("VisualNovelSingleton", "res://addons/visual_novel_editor/autoload/visual_novel_singleton.gd")
	
	# Esperar inicialização
	await get_tree().process_frame
	
	# Registrar tipos
	add_custom_type("VisualNovelManager", "Node", VisualNovelManager, null)
	
	# Criar editor
	visual_novel_editor_instance = VisualNovelEditorScene.instantiate()
	add_control_to_bottom_panel(visual_novel_editor_instance, "Visual Novel")
	
	# Registrar eventos após tudo estar pronto
	EventBus.register_event("_update_chapter_editor")
	EventBus.register_event("update_block_editor")

func _exit_tree():
	# Limpeza
	remove_custom_type("VisualNovelManager")
	if visual_novel_editor_instance:
		remove_control_from_bottom_panel(visual_novel_editor_instance)
		visual_novel_editor_instance.queue_free()
	
	# Não remova o EventBus no editor para evitar problemas
	if not Engine.is_editor_hint():
		remove_autoload_singleton("VisualNovelSingleton")
