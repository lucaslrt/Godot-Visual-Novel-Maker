# event_bus.gd
@tool
extends Node

# Variável estática para armazenar a instância do editor
static var _editor_instance: Node = null
var _events: Dictionary = {}

## Obtém a instância correta (editor ou runtime)
static func get_instance() -> Node:
	if Engine.is_editor_hint():
		if not _editor_instance:
			_editor_instance = _create_editor_instance()
		return _editor_instance
	else:
		return Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else null

## Cria instância para o editor
static func _create_editor_instance() -> Node:
	var script = load("res://addons/visual_novel_editor/autoload/event_bus.gd")
	var instance = Node.new()
	instance.set_script(script)
	# Garante que a instância persista no editor
	instance.set_meta("_editor_instance", true)
	EditorInterface.get_base_control().add_child(instance)
	return instance

## Registra um evento
static func register_event(event_name: String) -> bool:
	var bus = get_instance()
	if not bus:
		push_error("EventBus não disponível")
		return false
	if not bus._events.has(event_name):
		bus._events[event_name] = Signal()
		print("Evento registrado: ", event_name)
	return true

## Emite um evento
static func emit(event_name: String, args: Array = []) -> bool:
	var bus = get_instance()
	if not bus or not bus._events.has(event_name):
		push_error("Evento não registrado: ", event_name)
		return false
	bus._events[event_name].emit(args)
	return true

## Conecta a um evento
static func connect_event(event_name: String, callable: Callable) -> bool:
	var bus = get_instance()
	if not bus or not bus._events.has(event_name):
		return false
	if not bus._events[event_name].is_connected(callable):
		bus._events[event_name].connect(callable)
	return true

## Desconecta de um evento
static func disconnect_event(event_name: String, callable: Callable) -> bool:
	var bus = get_instance()
	if not bus or not bus._events.has(event_name):
		return false
	if bus._events[event_name].is_connected(callable):
		bus._events[event_name].disconnect(callable)
	return true

func _notification(what):
	if what == NOTIFICATION_PREDELETE and Engine.is_editor_hint():
		_cleanup_editor_instance()

static func _cleanup_editor_instance():
	if _editor_instance:
		_editor_instance.queue_free()
		_editor_instance = null
