//		Function declarations
global function TArmory_Init_MortarTone_Flares

global function OnWeaponActivate_MortarTone_Flares
global function OnWeaponDeactivate_MortarTone_Flares
global function OnWeaponAttemptOffhandSwitch_MortarTone_Flares

global function OnWeaponPrimaryAttack_MortarTone_Flares
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_Flares
#endif

global function OnProjectileCollision_MortarTone_Flares

//		Consts
//	Flare speed
const float FLARE_SPEED_MIN_DEF = 750 //0
const float FLARE_SPEED_MAX_DEF = 3000 //0

const float FLARE_SPEED_MIN_MOD = 500 //0
const float FLARE_SPEED_MAX_MOD = 4000 //0

//	Flare lifetime
const float FLARE_LIFETIME = 30.0
const float FLARE_DISAPPEAR_DELAY = 5.0

//	Flare health
const int FLARE_HEALTH = 150


//	Flare list
global table< entity, array< entity > > flareData

//		Functions
//	Init
void function TArmory_Init_MortarTone_Flares() {
    #if SERVER
	//  Precache weapon
    PrecacheWeapon( "ta_mortar_titanability_flares" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_mortar_titanability_flares = "Flares",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Charge level handling
float function MortarFlare_GetChargeLevel( entity weapon ) {
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( !owner.IsPlayer() )
		return 3

	if ( !weapon.IsReadyToFire() )
		return 0

	float charge = weapon.GetWeaponChargeFraction()
	return charge // (1 + charge)
}

//	Activate/deactivate
void function OnWeaponActivate_MortarTone_Flares( entity weapon ) {}
void function OnWeaponDeactivate_MortarTone_Flares( entity weapon ) {}

bool function OnWeaponAttemptOffhandSwitch_MortarTone_Flares( entity weapon ) {
	return true //weapon.GetWeaponChargeFraction() <= 0.8
}

//	Attack handling
var function OnWeaponPrimaryAttack_MortarTone_Flares( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//  Mod handling (flare upgrade)
	float maxFlareSpeed = pow( FLARE_SPEED_MAX_DEF, 0.5 )
	float minFlareSpeed = pow( FLARE_SPEED_MIN_DEF, 0.5 )

	//if( mods.contains( "pas_tone_wall" ) ) {
	//	minFlareSpeed = FLARE_SPEED_MIN_MOD
	//	maxFlareSpeed = FLARE_SPEED_MAX_MOD
	//}

	//	Get throw velocity
	float chargeFrac = MortarFlare_GetChargeLevel( weapon )
	float vel = Graph( chargeFrac, 0.0, 1.0, minFlareSpeed, maxFlareSpeed )

	//	Fire flare
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	ThrowMortarFlare( weapon, attackParams, vel * vel, true )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_Flares( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	ThrowMortarFlare( weapon, attackParams, 10.0, false )

	return weapon.GetAmmoPerShot()
}
#endif

void function ThrowMortarFlare( entity weapon, WeaponPrimaryAttackParams attackParams, float throwStrength, bool playerFired ) {
	//	Validity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return

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
		int damageFlags = weapon.GetWeaponDamageFlags()

		vector angVel = Vector(0, 2000, 0)
		vector attackVel = Normalize(attackParams.dir) * throwStrength

		entity flare = weapon.FireWeaponGrenade( attackParams.pos, attackVel, angVel, FLARE_LIFETIME,
			damageFlags, damageFlags, playerFired, PROJECTILE_LAG_COMPENSATED, false )
		if( flare ) {
			#if SERVER
			//	Apply some number of locks (determining how many missiles are fired)
			ApplyLocks( owner, flare, 1.0 )
			//thread FlareThink( flare, owner )
			thread TrapExplodeOnDamage( flare, FLARE_HEALTH )
			#endif
		}
	}
}

#if SERVER
void function ApplyLocks( entity owner, entity flare, float num ) {
	//	Test if owner has lockable weapon
	entity mortarAbility = owner.GetOffhandWeapon( OFFHAND_ORDNANCE )
	if ( !IsValid( mortarAbility ) )
		return

	//	Check if player has entry in flareData
	if( owner in flareData ) {
		flareData[owner].append(flare)
	} else { flareData[owner] <- [flare] }
}
#endif

//	Collision handling
void function OnProjectileCollision_MortarTone_Flares( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	table collisionParams = {
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool planted = = PlantStickyEntity( projectile, collisionParams )

	#if SERVER
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) ) {
		return
	}

	//	Play attach noise
	EmitSoundOnEntity( projectile, "Weapon_R1_Satchel.Attach" )
	#endif
}

/*
#if SERVER
void function FlareThink( entity flare, entity owner ) {
	//	Signaling
	flare.EndSignal( "OnDeath" )

	//	FX
	int index = GetParticleSystemIndex( $"P_ar_titan_droppoint" )
	vector origin = flare.GetOrigin()

	int fxHandle = StartParticleEffectInWorldWithHandle( index, origin, <0, 90, 0> ) //team )
	EffectSetControlPointVector( fxHandle, 1, <255, 195, 127> ) // <255, 127, 127>

	//	Thread
	OnThreadEnd( function() : ( flare, owner ) {
		flareData[owner].fastremovebyvalue(flare)
	})

	WaitForever()
}
#endif
*/