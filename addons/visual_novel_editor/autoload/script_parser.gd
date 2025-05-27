# script_parser.gd
extends Node

static func parse_script(content: String) -> Dictionary:
	var chapters = []
	var current_chapter = {
		"id": "",
		"title": "",
		"start_block": "",
		"blocks": {},
		"custom_ids": {}
	}
	
	var current_block = null
	var lines = content.split("\n")
	var in_front_matter = false
	var front_matter = ""
	
	for line in lines:
		line = line.strip_edges()
		
		# Detectar front matter (metadados)
		if line == "---":
			if in_front_matter:
				current_chapter = parse_front_matter(front_matter)
				front_matter = ""
			in_front_matter = !in_front_matter
			continue
			
		if in_front_matter:
			front_matter += line + "\n"
			continue
			
		# Detectar blocos
		if line.begins_with(":: "):
			var block_decl = line.substr(3).split(" ", false)
			var block_id = block_decl[0]
			var is_auto_id = block_id.begins_with("*")
			
			var final_id = ""
			if is_auto_id:
				final_id = "auto_" + UUID.v4().substr(0,8)
				current_chapter.custom_ids[block_id] = final_id
			else:
				final_id = "custom_" + block_id.sha1_text().substr(0,8)
				current_chapter.custom_ids[block_id] = final_id
			
			current_block = {
				"id": final_id,
				"original_id": block_id,
				"type": "text",
				"text": ""
			}
			
		elif line.begins_with("-> "):
			var parts = line.substr(3).split("|>", false)
			var text = parts[0].strip_edges()
			var target = parts[1].strip_edges() if parts.size() > 1 else ""
			
			var resolved_target = ""
			if target.begins_with("*"):
				resolved_target = current_chapter.custom_ids.get(target, UUID.v4())
			else:
				resolved_target = current_chapter.custom_ids.get(target, "custom_" + target.sha1_text().substr(0,8))
			
			current_block.choices.append({
				"text": text,
				"next": resolved_target
			})
			
		elif ": " in line:
			var parts = line.split(": ", 1)
			current_block.text += "[%s] %s\n" % [parts[0], parts[1]]
			
	# Adicionar último bloco
	if current_block != null:
		current_chapter.blocks[current_block.id] = current_block
	
	return current_chapter

static func parse_front_matter(front_matter: String) -> Dictionary:
	var metadata = {}
	var lines = front_matter.split("\n")
	
	for line in lines:
		if ": " in line:
			var parts = line.split(": ", 1)
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			metadata[key] = value
	
	return {
		"id": metadata.get("id", ""),
		"title": metadata.get("title", "Sem Título"),
		"blocks": {},
		"start_block": metadata.get("start", "")
	}
