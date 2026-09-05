@tool
@icon("res://addons/cm-gd/icons/CMNetManager.svg")
extends CMManager
## Network Manager for CMSession
class_name CMNetManager

signal server_connecting
signal server_connected
signal server_connection_failure
signal server_disconnected
signal net_activated
signal net_stopped

signal peer_joined(peer: CMNetPeer)
signal peer_left(peer: CMNetPeer)
signal _local_peer_joined(player: CMPlayer)

var current_multiplayer_peer: MultiplayerPeer

## Maximum amount of player a peer is allowed to create
@export var max_players_per_peer := 1
## Transport to use
@export var transport: CMNetTransportBase
## Optional Callable that determines if peer should be allowed to spawn the player, parameter is (peer: CMNetPeer). should return a boolean
var allow_player_condition: Callable

@export_subgroup("RPC Settings", "rpc_")
## If true, RPC that came from server will bypass authority check, making authority also owns by server.
## This only overrides rpc's behavior, not anything else like is_multiplayer_authority()
@export var rpc_server_bypass_authority_check: bool = false

@export_subgroup("Debug")
## Transport to use when debugging, if not set. transport will be used
@export var debug_transport: CMNetTransportBase
## Debug window title, if true. Window title will change to the peer ID which helps you identify what peer that window is.
## Only works in debug builds
@export var debug_window_title: bool = true
## Debug warning, if true. CM will log warning telling what peer it is in the debugger, helping you identify what peer that debug session is.
## Only works in debug builds
@export var debug_warning: bool = true

## Is the current machine the server
var is_server := false
## Is currently connected to the server
var is_connected_to_server := false
## Is network active
var is_net_active := false
var my_peer_id: int = 0
var local_peer: CMNetPeer

var peer_id_to_peer: Dictionary[int, CMNetPeer] = {}

@onready var _is_debug: bool = OS.is_debug_build()

## Array of all connected peers
var connected_peers: Array[CMNetPeer]:
	get:
		return peer_id_to_peer.values()

## Array of all connected peers (except the local peer)
var remote_peers: Array[CMNetPeer]:
	get:
		var result: Array[CMNetPeer] = []
		for peer in connected_peers:
			if peer.peer_id != my_peer_id:
				result.append(peer)
		return result

## Array of peers, including one that's currently connecting
var raw_peers: Array[CMNetPeer]:
	get:
		return peer_id_to_peer.values()

enum _PlayerCreateFailureReasonCode {
	UNKNOWN = 0,
	MAXIMUM_PLAYER_COUNT_REACHED = 1,
	MAXIMUM_PLAYER_COUNT_PER_PEER_REACHED = 2,
}

func _enter_tree() -> void:
	super()
	if Engine.is_editor_hint(): return
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_disconnected_from_server)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop_net()

func _pick_transport() -> CMNetTransportBase:
	if OS.has_feature("editor") and debug_transport != null:
		return debug_transport
	return transport

func start_server() -> void:
	_deinit_before_start_new() # Cleanup Previous Multiplayer Peer before starting a new one
	
	if _is_debug and debug_warning:
		push_warning("[CM] Server")
	
	var t := _pick_transport()
	if t == null:
		assert(false, "start_server: Transport is null, cannot start server")
		return
	
	current_multiplayer_peer = t.net_host()
	multiplayer.multiplayer_peer = current_multiplayer_peer
	
	is_server = true
	is_net_active = true
	
	# Assign 1 to itself
	my_peer_id = 1
	
	if not local_peer:
		_init_peer_from_rpc_id(1)
	
	# Assign existing peers to this
	for p in session.player.players:
		_assign_player_to_netpeer(p, local_peer)
	
	net_activated.emit()
	_debug_update_wintitle()

func start_client() -> void:
	_deinit_before_start_new() # Cleanup Previous Multiplayer Peer before starting a new one
	
	var t := _pick_transport()
	if t == null:
		assert(false, "start_client: Transport is null, cannot start client")
		return
	
	server_connecting.emit()
	current_multiplayer_peer = t.net_connect()
	multiplayer.multiplayer_peer = current_multiplayer_peer

