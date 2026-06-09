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


# ============================================================
# INITIALIZATION & STATE
# ============================================================

func test_client_initialization() -> void:
	assert_not_null(_client, "Client should be instantiated")
	assert_eq(_client.api_key, "test_key_12345", "API key should be set")
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Initial state should be IDLE")
	assert_eq(_client.name, "SpritesynthClient", "Node name should match")


func test_client_rejects_empty_api_key() -> void:
	var fired: bool = false
	var error_msg: String = ""
	_client.operation_failed.connect(func(msg: String):
		fired = true
		error_msg = msg
	)
	_client.api_key = ""
	_client.list_characters()
	assert_true(fired, "Should emit operation_failed for empty API key")
	assert_has(error_msg, "API key not set", "Error message should mention API key")


func test_client_state_machine_transitions() -> void:
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Start IDLE")
	_client._state = SpritesynthClient.State.GENERATING
	assert_eq(_client._state, SpritesynthClient.State.GENERATING, "Can set GENERATING")
	_client.cancel()
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Cancel returns to IDLE")
	_client._state = SpritesynthClient.State.POLLING
	_client._current_job_id = "job_1"
	_client.cancel()
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "Cancel clears POLLING")


func test_client_poll_state_transition() -> void:
	_client._state = SpritesynthClient.State.POLLING
	_client._current_job_id = "job_123"
	_client._poll_count = 0
	_client._on_poll_timeout()
	assert_eq(_client._poll_count, 1, "Poll count should increment")


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
	assert_eq(_client._current_job_id, "", "Job ID should reset")


# ============================================================
# URL CONSTRUCTION
# ============================================================

func test_generate_sends_correct_url() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	assert_eq(_client._state, SpritesynthClient.State.GENERATING, "generate_image sets GENERATING state")


func test_get_generation_url() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.get_generation("abc-123")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "get_generation sets CRUD_REQUEST")


func test_list_generations_with_params() -> void:
	_client.list_generations({"type": "image", "per_page": 10})
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "list_generations sets CRUD_REQUEST")


func test_image_ops_urls() -> void:
	_client.to_pixel_art("https://img.url", 16)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "to_pixel_art sets CRUD_REQUEST")
	_client.cancel()

	_client.resize_image("https://img.url", 64, 64)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "resize_image sets CRUD_REQUEST")
	_client.cancel()

	_client.remove_background("https://img.url")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "remove_background sets CRUD_REQUEST")
	_client.cancel()

	_client.inpaint_image("https://img.url", "", "fix it")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "inpaint_image sets CRUD_REQUEST")
	_client.cancel()

	_client.edit_image("https://img.url", "make it blue")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "edit_image sets CRUD_REQUEST")
	_client.cancel()

	_client.rotate_image("https://img.url", 90)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "rotate_image sets CRUD_REQUEST")


# ============================================================
# REQUEST BODY CONSTRUCTION
# ============================================================

func test_create_character_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_character("Hero", "A brave hero", "proj-1", 4, {"color": "red"})
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_character sets CRUD_REQUEST")


func test_create_character_minimal() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_character("Hero")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "minimal create_character works")


func test_create_object_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_object("Sword", "A sharp blade", "proj-1", 1, {"damage": 10})
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_object sets CRUD_REQUEST")


func test_create_tileset_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_tileset("Grassland", "Green tiles", "proj-1", 16, "top_down")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_tileset sets CRUD_REQUEST")


func test_create_project_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_project("My Game", "An RPG", {"resolution": "256x256"})
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_project sets CRUD_REQUEST")


func test_create_template_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.create_template("Pixel Hero", "Template for heroes", "character", {"prompt": "hero"}, true)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_template sets CRUD_REQUEST")


func test_add_character_state_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.add_character_state("char-1", "walk", "asset-1", "east", 4, 200)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "add_character_state sets CRUD_REQUEST")


func test_add_object_state_body() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client.add_object_state("obj-1", "broken", "asset-1", 2, 300)
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "add_object_state sets CRUD_REQUEST")


func test_export_character_zip() -> void:
	_client._state = SpritesynthClient.State.DOWNLOAD_ASSET
	_client.export_character_zip("char-1", "/tmp/test.zip")
	assert_eq(_client._state, SpritesynthClient.State.DOWNLOAD_ASSET, "export_character_zip sets DOWNLOAD_ASSET")


