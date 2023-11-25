untyped

//			Declarations
//		Function declarations
global function TArmory_Init_GrenadeFuelTrail

global function OnWeaponTossReleaseAnimEvent_grenade_fueltrail

//		Variables
//	Fuel trail creation
const float FUEL_TRAIL_START_DELAY = 0.5
const float FUEL_TRAIL_ITER = 0.08

const float FUEL_TRAIL_DET_ITER = 0.02 //0.02

//	Cloud behavior
const float CLOUD_GRAVITY = 15.0

const float CLOUD_MERGE_RADIUS_THRESH = 0.95
const float CLOUD_VOLUME_MERGE_FRAC = 1.0
const float CLOUD_DAMAGE_MERGE_FRAC = 0.75

//	FX config
const int FX_PER_CLOUD = 5

//	FX assets
const asset FUEL_CLOUD_FX = $"xo_health_smoke_white" //$"P_meteor_trap_gas"
const asset CLOUD_EXPLOSION_FX = $"mWall_FLASH_fire"  //$"mTrap_exp_CH_fireball" //$"wild_night_exp_puff_fire" //$"rocket_testfire_flame"

//	Struct def
struct FuelTrailInfo {
	//	Damage
	int damage
	int damageTitan
	float innerRadius
	float outerRadius

	int damageSourceId

	//	Volume calculation
	float innerVolume
	float outerVolume

	//	FX positions
	vector fxCenter
	array<vector> fxPos

	//	Explosion delay
	float delay
}

