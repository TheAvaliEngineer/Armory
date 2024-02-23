//		Function Declarations
global function TArmory_Init_MortarTone_NuclearStrike

global function OnWeaponDeactivate_MortarTone_NuclearStrike

global function OnAbilityCharge_MortarTone_NuclearStrike
global function OnAbilityChargeEnd_MortarTone_NuclearStrike

global function OnWeaponPrimaryAttack_MortarTone_NuclearStrike
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_NuclearStrike
#endif

global function OnProjectileCollision_MortarTone_NuclearStrike
global function OnProjectileIgnite_MortarTone_NuclearStrike

//		Data
//	Mortar properties
const float MORTAR_GRAVITY = 375.0

const float NUKE_INACCURACY = 0.05
const float NUKE_MAX_SPREAD = 50.0

//	Nuclear explosion properties
const int NUCLEAR_STRIKE_EXPLOSION_COUNT = 16
const float NUCLEAR_STRIKE_EXPLOSION_TIME = 1.4

//	Nuclear explosion FX
const var NUCLEAR_STRIKE_FX_3P = $"P_xo_exp_nuke_3P_alt"
const var NUCLEAR_STRIKE_FX_1P = $"P_xo_exp_nuke_1P_alt"
const var NUCLEAR_STRIKE_SUN_FX = $"P_xo_nuke_warn_flare"

//	Status effect properties
const SEVERITY_SLOWMOVE_MORTARCORE = 0.7

