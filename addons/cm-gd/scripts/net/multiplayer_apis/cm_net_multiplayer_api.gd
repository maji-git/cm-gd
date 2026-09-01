extends MultiplayerAPIExtension
class_name CMNetMultiplayerAPI

var base_multiplayer := SceneMultiplayer.new()

func _init() -> void:
	var cts := connected_to_server
	var cf := connection_failed
	var sd := server_disconnected
	var pc := peer_connected
	var pd := peer_disconnected
	base_multiplayer.connected_to_server.connect(func() -> void: cts.emit())
	base_multiplayer.connection_failed.connect(func() -> void: cf.emit())
	base_multiplayer.server_disconnected.connect(func() -> void: sd.emit())
	base_multiplayer.peer_connected.connect(func(id: int) -> void: pc.emit(id))
	base_multiplayer.peer_disconnected.connect(func(id: int) -> void: pd.emit(id))

func _poll() -> Error:
	return base_multiplayer.poll()

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	var node := object as Node
	if node is not CMNetManager and node:
		var session := CM.get_session(node)
		if session:
			return session.net._rpc_raw(peer, object, method, args)
	return base_multiplayer.rpc(peer, object, method, args)

func _object_configuration_add(object: Object, config: Variant) -> Error:
	return base_multiplayer.object_configuration_add(object, config)

func _object_configuration_remove(object: Object, config: Variant) -> Error:
	return base_multiplayer.object_configuration_remove(object, config)

func _set_multiplayer_peer(p_peer: MultiplayerPeer) -> void:
	base_multiplayer.multiplayer_peer = p_peer

func _get_multiplayer_peer() -> MultiplayerPeer:
	return base_multiplayer.multiplayer_peer

func _get_unique_id() -> int:
	return base_multiplayer.get_unique_id()

func _get_remote_sender_id() -> int:
	return base_multiplayer.get_remote_sender_id()

func _get_peer_ids() -> PackedInt32Array:
	return base_multiplayer.get_peers()
