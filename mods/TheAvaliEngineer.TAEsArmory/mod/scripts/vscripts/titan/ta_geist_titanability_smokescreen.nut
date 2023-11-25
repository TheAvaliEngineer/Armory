//		Function declarations


//		Data
//	Struct declarations
global struct DynamicSmokescreenData {
	vector origin
	vector angles

	bool fxUseWeaponOrProjectileAngles = false

	float lifetime = 5.0
	int ownerTeam = TEAM_ANY

	asset smokescreenFX = FX_ELECTRIC_SMOKESCREEN
	float fxXYRadius = 230.0 // single fx xy radius used to create nospawn area and block traces
	float fxZRadius = 170.0 // single fx z radius used to create nospawn area and block traces

	string deploySound1p = SFX_SMOKE_DEPLOY_1P
	string deploySound3p = SFX_SMOKE_DEPLOY_3P
	string stopSound1p = ""
	string stopSound3p = ""

	int damageSource = eDamageSourceId.mp_titanability_smoke

	bool blockLOS = true
	bool shouldHibernate = true

	bool isElectric = true
	entity attacker
	entity inflictor
	entity weaponOrProjectile
	float damageDelay = 2.0
	float damageInnerRadius = 320.0
	float damageOuterRadius = 350.0
	float dangerousAreaRadius = -1.0
	int dpsPilot = 30
	int dpsTitan = 2200

	array<vector> fxOffsets
}

struct DynamicSmokescreenFX {
	vector center	// center of all fx positions
	vector mins 	// approx mins of all fx relative to center
	vector maxs 	// approx maxs of all fx relative to center
	float radius	// approx radius of all fx relative to center
	array<vector> fxWorldPositions
	int ownerTeam = TEAM_ANY
}

//	Smokescreen storage
struct {
	array<SmokescreenFXStruct> allSmokescreenFX
	table<entity, float> nextSmokeSoundTime
} file

//		Functions
//	Smokescreen creation/destruction
void function CreateDynamicSmokescreen( DynamicSmokescreenData smokescreen ) {
	DynamicSmokescreenFX fxInfo = Smokescreen_CalculateFXStruct( smokescreen )
	file.allSmokescreenFX.append( fxInfo )

	//	Extinguish thermite
	array<entity> thermiteBurns = GetActiveThermiteBurnsWithinRadius( fxInfo.center, fxInfo.radius )
	foreach ( thermiteBurn in thermiteBurns ) {
		entity owner = thermiteBurn.GetOwner()

		if ( IsValid( owner ) && owner.GetTeam() != smokescreen.ownerTeam )
			thermiteBurn.Destroy()
	}

	//	Whether or not the smokescreen blocks traces
	entity traceBlocker
	if ( smokescreen.blockLOS )
		traceBlocker = Smokescreen_CreateTraceBlockerVol( smokescreen, fxInfo )

	#if DEV
	if ( SMOKESCREEN_DEBUG )
		DebugDrawCircle( fxInfo.center, <0,0,0>, fxInfo.radius + 240.0, 255, 255, 0, true, smokescreen.lifetime )
	#endif

	//	AI bullshit
	CreateNoSpawnArea( TEAM_ANY, TEAM_ANY, fxInfo.center, smokescreen.lifetime, fxInfo.radius + 240.0 )

	//	SFX
	if ( IsValid( smokescreen.attacker ) && smokescreen.attacker.IsPlayer() ) {
		EmitSoundAtPositionExceptToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.deploySound3p )
		EmitSoundAtPositionOnlyToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.deploySound1p)
	} else {
		EmitSoundAtPosition( TEAM_ANY, fxInfo.center, smokescreen.deploySound3p )
	}

	array<entity> fxEntities = SmokescreenFX( smokescreen, fxInfo )
	if ( smokescreen.isElectric )
		thread SmokescreenAffectsEntitiesInArea( smokescreen, fxInfo )
	//thread CreateSmokeSightTrigger( fxInfo.center, smokescreen.ownerTeam, smokescreen.lifetime ) // disabling for now, this should use the calculated radius if reenabled

	//	Destruction
	if( smokescreen.lifetime != 0 ) {
		thread DynamicSmokescreen_DestroyAfterTime( smokescreen, smokescreen.lifetime, fxInfo, traceBlocker, fxEntities )
	}

}

