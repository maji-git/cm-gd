extends GutTest

func _newcm() -> CMSession:
	# create node container
	var n := Node.new()
	add_child(n, true)
	autofree(n)
	
	var c := CMSession.new()
	n.add_child(c, true)
	return c

func test_host_client() -> void:
	var cm1 := _newcm()
	var cm2 := _newcm()
	var transport := CMNetTransportOffline.new()
	cm1.net.transport = transport
	cm2.net.transport = transport
	
	# Start host and clients
	cm1.net.start_server()
	cm2.net.start_client()
	assert_true(cm1.net.is_server)
	assert_true(cm1.net.is_net_active)
	assert_true(cm2.net.is_connected_to_server)
	
	# Stop net
	cm2.net.stop_net()
	
	cm1.free()
	cm2.free()

func test_switch_mode() -> void:
	var cm1 := _newcm()
	var cm2 := _newcm()
	var transport := CMNetTransportOffline.new()
	
	# CM1 switches mode
	cm1.net.start_offline()
	cm1.net.start_server()

	# CM2 tries to connect now
	cm2.net.transport = transport
	cm2.net.start_client()
	assert_true(cm2.net.is_connected_to_server)
	
	cm1.free()
	cm2.free()

class TestPlayerSpawner extends CMPlayerSpawnerBase:
	func spawn_player(_plr: CMPlayer) -> Node:
		return Node.new()

	func despawn_player(plr: CMPlayer) -> void:
		plr.player_node.queue_free()
