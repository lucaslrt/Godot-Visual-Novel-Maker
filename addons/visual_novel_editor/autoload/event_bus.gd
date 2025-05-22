# event_bus.gd
@tool
extends Node

# Variável estática para armazenar a instância do editor
static var _editor_instance: Node = null
var _events: Dictionary = {}

## Obtém a instância correta (editor ou runtime)
static func get_instance() -> Node:
	if Engine.is_editor_hint():
		if not _editor_instance or not is_instance_valid(_editor_instance):
			_editor_instance = _create_editor_instance()
		return _editor_instance
	else:
		return Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else null

## Cria instância para o editor
static func _create_editor_instance() -> Node:
	var script = load("res://addons/visual_novel_editor/autoload/event_bus.gd")
	var instance = Node.new()
	instance.set_script(script)
	
	# Em vez de adicionar ao EditorInterface, criar um nó persistente
	instance.name = "EventBusEditor"
	
	# Marcar como persistente no editor
	if Engine.is_editor_hint():
		instance.set_meta("_editor_tool", true)
	
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
		
	# Verificar se o sinal existe antes de emitir
	if bus._events[event_name]:
		bus._events[event_name].emit(args)
	return true

## Conecta a um evento
static func connect_event(event_name: String, callable: Callable) -> bool:
	var bus = get_instance()
	if not bus or not bus._events.has(event_name):
		return false
		
	# Verificar se o callable é válido
	if not callable.is_valid():
		push_warning("Callable inválido para evento: " + event_name)
		return false
		
	var signal_obj = bus._events[event_name]
	if signal_obj and not signal_obj.is_connected(callable):
		signal_obj.connect(callable)
		return true
	return false

## Desconecta de um evento
static func disconnect_event(event_name: String, callable: Callable) -> bool:
	var bus = get_instance()
	if not bus or not bus._events.has(event_name):
		return false
		
	var signal_obj = bus._events[event_name]
	if signal_obj and callable.is_valid() and signal_obj.is_connected(callable):
		signal_obj.disconnect(callable)
		return true
	return false

func _notification(what):
	if what == NOTIFICATION_PREDELETE and Engine.is_editor_hint():
		_cleanup_editor_instance()

static func _cleanup_editor_instance():
	if _editor_instance and is_instance_valid(_editor_instance):
		_editor_instance.queue_free()
		_editor_instance = null