void function DynamicSmokescreen_DestroyAfterTime( DynamicSmokescreenData smokescreen, float lifetime,
		DynamicSmokescreenFX fxInfo, entity traceBlocker, array<entity> fxEntities ) {
	//	Wait for... something
	float timeToWait = 0.0
	timeToWait = max( lifetime - 0.5, 0.0 )
	wait( timeToWait )

	//	Destroy trace blocker & fx
	if( IsValid( traceBlocker ) )
		traceBlocker.Destroy()
	file.allSmokescreenFX.fastremovebyvalue( fxInfo )

	//	SFX
	StopSoundAtPosition( fxInfo.center, smokescreen.deploySound1p )
	StopSoundAtPosition( fxInfo.center, smokescreen.deploySound3p )

	if( IsValid( smokescreen.attacker ) && smokescreen.attacker.IsPlayer() ) {
		if ( smokescreen.stopSound3p != "" )
			EmitSoundAtPositionExceptToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.stopSound3p )

		if ( smokescreen.stopSound1p != "" )
			EmitSoundAtPositionOnlyToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.stopSound1p)
	} else {
		if ( smokescreen.stopSound3p != "" )
			EmitSoundAtPosition( TEAM_ANY, fxInfo.center, smokescreen.stopSound3p )
	}

	//	Wait for... something
	timeToWait = max( ( lifetime + 0.1 ) - timeToWait, 0.0 )
	wait( timeToWait )

	//	Destroy fx
	foreach ( fxEnt in fxEntities ) {
		if ( IsValid( fxEnt ) )
			fxEnt.Destroy()
	}
}

void function DynamicSmokescreen_DestroyNow( DynamicSmokescreenData smokescreen,
		DynamicSmokescreenFX fxInfo, entity traceBlocker, array<entity> fxEntities ) {
	thread DynamicSmokescreen_DestroyAfterTime( smokescreen, 0.0, fxInfo, traceBlocker, fxEntities)
}

//	FX stuffs
void function Smokescreen( SmokescreenStruct smokescreen )
{
	SmokescreenFXStruct fxInfo = Smokescreen_CalculateFXStruct( smokescreen )
	file.allSmokescreenFX.append( fxInfo )

	array<entity> thermiteBurns = GetActiveThermiteBurnsWithinRadius( fxInfo.center, fxInfo.radius )
	foreach ( thermiteBurn in thermiteBurns )
	{
		entity owner = thermiteBurn.GetOwner()

		if ( IsValid( owner ) && owner.GetTeam() != smokescreen.ownerTeam )
			thermiteBurn.Destroy()
	}

	entity traceBlocker

	if ( smokescreen.blockLOS )
		traceBlocker = Smokescreen_CreateTraceBlockerVol( smokescreen, fxInfo )

#if DEV
	if ( SMOKESCREEN_DEBUG )
		DebugDrawCircle( fxInfo.center, <0,0,0>, fxInfo.radius + 240.0, 255, 255, 0, true, smokescreen.lifetime )
#endif
	CreateNoSpawnArea( TEAM_ANY, TEAM_ANY, fxInfo.center, smokescreen.lifetime, fxInfo.radius + 240.0 )

	if ( IsValid( smokescreen.attacker ) && smokescreen.attacker.IsPlayer() )
	{
		EmitSoundAtPositionExceptToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.deploySound3p )
		EmitSoundAtPositionOnlyToPlayer( TEAM_ANY, fxInfo.center, smokescreen.attacker, smokescreen.deploySound1p)
	}
	else
	{
		EmitSoundAtPosition( TEAM_ANY, fxInfo.center, smokescreen.deploySound3p )
	}

	array<entity> fxEntities = SmokescreenFX( smokescreen, fxInfo )
	if ( smokescreen.isElectric )
		thread SmokescreenAffectsEntitiesInArea( smokescreen, fxInfo )
	//thread CreateSmokeSightTrigger( fxInfo.center, smokescreen.ownerTeam, smokescreen.lifetime ) // disabling for now, this should use the calculated radius if reenabled

	thread DestroySmokescreen( smokescreen, smokescreen.lifetime, fxInfo, traceBlocker, fxEntities )
}

DynamicSmokescreenFX function Smokescreen_CalculateFXStruct( DynamicSmokescreenData smokescreen ) {
	DynamicSmokescreenFX fxInfo

	foreach ( i, position in smokescreen.fxOffsets ) {
		//mins
		if ( i == 0 || position.x < fxInfo.mins.x )
			fxInfo.mins = <position.x, fxInfo.mins.y, fxInfo.mins.z>

		if ( i == 0 || position.y < fxInfo.mins.y )
			fxInfo.mins = <fxInfo.mins.x, position.y, fxInfo.mins.z>

		if ( i == 0 || position.z < fxInfo.mins.z )
			fxInfo.mins = <fxInfo.mins.x, fxInfo.mins.y, position.z>

		// maxs
		if ( i == 0 || position.x > fxInfo.maxs.x )
			fxInfo.maxs = <position.x, fxInfo.maxs.y, fxInfo.maxs.z>

		if ( i == 0 || position.y > fxInfo.maxs.y )
			fxInfo.maxs = <fxInfo.maxs.x, position.y, fxInfo.maxs.z>

		if ( i == 0 || position.z > fxInfo.maxs.z )
			fxInfo.maxs = <fxInfo.maxs.x, fxInfo.maxs.y, position.z>
	}

	vector offsetCenter = fxInfo.mins + ( fxInfo.maxs - fxInfo.mins ) * 0.5

	float xyRadius = smokescreen.fxXYRadius * 0.7071
	float zRadius = smokescreen.fxZRadius * 0.7071

	fxInfo.mins = Vector( fxInfo.mins.x - xyRadius, fxInfo.mins.y - xyRadius, fxInfo.mins.z - zRadius ) - offsetCenter
	fxInfo.maxs = Vector( fxInfo.maxs.x + xyRadius, fxInfo.maxs.y + xyRadius, fxInfo.maxs.z + zRadius ) - offsetCenter

	float radiusSqr
	float singleFXRadius = max( smokescreen.fxXYRadius, smokescreen.fxZRadius )

	vector forward = AnglesToForward( smokescreen.angles )
	vector right = AnglesToRight( smokescreen.angles )
	vector up = AnglesToUp( smokescreen.angles )

	foreach ( i, position in smokescreen.fxOffsets ) {
		float distanceSqr = DistanceSqr( position, offsetCenter )

		if ( radiusSqr < distanceSqr )
			radiusSqr = distanceSqr

		fxInfo.fxWorldPositions.append( smokescreen.origin + ( position.x * forward ) + ( position.y * right ) + ( position.z * up ) )
	}

	fxInfo.center = smokescreen.origin + ( offsetCenter.x * forward ) + ( offsetCenter.y * right ) + ( offsetCenter.z * up )
	fxInfo.radius = sqrt( radiusSqr ) + singleFXRadius
	fxInfo.ownerTeam = smokescreen.ownerTeam

	return fxInfo
}

