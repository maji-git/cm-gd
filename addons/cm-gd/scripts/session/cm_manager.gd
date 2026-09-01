@tool
extends Node
class_name CMManager

var session: CMSession

func _enter_tree() -> void:
	if session == null:
		var p := get_parent()
		if p is CMSession:
			session = p
		else:
			push_error("Session not found")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var p := get_parent()
	if not p is CMSession:
		warnings.append("CM Managers must be a child of CMSession, reparent this to CMSession")
	return warnings
