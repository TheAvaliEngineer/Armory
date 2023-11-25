//		Func declarations
global function OnWeaponPrimaryAttack_TyrantLegion_Autocannon
#if SERVER
global function OnWeaponNpcPrimaryAttack_TyrantLegion_Autocannon
#endif

//	Data
const float[2][4] boltOffsets = [
	[ 0.2,  0.2],
	[ 0.2, -0.2],
	[-0.2, -0.2],
	[-0.2,  0.2]
]

//		Functions
//	Fire handling
var function OnWeaponPrimaryAttack_TyrantLegion_Autocannon( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireNormalAutocannon( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_TyrantLegion_Autocannon( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireNormalAutocannon( weapon, attackParams, false )
}
#endif

int function FireNormalAutocannon( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	//	Firing check
	entity owner = weapon.GetWeaponOwner()
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	//	ADS spread tightening effect
	float zoomFrac = 0.5
	if( playerFired ) {
		zoomFrac = owner.GetZoomFrac()
	}

	float boltSpreadMin = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_spread_min"	 ) )
	float boltSpreadMax = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_spread_max" ) )

    float spreadFrac = Graph( zoomFrac, 0, 1, boltSpreadMax, boltSpreadMin )

	print("[TAEsArmory] FireNormalAutocannon: spreadFrac = " + spreadFrac)

	//	Projectile spawning
	array<entity> projectiles
	if ( shouldCreateProjectile ) {
		int numProjectiles = weapon.GetProjectilesPerShot()
		Assert( numProjectiles <= boltOffsets.len() )

		for ( int index = 0; index < numProjectiles; index++ ) {
			vector upVec = baseUpVec * boltOffsets[index][0] * spreadFrac
			vector rightVec = baseRightVec * boltOffsets[index][1] * spreadFrac

			vector attackDir = attackParams.dir + upVec + rightVec

			int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
			int damageFlags = weapon.GetWeaponDamageFlags()

			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackDir, boltSpeed, damageFlags, damageFlags, playerFired, index )
			if ( bolt != null ) {
				bolt.kv.gravity = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_gravity_amount" ) )
				projectiles.append( bolt )
			}
		}
	}

	return 4
}