array<entity> function SmokescreenFX( DynamicSmokescreenData smokescreen, DynamicSmokescreenFX fxInfo ) {
	array<entity> fxEntities

	foreach ( position in fxInfo.fxWorldPositions ) {
		#if DEV
		if ( SMOKESCREEN_DEBUG )
			DebugDrawCircle( position, <0.0, 0.0, 0.0>, smokescreen.fxXYRadius, 0, 0, 255, true, smokescreen.lifetime )
		#endif

		int fxID = GetParticleSystemIndex( smokescreen.smokescreenFX )
		vector angles = smokescreen.fxUseWeaponOrProjectileAngles ? smokescreen.weaponOrProjectile.GetAngles() : <0.0, 0.0, 0.0>
		entity fxEnt = StartParticleEffectInWorld_ReturnEntity( fxID, position, angles )
		float fxLife = smokescreen.lifetime

		EffectSetControlPointVector( fxEnt, 1, <fxLife, 0.0, 0.0> )

		if ( !smokescreen.shouldHibernate )
			fxEnt.DisableHibernation()

		fxEntities.append( fxEnt )
	}

	return fxEntities
}

//	Area stuffs
void function DynamicSmokescreen_DoEntityAreaDamage( DynamicSmokescreenData smokescreen, DynamicSmokescreenFX fxInfo ) {
	float startTime = Time()
	float tickRate = 0.1

	float dpsPilot = smokescreen.dpsPilot * tickRate
	float dpsTitan = smokescreen.dpsTitan * tickRate
	Assert( dpsPilot || dpsTitan > 0, "Damaging smokescreen with 0 damage created" )

	entity aiDangerTarget = CreateEntity( "info_target" )
	DispatchSpawn( aiDangerTarget )
	aiDangerTarget.SetOrigin( fxInfo.center )
	SetTeam( aiDangerTarget, smokescreen.ownerTeam )

	float dangerousAreaRadius = smokescreen.damageOuterRadius
	if ( smokescreen.dangerousAreaRadius != -1.0 )
		dangerousAreaRadius = smokescreen.dangerousAreaRadius

	AI_CreateDangerousArea_Static( aiDangerTarget, smokescreen.weaponOrProjectile, dangerousAreaRadius, TEAM_INVALID, true, true, fxInfo.center )

	OnThreadEnd( function () : ( aiDangerTarget ) {
		aiDangerTarget.Destroy()
	})

	wait smokescreen.damageDelay

	while ( Time() - startTime <= smokescreen.lifetime ) {
		#if DEV
		if ( SMOKESCREEN_DEBUG ) {
			DebugDrawCircle( fxInfo.center, <0,0,0>, smokescreen.damageInnerRadius, 255, 0, 0, true, tickRate )
			DebugDrawCircle( fxInfo.center, <0,0,0>, smokescreen.damageOuterRadius, 255, 0, 0, true, tickRate )
		}
		#endif

		RadiusDamage(
			fxInfo.center,															// center
			smokescreen.attacker,													// attacker
			smokescreen.inflictor,													// inflictor
			dpsPilot,																// damage
			dpsTitan,																// damageHeavyArmor
			smokescreen.damageInnerRadius,											// innerRadius
			smokescreen.damageOuterRadius,											// outerRadius
			SF_ENVEXPLOSION_MASK_BRUSHONLY,	// flags
			0.0,																	// distanceFromAttacker
			0.0,																	// explosionForce
			DF_ELECTRICAL | DF_NO_HITBEEP,											// scriptDamageFlags
			smokescreen.damageSource )												// scriptDamageSourceIdentifier

		wait tickRate
	}
}