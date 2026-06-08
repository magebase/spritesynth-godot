@tool
class_name SpritesynthHistory
extends RefCounted

const HISTORY_PATH: String = "user://spritesynth/history.json"
const THUMBNAILS_DIR: String = "user://spritesynth/thumbnails/"

static var _cache: Array[Dictionary] = []


static func get_history() -> Array[Dictionary]:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(HISTORY_PATH):
		return []
	var file: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file == null:
		push_warning("Spritesynth: could not open history file")
		return []
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		return []
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_warning("Spritesynth: history JSON parse error: " + error_string(err))
		_backup_and_reset()
		return []
	var data = json.data
	if data is Array:
		_cache = data
		return _cache
	return []


static func add_entry(entry: Dictionary) -> void:
	var history: Array[Dictionary] = get_history()
	history.insert(0, entry)
	_cache = history

	DirAccess.make_dir_recursive_absolute(HISTORY_PATH.get_base_dir())

	var file: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Spritesynth: could not write history file")
		return
	file.store_string(JSON.stringify(history, "\t", false))
	file.close()


static func remove_entry(index: int) -> void:
	var history: Array[Dictionary] = get_history()
	if index < 0 or index >= history.size():
		return
	var entry: Dictionary = history[index]
	var thumb_path: String = entry.get("thumbnail_path", "")
	if not thumb_path.is_empty() and FileAccess.file_exists(thumb_path):
		DirAccess.remove_absolute(thumb_path)

	history.remove_at(index)
	_cache = history

	DirAccess.make_dir_recursive_absolute(HISTORY_PATH.get_base_dir())

	var file: FileAccess = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(history, "\t", false))
	file.close()


static func clear_all() -> void:
	_cache = []

	if FileAccess.file_exists(HISTORY_PATH):
		DirAccess.remove_absolute(HISTORY_PATH)

	var thumb_dir: String = THUMBNAILS_DIR
	if DirAccess.dir_exists_absolute(thumb_dir):
		var dir: DirAccess = DirAccess.open(thumb_dir)
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while not fname.is_empty():
				if fname != "." and fname != "..":
					var fpath: String = thumb_dir.path_join(fname)
					if FileAccess.file_exists(fpath):
						DirAccess.remove_absolute(fpath)
				fname = dir.get_next()
			dir.list_dir_end()


static func save_thumbnail(entry_index: int, image: Image) -> String:
	DirAccess.make_dir_recursive_absolute(THUMBNAILS_DIR)
	var thumb_path: String = THUMBNAILS_DIR + "thumb_" + str(Time.get_unix_time_from_system()) + ".png"
	var err: Error = image.save_png(thumb_path)
	if err != OK:
		push_warning("Spritesynth: could not save thumbnail: " + error_string(err))
		return ""
	return thumb_path


static func reload() -> void:
	_cache = []


static func _backup_and_reset() -> void:
	var backup_path: String = HISTORY_PATH + ".bak." + str(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(HISTORY_PATH, backup_path)
	_cache = []
