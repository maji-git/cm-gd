@tool
extends EditorPlugin

var splash_inspector_plugin: EditorInspectorPlugin

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	splash_inspector_plugin = preload("res://addons/cm-gd/editor/scripts/splash_inspector_plugin.gd").new()
	add_inspector_plugin(splash_inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(splash_inspector_plugin)
