//		Function declarations
global function OnWeaponPrimaryAttack_Weapon_ThermiteShotgun
#if SERVER
global function OnWeaponNpcPrimaryAttack_Weapon_ThermiteShotgun
#endif

global function OnProjectileCollision_Weapon_ThermiteShotgun
global function OnProjectileIgnite_Weapon_ThermiteShotgun

#if SERVER
global function CreateThermiteBurst
#endif

//		Consts
//	FX
const asset THERMITE_FX_MOVING = $"P_wpn_meteor_exp"

const asset THERMITE_FX_STATIC = $"P_wpn_meteor_exp_trail"

#if SERVER
//	Thermite behavior
const float THERMITE_SLUG_BURN_TIME = 2.5
const float THERMITE_SLUG_BURN_ITER = 0.1

const float THERMITE_REFLECT_FRAC_MAX = 0.9
const float THERMITE_REFLECT_FRAC_MIN = 0.25
#endif

//		Functions
//	Fire handling
var function OnWeaponPrimaryAttack_Weapon_ThermiteShotgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
    //vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

    if ( IsServer() || weapon.ShouldPredictProjectiles() ) {
		vector offset = Vector( 30.0, 6.0, -4.0 )
		if ( weapon.IsWeaponInAds() )
			offset = Vector( 30.0, 0.0, -3.0 )

        vector attackPos = player.OffsetPositionFromView( attackParams.pos, offset )	// forward, right, up
        FireThermiteSlug( weapon, attackParams )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Weapon_ThermiteShotgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireThermiteSlug( weapon, attackParams, true )
}
#endif

void function FireThermiteSlug( entity weapon, WeaponPrimaryAttackParams attackParams, bool isNPCFiring = false ) {
    vector angularVelocity = Vector(0, 2000, 0) // Slug doesn't tumble.

    int damageType = DF_RAGDOLL | DF_EXPLOSION | DF_STOPS_TITAN_REGEN

    entity slug = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0, damageType, damageType, !isNPCFiring, true, false )

    if ( slug ) {
        #if SERVER
			Grenade_Init( slug, weapon )
        #else
            entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( slug, weaponOwner.GetTeam() )
        #endif
    }
}

//	Impact handling
void function OnProjectileCollision_Weapon_ThermiteShotgun( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	entity owner = projectile.GetOwner()
	vector priorVel = projectile.GetVelocity()

	//	Attach shell
	bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
	if( !didStick )
		return

	#if SERVER
	//	SFX
	if( IsAlive( hitEnt ) && hitEnt.IsPlayer() ) {
		EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
		EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
	} else {
		EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
	}
	#endif

	//	Skip if already ignited
	if( projectile.GrenadeHasIgnited() ) return

	#if SERVER
	//	Start thermite wait thread
	if( !IsAlive( hitEnt ) || hitEnt.IsWorld() ) {
		float dot = DotProduct( Normalize( priorVel ), normal )
		float reduction = GraphCapped( dot, -1, 1, THERMITE_REFLECT_FRAC_MIN, THERMITE_REFLECT_FRAC_MAX )

		vector newVel = VectorReflectionAcrossNormal( priorVel, normal ) * reduction

		CreateThermiteBurst( projectile, owner, newVel, 5, 8, 0 )
		projectile.GrenadeIgnite()
	} else {
		thread WaitToIgnite( projectile, hitEnt, priorVel )
	}
	#endif
}

void function OnProjectileIgnite_Weapon_ThermiteShotgun( entity projectile ) {
	//	Owner validity check
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
		return

	#if SERVER
	//	Destroy projectile
	if( IsValid(projectile) )
	projectile.Destroy()
	#endif
}

#if SERVER
//	Ignition timing
void function WaitToIgnite( entity projectile, entity hitEnt, vector velocity ) {
	print("[TAEsArmory] WaitToIgnite: Started waiting")

	hitEnt.WaitSignal( "OnDeath" )
	hitEnt.WaitSignal( "OnDestroy" )

	if( !IsValid(projectile) ) return

	if( projectile.GrenadeHasIgnited() ) return
	projectile.GrenadeIgnite()
}

//	Create thermite burst
void function CreateThermiteBurst( entity projectile, entity owner, vector vel, float angle, int count, int fxTable ) {
	vector dir = Normalize( vel )

	for( int i = 0; i < count; i++ ) {
		vector spreadVec = ApplyVectorSpread( dir, angle, 0.5 )

		vector newPos = projectile.GetOrigin() + spreadVec * 10.
		vector newVel = spreadVec * Length( vel )

		ThermiteECS_CreateThermiteEnt( projectile, owner, newPos, newVel, fxTable )
	}
}
#endif