func start_offline() -> void:
	transport = CMNetTransportOffline.new()
	debug_transport = null
	start_server()
	if _is_debug and debug_warning:
		push_warning("[CM] -> Offline mode")

# Deinit but keep the local peer
func _deinit_before_start_new() -> void:
	_deinit_mpeer()
	_cleanup_net(true)

# Deinit (close) multiplayer peer
func _deinit_mpeer() -> void:
	if current_multiplayer_peer != null:
		current_multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func stop_net() -> void:
	if not is_net_active: return
	is_net_active = false
	_deinit_mpeer()
	_cleanup_net()
	my_peer_id = 0
	local_peer = null
	net_stopped.emit()
	_debug_update_wintitle()

func _cleanup_net(except_local: bool = false) -> void:
	@warning_ignore("untyped_declaration")
	for v: int in peer_id_to_peer.duplicate().keys():
		if except_local and v == my_peer_id: continue
		_peer_disconnected(v)

func _connection_failed() -> void:
	server_connection_failure.emit()

func _connected_to_server() -> void:
	is_net_active = true
	my_peer_id = multiplayer.get_unique_id()
	_debug_update_wintitle()
	# request peer from server
	_net_req_peer.rpc_id(1)
	
	if _is_debug and debug_warning:
		push_warning("[CM] Client (Peer ID: %d)" % [my_peer_id])

func _disconnected_from_server() -> void:
	is_connected_to_server = false
	server_disconnected.emit()
	stop_net()

func get_peer_from_rpc_id(id: int) -> CMNetPeer:
	if peer_id_to_peer.has(id):
		return peer_id_to_peer[id]
	return null

@rpc("reliable", "any_peer")
func _net_req_peer() -> void:
	# Init peer
	var peer_id := multiplayer.get_remote_sender_id()
	_init_peer_from_rpc_id(peer_id)
	_net_req_peer_complete.rpc_id(peer_id)

func _add_player_async() -> CMPlayer:
	if is_net_active == false:
		push_warning("add_player_async: network is not active, cannot add new player")
		return null
	
	# Use reference type because variables inside lambda are local
	var state := {"result": null, "resolved": false}
	
	var on_joined := func(plr: CMPlayer) -> void:
		state.result = plr
		state.resolved = true
	
	_local_peer_joined.connect(on_joined, CONNECT_ONE_SHOT)
	_net_new_player.rpc_id(1)
	
	if state.resolved:
		return state.result
	
	return await _local_peer_joined

func _remove_player(plr: CMPlayer) -> void:
	_net_remove_player.rpc_id(1, plr.player_id)

@rpc("reliable", "authority")
func _net_req_peer_complete() -> void:
	is_connected_to_server = true
	server_connected.emit()
	net_activated.emit()
	_debug_update_wintitle()

@rpc("reliable", "any_peer", "call_local")
func _net_new_player() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	_init_player_from_rpc_id(peer_id)

@rpc("reliable", "any_peer", "call_local")
func _net_remove_player(id: int) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	
	var peer := get_peer_from_rpc_id(peer_id)
	if peer == null: return

	var plr: CMPlayer = peer.id_to_player.get(id)
	if plr == null: return

	if does_peer_owns_plr(peer, plr) == false:
		return
	
	_deinit_player_from_id.rpc(id)

func does_peer_owns_plr(peer: CMNetPeer, plr: CMPlayer) -> bool:
	return peer.players.has(plr)

func _init_peer_from_rpc_id(peer_id: int) -> void:
	var peer: CMNetPeer = _init_peer_for_rpc_id(peer_id)
	
	# if already initalized, return
	if peer.initializing or peer.initialized:
		return

	peer.initializing = true
	
	for ep in connected_peers:
		# Cross introduce each other
		_net_init_newpeer.rpc_id(ep.peer_id, peer.peer_id, peer.player_ids)
		_net_init_newpeer.rpc_id(peer.peer_id, ep.peer_id, ep.player_ids)
	
	peer.initializing = false
	peer.initialized = true

@rpc("authority", "reliable", "call_local")
func _deinit_player_from_id(id: int) -> void:
	var plr := session.player.get_player_by_id(id)
	if plr != null:
		session.player._remove_player(plr)

