//		Func declarations
global function OnWeaponPrimaryAttack_WyvernNorthstar_AutoRocket
#if SERVER
global function OnWeaponNpcPrimaryAttack_WyvernNorthstar_AutoRocket
#endif

//		Funcs
var function OnWeaponPrimaryAttack_WyvernNorthstar_AutoRocket( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return AutoRocket_OnFire( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_WyvernNorthstar_AutoRocket( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return AutoRocket_OnFire( weapon, attackParams, false )
}
#endif

int function AutoRocket_OnFire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Validity check
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0

	bool doFire = IsServer() || weapon.ShouldPredictProjectiles()
	#if CLIENT
	doFire = doFire && playerFired
	#endif

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	if( doFire ) {
		vector bulletVec = ApplyVectorSpread( attackParams.dir, owner.GetAttackSpreadAngle() - 1.0 )
		attackParams.dir = bulletVec

		entity missile = weapon.FireWeaponMissile( attackParams.pos + bulletVec * 50, attackParams.dir,
			1.0, DF_GIB | DF_EXPLOSION, DF_GIB | DF_EXPLOSION, !playerFired, playerFired )
		if( missile ) {
			#if SERVER
			EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )

			missile.SetOwner( owner )
			#endif

			//	Tracking trace
			TraceResults result = TraceLine(
				owner.EyePosition(),
				owner.EyePosition() + attackParams.dir * 50000,
				[ owner ],
				TRACE_MASK_SHOT,
				TRACE_COLLISION_GROUP_BLOCK_WEAPONS
			)

			float speed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
			float trackDelay = Distance( missile.GetOrigin(), result.endPos ) / speed
			trackDelay = min( trackDelay - 0.15, 0 )

			missile.InitMissileForRandomDriftFromWeaponSettings( attackParams.pos, attackParams.dir )
			thread DelayedTrackingStart( missile, result.endPos, trackDelay )
		}
	}

	return weapon.GetAmmoPerShot()
}

void function DelayedTrackingStart( entity missile, vector targetPos, float delay ) {
	missile.EndSignal( "OnDestroy" )

	wait delay

	float speed = missile.GetProjectileWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
	missile.SetHomingSpeeds( speed * 1.5, 0 )
	missile.SetMissileTargetPosition( targetPos )
}