//		Function declarations
global function TArmory_Init_MortarTone_DomeShield

global function OnWeaponPrimaryAttack_MortarTone_DomeShield
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_DomeShield
#endif

//		Data
//	Deploy angle


//			Functions
//		Init
void function TArmory_Init_MortarTone_Rockets() {
	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titanability_domeshield" )
	#endif
}

//		Fire handling
global function OnWeaponPrimaryAttack_MortarTone_DomeShield( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return LaunchDomeShield( weapon, attackParams, true )
}


#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_DomeShield( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return LaunchDomeShield( weapon, attackParams, false )
}
#endif

int function LaunchDomeShield( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Sanity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0
	
	//	Direction handling
	attackParams.dir.z = min( attackParams.dir.z, 0.2588 )

	//	Create deployable
	float throwPower = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
	entity deployable = ThrowDeployable( weapon, attackParams, throwPower, OnDomeShieldPlanted )

	//	Offhand
	if( owner.IsPlayer() )
		PlayerUsedOffhand( owner, weapon )

	//	Ammo
	return weapon.GetAmmoPerShot()
}

//	Collision handling
void function OnDomeShieldPlanted( entity proj, vector pos, vector norm, entity hitEnt, int hitbox, bool isCrit ) {
	//	Sanity checks
	entity owner = proj.GetOwner()
	if( !IsValid(owner) )
		return

	//	Handle sticky flares
	bool place = true

	if( hitEnt.IsWorld() ) {
		float dot = norm.Dot( Vector( 0, 0, 1 ) )
		place = place && (dot > 0.8)
	}

	if( !place )
		return
	
	//	Attempt planted
	table params = { pos = pos, norm = norm, hitEnt = hitEnt, hitbox = hitbox }
	bool planted = PlantStickyEntity( proj, params )
	if( !planted )
		return

	//	Start thread
	#if SERVER
	thread DomeShieldThink( proj )
	#endif
}

void function DomeShieldThink( entity proj ) {
	//	Setup dome shield

}