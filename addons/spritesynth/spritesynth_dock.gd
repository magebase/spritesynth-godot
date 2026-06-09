@tool
extends VBoxContainer

const GENERATIONS_DIR: String = "res://spritesynth/generations/"
const EXPORTS_DIR: String = "res://spritesynth/exports/"

@onready var tab_container: TabContainer = $TabContainer

@onready var mode_dropdown: OptionButton = $TabContainer/Generate/ModeDropdown
@onready var dynamic_fields: VBoxContainer = $TabContainer/Generate/DynamicFields
@onready var style_image_url: LineEdit = $TabContainer/Generate/DynamicFields/StyleImageUrl
@onready var ui_style_input: LineEdit = $TabContainer/Generate/DynamicFields/UiStyleInput
@onready var prompt_text: TextEdit = $TabContainer/Generate/PromptText
@onready var size_input: LineEdit = $TabContainer/Generate/SizeSeedBox/SizeGroup/SizeInput
@onready var seed_input: SpinBox = $TabContainer/Generate/SizeSeedBox/SeedGroup/SeedInput
@onready var neg_prompt_input: LineEdit = $TabContainer/Generate/NegPromptInput
@onready var generate_btn: Button = $TabContainer/Generate/GenerateBtn
@onready var progress_bar: ProgressBar = $TabContainer/Generate/ProgressBar
@onready var status_label: Label = $TabContainer/Generate/StatusLabel
@onready var preview_rect: TextureRect = $TabContainer/Generate/PreviewRect
@onready var import_btn: Button = $TabContainer/Generate/ImportBtn

@onready var manage_tab_bar: TabBar = $TabContainer/Manage/ManageTabBar
@onready var search_input: LineEdit = $TabContainer/Manage/ManageHeader/SearchInput
@onready var create_btn: Button = $TabContainer/Manage/ManageHeader/CreateBtn
@onready var manage_scroll: ScrollContainer = $TabContainer/Manage/ManageScroll
@onready var manage_list: VBoxContainer = $TabContainer/Manage/ManageScroll/ManageList
@onready var manage_empty_label: Label = $TabContainer/Manage/ManageEmptyLabel
@onready var prev_btn: Button = $TabContainer/Manage/PaginationBar/PrevBtn
@onready var page_label: Label = $TabContainer/Manage/PaginationBar/PageLabel
@onready var next_btn: Button = $TabContainer/Manage/PaginationBar/NextBtn

@onready var top_pixel_btn: Button = $TabContainer/Tools/ImageOpsGrid/ToPixelBtn
@onready var resize_btn: Button = $TabContainer/Tools/ImageOpsGrid/ResizeBtn
@onready var remove_bg_btn: Button = $TabContainer/Tools/ImageOpsGrid/RemoveBgBtn
@onready var inpaint_btn: Button = $TabContainer/Tools/ImageOpsGrid/InpaintBtn
@onready var edit_btn: Button = $TabContainer/Tools/ImageOpsGrid/EditBtn
@onready var rotate_btn: Button = $TabContainer/Tools/ImageOpsGrid/RotateBtn
@onready var op_image_input: LineEdit = $TabContainer/Tools/ImageOpFields/OpImageInput
@onready var op_prompt_input: LineEdit = $TabContainer/Tools/ImageOpFields/OpPromptInput
@onready var op_param_input: LineEdit = $TabContainer/Tools/ImageOpFields/OpParamInput
@onready var op_execute_btn: Button = $TabContainer/Tools/ImageOpFields/OpExecuteBtn
@onready var tools_scroll: ScrollContainer = $TabContainer/Tools/ToolsScroll
@onready var tools_history_list: VBoxContainer = $TabContainer/Tools/ToolsScroll/ToolsHistoryList
@onready var api_key_input: LineEdit = $TabContainer/Tools/SettingsSection/ApiKeyInput
@onready var key_source_label: Label = $TabContainer/Tools/SettingsSection/KeySourceLabel
@onready var save_key_btn: Button = $TabContainer/Tools/SettingsSection/SaveKeyBtn
@onready var test_conn_btn: Button = $TabContainer/Tools/SettingsSection/TestConnBtn
@onready var clear_history_btn: Button = $TabContainer/Tools/SettingsSection/ClearHistoryBtn
@onready var tools_status_label: Label = $TabContainer/Tools/SettingsSection/ToolsStatusLabel

