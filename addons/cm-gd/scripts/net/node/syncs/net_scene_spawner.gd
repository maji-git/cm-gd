@icon("res://addons/cm-gd/icons/NetSceneSpawner.svg")
extends Node
class_name NetSceneSpawner

signal node_spawned(node: Node)
signal node_despawned(node: Node)

@export var scene_paths: Array[PackedScene] = []
@export var authority_mode := NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY

var tracked_objects: Array[Node] = []

var session: CMSession
var net: CMNetManager
var parent: Node

func _enter_tree() -> void:
	session = CM.get_session(self)
	net = session.net
	parent = get_parent()
	_refresh_authority()

func _ready() -> void:
	if net.is_net_active:
		_net_activated()
	else:
		net.net_activated.connect(_net_activated)
	
	parent.child_entered_tree.connect(_cet)
	parent.child_exiting_tree.connect(_cxt)

func _refresh_authority() -> void:
	set_multiplayer_authority(parent.get_multiplayer_authority())

func _net_activated() -> void:
	# Request scenes from owner when starting
	if is_multiplayer_authority() == false:
		_net_req_scenes.rpc_id(get_multiplayer_authority())

# Child Entering
func _cet(n: Node) -> void:
	if n.scene_file_path == "": return # No scene
	if scene_paths.has(n.scene_file_path) == false: return
	if tracked_objects.has(n): return
	
	broadcast_scene(n)

# Child Exiting
func _cxt(n: Node) -> void:
	if n.scene_file_path == "": return # No scene
	if scene_paths.has(n.scene_file_path) == false: return
	if not tracked_objects.has(n): return
	
	broadcast_scene_remove(n)

@rpc("any_peer", "reliable")
func _net_req_scenes() -> void:
	var from := CM.rpc_sender_peer
	for p in tracked_objects:
		broadcast_scene(p, from, true)

func broadcast_scene(n: Node, to_peer: CMNetPeer = null, mark_as_spawn: bool = false) -> void:
	# Check authority on authority mode first
	if is_multiplayer_authority() == false and authority_mode == NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	
	var tocall := _ss_authority
	var scene2do := n.scene_file_path
	var name2 := n.name
	var authority := n.get_multiplayer_authority()
	
	if scene_paths.has(scene2do) == false:
		push_error("Scene must be included in scene_paths for it to be replicated")
		return
	
	if name2.contains("@"):
		push_error(name2, "'s name must be unique, make sure you added the node with add_child(_, true)")
		return
	
	if to_peer == null and tracked_objects.has(n):
		return
	
	if not tracked_objects.has(n):
		tracked_objects.append(n)
	
	if authority_mode == NetSync.NetSyncAuthorityMode.SHARED:
		tocall = _ss_any
	if to_peer:
		tocall.rpc_id(to_peer.peer_id, scene2do, name2, authority, mark_as_spawn)
	else:
		tocall.rpc(scene2do, name2, authority, mark_as_spawn)


func broadcast_scene_remove(n: Node, to_peer: CMNetPeer = null) -> void:
	# Check authority on authority mode first
	if not net.is_net_active: return
	if is_multiplayer_authority() == false and authority_mode == NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	var scene2do := n.scene_file_path

	if scene_paths.has(scene2do) == false:
		push_error("Scene must be included in scene_paths for it to be replicated")
		return
	
	if to_peer == null and not tracked_objects.has(n):
		return
	
	if tracked_objects.has(n):
		tracked_objects.erase(n)
	
	var tocall := _sx_authority
	var name2 := n.name
	if authority_mode == NetSync.NetSyncAuthorityMode.SHARED:
		tocall = _sx_any
	
	if to_peer:
		tocall.rpc_id(to_peer.peer_id, name2)
	else:
		tocall.rpc(name2)

@rpc("any_peer", "reliable")
func _ss_any(scene2do: String, name2: String, authority: int, mark_as_spawn: bool) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SHARED: return
	_sync_scene(scene2do, name2, authority, mark_as_spawn)

@rpc("authority", "reliable")
func _ss_authority(scene2do: String, name2: String, authority: int, mark_as_spawn: bool) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	_sync_scene(scene2do, name2, authority, mark_as_spawn)

func _sync_scene(scene2do: String, name2: String, authority: int, mark_as_spawn: bool) -> void:
	if scene_paths.has(scene2do) == false:
		return
	
	if has_node(name2):
		# Node already exists
		return
	
	var res := load(scene2do)
	if res is PackedScene:
		var scene: Node = (res as PackedScene).instantiate()
		scene.name = name2
		scene.set_multiplayer_authority(authority)
		tracked_objects.append(scene)
		if mark_as_spawn:
			scene.set_meta("cm_auto_spawned", true)
		parent.add_child(scene, true)
		node_spawned.emit(scene)

@rpc("any_peer", "reliable")
func _sx_any(name2: String) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SHARED: return
	_syncx_scene(name2)

@rpc("authority", "reliable")
func _sx_authority(name2: String) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	_syncx_scene(name2)

func _syncx_scene(name2: String) -> void:
	var n: Node = parent.get_node_or_null(name2)
	if n != null:
		if n.scene_file_path == "": return
		if scene_paths.has(n.scene_file_path) == false: return
		
		tracked_objects.erase(n)
		node_despawned.emit(n)
		n.free()
