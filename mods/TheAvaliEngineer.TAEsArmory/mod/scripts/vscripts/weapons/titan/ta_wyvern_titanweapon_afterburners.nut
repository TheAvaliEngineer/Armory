untyped

//		Func declarations
global function TArmory_Init_WyvernNorthstar_Afterburners

global function OnWeaponActivate_WyvernNorthstar_Afterburners

global function OnWeaponPrimaryAttack_WyvernNorthstar_Afterburners
#if SERVER
global function OnWeaponNpcPrimaryAttack_WyvernNorthstar_Afterburners
#endif

//		Data
//	Status effects
const float BLAST_SLOW_STRENGTH = 0.5
const float BLAST_SLOW_DURATION = 2.0

//		Functions
//	Init
void function TArmory_Init_WyvernNorthstar_Afterburners() {
	//  Precache weapon
    PrecacheWeapon( "ta_wyvern_titanweapon_afterburners" )

	//	Signaling
	RegisterSignal( "AfterburnerBlast" )

    #if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_wyvern_titanweapon_afterburners = "Afterburner Backblast",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	AddDamageCallbackSourceID( eDamageSourceId.ta_wyvern_titanweapon_afterburners, AfterburnerBlastOnDamage )
	#endif
}

//	Activation
void function OnWeaponActivate_WyvernNorthstar_Afterburners( entity weapon ) {
	//	Get owner
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	print("[TAEsArmory] OnWeaponActivate_WyvernNorthstar_Afterburners: Triggered")
}

//	Attack
var function OnWeaponPrimaryAttack_WyvernNorthstar_Afterburners( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireAfterburners( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_WyvernNorthstar_Afterburners( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireAfterburners( weapon, attackParams, false )
}
#endif

int function FireAfterburners( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	entity owner = weapon.GetWeaponOwner()

	//	Check if has flight weapon
	entity flightWeapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )
	if( !("changeRate" in flightWeapon.s) )
		return 0

	//	Start listener thread
	#if SERVER
	if( !("threadsStarted" in weapon.s) ) {
		thread AfterburnerBlastListener( owner, weapon )
		weapon.s.threadsStarted <- true
	}
	#endif

	#if SERVER
	//	Check if has mod already
	bool hasDive = flightWeapon.HasMod( "TArmory_Flight_DiveHelper" )
	bool hasRise = flightWeapon.HasMod( "TArmory_Flight_RiseHelper" )

	print("[TAEsArmory] FireAfterburners: hasDive = " + hasDive + ", hasRise = " + hasRise)

	if(	hasDive ) flightWeapon.RemoveMod( "TArmory_Flight_DiveHelper" )
	if(	hasRise ) flightWeapon.RemoveMod( "TArmory_Flight_RiseHelper" )


	//	Add mod
	if( flightWeapon.s.changeRate < 0. && !hasDive ) {
		print("[TAEsArmory] FireAfterburners: Dive")
		flightWeapon.AddMod( "TArmory_Flight_DiveHelper" )
	} else if( flightWeapon.s.changeRate > 0. && flightWeapon.s.flightReady && !hasRise ) {
		print("[TAEsArmory] FireAfterburners: Rise")
		flightWeapon.AddMod( "TArmory_Flight_RiseHelper" )
		flightWeapon.Signal( "StartFlight" )

		weapon.Signal( "AfterburnerBlast" )
	}
	#endif

	return weapon.GetAmmoPerShot()
}

#if SERVER
void function AfterburnerBlastListener( entity owner, entity blastWeapon ) {
	//	Signaling
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	blastWeapon.EndSignal( "OnDestroy" )

	//	Listener loop
	while(1) {
		blastWeapon.WaitSignal( "AfterburnerBlast" )

		//	Signal recieved
		print("[TAEsArmory] AfterburnerBlastListener: Doing blast")

		//	Play FX (stolen from FlyerHovers)
		CreateShake( owner.GetOrigin(), 80, 150, 0.50, 1500 )
		PlayFX( FLIGHT_CORE_IMPACT_FX, owner.GetOrigin() )

		//	Create projectile
		int damageFlags = blastWeapon.GetWeaponDamageFlags()
		blastWeapon.FireWeaponBolt( owner.GetOrigin(), <0, 0, -1.0>, 4500, damageFlags, damageFlags, false, 0 )
	}
}

void function AfterburnerBlastOnDamage( entity ent, var damageInfo ) {
	//	Add effects
	if( ent.IsPlayer() || ent.IsNPC() ) {
		//	Make sure titan is slowed (& not pilot)
		entity entToSlow = ent
		entity soul = ent.GetTitanSoul()

		if ( soul != null )
			entToSlow = soul

		//	Apply effects
		StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, BLAST_SLOW_STRENGTH, BLAST_SLOW_DURATION, 1.0 )
		StatusEffect_AddTimed( entToSlow, eStatusEffect.dodge_speed_slow, BLAST_SLOW_STRENGTH, BLAST_SLOW_DURATION, 1.0 )
	}
}
#endif