func _init_player_from_rpc_id(peer_id: int) -> void:
	var peer: CMNetPeer = _init_peer_for_rpc_id(peer_id)
	
	if session.player.player_count >= session.player.max_players:
		_plr_req_failure.rpc_id(peer_id, _PlayerCreateFailureReasonCode.MAXIMUM_PLAYER_COUNT_REACHED)
		return
	
	if peer.players.size() >= max_players_per_peer:
		_plr_req_failure.rpc_id(peer_id, _PlayerCreateFailureReasonCode.MAXIMUM_PLAYER_COUNT_PER_PEER_REACHED)
		return
	
	if not allow_player_condition.is_null():
		@warning_ignore("untyped_declaration")
		var should_allow = allow_player_condition.call(peer)
		if not should_allow: return
	
	var plrnum := session.player._assign_id()
	
	for p in connected_peers:
		broadcast_net_player(plrnum, peer_id)

@rpc("authority", "reliable", "call_local")
func _plr_req_failure(reason: _PlayerCreateFailureReasonCode) -> void:
	push_error("Player request failure: ", _PlayerCreateFailureReasonCode.keys()[reason])
	_local_peer_joined.emit(null)

func broadcast_net_player(id: int, rpc_owner: int, only_to_peer_id: int = -1) -> void:
	if only_to_peer_id == -1:
		_net_spawn_player.rpc(id, rpc_owner)
	else:
		_net_spawn_player.rpc_id(only_to_peer_id, id, rpc_owner)

@rpc("authority", "call_local", "reliable")
func _net_spawn_player(id: int, owner_peer_id: int) -> CMPlayer:
	# Ensure the peer exists locally in-case _net_init_newpeer hasn't arrived yet
	var peer := _init_peer_for_rpc_id(owner_peer_id)
	
	# Player of this ID already exists
	if peer.player_ids.has(id): return peer.id_to_player[id]
	
	var cmplr := session.player._register_player(id)
	_assign_player_to_netpeer(cmplr, peer)
	session.player._finalize_player(cmplr)
	cmplr._spawn_player_node()
	
	if cmplr.is_local:
		_local_peer_joined.emit(cmplr)
	
	return cmplr

func _assign_player_to_netpeer(cmplr: CMPlayer, peer: CMNetPeer) -> void:
	cmplr.net_peer = peer
	cmplr.set_multiplayer_authority(peer.peer_id)
	cmplr.is_local = my_peer_id == peer.peer_id
	peer.players.append(cmplr)
	peer.id_to_player[cmplr.player_id] = cmplr

@rpc("authority", "call_local", "reliable")
func _net_init_newpeer(peer_id: int, plrids: Array[int] = []) -> void:
	_init_peer_for_rpc_id(peer_id, plrids)

func _init_peer_for_rpc_id(peer_id: int, plrids: Array[int] = []) -> CMNetPeer:
	if peer_id_to_peer.has(peer_id):
		var existing: CMNetPeer = peer_id_to_peer[peer_id]
		if peer_id != -1 and existing.peer_id == -1:
			existing.peer_id = peer_id
			peer_id_to_peer[peer_id] = existing
		return existing

	var peer := CMNetPeer.new()
	peer.peer_id = peer_id
	peer.net = self
	peer.is_local = peer_id == my_peer_id
	peer.name = "peer_" + str(peer_id)
	peer_id_to_peer[peer_id] = peer
	if peer_id == my_peer_id:
		local_peer = peer
	add_child(peer, true)
	
	peer_joined.emit(peer)
	
	# Init plr ids if exist
	for plrid in plrids:
		_net_spawn_player(plrid, peer_id)
	
	return peer

func _peer_disconnected(id: int) -> void:
	var peer := get_peer_from_rpc_id(id)
	if peer == null: return
	
	peer_left.emit(peer)
	
	# Cleanup player
	_cleanup_plrs_in_peer(peer)
	
	# Cleanup peer
	peer_id_to_peer.erase(id)
	peer.queue_free()

func _cleanup_plrs_in_peer(peer: CMNetPeer) -> void:
	@warning_ignore("untyped_declaration")
	for plr in peer.players.duplicate():
		if is_instance_valid(plr):
			session.player._remove_player(plr as CMPlayer)

