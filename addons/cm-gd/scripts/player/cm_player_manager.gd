@tool
@icon("res://addons/cm-gd/icons/CMPlayerManager.svg")
extends CMManager
## Player Manager for CMSession
class_name CMPlayerManager

signal player_joined(player: CMPlayer)
signal player_left(player: CMPlayer)

## The player spawner
@export var max_players: int = 8
@export var player_spawner: CMPlayerSpawnerBase
@export_subgroup("Joypad Configuration")
## Determine if the manager should remove player when the joypad is disconnected
@export var auto_remove_disconnected_joy: bool = true

var id_to_player: Dictionary[int, CMPlayer] = {}
var joy_id_to_player: Dictionary[int, CMPlayer] = {}
var player_count: int:
	get:
		return id_to_player.size()
var players: Array[CMPlayer]:
	get:
		return id_to_player.values()

var _requesting_joy_ids: Array[int] = []

func _ready() -> void:
	if Engine.is_editor_hint(): return
	Input.joy_connection_changed.connect(_joy_connection_changed)

func _joy_connection_changed(device: int, connected: bool) -> void:
	# Auto remove player when the joy is disconnected
	if auto_remove_disconnected_joy and connected == false:
		remove_player_from_joy(device)

func _assign_id() -> int:
	var index := 0
	while id_to_player.has(index):
		index += 1
	return index

func get_player_by_id(id: int) -> CMPlayer:
	return id_to_player.get(id)

func _register_player(id: int) -> CMPlayer:
	var plr := CMPlayer.new()
	plr.player_id = id
	plr.player_manager = self
	plr.name = "player_" + str(id)
	id_to_player[id] = plr
	return plr

# Call this after player init has been finalized
func _finalize_player(plr: CMPlayer) -> void:
	add_child(plr, true)
	player_joined.emit(plr)

func _deregister_player(plr: CMPlayer) -> void:
	if not is_instance_valid(plr):
		return
	id_to_player.erase(plr.player_id)
	player_left.emit(plr)
	plr.queue_free()

## Request player from server
func add_player_async() -> CMPlayer:
	return await session.net._add_player_async()

## Remove player from everyone
func remove_player(plr: CMPlayer) -> void:
	if session.net.is_net_active:
		session.net._remove_player(plr)
	else:
		_remove_player(plr)

func _remove_player(plr: CMPlayer) -> void:
	if not is_instance_valid(plr):
		return
	var peer_owner := plr.net_peer
	peer_owner.players.erase(plr)
	peer_owner.id_to_player.erase(plr.player_id)
	plr._despawn_player_node()
	_deregister_player(plr)

## Add player that are using joy controller to play
func add_player_from_joy_async(device: int) -> CMPlayer:
	if _requesting_joy_ids.has(device):
		push_warning("add_player_from_joy_async: Joy %d is already requesting player" % device)
		return null
	if joy_id_to_player.has(device): return joy_id_to_player[device] # Already exists
	_requesting_joy_ids.append(device)
	
	var plr := await add_player_async()
	if plr != null:
		plr.local_device_id = device
		plr.input_type = CMPlayer.InputType.JOYPAD
		
		joy_id_to_player[device] = plr
	_requesting_joy_ids.erase(device)
	return plr

## Remove player that are using joy controller to play
func remove_player_from_joy(device: int) -> void:
	if joy_id_to_player.has(device):
		var plr := joy_id_to_player[device]
		remove_player(plr)
		joy_id_to_player.erase(device)

## Get player from the joy
func get_player_from_joy(device: int) -> CMPlayer:
	return joy_id_to_player.get(device)
