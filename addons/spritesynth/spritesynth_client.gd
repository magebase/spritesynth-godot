@tool
class_name SpritesynthClient
extends Node

signal generation_progress(job_id: String, status: String)
signal generation_completed(job_id: String, image_data: PackedByteArray, metadata: Dictionary)
signal generation_failed(job_id: String, error_message: String)
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
var _download_body: PackedByteArray = PackedByteArray()
var _download_expecting: int = 0
var _download_chunks: PackedByteArray = PackedByteArray()

enum State { IDLE, GENERATING, POLLING, DOWNLOADING, TESTING }
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


func generate_image(description: String, image_size: String = "128x128", seed: int = -1, negative_prompt: String = "") -> void:
	if _state != State.IDLE:
		push_warning("Spritesynth: generation already in progress")
		return
	if api_key.is_empty():
		generation_failed.emit("", "API key not set. Go to the Settings tab to configure it.")
		return

	_state = State.GENERATING
	_current_job_id = ""
	_current_metadata = {}

	var body: Dictionary = {
		"description": description,
		"image_size": image_size,
	}
	if seed >= 0:
		body["seed"] = seed
	if not negative_prompt.is_empty():
		body["negative_prompt"] = negative_prompt

	var body_json: String = JSON.stringify(body)
	var error: Error = _http.request(
		BASE_URL + "/generations/image",
		_get_headers(),
		HTTPClient.METHOD_POST,
		body_json
	)
	if error != OK:
		_state = State.IDLE
		generation_failed.emit("", "Failed to send request: " + error_string(error))


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
	var error: Error = _http.request(
		BASE_URL + "/generations/" + _current_job_id,
		_get_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_state = State.IDLE
		generation_failed.emit(_current_job_id, "Poll request failed: " + error_string(error))


func test_connection() -> void:
	if _state != State.IDLE:
		return
	if api_key.is_empty():
		connection_test_completed.emit(false, "API key is not set")
		return
	_state = State.TESTING
	var error: Error = _http.request(
		BASE_URL + "/generations/image",
		_get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({"description": "test", "image_size": "64x64"})
	)
	if error != OK:
		_state = State.IDLE
		connection_test_completed.emit(false, "Request failed: " + error_string(error))


func cancel() -> void:
	if _poll_timer and _poll_timer.is_inside_tree() and not _poll_timer.is_stopped():
		_poll_timer.stop()
	_state = State.IDLE
	_current_job_id = ""


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	match _state:
		State.GENERATING:
			_handle_generate_response(result, response_code, body)
		State.POLLING:
			_handle_poll_response(result, response_code, body)
		State.DOWNLOADING:
			_handle_download_response(result, response_code, body)
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
				_state = State.IDLE
				generation_failed.emit(_current_job_id, "No asset URL in completed response")
				return
			_current_metadata = {
				"job_id": _current_job_id,
				"width": asset.get("width", 0),
				"height": asset.get("height", 0),
				"credits_cost": json.get("credits_cost", 0),
				"duration_ms": json.get("duration_ms", 0),
				"prompt": "",
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

	var old_state: int = _state
	_state = State.IDLE
	generation_completed.emit(_current_job_id, body, metadata)


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
