@tool
@icon("res://addons/cm-gd/icons/CMSession.svg")
extends Node
## Root of CM Management nodes
class_name CMSession

var net: CMNetManager
var player: CMPlayerManager

func _enter_tree() -> void:
	_ensure_children()
	if not Engine.is_editor_hint():
		var parent_root := get_parent()
		var root_path := parent_root.get_path()
		var api := CMNetMultiplayerAPI.new()
		get_tree().set_multiplayer(api, root_path)
		CM.set_session(self, parent_root)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		CM.set_session(self, null)

func _ensure_children() -> void:
	if not has_node("Net"):
		net = CMNetManager.new()
		net.name = "Net"
		add_child(net, true)
		if Engine.is_editor_hint():
			net.owner = get_tree().edited_scene_root
	
	if not has_node("Player"):
		player = CMPlayerManager.new()
		player.name = "Player"
		add_child(player, true)
		if Engine.is_editor_hint():
			player.owner = get_tree().edited_scene_root
	
	net = get_node("Net")
	player = get_node("Player")
