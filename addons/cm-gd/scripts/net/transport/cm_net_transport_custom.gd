extends CMNetTransportBase
class_name CMNetTransportCustom

var peer: MultiplayerPeer

func _init(p: MultiplayerPeer) -> void:
	peer = p

func net_host() -> MultiplayerPeer:
	return peer

func net_connect() -> MultiplayerPeer:
	return peer
