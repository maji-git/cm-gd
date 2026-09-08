extends GutTest

func test_netsync_authority() -> void:
	# Server can take authority if needed
	assert_true(NetSync.can_take_authority(1, 234, NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY))
	assert_true(NetSync.can_take_authority(1, 234, NetSync.NetSyncAuthorityMode.SHARED))
	
	# Other cannot take authority if is not the owner
	assert_false(NetSync.can_take_authority(22, 234, NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY))
	
	# Owner can take the authority
	assert_true(NetSync.can_take_authority(234, 234, NetSync.NetSyncAuthorityMode.SINGLE_AUTHORITY))
	assert_true(NetSync.can_take_authority(234, 234, NetSync.NetSyncAuthorityMode.SHARED))
	
	# Anyone can take the authority
	assert_true(NetSync.can_take_authority(22, 234, NetSync.NetSyncAuthorityMode.SHARED))
