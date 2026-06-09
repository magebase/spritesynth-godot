@tool
class_name SpritesynthClient
extends Node

signal generation_progress(job_id: String, status: String)
signal generation_completed(job_id: String, image_data: PackedByteArray, metadata: Dictionary)
signal generation_failed(job_id: String, error_message: String)
signal operation_completed(data: Dictionary)
signal operation_failed(error_message: String)
signal list_completed(data: Array)
signal action_completed(data: Dictionary)
signal download_completed(path: String, data: PackedByteArray)
signal connection_test_completed(success: bool, message: String)

const BASE_URL: String = "https://api.spritesynth.com/api"
const POLL_INTERVAL: float = 2.0
const MAX_POLLS: int = 300

var api_key: String = ""

var _http: HTTPRequest
var _poll_timer: Timer
var _current_job_id: String = ""
var _current_metadata: Dictionary = {}
var _poll_count: int = 0
var _download_chunks: PackedByteArray = PackedByteArray()
var _crud_signal_name: String = ""

enum State { IDLE, GENERATING, POLLING, DOWNLOADING, CRUD_REQUEST, TESTING, DOWNLOAD_ASSET }
var _state: int = State.IDLE


func _init(key: String = ""):
	api_key = key
	name = "SpritesynthClient"


func setup(parent: Node) -> void:
	if _http:
		return
	_http = HTTPRequest.new()
	_http.name = "SpritesynthHTTP"
	_http.request_completed.connect(_on_request_completed)
	parent.add_child(_http)

	_poll_timer = Timer.new()
	_poll_timer.name = "SpritesynthPollTimer"
	_poll_timer.one_shot = true
	_poll_timer.timeout.connect(_on_poll_timeout)
	parent.add_child(_poll_timer)


func _get_headers(content_type: bool = true) -> PackedStringArray:
	var h: PackedStringArray = ["Authorization: Bearer " + api_key]
	if content_type:
		h.append("Content-Type: application/json")
		h.append("Accept: application/json")
	return h


func _check_idle() -> bool:
	if _state != State.IDLE:
		push_warning("Spritesynth: operation already in progress")
		return false
	if api_key.is_empty():
		operation_failed.emit("API key not set. Go to the Settings tab to configure it.")
		return false
	return true