//		Functions
//	Init
void function TArmory_Init_MortarTone_NuclearStrike() {
	//	FX Precache
	PrecacheParticleSystem( NUCLEAR_STRIKE_FX_3P )
	PrecacheParticleSystem( NUCLEAR_STRIKE_FX_1P )
	PrecacheParticleSystem( NUCLEAR_STRIKE_SUN_FX )

	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titancore_nuclearstrike" )

	//	Custom damage type
	table<string, string> customDamageSourceIds = {
		ta_mortar_titancore_nuclearstrike = "Nuclear Strike",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	GameModeRulesRegisterTimerCreditException( eDamageSourceId.ta_mortar_titancore_nuclearstrike )
	#endif
}

//	Activate/deactivate
void function OnWeaponDeactivate_MortarTone_NuclearStrike( entity weapon ) {
	#if SERVER
	thread EndCore( weapon )
	#endif
}

void function EndCore( entity weapon ) {
	weapon.EndSignal( "OnDestroy" )

	entity player = weapon.GetWeaponOwner()
	if ( !IsValid(player) )
		return

	player.EndSignal( "OnDestroy" )
	if( IsAlive(player) ) {
		player.EndSignal( "OnDeath" )
		player.EndSignal( "TitanEjectionStarted" )
		player.EndSignal( "DisembarkingTitan" )
		player.EndSignal( "OnSyncedMelee" )
	}

	#if SERVER
	if( IsValid(player) ) {
		entity soul = player.GetTitanSoul()
		if ( IsValid( soul ) )
			CleanupCoreEffect( soul )
	}
	#endif

	if( IsValid(weapon) ) {
		#if SERVER
		OnAbilityEnd_TitanCore( weapon )
		#endif
	}
}

//	Charge
bool function OnAbilityCharge_MortarTone_NuclearStrike( entity weapon ) {
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

	#if SERVER
	entity titan = weapon.GetWeaponOwner()
	entity soul = titan.GetTitanSoul()
	if( soul == null )
		soul = titan

	//	Gotta fuck with this later
	//float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	//StatusEffect_AddTimed( soul, eStatusEffect.move_slow, SEVERITY_SLOWMOVE_MORTARCORE, chargeTime, 0 )

	if( titan.IsNPC() ) {
		titan.SetVelocity( <0,0,0> )
		//titan.Anim_ScriptedPlayActivityByName( "ACT_SPECIAL_ATTACK_START", true, 0.1 )
	}
	#endif
	return true
}

void function OnAbilityChargeEnd_MortarTone_NuclearStrike( entity weapon ) {
	#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )
	#endif
}

//	Attack handling
var function OnWeaponPrimaryAttack_MortarTone_NuclearStrike( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	if ( attackParams.burstIndex == 0 ) {
		OnAbilityStart_TitanCore( weapon )

		float delay = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	}

	return FireNuclearStrike( weapon, attackParams )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_NuclearStrike( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	OnWeaponPrimaryAttack_MortarTone_NuclearStrike( weapon, attackParams )
}
#endif

int function FireNuclearStrike( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	print("[TAEsArmory] FireNuclearStrike: Firing")

	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) || !IsAlive(owner) )
		return 0

	#if SERVER
	if(!(owner in flareData))
		return 0

	array<entity> flares = flareData[owner]
	if( flares.len() == 0 )
		return 0

	entity flare = flares[flares.len() - 1]

	//	Check if flare is valid
	if( !IsValid(flare) )
		return 0

	//	Get arc params
	vector playerPos = attackParams.pos
	vector flarePos = flare.GetOrigin()

	float gravityAmount = MORTAR_GRAVITY * weapon.GetWeaponSettingFloat( eWeaponVar.projectile_gravity_scale )

	//	Apply inaccuracy
	vector up = Vector(0.0, 0.0, 1.0)
	vector spreadVec = ApplyVectorSpread( up, NUKE_INACCURACY * 180 )
	vector spreadXY = Vector(spreadVec.x, spreadVec.y, 0.0) * NUKE_MAX_SPREAD

	flarePos += spreadXY

	//	Calculate trajectory
	MortarFireData fireData = CalculateFireArc( playerPos, flarePos, 1500.0, gravityAmount )

	//	Calculate fire params
	vector dir = fireData.launchDir * fireData.speed
	vector angVel = Vector(0., 0., 0.)
	float fuse = 0.0 	//	Infinite fuse	//	fireData.flightTime + 1.0

	entity rocket = weapon.FireWeaponGrenade( attackParams.pos, dir, angVel, fuse,
		damageTypes.pinkMist, damageTypes.pinkMist, false, true, false )
	//entity rocket = weapon.FireWeaponBolt( attackParams.pos, fireData.launchDir,
	//	fireData.speed, damageTypes.pinkMist, damageTypes.pinkMist, playerFired, 0 )
	if( rocket ) {
		rocket.kv.gravity = 1.0
		rocket.SetProjectileLifetime( fuse )

		#if SERVER
			Grenade_Init( rocket, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( rocket, weaponOwner.GetTeam() )
		#endif
	}

	//	Remove flare
	flareData[owner].fastremovebyvalue(flare)

	//	End core effect
	OnAbilityChargeEnd_TitanCore( weapon )
	#endif

	//	Consume ammo
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

//	Collision/ignite handling
void function OnProjectileCollision_MortarTone_NuclearStrike( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	table collisionParams = {
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool result = PlantStickyEntity( projectile, collisionParams )

	#if SERVER
	thread TArmory_DoNuclearExplosion( projectile )
	#endif
}

void function OnProjectileIgnite_MortarTone_NuclearStrike( entity projectile ) {
	print("[TAEsArmory] OnProjectileIgnite_MortarTone_NuclearStrike: End of nuke")
}

#if SERVER
void function TArmory_DoNuclearExplosion( entity projectile ) {
	//	Var initialisation
	int explosions = NUCLEAR_STRIKE_EXPLOSION_COUNT
	float time = NUCLEAR_STRIKE_EXPLOSION_TIME
	float explosionInterval = time / explosions

	vector origin = projectile.GetOrigin()

	entity player = projectile.GetOwner()
	int team = player.GetTeam()
	RadiusDamageData radiusDamage = GetRadiusDamageDataFromProjectile( projectile, player )

	int normalDamage = radiusDamage.explosionDamage
	int titanDamage = radiusDamage.explosionDamageHeavyArmor
	float innerRadius = radiusDamage.explosionInnerRadius
	float outerRadius = radiusDamage.explosionRadius

	//	Sun FX
	array< entity > nukeFX = []

	nukeFX.append( PlayFXOnEntity( NUCLEAR_STRIKE_SUN_FX, projectile ) )
	EmitSoundOnEntity( projectile, "titan_nuclear_death_charge" )

	wait 2.5 //2.05

	//	Clear sun FX
	ClearNuclearBlueSunEffect( nukeFX )

	//	Explosion FX
	if( IsValid(player) ) {
		thread __CreateFxInternal( NUCLEAR_STRIKE_FX_1P, null, "", origin,
			Vector(0, RandomInt(360), 0), C_PLAYFX_SINGLE, null, 1, player )
		thread __CreateFxInternal( NUCLEAR_STRIKE_FX_3P, null, "", origin + Vector(0, 0, -100),
			Vector(0, RandomInt(360), 0), C_PLAYFX_SINGLE, null, 6, player )
	} else {
		PlayFX( NUCLEAR_STRIKE_FX_3P, origin + Vector(0, 0, -100), Vector(0, RandomInt(360), 0) )
	}

	EmitSoundAtPosition( team, origin, "titan_nuclear_death_explode" )

	//	Create Inflictor
	entity inflictor = CreateEntity( "script_ref" )
	inflictor.SetOrigin( origin )

	inflictor.kv.spawnflags = SF_INFOTARGET_ALWAYS_TRANSMIT_TO_CLIENT

	DispatchSpawn( inflictor )

	//	Thread end
	OnThreadEnd( function() : ( projectile, inflictor ) {
		if ( !IsValid(projectile) || projectile.GrenadeHasIgnited() )
			return
		projectile.GrenadeIgnite()

		if ( IsValid(inflictor) )
			inflictor.Destroy()
	})

	//	Spawn explosions
	for( int i = 0; i < explosions; i++ ) {
		RadiusDamage(
			origin,													// origin
			player,													// owner
			inflictor,		 										// inflictor
			normalDamage,											// normal damage
			titanDamage,											// heavy armor damage
			innerRadius,											// inner radius
			outerRadius,											// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,						// explosion flags
			0, 														// distanceFromAttacker
			0, 														// explosionForce
			0,														// damage flags
			eDamageSourceId.ta_mortar_titancore_nuclearstrike	// damage source id
		)

		wait explosionInterval
	}
}

void function ClearNuclearBlueSunEffect( array< entity > nukeFX ) {
	foreach( fx in nukeFX ) {
		if ( IsValid( fx ) )
			fx.Destroy()
	}
	nukeFX.clear()
}
#endif