func _rpc_raw(peer: int, object: Object, method_name: StringName, args: Array) -> Error:
	if object is Node:
		var n := object as Node
		var s: Script = n.get_script()
		if s != null:
			# Read RPC Config
			var rpc_conf: Dictionary = s.get_rpc_config()
			var fu: Dictionary = rpc_conf.get(method_name)
			var transfer_mode := MultiplayerPeer.TransferMode.TRANSFER_MODE_RELIABLE
			var call_local := false
			if fu:
				if fu.has("transfer_mode"):
					transfer_mode = fu.transfer_mode
				if fu.has("call_local"):
					call_local = fu.call_local
			
			var rpc2call: Callable
			if transfer_mode == MultiplayerPeer.TransferMode.TRANSFER_MODE_RELIABLE:
				rpc2call = _net_rpc_recv_r
			else:
				rpc2call = _net_rpc_recv_uro
			
			var call_myself_too := false
			
			if peer == 0: # Call every remote peers (everyone)
				for pid in remote_peers:
					rpc2call.rpc_id(pid.peer_id, n.get_path(), method_name, args)
				call_myself_too = true
			elif peer == my_peer_id: # Call yourself
				call_myself_too = true
			else: # (Call a specific peer)
				rpc2call.rpc_id(peer, n.get_path(), method_name, args)
			
			# Handle call_local
			if call_local and call_myself_too:
				var t_callable := Callable(n, method_name)
				CM.rpc_sender_id = my_peer_id
				if local_peer and is_instance_valid(local_peer):
					CM.rpc_sender_peer = local_peer
				t_callable.callv(args)
				CM.rpc_sender_id = -1
				CM.rpc_sender_peer = null
		return OK
	return ERR_BUG

@rpc("any_peer", "reliable")
func _net_rpc_recv_r(obj_path: NodePath, method_name: String, args: Array) -> void:
	_net_rpc_handler(true, obj_path, method_name, args, multiplayer.get_remote_sender_id())

@rpc("any_peer", "unreliable_ordered")
func _net_rpc_recv_uro(obj_path: NodePath, method_name: String, args: Array) -> void:
	_net_rpc_handler(false, obj_path, method_name, args, multiplayer.get_remote_sender_id())

func _net_rpc_handler(_is_reliable: bool, obj_path: NodePath, method_name: String, args: Array, from_peer_id: int) -> void:
	var n: Node = get_node_or_null(obj_path)
	if n != null:
		var s: Script = n.get_script()
		if s != null:
			var rpc_conf: Dictionary = s.get_rpc_config()
			if not rpc_conf.has(method_name):
				# Method name doesn't exist
				return
			var fu: Dictionary = rpc_conf[method_name]
			
			if fu != null:
				var rpc_mode: int = fu.get("rpc_mode", MultiplayerAPI.RPC_MODE_AUTHORITY)
				var can_call := false
				var n_authority := n.get_multiplayer_authority()
				
				if rpc_mode == MultiplayerAPI.RPC_MODE_ANY_PEER:
					can_call = true
				elif rpc_mode == MultiplayerAPI.RPC_MODE_AUTHORITY:
					# Allows from authority only
					if from_peer_id == n_authority or (rpc_server_bypass_authority_check and from_peer_id == 1):
						can_call = true
				
				var from_peer := get_peer_from_rpc_id(from_peer_id)

				if from_peer == null:
					push_error("_net_rpc_handler: received RPC from invalid peer with peer_id %d" % from_peer_id)
					return
				
				if can_call:
					CM.rpc_sender_id = from_peer_id
					CM.rpc_sender_peer = from_peer
					n.callv(method_name, args)
					CM.rpc_sender_peer = null
					CM.rpc_sender_id = -1
				else:
					push_error("Cannot call '%s' on %s, network owner is %d but is called by %d" % [method_name, obj_path, n_authority, from_peer_id])

func _debug_update_wintitle() -> void:
	if _is_debug and debug_window_title:
		# wait a bit because godot overrides the window title at the beginning
		await get_tree().process_frame
		
		DisplayServer.window_set_title(\
		"%s (Peer ID: %d)" % \
		[ProjectSettings.get_setting("application/config/name"), my_peer_id])
