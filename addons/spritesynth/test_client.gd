extends GutTest

var _client: SpritesynthClient
var _scene: Node


func before_each() -> void:
	_scene = Node.new()
	_client = SpritesynthClient.new()
	_client.api_key = "test_key_12345"
	_client.setup(_scene)
	add_child_autoqfree(_scene)


func after_each() -> void:
	if _client:
		_client.cancel()


func test_client_initialization() -> void:
	assert_not_null(_client, "Client should be instantiated")
	assert_eq(_client.api_key, "test_key_12345", "API key should be set")
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Initial state should be IDLE")


func test_client_rejects_empty_api_key() -> void:
	var fired: bool = false
	var error_msg: String = ""
	_client.generation_failed.connect(func(_jid: String, msg: String):
		fired = true
		error_msg = msg
	)

	var old_key: String = _client.api_key
	_client.api_key = ""
	_client.generate_image("test prompt")
	assert_true(fired, "Should emit generation_failed for empty API key")
	assert_has(error_msg, "API key not set", "Error message should mention API key")
	_client.api_key = old_key


func test_client_rejects_empty_prompt() -> void:
	_client.generate_image("")
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Empty prompt should not start generation")


func test_client_generate_sends_request() -> void:
	_client.generate_image("a cute pixel art cat", "128x128", 42, "ugly")
	assert_eq(_client._state, SpritesynthClient.State.GENERATING, "State should be GENERATING")


func test_client_poll_state_transition() -> void:
	_client._state = SpritesynthClient.State.POLLING
	_client._current_job_id = "job_123"
	_client._poll_count = 0

	_client._on_poll_timeout()
	assert_eq(_client._poll_count, 1, "Poll count should increment")
	assert_eq(_client._state, SpritesynthClient.State.POLLING, "Should stay in POLLING state after first timeout (no response yet)")


func test_client_poll_timeout() -> void:
	_client._state = SpritesynthClient.State.POLLING
	_client._current_job_id = "job_timeout"
	_client._poll_count = SpritesynthClient.MAX_POLLS

	var fired: bool = false
	var error_msg: String = ""
	_client.generation_failed.connect(func(_jid: String, msg: String):
		fired = true
		error_msg = msg
	)

	_client._on_poll_timeout()
	assert_true(fired, "Should emit generation_failed on timeout")
	assert_has(error_msg, "timeout", "Error should mention timeout")
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "State should return to IDLE")


func test_client_cancel_during_polling() -> void:
	_client._state = SpritesynthClient.State.POLLING
	_client._current_job_id = "job_cancel"
	_client.cancel()
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "State should be IDLE after cancel")


func test_client_parse_json_valid() -> void:
	var body: PackedByteArray = '{"status": "completed", "id": "abc"}'.to_utf8_buffer()
	var result: Dictionary = _client._parse_json(body)
	assert_eq(result.get("status"), "completed", "Should parse status field")
	assert_eq(result.get("id"), "abc", "Should parse id field")


func test_client_parse_json_invalid() -> void:
	var body: PackedByteArray = "not json".to_utf8_buffer()
	var result: Dictionary = _client._parse_json(body)
	assert_true(result.is_empty(), "Invalid JSON should return empty dict")


func test_client_parse_json_empty() -> void:
	var body: PackedByteArray = PackedByteArray()
	var result: Dictionary = _client._parse_json(body)
	assert_true(result.is_empty(), "Empty body should return empty dict")


func test_client_rejects_concurrent_generations() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	var fired: bool = false
	_client.generation_failed.connect(func(_jid: String, _msg: String):
		fired = true
	)
	_client.generate_image("test")
	assert_false(fired, "Should not emit generation_failed for concurrent call (only warning)")


func test_settings_has_api_key_matches_get() -> void:
	var env_val: String = OS.get_environment("SPIRESYNTH_API_KEY")
	if env_val.is_empty():
		pass
	var has: bool = SpritesynthSettings.has_api_key()
	var got: String = SpritesynthSettings.get_api_key()
	assert_eq(has, not got.is_empty(), "has_api_key should match get_api_key")


func test_history_save_and_load() -> void:
	var test_entry: Dictionary = {
		"prompt": "test_prompt",
		"filename": "test.png",
		"created_at": Time.get_datetime_string_from_system(),
		"timestamp": Time.get_unix_time_from_system(),
	}
	SpritesynthHistory.add_entry(test_entry)
	var entries: Array[Dictionary] = SpritesynthHistory.get_history()
	var found: bool = false
	for entry in entries:
		if entry.get("prompt") == "test_prompt":
			found = true
			break
	assert_true(found, "History should contain the saved entry")
	SpritesynthHistory.remove_entry(0)
	entries = SpritesynthHistory.get_history()
	found = false
	for entry in entries:
		if entry.get("prompt") == "test_prompt":
			found = true
			break
	assert_false(found, "History should not contain removed entry")


func test_history_clear() -> void:
	SpritesynthHistory.add_entry({"prompt": "clear_test"})
	SpritesynthHistory.clear_all()
	var entries: Array[Dictionary] = SpritesynthHistory.get_history()
	assert_true(entries.is_empty(), "History should be empty after clear")


func test_settings_get_key_source() -> void:
	var source: String = SpritesynthSettings.get_key_source()
	assert_has(["ProjectSettings", "Environment variable ($SPIRESYNTH_API_KEY)", "Not configured"], source,
		"Key source should be one of the valid options")


func test_client_handle_generate_response_402() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	var fired: bool = false
	var msg: String = ""
	_client.generation_failed.connect(func(_jid: String, m: String):
		fired = true
		msg = m
	)
	var body: PackedByteArray = '{"error": "Insufficient credits"}'.to_utf8_buffer()
	_client._handle_generate_response(HTTPRequest.RESULT_SUCCESS, 402, body)
	assert_true(fired, "Should emit failed on 402")
	assert_has(msg.to_lower(), "credit", "Should mention credits")


func test_client_handle_generate_response_no_job_id_in_body() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	var fired: bool = false
	_client.generation_failed.connect(func(_jid: String, _m: String):
		fired = true
	)
	var body: PackedByteArray = '{"status": "ok"}'.to_utf8_buffer()
	_client._handle_generate_response(HTTPRequest.RESULT_SUCCESS, 201, body)
	assert_true(fired, "Should fail when no job_id in response")


func test_connection_test_without_key() -> void:
	var fired: bool = false
	var msg: String = ""
	_client.generation_failed.connect(func(_jid: String, m: String):
		fired = true
		msg = m
	)
	_client.api_key = ""
	_client.test_connection()
	assert_true(fired, "Should indicate API key is not set")


func test_client_state_machine_transitions() -> void:
	assert_eq(_client._state, SpritesynthClient.State.IDLE)

	_client._state = SpritesynthClient.State.GENERATING
	assert_eq(_client._state, SpritesynthClient.State.GENERATING)

	_client.cancel()
	assert_eq(_client._state, SpritesynthClient.State.IDLE)
