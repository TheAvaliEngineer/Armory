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

	//	Test for projectile creation
	bool shouldCreateProjectile = false
	if( IsServer() || weapon.ShouldPredictProjectiles() ) {
		shouldCreateProjectile = true
		#if CLIENT
		if( !playerFired )
			shouldCreateProjectile = false
		#endif
	}

	//	Create projectile
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
void function OnProjectileCollision_MortarTone_FlareLauncher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	table collisionParams = {
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	entity owner = projectile.GetOwner()
	if( !IsValid(owner) )
		return

	//	Handle sticky flares
	bool place = true

	if( hitEnt.IsWorld() ) {
		float dot = normal.Dot( Vector( 0, 0, 1 ) )
		place = place && dot > 0.8
	}
	
	if( !place )
		return

	bool planted = PlantStickyEntity( hitEnt, collisionParams )

	#if SERVER
	//	Planted sounds
	if( IsAlive( hitEnt ) && hitEnt.IsPlayer() ) {
		EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
		EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
	} else {
		EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
	}
	#endif

	thread FlareThink( projectile, hitEnt, owner )
}

void function FlareThink( entity projectile, entity hitEnt, entity owner ) {
	//	Register flare
	if( !(owner in flareData) ) {
		flareData[owner] <- [projectile]
	} else { flareData[owner].append( projectile ) }

	//	Indicator
	int fxHandle
	if( hitEnt.IsWorld() ) {
		#if CLIENT
		int index = GetParticleSystemIndex( $"P_ar_titan_droppoint" )
		vector origin = projectile.GetOrigin()

		fxHandle = StartParticleEffectInWorldWithHandle( index, origin, <0, 10000, 0> ) //team )
//		EffectSetControlPointVector( fxHandle, 1, <255, 80, 80> ) // <255, 127, 127>
		#endif
	}

	//	Signaling
	projectile.EndSignal( "OnDeath" )
	projectile.EndSignal( "OnDestroy" )

	owner.EndSignal( "OnDeath" )

	OnThreadEnd( function() : ( projectile, owner, fxHandle ) {
		flareData[owner].fastremovebyvalue( projectile )

		#if CLIENT
		if( EffectDoesExist( fxHandle ) )
			EffectStop( fxHandle, false, true )
		#endif
	})

	WaitForever()
}