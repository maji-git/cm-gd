@icon("res://addons/cm-gd/icons/CM.svg")
class_name CM

const VERSION = "0.0.1"

static var sessions: Array[CMSession] = []

## The RPC sender ID
static var rpc_sender_id: int
## The RPC sender Peer
static var rpc_sender_peer: CMNetPeer

static var nroot_to_session: Dictionary[Node, CMSession] = {}

## Set session at root node
static func set_session(sess: CMSession, at: Node) -> void:
	nroot_to_session[at] = sess
	if at == null:
		var k: Variant = nroot_to_session.find_key(sess)
		if k != null:
			nroot_to_session.erase(k)

## Get session from node
static func get_session(from: Node) -> CMSession:
	var n: Node = from
	while n:
		if nroot_to_session.has(n):
			return nroot_to_session[n]
		n = n.get_parent()
	return null
