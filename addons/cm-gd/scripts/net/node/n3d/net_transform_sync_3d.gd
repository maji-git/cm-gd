@icon("res://addons/cm-gd/icons/NetTransformSync3D.svg")
extends Node3D
class_name NetTransformSync3D

@export var sync_active := true
@export var sync_internal_sec: float = 0.05
@export var sync_speed: float = 15
@export var authority_mode := NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY
@export_category("Sync Options")
@export var sync_position := true
@export var sync_rotation := true
@export var sync_scale := false

var _has_authority := false
var _sync_target_position: Vector3
var _sync_target_rotation: Quaternion
var _sync_target_scale: Vector3
var _net_t: float = 0
var _is_sync_ready := false

var _old_transform: Transform3D

var owner_peer: CMNetPeer

var session: CMSession
var net: CMNetManager
var parent: Node3D

func _enter_tree() -> void:
	session = CM.get_session(self)
	net = session.net
	parent = get_parent()
	_refresh_authority()

func _ready() -> void:
	_refresh_authority()
	if net.is_net_active:
		_net_activated()
	else:
		net.net_activated.connect(_net_activated)
	net.peer_left.connect(_peer_left)

func _refresh_authority() -> void:
	if not net.is_net_active: return
	set_multiplayer_authority(parent.get_multiplayer_authority())

func _process(delta: float) -> void:
	if sync_active == false: return
	if _is_sync_ready == false: return
	if _has_authority:
		_net_t += delta
		
		if _net_t > sync_internal_sec:
			_net_t = 0
			broadcast_transform()
	else:
		if sync_position:
			parent.position = parent.position.lerp(_sync_target_position, delta * sync_speed)
		if sync_rotation:
			parent.quaternion = parent.quaternion.slerp(_sync_target_rotation, delta * sync_speed)
		if sync_scale:
			parent.scale = parent.scale.lerp(_sync_target_scale, delta * sync_speed)

func take_authority() -> void:
	if not net.is_net_active: return
	if is_multiplayer_authority() == false and authority_mode != NetSync.NetSyncAuthorityMode.SHARED:
		push_error("NetTransformSync3D: cannot take authority: this node is owned by peer %d. Set authority_mode to SHARED or call take_authority() from the owning peer.", get_multiplayer_authority())
		return
	
	_st_take_authority.rpc()

func _net_activated() -> void:
	if is_multiplayer_authority():
		take_authority()
	else:
		# Request transform
		_net_req_transform.rpc_id(get_multiplayer_authority())

func _peer_left(peer: CMNetPeer) -> void:
	if peer == owner_peer and net.is_server:
		take_authority()

@rpc("any_peer", "reliable")
func _net_req_transform() -> void:
	var from := CM.rpc_sender_peer
	broadcast_transform(true, from)

func broadcast_transform(snap: bool = false, to_peer: CMNetPeer = null) -> void:
	var curt := parent.transform
	if to_peer == null and _old_transform.is_equal_approx(curt):
		return
	_old_transform = curt
	var tocall := _st_authority
	if authority_mode == NetSync.NetSyncAuthorityMode.SHARED:
		tocall = _st_any
	if to_peer:
		tocall.rpc_id(to_peer.peer_id, parent.position, parent.quaternion, parent.scale, snap)
	else:
		tocall.rpc(parent.position, parent.quaternion, parent.scale, snap)

@rpc("any_peer", "unreliable_ordered")
func _st_any(pos: Vector3, rot: Quaternion, scl: Vector3, snap: bool) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SHARED: return
	_sync_transform(pos, rot, scl, snap)

@rpc("authority", "unreliable_ordered")
func _st_authority(pos: Vector3, rot: Quaternion, scl: Vector3, snap: bool) -> void:
	if authority_mode != NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	_sync_transform(pos, rot, scl, snap)

@rpc("any_peer", "reliable", "call_local")
func _st_take_authority() -> void:
	var from_peer := CM.rpc_sender_peer
	if not net.is_net_active: return
	if get_multiplayer_authority() != from_peer.peer_id and authority_mode == NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY: return
	owner_peer = from_peer
	_has_authority = from_peer.is_local
	if _has_authority:
		_is_sync_ready = true
		broadcast_transform(true)

func _sync_transform(pos: Vector3, rot: Quaternion, scl: Vector3, snap: bool) -> void:
	_sync_target_position = pos
	_sync_target_rotation = rot
	_sync_target_scale = scl
	
	if sync_active == false: return
	if snap:
		if sync_position:
			parent.position = pos
		if sync_rotation:
			parent.quaternion = rot
		if sync_scale:
			parent.scale = scl
	_is_sync_ready = true
