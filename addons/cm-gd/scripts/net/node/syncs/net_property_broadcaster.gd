@icon("res://addons/cm-gd/icons/NetPropertyBroadcaster.svg")
extends Node
class_name NetPropertyBroadcaster

@export var authority_mode := NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY

var tracked_properties: Array[String] = []

var net: CMNetManager
var parent: Node
var session: CMSession

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

func _net_activated() -> void:
	if is_multiplayer_authority() == false:
		_net_req_props.rpc_id(get_multiplayer_authority())

func _refresh_authority() -> void:
	if not net.is_net_active: return
	set_multiplayer_authority(parent.get_multiplayer_authority())

@rpc("any_peer", "reliable")
func _net_req_props() -> void:
	var from := CM.rpc_sender_peer
	for p in tracked_properties:
		broadcast_property(p, from)

func broadcast_property(prop_name: String, to_peer: CMNetPeer = null) -> void:
	# Check authority on authority mode first
	if not net.is_net_active: return
	if is_multiplayer_authority() == false and authority_mode == NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	var tocall := _sp_authority
	var value: Variant = parent.get(prop_name)
	track_property(prop_name)
	
	if authority_mode == NetSync.NetSyncAuthorityMode.SHARED:
		tocall = _sp_any
	if to_peer:
		tocall.rpc_id(to_peer.peer_id, prop_name, value)
	else:
		tocall.rpc(prop_name, value)

@rpc("any_peer", "reliable")
func _sp_any(prop_name: String, value: Variant) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SHARED: return
	_sync_property(prop_name, value)

@rpc("authority", "reliable")
func _sp_authority(prop_name: String, value: Variant) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	_sync_property(prop_name, value)

func _sync_property(prop_name: String, value: Variant) -> void:
	parent.set(prop_name, value)
	track_property(prop_name)

## Start tracking the property, "tracking" the property will sync property when a peer spawns
func track_property(prop_name: String) -> void:
	if not tracked_properties.has(prop_name):
		tracked_properties.append(prop_name)

## Stop tracking the property
func untrack_property(prop_name: String) -> void:
	tracked_properties.erase(prop_name)
