@tool
extends VBoxContainer

@onready var api_key_input: LineEdit = $ApiKeyInput
@onready var prompt_input: TextEdit = $PromptInput
@onready var generate_btn: Button = $GenerateBtn
@onready var status_label: Label = $StatusLabel

var client: SpritesynthClient

func _ready():
    client = SpritesynthClient.new()
    client.generation_completed.connect(_on_generation_completed)
    client.generation_failed.connect(_on_generation_failed)
    generate_btn.pressed.connect(_on_generate_pressed)

    # Load saved API key
    if ProjectSettings.has_setting("spritesynth/api_key"):
        api_key_input.text = ProjectSettings.get_setting("spritesynth/api_key")

func _on_generate_pressed():
    if api_key_input.text.is_empty():
        status_label.text = "Please enter your API key"
        return

    client.api_key = api_key_input.text
    ProjectSettings.set_setting("spritesynth/api_key", api_key_input.text)
    ProjectSettings.save()

    status_label.text = "Generating..."
    client.create_image(prompt_input.text)

func _on_generation_completed(result: Dictionary):
    status_label.text = "Generation completed! Asset URL: " + result.get("asset", {}).get("url", "unknown")

func _on_generation_failed(error: String):
    status_label.text = "Failed: " + error
