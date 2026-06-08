@tool
extends VBoxContainer

const GENERATIONS_DIR: String = "res://spritesynth/generations/"

@onready var tab_container: TabContainer = $TabContainer
@onready var generate_tab: VBoxContainer = $TabContainer/Generate
@onready var prompt_text: TextEdit = $TabContainer/Generate/PromptText
@onready var size_input: LineEdit = $TabContainer/Generate/SizeInput
@onready var neg_prompt_input: LineEdit = $TabContainer/Generate/NegPromptInput
@onready var seed_input: SpinBox = $TabContainer/Generate/SeedInput
@onready var generate_btn: Button = $TabContainer/Generate/GenerateBtn
@onready var status_label: Label = $TabContainer/Generate/StatusLabel
@onready var preview_rect: TextureRect = $TabContainer/Generate/PreviewRect

@onready var history_tab: VBoxContainer = $TabContainer/History
@onready var history_list: VBoxContainer = $TabContainer/History/ScrollContainer/HistoryList
@onready var refresh_btn: Button = $TabContainer/History/RefreshBtn
@onready var history_empty_label: Label = $TabContainer/History/EmptyLabel

@onready var settings_tab: VBoxContainer = $TabContainer/Settings
@onready var api_key_input: LineEdit = $TabContainer/Settings/ApiKeyInput
@onready var key_source_label: Label = $TabContainer/Settings/KeySourceLabel
@onready var save_key_btn: Button = $TabContainer/Settings/SaveKeyBtn
@onready var test_conn_btn: Button = $TabContainer/Settings/TestConnBtn
@onready var clear_history_btn: Button = $TabContainer/Settings/ClearHistoryBtn
@onready var settings_status_label: Label = $TabContainer/Settings/SettingsStatusLabel

var _client: SpritesynthClient
var _history_entries: Array[Dictionary] = []
var _current_image_data: PackedByteArray = PackedByteArray()


func _enter_tree() -> void:
	_client = SpritesynthClient.new()
	_client.setup(self)
	_client.generation_progress.connect(_on_progress)
	_client.generation_completed.connect(_on_completed)
	_client.generation_failed.connect(_on_failed)
	_client.connection_test_completed.connect(_on_connection_test)


