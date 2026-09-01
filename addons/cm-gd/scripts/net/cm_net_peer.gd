@icon("res://addons/cm-gd/icons/CMNetPeer.svg")
extends Node
class_name CMNetPeer

var initialized := false
var initializing := false
var peer_id := 0
var is_local := false
var players: Array[CMPlayer] = []
var id_to_player: Dictionary[int, CMPlayer] = {}
var player_ids: Array[int]:
	get:
		var result: Array[int] = []
		for plr in players:
			result.append(plr.player_id)
		return result
var net: CMNetManager
