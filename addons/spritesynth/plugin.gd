@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
    add_custom_type("SpritesynthClient", "Node", preload("spritesynth_client.gd"), preload("icon.svg"))
    dock = preload("spritesynth_dock.tscn").instantiate()
    add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

func _exit_tree():
    remove_custom_type("SpritesynthClient")
    remove_control_from_dock(dock)
    dock.free()