func _ready() -> void:
	if Engine.is_editor_hint():
		custom_minimum_size = Vector2(240, 0)

	seed_input.max_value = 9999999
	seed_input.min_value = -1
	seed_input.value = -1
	seed_input.editable = true

	generate_btn.pressed.connect(_on_generate_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	save_key_btn.pressed.connect(_on_save_key_pressed)
	test_conn_btn.pressed.connect(_on_test_conn_pressed)
	clear_history_btn.pressed.connect(_on_clear_history_pressed)

	_load_api_key_display()
	load_history()


func _load_api_key_display() -> void:
	var key: String = SpritesynthSettings.get_api_key()
	if not key.is_empty():
		_client.api_key = key
	if SpritesynthSettings.is_using_env_var():
		api_key_input.text = ""
		api_key_input.editable = false
		api_key_input.placeholder_text = "Using $" + SpritesynthSettings.ENV_VAR_NAME
	save_key_btn.disabled = SpritesynthSettings.is_using_env_var()
	key_source_label.text = "Source: " + SpritesynthSettings.get_key_source()


func load_history() -> void:
	_history_entries = SpritesynthHistory.get_history()
	_refresh_history_ui()


func _refresh_history_ui() -> void:
	for child in history_list.get_children():
		child.queue_free()

	if _history_entries.is_empty():
		history_empty_label.visible = true
		return

	history_empty_label.visible = false

	for i in range(_history_entries.size()):
		var entry: Dictionary = _history_entries[i]
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var thumb: TextureRect = TextureRect.new()
		thumb.custom_minimum_size = Vector2(48, 48)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		var thumb_path: String = entry.get("thumbnail_path", "")
		if not thumb_path.is_empty() and FileAccess.file_exists(thumb_path):
			var img: Image = Image.new()
			var err: Error = img.load(thumb_path)
			if err == OK:
				thumb.texture = ImageTexture.create_from_image(img)
		hbox.add_child(thumb)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var prompt_label: Label = Label.new()
		var prompt_text_display: String = entry.get("prompt", entry.get("description", "No prompt"))
		if prompt_text_display.length() > 60:
			prompt_text_display = prompt_text_display.left(60) + "..."
		prompt_label.text = prompt_text_display
		prompt_label.autowrap_mode = TextServer.AUTOWORD_WRAP
		vbox.add_child(prompt_label)

		var meta_label: Label = Label.new()
		var created: String = entry.get("created_at", "")
		if created.is_empty():
			created = "Unknown date"
		var size_str: String = entry.get("image_size", "")
		var meta_parts: PackedStringArray = [created]
		if not size_str.is_empty():
			meta_parts.append(size_str)
		meta_label.text = "  ".join(meta_parts)
		meta_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(meta_label)

		hbox.add_child(vbox)

		var import_btn: Button = Button.new()
		import_btn.text = "Import"
		import_btn.custom_minimum_size = Vector2(60, 0)
		import_btn.pressed.connect(_on_import_pressed.bind(i))
		hbox.add_child(import_btn)

		var delete_btn: Button = Button.new()
		delete_btn.text = "X"
		delete_btn.custom_minimum_size = Vector2(30, 0)
		delete_btn.pressed.connect(_on_history_delete_pressed.bind(i))
		hbox.add_child(delete_btn)

		history_list.add_child(hbox)

		if i < _history_entries.size() - 1:
			var sep: HSeparator = HSeparator.new()
			history_list.add_child(sep)


func _on_generate_pressed() -> void:
	var prompt: String = prompt_text.text.strip_edges()
	if prompt.is_empty():
		status_label.text = "Please enter a prompt"
		return

	var size_str: String = size_input.text.strip_edges()
	if size_str.is_empty():
		size_str = "128x128"

	var seed: int = int(seed_input.value)
	var neg: String = neg_prompt_input.text.strip_edges()

	_generate(prompt, size_str, seed, neg)


func _generate(description: String, image_size: String, seed: int, negative_prompt: String) -> void:
	if not SpritesynthSettings.has_api_key():
		status_label.text = "API key not configured. Go to Settings tab."
		return

	_client.api_key = SpritesynthSettings.get_api_key()

	status_label.text = "Generating..."
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	generate_btn.disabled = true
	preview_rect.texture = null
	preview_rect.visible = false

	_client.generate_image(description, image_size, seed, negative_prompt)


func _on_progress(job_id: String, status: String) -> void:
	status_label.text = "Status: " + status


func _on_completed(job_id: String, image_data: PackedByteArray, metadata: Dictionary) -> void:
	status_label.text = "Generation complete! Importing..."
	_current_image_data = image_data

	var image: Image = Image.new()
	var err: Error = image.load_png_from_buffer(image_data)
	if err != OK:
		status_label.text = "Error: could not decode PNG (" + error_string(err) + ")"
		generate_btn.disabled = false
		return

	var preview_tex: ImageTexture = ImageTexture.create_from_image(image)
	preview_rect.texture = preview_tex
	preview_rect.visible = true

	var success: bool = _save_generated_image(image, metadata)
	if success:
		status_label.text = "Saved to res://spritesynth/generations/"
	else:
		status_label.text = "Image saved but filesystem refresh may be needed"

	generate_btn.disabled = false


func _on_failed(job_id: String, error_message: String) -> void:
	status_label.text = "Failed: " + error_message
	status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	generate_btn.disabled = false


func _save_generated_image(image: Image, metadata: Dictionary) -> bool:
	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		push_error("Spritesynth: could not open res://")
		return false

	var gens_dir: String = "res://spritesynth/generations"
	if not DirAccess.dir_exists_absolute(gens_dir):
		var mkdir_err: Error = DirAccess.make_dir_recursive_absolute(gens_dir)
		if mkdir_err != OK:
			push_error("Spritesynth: could not create " + gens_dir + ": " + error_string(mkdir_err))
			return false

	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "spritesynth_" + str(timestamp) + ".png"
	var save_path: String = gens_dir + "/" + filename

	var save_err: Error = image.save_png(save_path)
	if save_err != OK:
		push_error("Spritesynth: could not save PNG to " + save_path + ": " + error_string(save_err))
		return false

	_import_file(save_path)
	_save_to_history(filename, metadata)

	return true


func _import_file(path: String) -> void:
	if not Engine.has_singleton("EditorInterface"):
		return
	var ei: EditorInterface = Engine.get_singleton("EditorInterface")
	var fs: EditorFileSystem = ei.get_resource_filesystem()
	if fs:
		fs.scan()
	if ei.get_script_editor():
		pass


func _save_to_history(filename: String, metadata: Dictionary) -> void:
	var entry: Dictionary = {
		"filename": filename,
		"prompt": prompt_text.text.strip_edges(),
		"image_size": size_input.text.strip_edges(),
		"seed": int(seed_input.value),
		"negative_prompt": neg_prompt_input.text.strip_edges(),
		"created_at": Time.get_datetime_string_from_system(),
		"timestamp": Time.get_unix_time_from_system(),
	}

	var image: Image = Image.new()
	var load_err: Error = image.load_png_from_buffer(_current_image_data)
	if load_err == OK:
		if image.get_width() > 128 or image.get_height() > 128:
			image.resize(128, 128, Image.INTERPOLATE_NEAREST)
		var thumb_path: String = SpritesynthHistory.save_thumbnail(0, image)
		if not thumb_path.is_empty():
			entry["thumbnail_path"] = thumb_path

	SpritesynthHistory.add_entry(entry)
	_history_entries = SpritesynthHistory.get_history()
	_refresh_history_ui()


func _on_import_pressed(index: int) -> void:
	if index < 0 or index >= _history_entries.size():
		return
	var entry: Dictionary = _history_entries[index]
	var thumb_path: String = entry.get("thumbnail_path", "")
	if thumb_path.is_empty() or not FileAccess.file_exists(thumb_path):
		settings_status_label.text = "No thumbnail available to import"
		return

	var img: Image = Image.new()
	var err: Error = img.load(thumb_path)
	if err != OK:
		settings_status_label.text = "Could not load thumbnail"
		return

	_current_image_data = PackedByteArray()

	var filename: String = entry.get("filename", "spritesynth_" + str(Time.get_unix_time_from_system()) + ".png")
	var save_path: String = GENERATIONS_DIR + filename

	var dir: DirAccess = DirAccess.open("res://")
	if dir == null:
		return
	if not DirAccess.dir_exists_absolute(GENERATIONS_DIR):
		DirAccess.make_dir_recursive_absolute(GENERATIONS_DIR)

	var save_err: Error = img.save_png(save_path)
	if save_err == OK:
		_import_file(save_path)
		status_label.text = "Imported: " + filename

		if not Engine.has_singleton("EditorInterface"):
			return
		var ei: EditorInterface = Engine.get_singleton("EditorInterface")
		var fs: EditorFileSystem = ei.get_resource_filesystem()
		if fs:
			fs.scan()


func _on_history_delete_pressed(index: int) -> void:
	SpritesynthHistory.remove_entry(index)
	_history_entries = SpritesynthHistory.get_history()
	_refresh_history_ui()


func _on_refresh_pressed() -> void:
	SpritesynthHistory.reload()
	load_history()


func _on_save_key_pressed() -> void:
	var key: String = api_key_input.text.strip_edges()
	if key.is_empty():
		settings_status_label.text = "Please enter an API key"
		return
	if SpritesynthSettings.is_using_env_var():
		settings_status_label.text = "Cannot save: using $" + SpritesynthSettings.ENV_VAR_NAME
		return
	SpritesynthSettings.save_api_key(key)
	_client.api_key = key
	api_key_input.text = ""
	key_source_label.text = "Source: " + SpritesynthSettings.get_key_source()
	settings_status_label.text = "API key saved to ProjectSettings"


func _on_test_conn_pressed() -> void:
	if not SpritesynthSettings.has_api_key():
		settings_status_label.text = "No API key configured. Set one first."
		return

	_client.api_key = SpritesynthSettings.get_api_key()
	settings_status_label.text = "Testing connection..."
	test_conn_btn.disabled = true
	_client.test_connection()


func _on_connection_test(success: bool, message: String) -> void:
	test_conn_btn.disabled = false
	settings_status_label.text = message
	if success:
		settings_status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		settings_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func _on_clear_history_pressed() -> void:
	SpritesynthHistory.clear_all()
	_history_entries = []
	_refresh_history_ui()
	settings_status_label.text = "History cleared"
