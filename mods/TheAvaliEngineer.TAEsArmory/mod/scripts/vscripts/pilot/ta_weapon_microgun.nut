global function OnWeaponPrimaryAttack_weapon_microgun
#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_microgun
#endif

var function OnWeaponPrimaryAttack_weapon_microgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	entity owner = weapon.GetWeaponOwner()

	if( owner.IsPlayer() ) {
		float zoomFrac = owner.GetZoomFrac()
		if ( zoomFrac < 0.5 )
			return 0
	}

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireMicrogun( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_microgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireMicrogun( weapon, attackParams, false )
}
#endif // #if SERVER

int function FireMicrogun( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if( shouldCreateProjectile ) {
		int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
		int damageFlags = weapon.GetWeaponDamageFlags()
		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )

		if( bolt != null ) {
			bolt.kv.gravity = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_gravity_amount" ) )

			#if CLIENT
			StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"Rocket_Smoke_SMR_Glow" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
			#endif // #if CLIENT
		}
	}

	return 1
}
