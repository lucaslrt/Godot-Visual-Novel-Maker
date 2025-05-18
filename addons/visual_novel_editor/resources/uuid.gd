class_name UUID
extends RefCounted

static func v4() -> String:
	var uuid := PackedByteArray()
	uuid.resize(16)
	
	# Preenchimento aleatório
	for i in range(16):
		uuid[i] = randi() % 256
	
	# Ajuste de versão e variante
	uuid[6] = (uuid[6] & 0x0f) | 0x40
	uuid[8] = (uuid[8] & 0x3f) | 0x80
	
	# Conversão manual para hex string
	var parts := []
	parts.append(_bytes_to_hex(uuid.slice(0, 4)))
	parts.append(_bytes_to_hex(uuid.slice(4, 6)))
	parts.append(_bytes_to_hex(uuid.slice(6, 8)))
	parts.append(_bytes_to_hex(uuid.slice(8, 10)))
	parts.append(_bytes_to_hex(uuid.slice(10, 16)))
	
	return "%s-%s-%s-%s-%s" % parts

static func _bytes_to_hex(bytes: PackedByteArray) -> String:
	var hex := ""
	for byte in bytes:
		hex += "%02x" % byte
	return hex
