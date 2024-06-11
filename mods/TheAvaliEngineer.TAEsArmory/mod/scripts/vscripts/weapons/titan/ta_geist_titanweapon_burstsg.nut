untyped

//		Function declarations
global function TArmory_Init_GeistRonin_BurstSG

global function OnWeaponPrimaryAttack_GeistRonin_BurstSG
#if SERVER
global function OnWeaponNpcPrimaryAttack_GeistRonin_BurstSG
#endif

global function OnWeaponReload_GeistRonin_BurstSG
global function OnWeaponReadyToFire_GeistRonin_BurstSG


//		Data
//	Stun
const float STUN_DURATION = 0.5
const float STUN_FADEOUT = 0.25

//	FX
const int SHOT_TRACER_COUNT = 8
const asset CHARGE_EFFECT_1P = $"P_rail_charge" //$"P_wpn_xo_sniper_charge_FP"
const asset CHARGE_EFFECT_3P = $"P_rail_charge" //$"P_wpn_xo_sniper_charge"

//		Functions
//	Init
void function TArmory_Init_GeistRonin_BurstSG() {
	//	FX precache
	PrecacheParticleSystem( CHARGE_EFFECT_1P )
	PrecacheParticleSystem( CHARGE_EFFECT_3P )

	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_geist_titanweapon_burstsg" )

	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_geist_titanweapon_burstsg = "Thumper",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	//	Callback
	AddDamageCallbackSourceID( eDamageSourceId.ta_geist_titanweapon_burstsg, BurstSG_DamagedTarget )
	#endif
}

//	Fire handling
var function OnWeaponPrimaryAttack_GeistRonin_BurstSG( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireBurstSG( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_GeistRonin_BurstSG( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireBurstSG( weapon, attackParams, false )
}
#endif

int function FireBurstSG( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	SFX
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	//	Set fire amount
	int returnAmount = 1

	//	Fire
	int damageFlags = weapon.GetWeaponDamageFlags()
	int projCount = weapon.GetWeaponSettingInt( eWeaponVar.projectiles_per_shot )
	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, projCount, damageFlags )

	//	Stop FX
	bool isChargedShot = weapon.HasMod( "TArmory_ChargedShot" )
	if( isChargedShot ) {
		#if SERVER
		StopChargeFX( weapon )
		#endif
	}

	//	Break cloak
	entity owner = weapon.GetWeaponOwner()
	entity cloakWeapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )

	if( "breakCloak" in cloakWeapon.s ) {
		cloakWeapon.s.breakCloak = true
	}

	return returnAmount
}

//	Reload handling
void function OnWeaponReload_GeistRonin_BurstSG( entity weapon, int milestoneIndex ) {
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

void function OnWeaponReadyToFire_GeistRonin_BurstSG( entity weapon ) {
	bool isChargedShot = weapon.HasMod("TArmory_ChargedShot")
	if( !weapon.IsReloading() && !isChargedShot ) {
		weapon.AddMod("TArmory_ReloadHelper")
	}
}

//	Damage handling
void function BurstSG_DamagedTarget( entity hitEnt, var damageInfo ) {
	//	Retrieval + sanity checks
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	if( !IsValid(weapon) )
		return

	if( weapon.HasMod("TArmory_ChargedShot") ) {
		entity target = ent.IsTitan() ? ent.GetTitanSoul() : ent
		int slowEffect = StatusEffect_AddTimed( target, eStatusEffect.turn_slow, EMP_SEVERITY_SLOWTURN, STUN_DURATION, STUN_FADEOUT )
		int turnEffect = StatusEffect_AddTimed( target, eStatusEffect.move_slow, EMP_SEVERITY_SLOWMOVE, STUN_DURATION, STUN_FADEOUT )

		#if SERVER
		if( ent.IsPlayer() ) {
			ent.p.empStatusEffectsToClearForPhaseShift.append( slowEffect )
			ent.p.empStatusEffectsToClearForPhaseShift.append( turnEffect )
		}
		#endif
	}
}

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
	EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_Predator_Powershot_ChargeUp_1P" )
	EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_Predator_Powershot_ChargeUp_3P" )

	EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_Titan_Sniper_SustainLoop" )
}

void function StopChargeFX(	entity weapon ) {
	//	Particle FX
	//*
	foreach( fx in weapon.s.chargeFX ) {
		fx.Destroy()
	} //*/

//	weapon.StopWeaponEffect( CHARGE_EFFECT_1P, CHARGE_EFFECT_3P )

	//	SFX
	StopSoundOnEntity( weapon, "Weapon_Titan_Sniper_SustainLoop" )
}
#endif