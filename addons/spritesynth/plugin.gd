@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/spritesynth/spritesynth_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR_1, dock)
	add_autoload_singleton("SpritesynthSettings", "res://addons/spritesynth/spritesynth_settings.gd")
	add_autoload_singleton("SpritesynthHistory", "res://addons/spritesynth/spritesynth_history.gd")


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

	remove_autoload_singleton("SpritesynthSettings")
	remove_autoload_singleton("SpritesynthHistory")


func has_main_screen() -> bool:
	return false
