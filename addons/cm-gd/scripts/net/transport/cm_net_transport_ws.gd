extends CMNetTransportBase
class_name CMNetTransportWebSocket

@export_subgroup("Host", "host_")
@export var host_bind_ip: String = "*"
@export var host_port: int = 6967
@export_subgroup("Client", "connect_")
@export var connect_url: String
var tls_server_options: TLSOptions = null
var peer: WebSocketMultiplayerPeer

func net_host() -> MultiplayerPeer:
	peer = WebSocketMultiplayerPeer.new()
	peer.create_server(host_port, host_bind_ip, tls_server_options)
	return peer

func net_connect() -> MultiplayerPeer:
	peer = WebSocketMultiplayerPeer.new()
	peer.create_client(connect_url, tls_server_options)
	return peer
