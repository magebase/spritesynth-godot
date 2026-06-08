extends "res://addons/gut/test.gd"

func test_create_request_defaults():
    var client = SpritesynthClient.new("test_key")
    assert_eq(client.api_key, "test_key")

func test_create_request_body():
    var client = SpritesynthClient.new("test_key")
    var body = client._build_request_body("a knight", "64x64", 42, "blurry")
    var json = JSON.parse_string(body)
    assert_eq(json["description"], "a knight")
    assert_eq(json["image_size"], "64x64")
    assert_eq(json["seed"], 42)

func test_generation_response_parse():
    var client = SpritesynthClient.new("test_key")
    var json_str = '{"job_id": "abc123", "status": "pending"}'
    var result = JSON.parse_string(json_str)
    assert_eq(result["job_id"], "abc123")
    assert_eq(result["status"], "pending")
