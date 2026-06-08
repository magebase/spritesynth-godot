# SpriteSynth AI — Godot 4 Editor Plugin

Generate pixel art directly inside the Godot Editor using the SpriteSynth API.

## Features

- **Editor Dock** — left-side dock with three tabs
- **Generate** — Text-to-pixel-art generation with prompt, size, seed, and negative prompt controls
- **History** — browse past generations, preview thumbnails, re-import or delete
- **Settings** — API key management with `$SPIRESYNTH_API_KEY` env var fallback
- **Auto-Import** — generated images are saved to `res://spritesynth/generations/` and the filesystem is refreshed automatically

## Installation

1. Copy `addons/spritesynth/` into your Godot project's `addons/` directory
2. Enable the plugin in **Project → Project Settings → Plugins** (toggle `Spritesynth` to **On**)
3. The SpriteSynth dock appears in the left dock area

## API Key

You need a SpriteSynth API key from [api.spritesynth.com](https://api.spritesynth.com).

**Priority order:**
1. `$SPIRESYNTH_API_KEY` environment variable (if set, ProjectSettings are ignored)
2. ProjectSettings (`spritesynth/api_key`), saved from the Settings tab

## Usage

### Generate Tab

1. Enter a prompt (e.g. "16-bit pixel art sword, game asset")
2. Set image size (default: `128x128`)
3. Optionally set a seed (-1 for random) and negative prompt
4. Click **Generate**
5. The generated image appears as a preview and is saved to `res://spritesynth/generations/`

### History Tab

- Scroll through past generations
- Click **Import** to re-import into the project
- Click **X** to remove an entry

### Settings Tab

- Enter and save your API key
- Click **Test Connection** to verify the key works
- **Clear History** removes all past entries and thumbnails

## API Endpoints

The plugin calls these SpriteSynth API endpoints:

| Endpoint | Purpose |
|---|---|
| `POST /api/generations/image` | Submit a generation job |
| `GET /api/generations/{job_id}` | Poll for completion |
| `GET {asset.url}` | Download generated PNG |

**Base URL:** `https://api.spritesynth.com/api`

## Development

The plugin is written in GDScript with `@tool` for editor-mode execution. All source files are in `addons/spritesynth/`.

### File Overview

| File | Purpose |
|---|---|
| `plugin.gd` | `EditorPlugin` — registers dock and autoloads |
| `spritesynth_dock.gd` | Dock controller with tab logic |
| `spritesynth_dock.tscn` | Dock scene layout |
| `spritesynth_client.gd` | HTTP client (polling, download) |
| `spritesynth_settings.gd` | Settings manager (ProjectSettings + env) |
| `spritesynth_history.gd` | History persistence (JSON) |
| `test_client.gd` | GUT test suite |

## License

MIT