func _make_get(url_suffix: String, signal_name: String = "operation_completed") -> void:
	_state = State.CRUD_REQUEST
	_crud_signal_name = signal_name
	var err: Error = _http.request(BASE_URL + url_suffix, _get_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


func _make_post(url_suffix: String, body: Dictionary, signal_name: String = "action_completed") -> void:
	_state = State.CRUD_REQUEST
	_crud_signal_name = signal_name
	var err: Error = _http.request(BASE_URL + url_suffix, _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


func _make_patch(url_suffix: String, body: Dictionary, signal_name: String = "action_completed") -> void:
	_state = State.CRUD_REQUEST
	_crud_signal_name = signal_name
	var err: Error = _http.request(BASE_URL + url_suffix, _get_headers(), HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


func _make_put(url_suffix: String, body: Dictionary, signal_name: String = "action_completed") -> void:
	_state = State.CRUD_REQUEST
	_crud_signal_name = signal_name
	var err: Error = _http.request(BASE_URL + url_suffix, _get_headers(), HTTPClient.METHOD_PUT, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


func _make_delete(url_suffix: String, signal_name: String = "action_completed") -> void:
	_state = State.CRUD_REQUEST
	_crud_signal_name = signal_name
	var err: Error = _http.request(BASE_URL + url_suffix, _get_headers(), HTTPClient.METHOD_DELETE)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


# ============================================================
# GENERATIONS
# ============================================================

func create_image(description: String, image_size: String = "128x128", seed: int = -1, negative_prompt: String = "", project_id: String = "") -> void:
	if not _check_idle():
		return
	_state = State.GENERATING
	_current_job_id = ""
	_current_metadata = {}
	var body: Dictionary = {"description": description, "image_size": image_size}
	if seed >= 0:
		body["seed"] = seed
	if not negative_prompt.is_empty():
		body["negative_prompt"] = negative_prompt
	if not project_id.is_empty():
		body["project_id"] = project_id
	var err: Error = _http.request(BASE_URL + "/generations/image", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(err))


func create_with_style(description: String, style_image: String, image_size: String = "128x128", seed: int = -1, project_id: String = "") -> void:
	if not _check_idle():
		return
	_state = State.GENERATING
	_current_job_id = ""
	_current_metadata = {}
	var body: Dictionary = {"description": description, "style_image": style_image, "image_size": image_size}
	if seed >= 0:
		body["seed"] = seed
	if not project_id.is_empty():
		body["project_id"] = project_id
	var err: Error = _http.request(BASE_URL + "/generations/style", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(err))


func create_ui(description: String, image_size: String = "128x128", style: String = "", seed: int = -1, project_id: String = "") -> void:
	if not _check_idle():
		return
	_state = State.GENERATING
	_current_job_id = ""
	_current_metadata = {}
	var body: Dictionary = {"description": description, "image_size": image_size}
	if not style.is_empty():
		body["style"] = style
	if seed >= 0:
		body["seed"] = seed
	if not project_id.is_empty():
		body["project_id"] = project_id
	var err: Error = _http.request(BASE_URL + "/generations/ui", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(err))


func preview(description: String, image_size: String = "64x64") -> void:
	if not _check_idle():
		return
	_state = State.GENERATING
	var body: Dictionary = {"description": description, "image_size": image_size}
	var err: Error = _http.request(BASE_URL + "/generations/preview", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(err))


func get_generation(uuid: String) -> void:
	_make_get("/generations/" + uuid)


func get_generation_status(uuid: String) -> void:
	_make_get("/generations/" + uuid + "/status")


func list_generations(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/generations" + query, "list_completed")


func cancel_generation(uuid: String) -> void:
	_make_post("/generations/cancel", {"job_id": uuid})


func retry_generation(uuid: String) -> void:
	_make_post("/generations/retry", {"job_id": uuid})


func create_variation(uuid: String) -> void:
	if not _check_idle():
		return
	_state = State.GENERATING
	var body: Dictionary = {"job_id": uuid}
	var err: Error = _http.request(BASE_URL + "/generations/variation", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(err))


func poll_generation(job_id: String) -> void:
	if _state != State.IDLE:
		return
	_state = State.POLLING
	_current_job_id = job_id
	_poll_count = 0
	_start_polling()


func _start_polling() -> void:
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.start()


func _on_poll_timeout() -> void:
	if _state != State.POLLING:
		return
	_poll_count += 1
	if _poll_count > MAX_POLLS:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Polling timeout after " + str(MAX_POLLS * POLL_INTERVAL) + " seconds")
		return
	var err: Error = _http.request(BASE_URL + "/generations/" + _current_job_id, _get_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Poll request failed: " + error_string(err))


# ============================================================
# IMAGE OPERATIONS
# ============================================================

func to_pixel_art(image: String, pixel_size: int = 16) -> void:
	if not _check_idle():
		return
	_state = State.CRUD_REQUEST
	_crud_signal_name = "action_completed"
	var body: Dictionary = {"image": image, "pixel_size": pixel_size}
	var err: Error = _http.request(BASE_URL + "/image-ops/to-pixel", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Request failed: " + error_string(err))


func resize_image(image: String, width: int, height: int) -> void:
	_make_post("/image-ops/resize", {"image": image, "width": width, "height": height})


func remove_background(image: String) -> void:
	_make_post("/image-ops/remove-bg", {"image": image})


func inpaint_image(image: String, mask: String = "", prompt: String = "") -> void:
	var body: Dictionary = {"image": image}
	if not mask.is_empty():
		body["mask"] = mask
	if not prompt.is_empty():
		body["prompt"] = prompt
	_make_post("/image-ops/inpaint", body)


func edit_image(image: String, prompt: String, strength: float = 0.8) -> void:
	_make_post("/image-ops/edit", {"image": image, "prompt": prompt, "strength": strength})


func rotate_image(image: String, degrees: int, expand: bool = true) -> void:
	_make_post("/image-ops/rotate", {"image": image, "degrees": degrees, "expand": expand})


# ============================================================
# CHARACTERS
# ============================================================

func list_characters(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/characters" + query, "list_completed")


func create_character(name: String, description: String = "", project_id: String = "", direction_count: int = 1, metadata: Dictionary = {}, asset_id: String = "") -> void:
	var body: Dictionary = {"name": name}
	if not description.is_empty():
		body["description"] = description
	if not project_id.is_empty():
		body["project_id"] = project_id
	body["direction_count"] = direction_count
	if not metadata.is_empty():
		body["metadata"] = metadata
	if not asset_id.is_empty():
		body["asset_id"] = asset_id
	_make_post("/characters", body)


func get_character(uuid: String) -> void:
	_make_get("/characters/" + uuid)


func update_character(uuid: String, data: Dictionary) -> void:
	_make_patch("/characters/" + uuid, data)


func delete_character(uuid: String) -> void:
	_make_delete("/characters/" + uuid)


func export_character_zip(uuid: String, save_path: String) -> void:
	_state = State.DOWNLOAD_ASSET
	_current_metadata = {"save_path": save_path}
	var err: Error = _http.request(BASE_URL + "/characters/" + uuid + "/export-zip", _get_headers(false), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Export request failed: " + error_string(err))


func duplicate_character(uuid: String) -> void:
	_make_post("/characters/" + uuid + "/duplicate", {})


func assign_character_to_project(uuid: String, project_id: String) -> void:
	_make_patch("/characters/" + uuid + "/assign-project", {"project_id": project_id})


func set_character_thumbnail(uuid: String, asset_id: String) -> void:
	_make_patch("/characters/" + uuid + "/thumbnail", {"asset_id": asset_id})


func add_character_state(char_uuid: String, name: String, asset_id: String, direction: String = "south", frame_count: int = 1, frame_duration_ms: int = 500) -> void:
	var body: Dictionary = {"name": name, "asset_id": asset_id, "direction": direction, "frame_count": frame_count, "frame_duration_ms": frame_duration_ms}
	_make_post("/characters/" + char_uuid + "/states", body)


func update_character_state(char_uuid: String, state_uuid: String, data: Dictionary) -> void:
	_make_patch("/characters/" + char_uuid + "/states/" + state_uuid, data)


func get_character_state_spritesheet(char_uuid: String, state_uuid: String) -> void:
	_make_get("/characters/" + char_uuid + "/states/" + state_uuid + "/spritesheet")


# ============================================================
# OBJECTS
# ============================================================

func list_objects(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/objects" + query, "list_completed")


func create_object(name: String, description: String = "", project_id: String = "", direction_count: int = 1, metadata: Dictionary = {}, asset_id: String = "") -> void:
	var body: Dictionary = {"name": name}
	if not description.is_empty():
		body["description"] = description
	if not project_id.is_empty():
		body["project_id"] = project_id
	body["direction_count"] = direction_count
	if not metadata.is_empty():
		body["metadata"] = metadata
	if not asset_id.is_empty():
		body["asset_id"] = asset_id
	_make_post("/objects", body)


func get_object(uuid: String) -> void:
	_make_get("/objects/" + uuid)


func update_object(uuid: String, data: Dictionary) -> void:
	_make_patch("/objects/" + uuid, data)


func delete_object(uuid: String) -> void:
	_make_delete("/objects/" + uuid)


func export_object_zip(uuid: String, save_path: String) -> void:
	_state = State.DOWNLOAD_ASSET
	_current_metadata = {"save_path": save_path}
	var err: Error = _http.request(BASE_URL + "/objects/" + uuid + "/export-zip", _get_headers(false), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Export request failed: " + error_string(err))


func duplicate_object(uuid: String) -> void:
	_make_post("/objects/" + uuid + "/duplicate", {})


func assign_object_to_project(uuid: String, project_id: String) -> void:
	_make_patch("/objects/" + uuid + "/assign-project", {"project_id": project_id})


func set_object_thumbnail(uuid: String, asset_id: String) -> void:
	_make_patch("/objects/" + uuid + "/thumbnail", {"asset_id": asset_id})


func add_object_state(obj_uuid: String, name: String, asset_id: String, frame_count: int = 1, frame_duration_ms: int = 500) -> void:
	var body: Dictionary = {"name": name, "asset_id": asset_id, "frame_count": frame_count, "frame_duration_ms": frame_duration_ms}
	_make_post("/objects/" + obj_uuid + "/states", body)


func update_object_state(obj_uuid: String, state_uuid: String, data: Dictionary) -> void:
	_make_patch("/objects/" + obj_uuid + "/states/" + state_uuid, data)


# ============================================================
# TILESETS
# ============================================================

func list_tilesets(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/tilesets" + query, "list_completed")


func create_tileset(name: String, description: String = "", project_id: String = "", tile_size: int = 16, tileset_type: String = "top_down", metadata: Dictionary = {}) -> void:
	var body: Dictionary = {"name": name}
	if not description.is_empty():
		body["description"] = description
	if not project_id.is_empty():
		body["project_id"] = project_id
	body["tile_size"] = tile_size
	body["type"] = tileset_type
	if not metadata.is_empty():
		body["metadata"] = metadata
	_make_post("/tilesets", body)


func get_tileset(uuid: String) -> void:
	_make_get("/tilesets/" + uuid)


func update_tileset(uuid: String, data: Dictionary) -> void:
	_make_patch("/tilesets/" + uuid, data)


func delete_tileset(uuid: String) -> void:
	_make_delete("/tilesets/" + uuid)


func export_tileset_zip(uuid: String, save_path: String) -> void:
	_state = State.DOWNLOAD_ASSET
	_current_metadata = {"save_path": save_path}
	var err: Error = _http.request(BASE_URL + "/tilesets/" + uuid + "/export-zip", _get_headers(false), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Export request failed: " + error_string(err))


func duplicate_tileset(uuid: String) -> void:
	_make_post("/tilesets/" + uuid + "/duplicate", {})


func get_tileset_tiles(uuid: String) -> void:
	_make_get("/tilesets/" + uuid + "/tiles")


# ============================================================
# PROJECTS
# ============================================================

func list_projects(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/projects" + query, "list_completed")


func create_project(name: String, description: String = "", settings: Dictionary = {}) -> void:
	var body: Dictionary = {"name": name}
	if not description.is_empty():
		body["description"] = description
	if not settings.is_empty():
		body["settings"] = settings
	_make_post("/projects", body)


func get_project(uuid: String) -> void:
	_make_get("/projects/" + uuid)


func update_project(uuid: String, data: Dictionary) -> void:
	_make_patch("/projects/" + uuid, data)


func delete_project(uuid: String) -> void:
	_make_delete("/projects/" + uuid)


func duplicate_project(uuid: String) -> void:
	_make_post("/projects/" + uuid + "/duplicate", {})


func archive_project(uuid: String) -> void:
	_make_post("/projects/" + uuid + "/archive", {})


func unarchive_project(uuid: String) -> void:
	_make_post("/projects/" + uuid + "/unarchive", {})


# ============================================================
# ASSETS
# ============================================================

func list_assets(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/assets" + query, "list_completed")


func get_asset(uuid: String) -> void:
	_make_get("/assets/" + uuid)


func delete_asset(uuid: String) -> void:
	_make_delete("/assets/" + uuid)


func bulk_delete_assets(uuids: Array) -> void:
	_make_post("/assets/bulk-destroy", {"ids": uuids})


func move_asset(uuid: String, project_id: String) -> void:
	_make_patch("/assets/" + uuid + "/move", {"project_id": project_id})


func download_asset(uuid: String, save_path: String) -> void:
	_state = State.DOWNLOAD_ASSET
	_current_metadata = {"save_path": save_path}
	var err: Error = _http.request(BASE_URL + "/assets/" + uuid + "/download", _get_headers(false), HTTPClient.METHOD_GET)
	if err != OK:
		_state = State.IDLE
		operation_failed.emit("Download request failed: " + error_string(err))


func list_asset_versions(uuid: String) -> void:
	_make_get("/assets/" + uuid + "/versions")


func create_asset_version(uuid: String) -> void:
	_make_post("/assets/" + uuid + "/versions", {})


func restore_asset_version(uuid: String, version_uuid: String) -> void:
	_make_post("/assets/" + uuid + "/versions/" + version_uuid + "/restore", {})


# ============================================================
# TEMPLATES
# ============================================================

func list_templates(params: Dictionary = {}) -> void:
	var query: String = ""
	if not params.is_empty():
		var parts: PackedStringArray = []
		for key in params:
			parts.append(key + "=" + str(params[key]))
		query = "?" + "&".join(parts)
	_make_get("/templates" + query, "list_completed")


func create_template(name: String, description: String = "", template_type: String = "generation", config: Dictionary = {}, is_public: bool = false) -> void:
	var body: Dictionary = {"name": name}
	if not description.is_empty():
		body["description"] = description
	body["type"] = template_type
	if not config.is_empty():
		body["config"] = config
	body["is_public"] = is_public
	_make_post("/templates", body)


func get_template(uuid: String) -> void:
	_make_get("/templates/" + uuid)


func update_template(uuid: String, data: Dictionary) -> void:
	_make_patch("/templates/" + uuid, data)


func delete_template(uuid: String) -> void:
	_make_delete("/templates/" + uuid)


func apply_template(uuid: String) -> void:
	_make_post("/templates/" + uuid + "/apply", {})


func duplicate_template(uuid: String) -> void:
	_make_post("/templates/" + uuid + "/duplicate", {})


# ============================================================
# ACCOUNT
# ============================================================

func list_api_keys() -> void:
	_make_get("/account/api-keys", "list_completed")


func create_api_key(name: String) -> void:
	_make_post("/account/api-keys", {"name": name})


func delete_api_key(uuid: String) -> void:
	_make_delete("/account/api-keys/" + uuid)


func revoke_api_key(uuid: String) -> void:
	_make_post("/account/api-keys/" + uuid + "/revoke", {})


func rotate_api_key(uuid: String) -> void:
	_make_post("/account/api-keys/" + uuid + "/rotate", {})


func get_balance() -> void:
	_make_get("/account/balance")


# ============================================================
# TESTING
# ============================================================

func test_connection() -> void:
	if _state != State.IDLE:
		return
	if api_key.is_empty():
		connection_test_completed.emit(false, "API key is not set")
		return
	_state = State.TESTING
	var err: Error = _http.request(
		BASE_URL + "/generations/image",
		_get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({"description": "test", "image_size": "64x64"})
	)
	if err != OK:
		_state = State.IDLE
		connection_test_completed.emit(false, "Request failed: " + error_string(err))


func cancel() -> void:
	if _poll_timer and _poll_timer.is_inside_tree() and not _poll_timer.is_stopped():
		_poll_timer.stop()
	_state = State.IDLE
	_current_job_id = ""
	_crud_signal_name = ""


# ============================================================
# RESPONSE HANDLING
# ============================================================

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	match _state:
		State.GENERATING:
			_handle_generate_response(result, response_code, body)
		State.POLLING:
			_handle_poll_response(result, response_code, body)
		State.DOWNLOADING:
			_handle_download_response(result, response_code, body)
		State.DOWNLOAD_ASSET:
			_handle_download_asset_response(result, response_code, body)
		State.CRUD_REQUEST:
			_handle_crud_response(result, response_code, body)
		State.TESTING:
			_handle_test_response(result, response_code, body)
		_:
			_state = State.IDLE


func _handle_generate_response(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_state = State.IDLE
		generation_failed.emit("", "Network error: " + error_string(result))
		return

	var json: Dictionary = _parse_json(body)
	if json.is_empty():
		_state = State.IDLE
		generation_failed.emit("", "Invalid JSON response (code " + str(response_code) + ")")
		return

	if response_code >= 400:
		var msg: String = json.get("error", json.get("message", "API error (code " + str(response_code) + ")"))
		_state = State.IDLE
		generation_failed.emit("", msg)
		return

	if response_code == 402:
		_state = State.IDLE
		generation_failed.emit("", "Insufficient credits")
		return

	var job_id: String = json.get("job_id", json.get("id", ""))
	if job_id.is_empty():
		_state = State.IDLE
		generation_failed.emit("", "No job_id in response")
		return

	_current_job_id = job_id
	_state = State.POLLING
	_poll_count = 0
	generation_progress.emit(job_id, "queued")
	_start_polling()


func _handle_poll_response(result: int, response_code: int, body: PackedByteArray) -> void:
	if _state != State.POLLING:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Network error: " + error_string(result))
		return

	var json: Dictionary = _parse_json(body)
	if json.is_empty():
		_start_polling()
		return

	var status: String = json.get("status", "unknown")
	generation_progress.emit(_current_job_id, status)

	match status:
		"completed":
			var asset: Dictionary = json.get("asset", {})
			var asset_url: String = asset.get("url", "")
			if asset_url.is_empty():
				asset_url = json.get("url", "")
			if asset_url.is_empty():
				_state = State.IDLE
				generation_failed.emit(_current_job_id, "No asset URL in completed response")
				return
			_current_metadata = {
				"job_id": _current_job_id,
				"width": asset.get("width", 0),
				"height": asset.get("height", 0),
				"credits_cost": json.get("credits_cost", 0),
				"duration_ms": json.get("duration_ms", 0),
				"prompt": json.get("prompt", ""),
			}
			_state = State.DOWNLOADING
			_download_chunks = PackedByteArray()
			var err: Error = _http.request(asset_url, _get_headers(false), HTTPClient.METHOD_GET)
			if err != OK:
				_state = State.IDLE
				generation_failed.emit(_current_job_id, "Download request failed: " + error_string(err))
		"failed":
			_state = State.IDLE
			var err_msg: String = json.get("error_message", json.get("error", "Generation failed"))
			generation_failed.emit(_current_job_id, err_msg)
		_:
			_start_polling()


func _handle_download_response(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	if _state != State.DOWNLOADING:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Download network error: " + error_string(result))
		return
	if response_code >= 400:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Download failed with HTTP " + str(response_code))
		return
	if body.is_empty():
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Downloaded empty image data")
		return
	var metadata: Dictionary = _current_metadata.duplicate()
	metadata["prompt"] = metadata.get("prompt", "")
	_state = State.IDLE
	generation_completed.emit(_current_job_id, body, metadata)


func _handle_download_asset_response(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	if _state != State.DOWNLOAD_ASSET:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_state = State.IDLE
		operation_failed.emit("Download network error: " + error_string(result))
		return
	if response_code >= 400:
		_state = State.IDLE
		operation_failed.emit("Download failed with HTTP " + str(response_code))
		return
	if body.is_empty():
		_state = State.IDLE
		operation_failed.emit("Downloaded empty data")
		return
	var save_path: String = _current_metadata.get("save_path", "")
	if not save_path.is_empty():
		var dir_path: String = save_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir_path)
		var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
	_state = State.IDLE
	download_completed.emit(save_path, body)


func _handle_crud_response(result: int, response_code: int, body: PackedByteArray) -> void:
	var signal_name: String = _crud_signal_name
	_crud_signal_name = ""
	var prev_state: int = _state
	_state = State.IDLE

	if result != HTTPRequest.RESULT_SUCCESS:
		var msg: String = "Network error: " + error_string(result)
		if signal_name == "list_completed":
			list_completed.emit([])
		else:
			operation_failed.emit(msg)
		return

	var json: Dictionary = _parse_json(body)

	if response_code >= 400:
		var msg: String = json.get("error", json.get("message", "API error (code " + str(response_code) + ")"))
		if signal_name == "list_completed":
			list_completed.emit([])
		else:
			operation_failed.emit(msg)
		return

	match signal_name:
		"list_completed":
			var data: Array = json.get("data", [])
			if data.is_empty() and json.has("data") == false and json.size() > 0:
				if json.get("id") != null:
					data = [json]
			list_completed.emit(data)
		"action_completed":
			action_completed.emit(json)
		"operation_completed":
			operation_completed.emit(json)
		_:
			operation_completed.emit(json)


func _handle_test_response(result: int, response_code: int, body: PackedByteArray) -> void:
	_state = State.IDLE
	if result != HTTPRequest.RESULT_SUCCESS:
		connection_test_completed.emit(false, "Network error: " + error_string(result))
		return
	if response_code == 401 or response_code == 403:
		connection_test_completed.emit(false, "Invalid API key (HTTP " + str(response_code) + ")")
		return
	if response_code >= 400:
		var json: Dictionary = _parse_json(body)
		var msg: String = json.get("error", json.get("message", "API error (code " + str(response_code) + ")"))
		connection_test_completed.emit(false, msg)
		return
	connection_test_completed.emit(true, "Connection successful (HTTP " + str(response_code) + ")")


func _parse_json(body: PackedByteArray) -> Dictionary:
	var text: String = body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_warning("Spritesynth: JSON parse error: " + error_string(err) + " text: " + text.left(200))
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data