var _client: SpritesynthClient
var _history_entries: Array[Dictionary] = []
var _current_image_data: PackedByteArray = PackedByteArray()

var _manage_data: Array[Dictionary] = []
var _manage_page: int = 0
var _manage_page_size: int = 20
var _current_op: String = ""

const MANAGE_CATEGORIES: PackedStringArray = ["Characters", "Objects", "Tilesets", "Projects"]


func _enter_tree() -> void:
	_client = SpritesynthClient.new()
	_client.setup(self)
	_client.generation_progress.connect(_on_progress)
	_client.generation_completed.connect(_on_completed)
	_client.generation_failed.connect(_on_failed)
	_client.connection_test_completed.connect(_on_connection_test)
	_client.list_completed.connect(_on_list_completed)
	_client.action_completed.connect(_on_action_completed)
	_client.operation_completed.connect(_on_operation_completed)
	_client.operation_failed.connect(_on_operation_failed)
	_client.download_completed.connect(_on_download_completed)


func _ready() -> void:
	if Engine.is_editor_hint():
		custom_minimum_size = Vector2(280, 0)

	mode_dropdown.add_item("Create Image", 0)
	mode_dropdown.add_item("Style Reference", 1)
	mode_dropdown.add_item("UI Elements", 2)
	mode_dropdown.add_item("Preview", 3)
	mode_dropdown.selected = 0
	mode_dropdown.item_selected.connect(_on_mode_changed)

	seed_input.max_value = 9999999
	seed_input.min_value = -1
	seed_input.value = -1
	seed_input.editable = true

	generate_btn.pressed.connect(_on_generate_pressed)
	import_btn.pressed.connect(_on_import_btn_pressed)
	import_btn.visible = false

	manage_tab_bar.tab_selected.connect(_on_manage_tab_changed)
	for cat in MANAGE_CATEGORIES:
		manage_tab_bar.add_tab(cat)
	manage_tab_bar.current_tab = 0

	search_input.text_changed.connect(_on_search_changed)
	create_btn.pressed.connect(_on_create_pressed)
	prev_btn.pressed.connect(_on_prev_page)
	next_btn.pressed.connect(_on_next_page)

	top_pixel_btn.pressed.connect(_on_op_pressed.bind("to_pixel"))
	resize_btn.pressed.connect(_on_op_pressed.bind("resize"))
	remove_bg_btn.pressed.connect(_on_op_pressed.bind("remove_bg"))
	inpaint_btn.pressed.connect(_on_op_pressed.bind("inpaint"))
	edit_btn.pressed.connect(_on_op_pressed.bind("edit"))
	rotate_btn.pressed.connect(_on_op_pressed.bind("rotate"))
	op_execute_btn.pressed.connect(_on_op_execute)

	save_key_btn.pressed.connect(_on_save_key_pressed)
	test_conn_btn.pressed.connect(_on_test_conn_pressed)
	clear_history_btn.pressed.connect(_on_clear_history_pressed)

	_on_mode_changed(0)
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
	_refresh_tools_history()


func _refresh_tools_history() -> void:
	for child in tools_history_list.get_children():
		child.queue_free()
	if _history_entries.is_empty():
		return
	var max_show: int = mini(30, _history_entries.size())
	for i in range(max_show):
		var entry: Dictionary = _history_entries[i]
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: Label = Label.new()
		var txt: String = entry.get("prompt", entry.get("name", entry.get("description", "No description")))
		if txt.length() > 40:
			txt = txt.left(40) + "..."
		var type_str: String = entry.get("type", "generation")
		label.text = "[" + type_str + "] " + txt
		label.autowrap_mode = TextServer.AUTOWORD_WRAP
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		tools_history_list.add_child(hbox)
		if i < max_show - 1:
			tools_history_list.add_child(HSeparator.new())


# ============================================================
# GENERATE TAB
# ============================================================

func _on_mode_changed(index: int) -> void:
	style_image_url.visible = index == 1
	ui_style_input.visible = index == 2
	neg_prompt_input.visible = index == 0
	$TabContainer/Generate/NegPromptLabel.visible = index == 0
	$TabContainer/Generate/SizeSeedBox/SeedGroup.visible = index != 3


