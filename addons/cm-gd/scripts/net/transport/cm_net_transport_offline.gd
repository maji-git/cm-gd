extends CMNetTransportBase
class_name CMNetTransportOffline

var peer: OfflineMultiplayerPeer

func net_host() -> MultiplayerPeer:
	peer = OfflineMultiplayerPeer.new()
	return peer

func net_connect() -> MultiplayerPeer:
	peer = OfflineMultiplayerPeer.new()
	return peer
