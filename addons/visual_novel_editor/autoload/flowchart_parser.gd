class_name FlowchartParser

static func parse_flowchart(content: String) -> Dictionary:
	var result = {
		"title": "Sem Título",
		"id": UUID.v4(),
		"start_block": "",
		"blocks": {},
		"connections": []
	}
	
	var lines = content.split("\n")
	var current_block = null
	var current_block_id = ""  # Declaramos a variável aqui, no escopo correto
	
	for line in lines:
		line = line.strip_edges()
		
		# Ignorar linhas vazias e comentários
		if line.is_empty() or line.begins_with("%%"):
			continue
		
		# Detectar blocos
		if "(" in line or "[" in line or "{" in line:
			var parts = []
			if "[" in line:
				parts = line.split("[", false, 1)
				current_block_id = parts[0].strip_edges()  # Atribuímos à variável já declarada
				var content_part = parts[1].split("]", false, 1)[0]
				
				current_block = {
					"type": "dialogue",
					"dialogues": _parse_dialogue_content(content_part)
				}
			
			elif "(" in line:
				parts = line.split("(", false, 1)
				current_block_id = parts[0].strip_edges()
				current_block = {
					"type": "start" if result.start_block.is_empty() else "end"
				}
				if current_block["type"] == "start":
					result.start_block = current_block_id
			
			elif "{" in line:
				parts = line.split("{", false, 1)
				current_block_id = parts[0].strip_edges()
				var content_part = parts[1].split("}", false, 1)[0]
				
				current_block = {
					"type": "choice",
					"choices": _parse_choice_content(content_part)
				}
			
			if current_block:
				result.blocks[current_block_id] = current_block
		
		# Processar conexões
		elif "-->" in line:
			var parts = line.split("-->", false, 1)
			var from = parts[0].strip_edges()
			var to_part = parts[1].strip_edges()
			
			var to = ""
			var label = ""
			
			if "|" in to_part:  # Conexão com rótulo
				var label_parts = to_part.split("|", false, 2)
				label = label_parts[1].strip_edges()
				to = label_parts[2].strip_edges()
			else:  # Conexão simples
				to = to_part.strip_edges()
			
			result.connections.append({"from": from, "to": to, "label": label})
	
	return result

static func _parse_dialogue_content(content: String) -> Array:
	var dialogues = []
	var lines = content.split("\n")
	
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("-"):
			var parts = line.substr(1).split(":", false, 2)
			var char_name = parts[0].strip_edges()
			var expression = ""
			var text = ""
			
			if parts.size() == 2:
				text = parts[1].strip_edges()
			elif parts.size() == 3:
				expression = parts[1].strip_edges()
				text = parts[2].strip_edges()
			
			dialogues.append({
				"character_name": char_name,
				"character_expression": expression,
				"text": text
			})
	
	return dialogues

static func _parse_choice_content(content: String) -> Array:
	var choices = []
	var lines = content.split("\n")
	
	for line in lines:
		line = line.strip_edges()
		if "." in line:
			var parts = line.split(".", false, 1)
			choices.append({
				"text": parts[1].strip_edges(),
				"next_block_id": ""
			})
	
	return choices