func _on_generate_pressed() -> void:
	var prompt: String = prompt_text.text.strip_edges()
	if prompt.is_empty():
		status_label.text = "Please enter a prompt"
		return
	if not SpritesynthSettings.has_api_key():
		status_label.text = "API key not configured. Go to Tools tab."
		return

	_client.api_key = SpritesynthSettings.get_api_key()
	var size_str: String = size_input.text.strip_edges()
	if size_str.is_empty():
		size_str = "128x128"
	var seed: int = int(seed_input.value)
	var neg: String = neg_prompt_input.text.strip_edges()

	status_label.text = "Generating..."
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	generate_btn.disabled = true
	import_btn.visible = false
	preview_rect.texture = null
	preview_rect.visible = false
	progress_bar.visible = true
	progress_bar.value = 0

	match mode_dropdown.selected:
		0:
			_client.create_image(prompt, size_str, seed, neg)
		1:
			var style_url: String = style_image_url.text.strip_edges()
			_client.create_with_style(prompt, style_url, size_str, seed)
		2:
			var ui_style: String = ui_style_input.text.strip_edges()
			_client.create_ui(prompt, size_str, ui_style, seed)
		3:
			_client.preview(prompt, size_str)


func _on_progress(job_id: String, status: String) -> void:
	status_label.text = "Status: " + status
	progress_bar.value = progress_bar.value + 5.0
	if progress_bar.value > 95:
		progress_bar.value = 95


func _on_completed(job_id: String, image_data: PackedByteArray, metadata: Dictionary) -> void:
	status_label.text = "Generation complete!"
	_current_image_data = image_data
	progress_bar.value = 100
	progress_bar.visible = false

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
	status_label.text = "Saved to " + GENERATIONS_DIR if success else "Image received (save may need refresh)"
	import_btn.visible = true
	generate_btn.disabled = false
	_save_to_history(metadata)


func _on_failed(job_id: String, error_message: String) -> void:
	status_label.text = "Failed: " + error_message
	status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	generate_btn.disabled = false
	progress_bar.visible = false


