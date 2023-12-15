//		Func Decs
global function TAInit_Archer_GravityBow

global function OnWeaponPrimaryAttack_Archer_GravityBow
#if SERVER
global function OnWeaponNpcPrimaryAttack_Archer_GravityBow
#endif

global function OnWeaponReload_Archer_GravityBow
global function OnWeaponReadyToFire_Archer_GravityBow

//		Data

//		Funcs
//	Init
void function TAInit_Archer_GravityBow() {
	//  Precache weapon
    PrecacheWeapon( "ta_archer_primary_gravitybow" )

    #if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_archer_primary_gravitybow = "Gravity Bow",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Fire handling
var function OnWeaponPrimaryAttack_Archer_GravityBow( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireGravityBow( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Archer_GravityBow( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireGravityBow( weapon, attackParams, false )
}
#endif

int function FireGravityBow( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {

}

//	Reload handling
void function OnWeaponReload_GeistRonin_BurstSG( entity weapon, int milestoneIndex ) {
	//	Mod cleanup
	weapon.RemoveMod("TArmory_ChargedShot")
	weapon.RemoveMod("TArmory_ReloadHelper")

	entity owner = weapon.GetWeaponOwner()
	if( owner.GetWeaponAmmoLoaded(weapon) >= 1 ) {
		weapon.AddMod("TArmory_ChargedShot")
		#if SERVER
		StartChargeFX( weapon, owner )
		#endif
	}
}

void function OnWeaponReadyToFire_GeistRonin_BurstSG( entity weapon ) {
	bool isChargedShot = weapon.HasMod("TArmory_ChargedShot")
	if( !weapon.IsReloading() && !isChargedShot ) {
		weapon.AddMod("TArmory_ReloadHelper")
	}
}

//	Gravity handling
void function GravityArrowThink( entity projectile, entity hitEnt, vector normal, vector pos ) {
	//


	//	Create triggers


	entity trig = CreateEntity( "trigger_cylinder" )

	trig.SetRadius( PULL_RANGE )
	trig.SetAboveHeight( PULL_RANGE )
	trig.SetBelowHeight( PULL_RANGE )

	trig.SetOrigin( projectile.GetOrigin() )
	SetGravityGrenadeTriggerFilters( projectile, trig )

	trig.SetEnterCallback( OnGravGrenadeTrigEnter )
	trig.SetLeaveCallback( OnGravGrenadeTrigLeave )

	//	Spawn & such
}