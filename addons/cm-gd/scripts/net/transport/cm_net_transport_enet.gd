extends CMNetTransportBase
class_name CMNetTransportENet

@export var port: int = 6769
@export var connect_address: String = "127.0.0.1"
@export var host_bind_ip: String = "*"
@export var max_clients: int = 32
@export_subgroup("Advanced")
@export var max_channels: int = 0
@export var in_bandwidth: int = 0
@export var out_bandwidth: int = 0

var peer: ENetMultiplayerPeer

func net_host() -> MultiplayerPeer:
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(host_bind_ip)
	peer.create_server(port, max_clients, max_channels, in_bandwidth, out_bandwidth)
	return peer

func net_connect() -> MultiplayerPeer:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(connect_address, port)
	return peer
