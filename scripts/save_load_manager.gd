# SaveLoadManager.gd
extends CanvasLayer

@onready var save_slots = $SaveLoadPanel/ScrollContainer/SaveSlots
@onready var visual_novel_manager = $VisualNovelManager

func show_save_menu():
	update_slot_previews()
	show()

func update_slot_previews():
	for slot in save_slots.get_children():
		var save_data = VisualNovelSingleton.load_save(slot.slot_number)
		slot.update_preview(save_data)

func save_game(slot_number):
	var save_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"chapter": visual_novel_manager.current_chapter_resource.chapter_id,
		"block": visual_novel_manager.current_block_id,
		"game_state": VisualNovelSingleton.game_state
	}
	VisualNovelSingleton.save_game(slot_number, save_data)

func load_game(slot_number):
	var save_data = VisualNovelSingleton.load_save(slot_number)
	if save_data:
		var chapter = VisualNovelSingleton.chapters[save_data.chapter]
		visual_novel_manager.start_chapter(chapter)
		visual_novel_manager.jump_to_block(save_data.block)
		VisualNovelSingleton.game_state = save_data.game_state
