@icon("res://addons/cm-gd/icons/CMPlayer.svg")
extends Node
class_name CMPlayer

signal player_type_changed(value: PlayerType)
signal input_type_changed(value: PlayerType)

## Is this player local?
var is_local := false

var player_manager: CMPlayerManager

## Local device ID, use this when sampling input from controller devices
var local_device_id: int = -1

## Player ID, This will use already allocated number if one doesn't exist yet
var player_id: int

## Networked peer, if it exists
var net_peer: CMNetPeer

## The view node, one that actually exists in your scene
var player_node: Node

## Player type of this player
var player_type: PlayerType = PlayerType.PLAYER:
	get:
		return player_type
	set(value):
		player_type = value
		player_type_changed.emit(value)
		_net_prop_sync.broadcast_property("player_type")

## Input type of this player
var input_type: InputType = InputType.KEYBOARD_AND_MOUSE:
	get:
		return input_type
	set(value):
		input_type = value
		input_type_changed.emit(value)
		_net_prop_sync.broadcast_property("input_type")

var _net_prop_sync := NetPropertyBroadcaster.new()

func _ready() -> void:
	_net_prop_sync.name = "PropertyBroadcast"
	add_child(_net_prop_sync, true)
	
	## Add basic sync functions
	_net_prop_sync.broadcast_property("player_type")
	_net_prop_sync.broadcast_property("input_type")

## Spawn the player
func spawn_player_node() -> void:
	_net_sdr_plr.rpc(0)

## Despawn the player
func despawn_player_node() -> void:
	_net_sdr_plr.rpc(1)

## Respawn the player
func respawn_player_node() -> void:
	_net_sdr_plr.rpc(2)

@rpc("any_peer", "call_local", "reliable")
func _net_sdr_plr(m: int) -> void:
	var sender := CM.rpc_sender_id
	if sender != 1 and sender != net_peer.peer_id and sender != multiplayer.get_unique_id():
		return
	if m == 0:
		_spawn_player_node()
	elif m == 1:
		_despawn_player_node()
	elif m == 2:
		_respawn_player_node()

func _spawn_player_node() -> void:
	if player_node != null:
		push_warning("CMPlayer: _spawn_player: player already exists, cannot spawn")
		return
	
	if player_manager.player_spawner != null:
		var plrn := player_manager.player_spawner.spawn_player(self)
		player_node = plrn
	else:
		push_warning("Can't spawn player ID: %d, there's no player_spawner" % [player_id])

func _despawn_player_node() -> void:
	if player_node == null:
		push_warning("CMPlayer: _despawn_player: player is null, cannot despawn")
		return
	
	if player_manager.player_spawner != null:
		player_manager.player_spawner.despawn_player(self)
		player_node = null
	else:
		push_warning("Can't despawn player ID: %d, there's no player_spawner" % [player_id])

func _respawn_player_node() -> void:
	if player_node == null:
		push_warning("CMPlayer: _respawn_player: player is null, cannot respawn")
		return
	
	_despawn_player_node()
	_spawn_player_node()

enum PlayerType {
	## A normal player
	PLAYER,
	## A Bot player, aka CPU player
	BOT,
	## A dummy player
	DUMMY
}

enum InputType {
	KEYBOARD_AND_MOUSE = 0,
	KEYBOARD = 1,
	MOUSE = 2,
	JOYPAD = 3,
}