/*
//	Ignition handling
void function OnProjectileIgnite_Weapon_ThermiteShotgun( entity projectile ) {
	projectile.SetDoesExplode( false )

	#if SERVER
	projectile.proj.onlyAllowSmartPistolDamage = false

	entity player = projectile.GetOwner()

	if ( !IsValid( player ) ) {
		projectile.Destroy()
		return
	}

	thread ThermiteShotgun_SlugBurn( THERMITE_SLUG_BURN_TIME, player, projectile )

	entity entAttachedTo = projectile.GetParent()
	if ( !IsValid( entAttachedTo ) )
		return

	//  uhh respawn this is a firestar not a satchel
	// If an NPC Titan has vortexed a satchel and fires it back out,
	// then it won't be a player that is the owner of this satchel
	if ( !player.IsPlayer() )
		return

	entity titanSoulRodeoed = player.GetTitanSoulBeingRodeoed()
	if ( !IsValid( titanSoulRodeoed ) )
		return

	entity titan = titanSoulRodeoed.GetTitan()

	if ( !IsAlive( titan ) )
		return

	if ( titan == entAttachedTo )
		titanSoulRodeoed.SetLastRodeoHitTime( Time() )
	#endif
}

//	Thermite behavior
#if SERVER
void function ThermiteShotgun_SlugBurn( float burnTime, entity owner, entity projectile, entity vortexSphere = null ) {
	if ( !IsValid( projectile ) ) //MarkedForDeletion check
		return

	projectile.SetTakeDamageType( DAMAGE_NO )

	const vector ROTATE_FX = <90.0, 0.0, 0.0>
	entity fx = PlayFXOnEntity( THERMITE_GRENADE_FX, projectile, "", null, ROTATE_FX )
	fx.SetOwner( owner )
	fx.EndSignal( "OnDestroy" )

	if ( IsValid( vortexSphere ) )
		vortexSphere.EndSignal( "OnDestroy" )

	projectile.EndSignal( "OnDestroy" )

	int statusEffectHandle = -1
	entity attachedToEnt = projectile.GetParent()
	if ( ThermiteShotgun_ShouldAddThermiteStatusEffect( attachedToEnt, owner ) )
		statusEffectHandle = StatusEffect_AddEndless( attachedToEnt, eStatusEffect.thermite, 1.0 )

	OnThreadEnd(
		function() : ( projectile, fx, attachedToEnt, statusEffectHandle ) {
			if ( IsValid( projectile ) )
				projectile.Destroy()

			if ( IsValid( fx ) )
				fx.Destroy()

			if ( IsValid( attachedToEnt) && statusEffectHandle != -1 )
				StatusEffect_Stop( attachedToEnt, statusEffectHandle )
		}
	)

	AddActiveThermiteBurn( fx )

	RadiusDamageData radiusDamage 	= GetRadiusDamageDataFromProjectile( projectile, owner )
	int damage 						= radiusDamage.explosionDamage
	int titanDamage					= radiusDamage.explosionDamageHeavyArmor
	float explosionRadius 			= radiusDamage.explosionRadius
	float explosionInnerRadius 		= radiusDamage.explosionInnerRadius
	int damageSourceId 				= projectile.ProjectileGetDamageSourceID()

	CreateNoSpawnArea( TEAM_INVALID, owner.GetTeam(), projectile.GetOrigin(), burnTime, explosionRadius )
	AI_CreateDangerousArea( fx, projectile, explosionRadius * 1.5, TEAM_INVALID, true, false )
	EmitSoundOnEntity( projectile, "explo_firestar_impact" )

	bool firstBurst = true

	float endTime = Time() + burnTime
	while ( Time() < endTime ) {
		vector origin = projectile.GetOrigin()
		RadiusDamage(
			origin,															//	origin
			owner,															//	attacker
			projectile,		 												//	inflictor
			firstBurst ? float( damage ) * 1.2 : float( damage ),			//	normal damage
			firstBurst ? float( titanDamage ) * 2.5 : float( titanDamage ),	//	heavy armor damage
			explosionInnerRadius,											//	inner radius
			explosionRadius,												//	outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,								//	explosion flags
			0, 																//	distanceFromAttacker
			0, 																//	explosionForce
			DF_SHOTGUN | DF_EXPLOSION | DF_INSTANT,							//	damage flags
			damageSourceId													//	damage source id
		)
		firstBurst = false

		//wait THERMITE_SLUG_BURN_ITER
		WaitFrame()	//	0.1 sec ~= 1 frame

		if ( statusEffectHandle != -1 && IsValid( attachedToEnt ) && !attachedToEnt.IsTitan() ) { //Stop if thermited player Titan becomes a Pilot
			StatusEffect_Stop( attachedToEnt, statusEffectHandle )
			statusEffectHandle = -1
		}
	}
}

bool function ThermiteShotgun_ShouldAddThermiteStatusEffect( entity attachedEnt, entity thermiteOwner ) {
	if ( !IsValid( attachedEnt ) )
		return false

	if ( !attachedEnt.IsPlayer() )
		return false

	if ( !attachedEnt.IsTitan() )
		return false

	if ( IsValid( thermiteOwner ) &&  attachedEnt.GetTeam() == thermiteOwner.GetTeam() )
		return false

	return true
}
#endif
//*/