//		Functions
//	Init
void function TArmory_Init_GrenadeFuelTrail() {
	//	FX precache
	PrecacheParticleSystem( FUEL_CLOUD_FX )
	PrecacheParticleSystem( CLOUD_EXPLOSION_FX )

	//	Weapon precache
	PrecacheWeapon( "ta_grenade_fueltrail" )

	#if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_grenade_fueltrail = "Fuel Trail Grenade",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Toss handling
var function OnWeaponTossReleaseAnimEvent_grenade_fueltrail( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//	sfx
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	//	Lag compensation
	bool isPredicted = PROJECTILE_PREDICTED
	bool isLagCompensated = PROJECTILE_LAG_COMPENSATED
	#if SERVER
	if ( weapon.IsForceReleaseFromServer() ) {
		isPredicted = false
		isLagCompensated = false
	}
	#endif

	#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 0
	#endif

	//	Launch nade
	vector angVel = Vector( 100, 100, RandomFloatRange( 1200, 2200 ) )

	float fuseTime = weapon.GetWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	int damageFlags = weapon.GetWeaponDamageFlags()

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angVel, fuseTime, damageFlags, damageFlags, isPredicted, isLagCompensated, true )
	if( nade ) {
		//	Disc toss angle adjust
		Assert( !nade.IsMarkedForDeletion(), "Nade before .SetAngles() is marked for deletion." )
		nade.SetAngles( nade.GetAngles() + < RandomFloatRange( 7,11 ),0,0 > )
		if ( nade.IsMarkedForDeletion() ) {
			CodeWarning( "Nade after .SetAngles() was marked for deletion." )
			return null
		}

		Grenade_Init( nade, weapon )
		#if SERVER
		thread TrapExplodeOnDamage( nade, 20, 0.0, 0.0 )

		string projectileSound = GetGrenadeProjectileSound( weapon )
		if ( projectileSound != "" )
			EmitSoundOnEntity( nade, projectileSound )

		//	Fuel trail functionality
		thread FuelTrailThink( nade, fuseTime )
		#endif
	}

	//	Signals
	entity owner = weapon.GetWeaponOwner()
	owner.Signal( "ThrowGrenade" )

	PlayerUsedOffhand( owner, weapon )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

#if SERVER
//	Fuel trail creation
void function FuelTrailThink( entity grenade, float fuseTime ) {
	//	Owner validity check
	entity owner = grenade.GetThrower()
	if ( !IsValid( owner ) )
		return

	//	Fuse handling
	float startTime = Time()
	float endTime = Time() + fuseTime

	print("[TAEsArmory] FuelTrailThink: startTime = " + startTime + ", endTime = " + endTime + ", diff = " + (endTime - startTime) + ", fuseTime = " + fuseTime)

	wait FUEL_TRAIL_START_DELAY

	//	Array for managing ents
	array<entity> trailEnts
	table<entity, FuelTrailInfo> trailExplodeData

	OnThreadEnd( function() : ( grenade, trailEnts, trailExplodeData ) {
		if( IsValid(grenade) )
			grenade.Destroy()

		FuelTrailGrenade_TrailExplode( trailEnts, trailExplodeData )
	} )

	//	Math
	RadiusDamageData r = GetRadiusDamageDataFromProjectile( grenade, owner )

	float innerRadius = r.explosionInnerRadius
	float outerRadius = r.explosionRadius

	float innerVolume = ( 4.0 * PI * innerRadius * innerRadius * innerRadius ) / 3.0
	float outerVolume = ( 4.0 * PI * outerRadius * outerRadius * outerRadius ) / 3.0

	//	Start creating fuel stuff
	while( Time() < endTime ) {
		//	Create new damage data
		FuelTrailInfo cloudInfo

		cloudInfo.damage = r.explosionDamage
		cloudInfo.damageTitan = r.explosionDamageHeavyArmor

		cloudInfo.innerVolume = innerVolume
		cloudInfo.outerVolume = outerVolume

		cloudInfo.innerRadius = innerRadius
		cloudInfo.outerRadius = outerRadius

		cloudInfo.damageSourceId = eDamageSourceId.ta_grenade_fueltrail

		cloudInfo.delay = - (trailEnts.len() * FUEL_TRAIL_DET_ITER)
		float fxTime = endTime - Time() + cloudInfo.delay

		//	Create gas cloud
		vector origin = grenade.GetOrigin()
		FuelTrailGrenade_CreateGasCloud( origin, owner, cloudInfo, trailEnts, trailExplodeData, fxTime )

		wait FUEL_TRAIL_ITER
	}
}

void function FuelTrailGrenade_CreateGasCloud( vector origin, entity owner, FuelTrailInfo newInfo,
		array<entity> cloudArr, table<entity, FuelTrailInfo> trailDamageData, float fxTime ) {
	//	Merge with nearby clouds ents if possible
	while( 1 ) {
		//	Find mergeable clouds
		array<entity> mergeArr
		array<entity> removeArr
		foreach( ent in cloudArr ) {
			if( !IsValid(ent) ) {
				//print("[TAEsArmory] FuelTrailGrenade_CreateGasCloud: Invalid ent in cloudArr")
				removeArr.append(ent)
				continue
			}

			//	Merge math
			float centerDistance = Distance( origin, ent.GetOrigin() )
			float furthestEdgesDist = (centerDistance + newInfo.outerRadius * CLOUD_MERGE_RADIUS_THRESH ) - trailDamageData[ent].outerRadius

			if( furthestEdgesDist <= 0 ) {
				TraceResults results = TraceLine( origin, ent.GetOrigin(), null, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )

				print("[TAEsArmory] FuelTrailGrenade_CreateGasCloud: Trace complete!\n\tresults.fraction = "
					+ results.fraction + "\n\tresults.hitEnt == ent? " + (results.hitEnt == ent))

				if ( results.fraction >= 1 || results.hitEnt == ent )
					mergeArr.append( ent )
			}
		}

		//	Remove invalid ents
		foreach( ent in removeArr ) {
			print("[TAEsArmory] FuelTrailGrenade_CreateGasCloud: Removed entry from cloudArr")
			cloudArr.fastremovebyvalue(ent)
		}

		//	Break if no entries
		if( mergeArr.len() == 0 )
			break

		//	Merge with other clouds
		for( int i = 0; i < mergeArr.len(); i++ ) {
			entity other = mergeArr[i]
			FuelTrailInfo otherInfo = trailDamageData[other]

			//		Modify data
			//	Add damage
			newInfo.damage += (otherInfo.damage * CLOUD_DAMAGE_MERGE_FRAC).tointeger()
			newInfo.damageTitan += (otherInfo.damageTitan * CLOUD_DAMAGE_MERGE_FRAC).tointeger()

			print("[TAEsArmory] FuelTrailThink: dV/dt = " + otherInfo.outerVolume + ", r = " + newInfo.outerRadius)
			print("[TAEsArmory] FuelTrailThink: other volume = " + otherInfo.outerVolume + ", this volume = " + newInfo.outerVolume)

			/*	This doesn't work. dunno why.
			//	Realistic cloud growth
			//	dr/dt = dV/dt / 4*pi*r^2
			float addInnerRadius = (newInfo.innerVolume * CLOUD_VOLUME_MERGE_FRAC) / ( 4.0 * PI * pow( otherInfo.innerRadius, 2 ) )
			float addOuterRadius = (newInfo.outerVolume * CLOUD_VOLUME_MERGE_FRAC) / ( 4.0 * PI * pow( otherInfo.outerRadius, 2 ) )

			print("[TAEsArmory] FuelTrailThink: addInnerRadius = " + addInnerRadius + ", addOuterRadius = " + addOuterRadius)

			newInfo.innerRadius += addInnerRadius
			newInfo.outerRadius += addOuterRadius

			newInfo.innerVolume += otherInfo.innerVolume
			newInfo.outerVolume += otherInfo.outerVolume
			*/

			newInfo.innerVolume += otherInfo.innerVolume
			newInfo.outerVolume += otherInfo.outerVolume

			newInfo.innerRadius = pow( 0.75 / PI * newInfo.innerVolume, 1./3. )
			newInfo.outerRadius = pow( 0.75 / PI * newInfo.outerVolume, 1./3. )

			//	Modify delay
			newInfo.delay = otherInfo.delay

			/*
			//		Modify data
			//	Add damage
			trailDamageData[other].damage += (newInfo.damage * CLOUD_DAMAGE_MERGE_FRAC).tointeger()
			trailDamageData[other].damageTitan += (newInfo.damageTitan * CLOUD_DAMAGE_MERGE_FRAC).tointeger()

			//	This is so that the clouds grow realistically
			//	dr/dt = dV/dt / 4*pi*r^2
			trailDamageData[other].innerRadius += newInfo.innerVolume * CLOUD_VOLUME_MERGE_FRAC / ( 4.0 * PI * pow( trailDamageData[other].innerRadius, 2 ) )
			trailDamageData[other].outerRadius += newInfo.outerVolume * CLOUD_VOLUME_MERGE_FRAC / ( 4.0 * PI * pow( trailDamageData[other].outerRadius, 2 ) )

			trailDamageData[other].innerVolume += newInfo.innerVolume
			trailDamageData[other].outerVolume += newInfo.outerVolume
			*/

			print("[TAEsArmory] FuelTrailThink: Merging clouds\n\tNew radius (inner): "
				+ newInfo.innerRadius + "\n\tNew radius (outer): "
				+ newInfo.outerRadius )

			//	Destroy other
			if( IsValid(other) ) {
				cloudArr.fastremovebyvalue(other)
				other.Destroy()
			}
		}
	}

	//	Create an ent to use as script target
	entity cloudEnt = CreateScriptMover( origin )
	cloudEnt.SetOwner( owner )

	cloudEnt.NonPhysicsMoveWithGravity( <0., 0., 0.>, Vector(0., 0., -CLOUD_GRAVITY) )

	EntFireByHandle( cloudEnt, "Kill", "", 10.0, null, null )

	//	AI stuffs
	AI_CreateDangerousArea( cloudEnt, cloudEnt, newInfo.outerRadius, TEAM_INVALID, true, true )

	//	Register ent
	cloudArr.append( cloudEnt )
	trailDamageData[cloudEnt] <- newInfo

	//	FX
	GasCloudFx_UpdateOrNew( cloudEnt, trailDamageData )
}

//	Explosion handling
void function FuelTrailGrenade_TrailExplode( array<entity> trailEnts, table<entity, FuelTrailInfo> trailDamageData ) {
	print("[TAEsArmory] FuelTrailGrenade_TrailExplode: Detonating")
	foreach( ent in trailEnts ) {
		trailDamageData[ent].delay += FUEL_TRAIL_DET_ITER * trailEnts.len()
		thread FuelTrailGrenade_CloudExplode( ent, trailDamageData[ent] )
	}
}

void function FuelTrailGrenade_CloudExplode( entity cloud, FuelTrailInfo explodeData ) {
	//	Thread end handling
	OnThreadEnd( function() : ( cloud ) {
		if ( IsValid( cloud ) ) {
			foreach ( fx in cloud.e.fxArray ) {
				if ( IsValid( fx ) )
					fx.Destroy()
			}

			cloud.Destroy()
		}
	})

	wait explodeData.delay

	//	Do explosion
	vector origin = cloud.GetOrigin()
	entity owner = cloud.GetOwner()

	RadiusDamage(
		origin,									// origin
		owner,									// owner
		cloud,		 							// inflictor
		explodeData.damage,						// normal damage
		explodeData.damageTitan,				// heavy armor damage
		explodeData.innerRadius,				// inner radius
		explodeData.outerRadius,				// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,		// explosion flags
		0, 										// distanceFromAttacker
		0, 										// explosionForce
		0,										// damage flags
		explodeData.damageSourceId				// damage source id
	)

	//	FX
	GasCloudExplodeFx( origin, explodeData )
	EmitSoundAtPosition( TEAM_UNASSIGNED, origin, "heat_shield_3p_start" )
}

//	FX
void function GasCloudFx_UpdateOrNew( entity cloudEnt, table<entity, FuelTrailInfo> trailDamageData ) {
	FuelTrailInfo cloudData = trailDamageData[cloudEnt]

	if( cloudEnt.e.fxArray.len() > 0 ) {
		foreach( fx in cloudEnt.e.fxArray ) {
			if ( IsValid( fx ) )
				fx.Destroy()
		}
	}

	GasCloudFx( cloudEnt, cloudData )
}

void function GasCloudFx( entity cloudEnt, FuelTrailInfo cloudData ) {
	int numPoints = pow(cloudData.outerRadius / 25.0, 1.5).tointeger()

	//	Generate positions
	vector origin = cloudEnt.GetOrigin()

	array<vector> fxPos
	for( int i = 0; i < numPoints; i++ ) { //numPoints; i++ ) {
		float factor = RandomFloat( 1. )
		float theta = acos( RandomFloatRange( -1., 1. ) )
		float phi = RandomFloatRange( 0., 2 * PI )

		vector pos = Vector( sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta) )
		pos *= factor * cloudData.outerRadius
		//pos += origin

		fxPos.append(pos)
	}

	int fxID = GetParticleSystemIndex( FUEL_CLOUD_FX )
	int attachID = cloudEnt.LookupAttachment( "REF" )

	//	Generate FX
	foreach( pos in fxPos ) {
		vector angles = <0., 0., 0.>
		entity fx = StartParticleEffectOnEntityWithPos_ReturnEntity( cloudEnt, fxID, FX_PATTACH_ABSORIGIN_FOLLOW, attachID, pos, angles )

		cloudEnt.e.fxArray.append( fx )
	}
}

void function GasCloudExplodeFx( vector origin, FuelTrailInfo cloudData ) {
	int numPoints = pow(cloudData.outerRadius / 25.0, 1.5).tointeger() * 2

	//	Generate positions
	array<vector> fxPos
	for( int i = 0; i < numPoints; i++ ) { //numPoints; i++ ) {
		float factor = RandomFloat( 1. )
		float theta = acos( RandomFloatRange( -1., 1. ) )
		float phi = RandomFloatRange( 0., 2 * PI )

		vector pos = Vector( sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta) )
		pos *= factor * cloudData.outerRadius
		pos += origin

		fxPos.append(pos)
	}

	//	Play FX
	foreach( pos in fxPos ) {
		vector angles = < -90., 0., 0. >
		PlayFX( CLOUD_EXPLOSION_FX, pos, angles )
	}

}
#endif