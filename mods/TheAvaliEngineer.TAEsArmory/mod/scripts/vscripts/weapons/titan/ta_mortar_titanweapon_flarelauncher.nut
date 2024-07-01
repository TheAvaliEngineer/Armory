//		Function declarations
global function TArmory_Init_MortarTone_FlareLauncher

global function OnWeaponPrimaryAttack_MortarTone_FlareLauncher
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_FlareLauncher
#endif

global function OnProjectileCollision_MortarTone_FlareLauncher

//		Vars
//	Flare lifetime
const float FLARE_LIFETIME = 30.0
const float FLARE_DISAPPEAR_DELAY = 5.0

//	Flare health
const int FLARE_HEALTH = 250

//	Flare FX
const asset FLARE_PARTICLE_FX = $"P_ar_titan_droppoint"

//	Flare list
global table< entity, array< entity > > flareData

//		Functions
//	Init
void function TArmory_Init_MortarTone_FlareLauncher() {
	//	FX precache
	PrecacheParticleSystem( FLARE_PARTICLE_FX )

    #if SERVER
	//  Precache weapon
    PrecacheWeapon( "ta_mortar_titanweapon_flarelauncher" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_mortar_titanweapon_flarelauncher = "Flare Launcher",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Charge level handling
float function FlareLauncher_GetChargeLevel( entity weapon ) {
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

//	Attack handling
var function OnWeaponPrimaryAttack_MortarTone_FlareLauncher( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FlareLauncher_Fire( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_FlareLauncher( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FlareLauncher_Fire( weapon, attackParams, false )
}
#endif

int function FlareLauncher_Fire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Validity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0

	//	Test for proj creation
	bool shouldCreateProjectile = false
	if( IsServer() || weapon.ShouldPredictProjectiles() ) {
		shouldCreateProjectile = true
		#if CLIENT
		if( !playerFired )
			shouldCreateProjectile = false
		#endif
	}

	//	Create proj
	if( shouldCreateProjectile ) {
		int damageFlags = weapon.GetWeaponDamageFlags()

		//	Get launch speed
		float minSpeed = weapon.GetWeaponSettingFloat( eWeaponVar.damage_near_distance )
		float maxSpeed = weapon.GetWeaponSettingFloat( eWeaponVar.damage_far_distance )

		float chargeFrac = FlareLauncher_GetChargeLevel( weapon )
		float launchSpeed = Graph( chargeFrac * chargeFrac, 0.0, 1.0, minSpeed, maxSpeed )

		//	Velocities
		vector angVel = Vector(0, 2000, 0)
		vector attackVel = Normalize(attackParams.dir) * launchSpeed

		//	Spawn grenade
		entity flare = weapon.FireWeaponGrenade( attackParams.pos, attackVel, angVel, FLARE_LIFETIME,
			damageFlags, damageFlags, playerFired, PROJECTILE_LAG_COMPENSATED, false )
		if( flare ) {
			#if SERVER
			thread TrapExplodeOnDamage( flare, FLARE_HEALTH )
			#endif
		}
	}

	return weapon.GetAmmoPerShot()
}

//	Collision handling
void function OnProjectileCollision_MortarTone_FlareLauncher( entity proj, vector pos, vector norm, entity hitEnt, int hitbox, bool isCrit ) {
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
	table params = { pos = pos, normal = norm, hitEnt = hitEnt, hitbox = hitbox }
	bool planted = PlantStickyEntity( proj, params )
	if( !planted )
		return

	#if SERVER
	//	Planted sounds
	if( IsAlive( hitEnt ) && hitEnt.IsPlayer() ) {
		EmitSoundOnEntityOnlyToPlayer( proj, hitEnt, "weapon_softball_grenade_attached_1P" )
		EmitSoundOnEntityExceptToPlayer( proj, hitEnt, "weapon_softball_grenade_attached_3P" )
	} else {
		EmitSoundOnEntity( proj, "weapon_softball_grenade_attached_3P" )
	}
	#endif

	thread FlareThink( proj, hitEnt, owner )
}

void function FlareThink( entity proj, entity hitEnt, entity owner ) {
	//	Register flare
	if( !(owner in flareData) ) {
		flareData[owner] <- [proj]
	} else { flareData[owner].append( proj ) }

	//	Indicator
	int fxHandle
	if( hitEnt.IsWorld() ) {
		#if CLIENT
		int index = GetParticleSystemIndex( $"P_ar_titan_droppoint" )
		vector origin = proj.GetOrigin()

		fxHandle = StartParticleEffectInWorldWithHandle( index, origin, <0, 0, 1> ) //team )
		EffectSetControlPointVector( fxHandle, 1, <255, 80, 80> ) // <255, 127, 127>
		#endif
	}

	//	Signaling
	proj.EndSignal( "OnDeath" )
	proj.EndSignal( "OnDestroy" )

	owner.EndSignal( "OnDeath" )

	OnThreadEnd( function() : ( proj, owner, fxHandle ) {
		flareData[owner].fastremovebyvalue( proj )

		#if CLIENT
		if( EffectDoesExist( fxHandle ) )
			EffectStop( fxHandle, false, true )
		#endif
	})

	WaitForever()
}