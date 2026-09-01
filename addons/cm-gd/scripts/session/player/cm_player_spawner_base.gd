@abstract
@icon("res://addons/cm-gd/icons/CMPlayerSpawnerBase.svg")
extends Node
class_name CMPlayerSpawnerBase

@abstract func spawn_player(plr: CMPlayer) -> Node

@abstract func despawn_player(plr: CMPlayer) -> void
