class_name NetSync

enum NetSyncAuthorityMode {
	SINGLE_AUTHORITY,
	SHARED
}

static func can_take_authority(from_id: int, owner_id: int, authority_mode: NetSyncAuthorityMode) -> bool:
	if authority_mode == NetSync.NetSyncAuthorityMode.SHARED:
		return true
	return from_id == 1 or from_id == owner_id