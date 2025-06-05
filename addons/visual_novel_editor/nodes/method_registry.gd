# method_registry.gd
class_name MethodRegistry
extends Node

var registered_methods = {}

func register_method(name: String, callable: Callable):
	registered_methods[name] = callable

func execute_method(name: String, args: Array = []):
	if registered_methods.has(name):
		return registered_methods[name].callv(args)
	push_error("Método não registrado: " + name)
	return null

func has_registered_method(name: String) -> bool:
	return registered_methods.has(name)
