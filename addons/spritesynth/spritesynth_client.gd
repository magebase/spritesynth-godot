@tool
extends Node
class_name SpritesynthClient

const BASE_URL := "https://api.spritesynth.com/api"

var api_key: String = ""

signal generation_completed(result: Dictionary)
signal generation_failed(error: String)

func _init(key: String = ""):
    api_key = key

# Generate an image from a text prompt
func create_image(description: String, image_size: String = "128x128", seed: int = 0, negative_prompt: String = "") -> Dictionary:
    var headers = [
        "Authorization: Bearer " + api_key,
        "Content-Type: application/json"
    ]
    var body = JSON.stringify({
        "description": description,
        "image_size": image_size,
        "seed": seed if seed > 0 else null,
        "negative_prompt": negative_prompt if negative_prompt else null
    })

    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_request_completed.bind("create_image"))
    http.request(BASE_URL + "/generations/image", headers, HTTPClient.METHOD_POST, body)
    return {"status": "pending"}

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, action: String):
    var json = JSON.parse_string(body.get_string_from_utf8())
    if response_code != 200 and response_code != 202:
        generation_failed.emit(JSON.stringify(json))
        return
    generation_completed.emit(json)

# Poll a generation job for completion
func poll_generation(job_id: String, max_retries: int = 30) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)
    var headers = ["Authorization: Bearer " + api_key]
    http.request(BASE_URL + "/generations/" + job_id, headers)
    # Returns immediately; use generation_completed signal for async result
    return {"polling": true}