func _save_generated_image(image: Image, metadata: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(GENERATIONS_DIR):
		var mkdir_err: Error = DirAccess.make_dir_recursive_absolute(GENERATIONS_DIR)
		if mkdir_err != OK:
			push_error("Spritesynth: could not create " + GENERATIONS_DIR + ": " + error_string(mkdir_err))
			return false

	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "spritesynth_" + str(timestamp) + ".png"
	var save_path: String = GENERATIONS_DIR + filename

	var save_err: Error = image.save_png(save_path)
	if save_err != OK:
		push_error("Spritesynth: could not save PNG to " + save_path + ": " + error_string(save_err))
		return false

	_import_file(save_path)
	return true


func _import_file(path: String) -> void:
	if not Engine.has_singleton("EditorInterface"):
		return
	var ei: EditorInterface = Engine.get_singleton("EditorInterface")
	var fs: EditorFileSystem = ei.get_resource_filesystem()
	if fs:
		fs.scan()


func _save_to_history(metadata: Dictionary) -> void:
	var entry: Dictionary = {
		"type": "generation",
		"prompt": prompt_text.text.strip_edges(),
		"image_size": size_input.text.strip_edges(),
		"seed": int(seed_input.value),
		"negative_prompt": neg_prompt_input.text.strip_edges(),
		"created_at": Time.get_datetime_string_from_system(),
		"timestamp": Time.get_unix_time_from_system(),
		"mode": mode_dropdown.get_item_text(mode_dropdown.selected),
	}
	if metadata.get("credits_cost", 0) > 0:
		entry["credits_cost"] = metadata["credits_cost"]
	if metadata.get("duration_ms", 0) > 0:
		entry["duration_ms"] = metadata["duration_ms"]

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
	_refresh_tools_history()


func _on_import_btn_pressed() -> void:
	if _current_image_data.is_empty():
		return
	var timestamp: int = Time.get_unix_time_from_system()
	var filename: String = "spritesynth_import_" + str(timestamp) + ".png"
	var save_path: String = GENERATIONS_DIR + filename
	if not DirAccess.dir_exists_absolute(GENERATIONS_DIR):
		DirAccess.make_dir_recursive_absolute(GENERATIONS_DIR)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(_current_image_data)
		file.close()
		_import_file(save_path)
		status_label.text = "Imported: " + filename


# ============================================================
# MANAGE TAB
# ============================================================

func _on_manage_tab_changed(index: int) -> void:
	_manage_page = 0
	_manage_data = []
	_refresh_manage_list()


func _on_search_changed(_new_text: String) -> void:
	_manage_page = 0
	_refresh_manage_list()


func _refresh_manage_list() -> void:
	var category: String = MANAGE_CATEGORIES[manage_tab_bar.current_tab].to_lower()
	for child in manage_list.get_children():
		child.queue_free()

	_client.api_key = SpritesynthSettings.get_api_key()
	var params: Dictionary = {"per_page": _manage_page_size, "page": _manage_page + 1}
	var search_text: String = search_input.text.strip_edges()
	if not search_text.is_empty():
		params["search"] = search_text

	match category:
		"characters":
			_client.list_characters(params)
		"objects":
			_client.list_objects(params)
		"tilesets":
			_client.list_tilesets(params)
		"projects":
			_client.list_projects(params)
	_manage_expand_cache = {}
	manage_list.add_child(Label.new())
	manage_list.get_child(0).text = "Loading..."
	manage_list.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL


var _manage_expand_cache: Dictionary = {}

func _on_list_completed(data: Array) -> void:
	_manage_data = data
	_populate_manage_list()


func _populate_manage_list() -> void:
	for child in manage_list.get_children():
		child.queue_free()

	if _manage_data.is_empty():
		manage_empty_label.visible = true
		manage_list.visible = false
		return

	manage_empty_label.visible = false
	manage_list.visible = true

	for i in range(_manage_data.size()):
		var item: Dictionary = _manage_data[i]
		var item_id: String = item.get("uuid", item.get("id", ""))
		if item_id.is_empty():
			continue

		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox: VBoxContainer = VBoxContainer.new()

		var header: HBoxContainer = HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label: Label = Label.new()
		name_label.text = item.get("name", item.get("title", "Unnamed"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)

		var expand_btn: Button = Button.new()
		expand_btn.text = ">"
		expand_btn.custom_minimum_size = Vector2(24, 0)
		var expand_idx: int = i
		expand_btn.pressed.connect(_on_toggle_expand.bind(panel, vbox, expand_idx))
		header.add_child(expand_btn)

		var delete_btn: Button = Button.new()
		delete_btn.text = "X"
		delete_btn.custom_minimum_size = Vector2(24, 0)
		delete_btn.pressed.connect(_on_manage_delete.bind(item_id, category_from_index(manage_tab_bar.current_tab)))
		header.add_child(delete_btn)

		vbox.add_child(header)
		panel.add_child(vbox)
		manage_list.add_child(panel)

		if i < _manage_data.size() - 1:
			manage_list.add_child(HSeparator.new())

	_update_pagination()


func category_from_index(idx: int) -> String:
	if idx >= 0 and idx < MANAGE_CATEGORIES.size():
		return MANAGE_CATEGORIES[idx].to_lower()
	return ""


func _on_toggle_expand(panel: PanelContainer, vbox: VBoxContainer, index: int) -> void:
	if vbox.get_child_count() > 1:
		while vbox.get_child_count() > 1:
			var c = vbox.get_child(vbox.get_child_count() - 1)
			vbox.remove_child(c)
			c.queue_free()
		return

	var item: Dictionary = _manage_data[index]
	var detail_vbox: VBoxContainer = VBoxContainer.new()
	var category: String = category_from_index(manage_tab_bar.current_tab)

	for key in item:
		if key in ["uuid", "id", "name"]:
			continue
		var val = item[key]
		if val is Dictionary or val is Array:
			val = JSON.stringify(val)
		var dl: Label = Label.new()
		dl.text = key + ": " + str(val)
		dl.add_theme_font_size_override("font_size", 10)
		detail_vbox.add_child(dl)

	var action_hbox: HBoxContainer = HBoxContainer.new()

	var item_id: String = item.get("uuid", item.get("id", ""))

	var export_zip_btn: Button = Button.new()
	export_zip_btn.text = "Export ZIP"
	export_zip_btn.pressed.connect(_on_export_zip.bind(item_id, category))
	action_hbox.add_child(export_zip_btn)

	var duplicate_btn: Button = Button.new()
	duplicate_btn.text = "Duplicate"
	duplicate_btn.pressed.connect(_on_duplicate_item.bind(item_id, category))
	action_hbox.add_child(duplicate_btn)

	detail_vbox.add_child(action_hbox)

	if category == "characters" or category == "objects":
		var states_btn: Button = Button.new()
		states_btn.text = "States: " + str(item.get("states_count", item.get("states", []).size()))
		detail_vbox.add_child(states_btn)

	vbox.add_child(detail_vbox)


func _on_manage_delete(item_id: String, category: String) -> void:
	_client.api_key = SpritesynthSettings.get_api_key()
	match category:
		"characters":
			_client.delete_character(item_id)
		"objects":
			_client.delete_object(item_id)
		"tilesets":
			_client.delete_tileset(item_id)
		"projects":
			_client.delete_project(item_id)


func _on_export_zip(item_id: String, category: String) -> void:
	var timestamp: int = Time.get_unix_time_from_system()
	var save_path: String = EXPORTS_DIR + category + "_" + item_id + "_" + str(timestamp) + ".zip"
	if not DirAccess.dir_exists_absolute(EXPORTS_DIR):
		DirAccess.make_dir_recursive_absolute(EXPORTS_DIR)
	_client.api_key = SpritesynthSettings.get_api_key()
	match category:
		"characters":
			_client.export_character_zip(item_id, save_path)
		"objects":
			_client.export_object_zip(item_id, save_path)
		"tilesets":
			_client.export_tileset_zip(item_id, save_path)
	tools_status_label.text = "Exporting to " + save_path


func _on_duplicate_item(item_id: String, category: String) -> void:
	_client.api_key = SpritesynthSettings.get_api_key()
	match category:
		"characters":
			_client.duplicate_character(item_id)
		"objects":
			_client.duplicate_object(item_id)
		"tilesets":
			_client.duplicate_tileset(item_id)
		"projects":
			_client.duplicate_project(item_id)


func _on_download_completed(path: String, _data: PackedByteArray) -> void:
	tools_status_label.text = "Downloaded: " + path
	if not path.is_empty():
		_import_file(path)


func _on_create_pressed() -> void:
	var category: String = category_from_index(manage_tab_bar.current_tab)
	if category.is_empty():
		return
	_create_dialog(category)


func _create_dialog(category: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Create " + category
	dialog.dialog_text = "Enter name:"
	dialog.size = Vector2(300, 120)

	var name_input: LineEdit = LineEdit.new()
	name_input.placeholder_text = category + " name"
	dialog.add_child(name_input)

	dialog.confirmed.connect(func():
		var name_val: String = name_input.text.strip_edges()
		if name_val.is_empty():
			return
		_client.api_key = SpritesynthSettings.get_api_key()
		match category:
			"characters":
				_client.create_character(name_val)
			"objects":
				_client.create_object(name_val)
			"tilesets":
				_client.create_tileset(name_val)
			"projects":
				_client.create_project(name_val)
		_refresh_manage_list()
	)
	add_child(dialog)
	dialog.popup_centered()


func _on_prev_page() -> void:
	if _manage_page > 0:
		_manage_page -= 1
		_refresh_manage_list()


func _on_next_page() -> void:
	if _manage_data.size() >= _manage_page_size:
		_manage_page += 1
		_refresh_manage_list()


func _update_pagination() -> void:
	prev_btn.disabled = _manage_page <= 0
	next_btn.disabled = _manage_data.size() < _manage_page_size
	page_label.text = "Page " + str(_manage_page + 1)


func _on_operation_completed(data: Dictionary) -> void:
	tools_status_label.text = "Operation completed"
	_manage_expand_cache = {}


func _on_operation_failed(error_message: String) -> void:
	tools_status_label.text = "Error: " + error_message
	tools_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	generate_btn.disabled = false


func _on_action_completed(data: Dictionary) -> void:
	tools_status_label.text = "Action completed"
	if data.get("api_key", "") != "":
		tools_status_label.text = "API key created: " + data["api_key"]
	_refresh_manage_list()


# ============================================================
# TOOLS TAB — IMAGE OPS
# ============================================================

func _on_op_pressed(op: String) -> void:
	_current_op = op
	var labels: Dictionary = {
		"to_pixel": "To Pixel Art", "resize": "Resize",
		"remove_bg": "Remove BG", "inpaint": "Inpaint",
		"edit": "Edit", "rotate": "Rotate"
	}
	tools_status_label.text = "Operation: " + labels.get(op, op)
	op_image_input.visible = true
	$TabContainer/Tools/ImageOpFields/OpImageLabel.visible = true

	var show_prompt: bool = op in ["inpaint", "edit"]
	op_prompt_input.visible = show_prompt
	$TabContainer/Tools/ImageOpFields/OpPromptLabel.visible = show_prompt

	var show_param: bool = op in ["to_pixel", "resize", "rotate"]
	op_param_input.visible = show_param
	$TabContainer/Tools/ImageOpFields/OpParamLabel.visible = show_param

	match op:
		"to_pixel":
			op_param_input.placeholder_text = "Pixel size (default 16)"
			$TabContainer/Tools/ImageOpFields/OpParamLabel.text = "Pixel Size:"
		"resize":
			op_param_input.placeholder_text = "WidthxHeight (e.g. 64x64)"
			$TabContainer/Tools/ImageOpFields/OpParamLabel.text = "Dimensions:"
		"rotate":
			op_param_input.placeholder_text = "Degrees (e.g. 90)"
			$TabContainer/Tools/ImageOpFields/OpParamLabel.text = "Degrees:"
		"inpaint":
			op_prompt_input.placeholder_text = "Prompt (optional)"
		"edit":
			op_prompt_input.placeholder_text = "Edit description"

	op_execute_btn.visible = true


func _on_op_execute() -> void:
	if not SpritesynthSettings.has_api_key():
		tools_status_label.text = "API key not configured"
		return
	_client.api_key = SpritesynthSettings.get_api_key()

	var image_url: String = op_image_input.text.strip_edges()
	if image_url.is_empty():
		tools_status_label.text = "Enter an image URL"
		return

	match _current_op:
		"to_pixel":
			var psize: int = 16
			if not op_param_input.text.strip_edges().is_empty():
				psize = int(op_param_input.text.strip_edges())
			_client.to_pixel_art(image_url, psize)
		"resize":
			var dims: String = op_param_input.text.strip_edges()
			if "x" in dims:
				var parts: PackedStringArray = dims.split("x")
				var w: int = int(parts[0])
				var h: int = int(parts[1]) if parts.size() > 1 else w
				_client.resize_image(image_url, w, h)
			else:
				tools_status_label.text = "Format: WidthxHeight (e.g. 64x64)"
				return
		"remove_bg":
			_client.remove_background(image_url)
		"inpaint":
			var prompt: String = op_prompt_input.text.strip_edges()
			_client.inpaint_image(image_url, "", prompt)
		"edit":
			var prompt: String = op_prompt_input.text.strip_edges()
			_client.edit_image(image_url, prompt)
		"rotate":
			var degrees: int = 90
			if not op_param_input.text.strip_edges().is_empty():
				degrees = int(op_param_input.text.strip_edges())
			_client.rotate_image(image_url, degrees)

	tools_status_label.text = "Executing " + _current_op + "..."
	op_execute_btn.disabled = true


# ============================================================
# SETTINGS
# ============================================================

func _on_save_key_pressed() -> void:
	var key: String = api_key_input.text.strip_edges()
	if key.is_empty():
		tools_status_label.text = "Please enter an API key"
		return
	if SpritesynthSettings.is_using_env_var():
		tools_status_label.text = "Cannot save: using $" + SpritesynthSettings.ENV_VAR_NAME
		return
	SpritesynthSettings.save_api_key(key)
	_client.api_key = key
	api_key_input.text = ""
	key_source_label.text = "Source: " + SpritesynthSettings.get_key_source()
	tools_status_label.text = "API key saved to ProjectSettings"


func _on_test_conn_pressed() -> void:
	if not SpritesynthSettings.has_api_key():
		tools_status_label.text = "No API key configured"
		return
	_client.api_key = SpritesynthSettings.get_api_key()
	tools_status_label.text = "Testing connection..."
	test_conn_btn.disabled = true
	_client.test_connection()


func _on_connection_test(success: bool, message: String) -> void:
	test_conn_btn.disabled = false
	tools_status_label.text = message
	if success:
		tools_status_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		tools_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))


func _on_clear_history_pressed() -> void:
	SpritesynthHistory.clear_all()
	_history_entries = []
	_refresh_tools_history()
	tools_status_label.text = "History cleared"
