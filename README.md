# SpriteSynth Godot SDK

![Godot 4.x](https://img.shields.io/badge/Godot-4.x-478cbf?logo=godot-engine&logoColor=white)

Generate pixel art game assets directly from Godot using the [SpriteSynth](https://spritesynth.com) AI API.

## Quick Start

1. Copy `addons/spritesynth` into your project's `addons/` directory.
2. Get an API key from [spritesynth.com](https://spritesynth.com).
3. Enable the plugin in **Project → Settings → Plugins**.

## Usage

```gdscript
extends Node

@onready var client = SpritesynthClient.new("YOUR_API_KEY")

func _ready():
    client.generation_completed.connect(_on_done)
    client.generation_failed.connect(_on_error)
    client.create_image("A knight with a sword, pixel art, 16-bit")

func _on_done(result: Dictionary):
    print("Generated: ", result.get("asset", {}).get("url", "no url"))

func _on_error(error: String):
    print("Failed: ", error)
```

## License

MIT