func test_export_tileset_zip() -> void:
	_client._state = SpritesynthClient.State.DOWNLOAD_ASSET
	_client.export_tileset_zip("tile-1", "/tmp/tiles.zip")
	assert_eq(_client._state, SpritesynthClient.State.DOWNLOAD_ASSET, "export_tileset_zip sets DOWNLOAD_ASSET")


func test_version_endpoints() -> void:
	_client.list_asset_versions("asset-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "list_asset_versions")
	_client.cancel()
	_client.create_asset_version("asset-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_asset_version")
	_client.cancel()
	_client.restore_asset_version("asset-1", "ver-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "restore_asset_version")


# ============================================================
# ACCOUNT ENDPOINTS
# ============================================================

func test_account_endpoints() -> void:
	_client.list_api_keys()
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "list_api_keys")
	_client.cancel()

	_client.create_api_key("My App")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "create_api_key")
	_client.cancel()

	_client.delete_api_key("key-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "delete_api_key")
	_client.cancel()

	_client.revoke_api_key("key-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "revoke_api_key")
	_client.cancel()

	_client.rotate_api_key("key-1")
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "rotate_api_key")
	_client.cancel()

	_client.get_balance()
	assert_eq(_client._state, SpritesynthClient.State.CRUD_REQUEST, "get_balance")


# ============================================================
# RESPONSE PARSING
# ============================================================

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


# ============================================================
# ERROR HANDLING
# ============================================================

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
	assert_eq(_client._state, SpritesynthClient.State.IDLE, "State returns to IDLE on 402")


func test_client_handle_generate_response_no_job_id() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	var fired: bool = false
	_client.generation_failed.connect(func(_jid: String, _m: String):
		fired = true
	)
	var body: PackedByteArray = '{"status": "ok"}'.to_utf8_buffer()
	_client._handle_generate_response(HTTPRequest.RESULT_SUCCESS, 201, body)
	assert_true(fired, "Should fail when no job_id in response")


func test_client_handle_generate_response_network_error() -> void:
	_client._state = SpritesynthClient.State.GENERATING
	var fired: bool = false
	_client.generation_failed.connect(func(_jid: String, _m: String):
		fired = true
	)
	_client._handle_generate_response(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedByteArray())
	assert_true(fired, "Should emit failed on network error")


func test_client_handle_crud_response_401() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client._crud_signal_name = "action_completed"
	var fired: bool = false
	_client.operation_failed.connect(func(_m: String):
		fired = true
	)
	var body: PackedByteArray = '{"error": "Unauthorized"}'.to_utf8_buffer()
	_client._handle_crud_response(HTTPRequest.RESULT_SUCCESS, 401, body)
	assert_true(fired, "Should emit operation_failed on 401")


func test_connection_test_without_key() -> void:
	var fired: bool = false
	var msg: String = ""
	_client.connection_test_completed.connect(func(success: bool, m: String):
		fired = true
		msg = m
	)
	_client.api_key = ""
	_client.test_connection()
	assert_true(fired, "Should emit connection_test for missing key")
	assert_has(msg, "not set", "Should indicate API key is not set")


# ============================================================
# CRUD RESPONSE HANDLING
# ============================================================

func test_crud_list_completed_signal() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client._crud_signal_name = "list_completed"
	var fired: bool = false
	var result: Array = []
	_client.list_completed.connect(func(data: Array):
		fired = true
		result = data
	)
	var body: PackedByteArray = '{"data": [{"id": "1", "name": "test"}]}'.to_utf8_buffer()
	_client._handle_crud_response(HTTPRequest.RESULT_SUCCESS, 200, body)
	assert_true(fired, "list_completed should fire")
	assert_eq(result.size(), 1, "Should have 1 item")


func test_crud_action_completed_signal() -> void:
	_client._state = SpritesynthClient.State.CRUD_REQUEST
	_client._crud_signal_name = "action_completed"
	var fired: bool = false
	var result: Dictionary = {}
	_client.action_completed.connect(func(data: Dictionary):
		fired = true
		result = data
	)
	var body: PackedByteArray = '{"id": "new-1", "name": "created"}'.to_utf8_buffer()
	_client._handle_crud_response(HTTPRequest.RESULT_SUCCESS, 201, body)
	assert_true(fired, "action_completed should fire")
	assert_eq(result.get("id"), "new-1", "Should have id")


# ============================================================
# DOWNLOAD ASSET
# ============================================================

func test_download_asset_empty_body() -> void:
	_client._state = SpritesynthClient.State.DOWNLOAD_ASSET
	var fired: bool = false
	_client.operation_failed.connect(func(_m: String):
		fired = true
	)
	_client._handle_download_asset_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	assert_true(fired, "Should fail on empty body")


func test_download_asset_network_error() -> void:
	_client._state = SpritesynthClient.State.DOWNLOAD_ASSET
	var fired: bool = false
	_client.operation_failed.connect(func(_m: String):
		fired = true
	)
	_client._handle_download_asset_response(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedStringArray(), PackedByteArray())
	assert_true(fired, "Should fail on network error")


# ============================================================
# SETTINGS
# ============================================================

func test_settings_has_api_key_matches_get() -> void:
	var has: bool = SpritesynthSettings.has_api_key()
	var got: String = SpritesynthSettings.get_api_key()
	assert_eq(has, not got.is_empty(), "has_api_key should match get_api_key")


func test_settings_get_key_source_valid() -> void:
	var source: String = SpritesynthSettings.get_key_source()
	assert_has(["ProjectSettings", "Environment variable ($SPIRESYNTH_API_KEY)", "Not configured"], source,
		"Key source should be one of the valid options")


func test_settings_env_var_name() -> void:
	assert_eq(SpritesynthSettings.ENV_VAR_NAME, "SPIRESYNTH_API_KEY", "Env var name should be SPIRESYNTH_API_KEY")


# ============================================================
# HISTORY
# ============================================================

func test_history_save_and_load() -> void:
	var test_entry: Dictionary = {
		"type": "generation",
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
	SpritesynthHistory.add_entry({"type": "generation", "prompt": "clear_test"})
	SpritesynthHistory.clear_all()
	var entries: Array[Dictionary] = SpritesynthHistory.get_history()
	assert_true(entries.is_empty(), "History should be empty after clear")


func test_history_type_filter() -> void:
	SpritesynthHistory.add_entry({"type": "generation", "prompt": "gen_test"})
	SpritesynthHistory.add_entry({"type": "character", "name": "char_test"})
	var chars: Array[Dictionary] = SpritesynthHistory.get_history("character")
	assert_true(chars.size() > 0, "Should find character entries")
	var found_char: bool = false
	for c in chars:
		if c.get("name") == "char_test":
			found_char = true
			break
	assert_true(found_char, "Should find the char_test entry")
	SpritesynthHistory.clear_all()


func test_history_max_entries() -> void:
	var cap: int = SpritesynthHistory.MAX_ENTRIES
	assert_eq(cap, 200, "MAX_ENTRIES should be 200")


func test_history_default_type() -> void:
	var entry: Dictionary = {"prompt": "default_type_test"}
	SpritesynthHistory.add_entry(entry)
	var entries: Array[Dictionary] = SpritesynthHistory.get_history()
	var found: bool = false
	for e in entries:
		if e.get("prompt") == "default_type_test":
			found = true
			assert_eq(e.get("type"), "generation", "Default type should be 'generation'")
			break
	assert_true(found, "Should find the entry")
	SpritesynthHistory.remove_entry(0)


func test_history_adds_timestamp_automatically() -> void:
	var entry: Dictionary = {"prompt": "timestamp_test"}
	SpritesynthHistory.add_entry(entry)
	var entries: Array[Dictionary] = SpritesynthHistory.get_history()
	for e in entries:
		if e.get("prompt") == "timestamp_test":
			assert_true(e.has("created_at"), "Should auto-add created_at")
			assert_true(e.has("timestamp"), "Should auto-add timestamp")
			break
	SpritesynthHistory.remove_entry(0)


func test_history_persistence() -> void:
	var before: Array[Dictionary] = SpritesynthHistory.get_history()
	var count_before: int = before.size()
	var entry: Dictionary = {"prompt": "persist_test", "type": "generation"}
	SpritesynthHistory.add_entry(entry)
	SpritesynthHistory.reload()
	var after: Array[Dictionary] = SpritesynthHistory.get_history()
	assert_eq(after.size(), count_before + 1, "History should persist after reload")
	for e in after:
		if e.get("prompt") == "persist_test":
			assert_eq(e.get("type"), "generation", "Type should persist")
			break
	for e in after:
		if e.get("prompt") == "persist_test":
			SpritesynthHistory.remove_entry(after.find(e))
			break


# ============================================================
# DOCK CATEGORY HELPERS
# ============================================================

func test_category_from_index() -> void:
	var dock: VBoxContainer = VBoxContainer.new()
	dock.set_script(load("res://addons/spritesynth/spritesynth_dock.gd"))
	dock.queue_free()
