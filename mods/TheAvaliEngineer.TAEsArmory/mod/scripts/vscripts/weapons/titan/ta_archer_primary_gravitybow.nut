//		Func Decs
global function TAInit_Archer_GravityBow

global function OnWeaponPrimaryAttack_Archer_GravityBow
#if SERVER
global function OnWeaponNpcPrimaryAttack_Archer_GravityBow
#endif

global function OnWeaponReload_Archer_GravityBow
global function OnWeaponReadyToFire_Archer_GravityBow

//		Data
//	Charge behavior
const int CHARGE_SHOT_LEVEL = 2
const int POWER_SHOT_LEVEL = 5

//		Funcs
//	Init
void function TAInit_Archer_GravityBow() {
    #if SERVER
	//  Precache weapon
	PrecacheWeapon( "ta_archer_primary_gravitybow" )

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
	//	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) ) return 0

	//	Projectile creation check
    bool shouldCreateProjectile = false
    if( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if( !playerFired )
			shouldCreateProjectile = false
	#endif

	if( !shouldCreateProjectile )
		return 1

	//	Get charge
	int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
	int damageFlags = weapon.GetWeaponDamageFlags()

	entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
	if( bolt ) {
		//	Set additional bullets
		int chargeLevel = GravityBow_GetChargeLevel( weapon )
		bolt.s.damageInstances <- chargeLevel

		if( chargeLevel >= CHARGE_SHOT_LEVEL && chargeLevel < POWER_SHOT_LEVEL )
			bolt.s.damageInstances = CHARGE_SHOT_LEVEL

		//	Set additional damage
		bolt.s.extraDamagePerBullet <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets )
		bolt.s.extraDamagePerBullet_Titan <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets_titanarmor )
	}
}

//	Charge handling
int function GravityBow_GetChargeLevel( entity weapon ) {
	if( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return 0

	if( !owner.IsPlayer() )
		return 3

	if( !weapon.IsReadyToFire() )
		return 0

	int charge = weapon.GetWeaponChargeLevel()
	return charge // (1 + charge)
}

//	Reload handling
void function OnWeaponReload_Archer_GravityBow( entity weapon, int milestoneIndex ) {
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

void function OnWeaponReadyToFire_Archer_GravityBow( entity weapon ) {
	bool isChargedShot = weapon.HasMod("TArmory_ChargedShot")
	if( !weapon.IsReloading() && !isChargedShot ) {
		weapon.AddMod("TArmory_ReloadHelper")
	}
}

//	Gravity handling
void function GravityArrowThink( entity projectile, entity hitEnt, vector normal, vector pos ) {
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

	//	Callbacks
	trig.SetEnterCallback( OnGravTriggerEnter )
	trig.SetLeaveCallback( OnGravTriggerLeave )

	//	Spawn & such
	DispatchSpawn( gravTrig )
	gravTrig.SearchForNewTouchingEntity()

	DispatchSpawn( trig )
	trig.SearchForNewTouchingEntity()
}

//	Trigger handling
void function OnGravTriggerEnter( entity trigger, entity ent ) {
	//	NPC Check
	if( !ent.IsNPC() )
		return

	//	Dead check
	if( !IsAlive( ent ) )
		return

	//	Allied check
	if( ent.GetTeam() == trigger.GetTeam() )
		return

	//	Gravable check
	if( !(IsGrunt( ent ) || IsSpectre( ent ) || IsStalker( ent )) )
		return

	//	Interruptable check
	if( !ent.ContextAction_IsActive() && ent.IsInterruptable() ) {
		ent.ContextAction_SetBusy()
		ent.Anim_ScriptedPlayActivityByName( "ACT_FALL", true, 0.2 )

		if ( IsGrunt( ent ) )
			EmitSoundOnEntity( ent, "diag_efforts_gravStruggle_gl_grunt_3p" )

		thread EndNPCGravGrenadeAnim( ent )
	}
}

void function OnGravTriggerLeave( entity trigger, entity ent ) {
	if ( IsValid( ent ) )
		ent.Signal( "LeftGravityMine" )
}