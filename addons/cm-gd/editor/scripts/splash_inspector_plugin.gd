@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is CMSession

func _parse_begin(_object: Object) -> void:
	add_custom_control((preload("res://addons/cm-gd/editor/scenes/inspector_splash.tscn").instantiate() as Control))
