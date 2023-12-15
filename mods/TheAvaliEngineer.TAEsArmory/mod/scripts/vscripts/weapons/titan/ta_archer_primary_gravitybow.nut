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


	//		Triggers
	int range = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosionRadius )

	//	Gravity
	entity gravTrig = CreateEntity( "trigger_point_gravity" )
	SetTeam( gravTrig, projectile.GetTeam() )
	gravTrig.SetOrigin( projectile.GetOrigin() )
	gravTrig.RoundOriginAndAnglesToNearestNetworkValue()

	//	Normal
	entity trig = CreateEntity( "trigger_cylinder" )
	SetTeam( trig, projectile.GetTeam() )
	trig.SetOrigin( projectile.GetOrigin() )

	trig.SetRadius( range )
	trig.SetAboveHeight( range )
	trig.SetBelowHeight( range )

	SetGravityGrenadeTriggerFilters( projectile, trig )

	//trig.SetEnterCallback( OnGravGrenadeTrigEnter )
	//trig.SetLeaveCallback( OnGravGrenadeTrigLeave )

	//	Spawn & such
	DispatchSpawn( gravTrig )
	gravTrig.SearchForNewTouchingEntity()

	DispatchSpawn( trig )
	trig.SearchForNewTouchingEntity()
}

//	Trigger handling
void function OnGravTriggerEnter( entity trigger, entity ent ) {}
void function OnGravTriggerLeave( entity trigger, entity ent ) {}