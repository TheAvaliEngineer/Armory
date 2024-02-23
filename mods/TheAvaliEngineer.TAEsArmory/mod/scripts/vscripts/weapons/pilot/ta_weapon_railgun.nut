untyped

//		Function declarations
global function TArmory_Init_Weapon_Railgun

global function OnWeaponPrimaryAttack_Weapon_Railgun
#if SERVER
global function OnWeaponNpcPrimaryAttack_Weapon_Railgun
#endif

global function OnWeaponReload_Weapon_Railgun
global function OnWeaponReadyToFire_Weapon_Railgun

//		Variables
const float PROJ_SPEED_SCALE = 1.0

//	FX
const asset CHARGE_EFFECT_1P = $"P_wpn_xo_sniper_charge_FP"	//$"xo_damage_fire_CH_arc"
const asset CHARGE_EFFECT_3P = $"P_wpn_xo_sniper_charge" //$"xo_damage_fire_CH_arc"


//		Functions
void function TArmory_Init_Weapon_Railgun() {
	//	FX precache
	PrecacheParticleSystem( CHARGE_EFFECT_1P )
	PrecacheParticleSystem( CHARGE_EFFECT_3P )

	//	Signaling
	RegisterSignal( "OnConsumeAmmo" )

	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_weapon_railgun" )

	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_weapon_railgun = "PilotRailgun",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Fire handling
var function OnWeaponPrimaryAttack_Weapon_Railgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	FireRailgun( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Weapon_Railgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	FireRailgun( weapon, attackParams, false )
}
#endif

int function FireRailgun( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	SFX
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	//	Fire
	bool isChargedShot = weapon.HasMod( "TArmory_Railgun_ChargedShot" )
	if( isChargedShot ) {
		#if SERVER
		StopChargeFX( weapon )
		#endif
	}
	FireRailgunProjectile( weapon, attackParams, playerFired )

	//	Consume ammo
	weapon.Signal( "OnConsumeAmmo" )
	return weapon.GetAmmoPerShot()
}

void function FireRailgunProjectile( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Test for projectile creation
	bool shouldCreateProjectile = false
	if( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if( !playerFired )
			shouldCreateProjectile = false
	#endif

	//	Create projectile
	if( shouldCreateProjectile ) {
		int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
		int damageFlags = weapon.GetWeaponDamageFlags()

		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
		if( bolt ) {
			#if CLIENT
			StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"Rocket_Smoke_SMR_Glow" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
			#endif
		}
	}
}

//	Reload handling
//IMPORTANT SHIT I FIXED ANY OTHER PIECE OF LOGIC IS FUCKED PLEASE REMOVE IT	(thank you Moblin)
void function OnWeaponReload_Weapon_Railgun( entity weapon, int milestoneIndex ) {
	//	Mod cleanup
	weapon.RemoveMod("TArmory_ChargedShot")
	weapon.RemoveMod("TArmory_ReloadHelper")

	entity owner = weapon.GetWeaponOwner()
	if( owner.GetWeaponAmmoLoaded(weapon) >= 4 ) {
		weapon.AddMod("TArmory_ChargedShot")
		#if SERVER
		StartChargeFX( weapon, owner )
		#endif
	}
}

void function OnWeaponReadyToFire_Weapon_Railgun( entity weapon ) {
	bool isChargedShot = weapon.HasMod("TArmory_ChargedShot")
	if( !weapon.IsReloading() && !isChargedShot ) {
		weapon.AddMod("TArmory_ReloadHelper")
	}
}
//YEAH I FUCKING DID IT LET'S GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO

#if SERVER
//	FX
void function StartChargeFX( entity weapon, entity owner ) {
	//	Particle FX
	//*
	int attachIdx = owner.LookupAttachment( "origin" )

	entity fx1p = StartParticleEffectOnEntity_ReturnEntity( weapon, GetParticleSystemIndex( CHARGE_EFFECT_1P ), FX_PATTACH_POINT_FOLLOW, attachIdx )
	entity fx3p = StartParticleEffectOnEntity_ReturnEntity( weapon, GetParticleSystemIndex( CHARGE_EFFECT_3P ), FX_PATTACH_POINT_FOLLOW, attachIdx )

	fx1p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_ONLY_PARENT_PLAYER
	fx3p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER
	//*/

	/*
	int attachID = owner.LookupAttachment( "muzzle_flash" )
	weapon.PlayWeaponEffect( CHARGE_EFFECT_1P, CHARGE_EFFECT_3P, "muzzle_flash" )
	//*/

	//*
	if( "chargeFX" in weapon.s ) {
		weapon.s.chargeFX = [fx1p, fx3p]
	} else { weapon.s.chargeFX <- [fx1p, fx3p] }
	//*/

	//	SFX
//	EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_Predator_Powershot_ChargeUp_1P" )
//	EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_Predator_Powershot_ChargeUp_3P" )

//	EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_Titan_Sniper_SustainLoop" )
}

void function StopChargeFX(	entity weapon ) {
	//	Particle FX
	//*
	foreach( fx in weapon.s.chargeFX ) {
		fx.Destroy()
	} //*/

	//	SFX
	StopSoundOnEntity( weapon, "Weapon_Titan_Sniper_SustainLoop" )
}
#endif