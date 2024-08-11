untyped

//		Function declarations
global function CalculateFireArc
global function CalculateFireVecs
global function TeleportProjectile
global function TeleportGrenade

//		Data
//	Struct
global struct MortarFireData {
	vector launchDir
	float speed

	float flightTime
}

//	Settings
const float MORTAR_GRAVITY = 375.0
const float MORTAR_OFFSET = 100.0

//		Functions
/*	Calculate throw direction + velocity for arc with params
 *	See https://github.com/Masterchef365/avali_projectile_path/blob/main/main.pdf
 *	Thanks Seg!
 */
MortarFireData function CalculateFireArc( vector startPos, vector endPos, float maxHeight, float g ) {
	//	Add pos to maxHeight
	maxHeight += max(0, endPos.z - startPos.z)

	//	Calculate offsets
	float xOffset = endPos.x - startPos.x
	float yOffset = endPos.y - startPos.y
	float horizOffset = sqrt(xOffset * xOffset + yOffset * yOffset)
	float vertOffset = endPos.z - startPos.z

	//	Calculate velocity
	float vertSpeed = 2 * sqrt(maxHeight * g)
	float flightTime = (vertSpeed + sqrt(vertSpeed * vertSpeed - 4 * g * vertOffset)) / (2 * g)
	float horizSpeed = horizOffset / flightTime

	float projSpeed = sqrt( vertSpeed * vertSpeed + horizSpeed * horizSpeed )

	//	Find angles
	vector projAngles = VectorToAngles( Vector( horizSpeed, 0.0, vertSpeed ) )
	vector xyAngles = VectorToAngles( Vector( xOffset, yOffset, 0.0 ) )

	vector launchAngles = AnglesCompose( xyAngles, projAngles )

	//	Create direction vector
	vector dir = AnglesToForward( launchAngles )

	//	Create data
	MortarFireData data

	data.launchDir = dir
	data.speed = projSpeed

	data.flightTime = flightTime

	/*
	print("\n[TAEsArmory] CalculateFireArc: Variables\n\tmaxHeight = " + maxHeight + "\n\tvertOffset = "
		+ vertOffset + "\n\thorizOffset = " + horizOffset + "\n\tvertSpeed = " + vertSpeed +
		"\n\tflightTime = " + flightTime + "\n\thorizSpeed = " + horizSpeed + "\n\n")
	//	*/

	//	Return
	return data
}

vector function CalculateFireVecs( vector startPos, vector endPos, float tof, float g ) {
	//	Calculate offsets
	float xOffset = endPos.x - startPos.x
	float yOffset = endPos.y - startPos.y
	float vertOffset = endPos.z - startPos.z

	//	Calculate velocity
	float vertSpeed = (g*tof*tof + vertOffset)/tof		//	(m/s^2 * s * s + m) / s

	//	Create & return velocity
	return Vector(xOffset/tof, yOffset/tof, vertSpeed)
}

//	New method - teleport rockets to the new point after a delay
void function TeleportProjectile( entity proj, entity weapon, vector targetPos, vector endNormal, float delay ) {
	//		Calculation
	//	Raytraces
	vector startNormal = Normalize( proj.GetVelocity() )

	float projSpeed = Length( proj.GetVelocity() )
	float traceRange = projSpeed * delay * 0.5

	vector projPos = proj.GetOrigin()
	vector projTracePos = projPos + startNormal * (traceRange + MORTAR_OFFSET)
	vector targetTracePos = targetPos + endNormal * (traceRange + MORTAR_OFFSET)

	TraceResults resultProj = TraceLine( projPos, projTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	TraceResults resultTarget = TraceLine( targetPos, targetTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	//	Calculate delay
	float delayProj = delay
	float delayTarget = delay

	if( resultProj.fraction < 1.0 ) {
		delayProj *= resultProj.fraction
		delayProj -= 0.1
	}

	if( resultTarget.fraction < 1.0 ) {
		delayTarget *= resultTarget.fraction
		delayTarget += 0.1

		targetTracePos = resultTarget.endPos
	}

	delayTarget = delay - delayTarget
	targetTracePos -= endNormal * MORTAR_OFFSET

	wait delayProj

	//		Projectile handling
	//	Handle projectile deletion
	float fuse = delay*0.5 //+ expect float( proj.s.fuse )
	if( IsValid(proj) )
		proj.Destroy()

	wait delayTarget

	//	Handle projectile creation
	entity owner = weapon.GetWeaponOwner()
	int damageFlags = weapon.GetWeaponDamageFlags()

	entity newProj = weapon.FireWeaponBolt( targetTracePos, -endNormal,
		projSpeed, damageFlags, damageFlags, false, 0 )

	#if SERVER
		PlayPhaseRocketFX(newProj)
	#endif

	if( newProj ) {
		if( "phase" in newProj.s ) {
			newProj.s.phase = false
		} else { newProj.s.phase <- false }

		//	Grenade init
		newProj.SetProjectileLifetime( delay )
		newProj.kv.gravity = 0.0
	}
}

#if SERVER
entity function PlayPhaseRocketFX( entity ent )
{
	asset effect = $"P_phase_shift_main"

	if ( IsValid(ent) )
	{
		//EmitSoundOnEntity( ent, SHIFTER_END_SOUND_3P )

		return PlayFX( effect, ent.GetOrigin(), ent.GetAngles() )
	}
}
#endif

void function TeleportGrenade( entity proj, entity weapon, vector targetPos, vector endNormal, float delay ) {
	//		Calculation
	//	Raytraces
	vector startNormal = Normalize( proj.GetVelocity() )

	float projSpeed = Length( proj.GetVelocity() )
	float traceRange = projSpeed * delay * 0.5

	vector projPos = proj.GetOrigin()
	targetPos = targetPos + startNormal * MORTAR_OFFSET
	vector projTracePos = projPos + startNormal * (traceRange + MORTAR_OFFSET)
	vector targetTracePos = targetPos + endNormal * (traceRange + MORTAR_OFFSET)

	TraceResults resultProj = TraceLine( projPos, projTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	TraceResults resultTarget = TraceLine( targetPos, targetTracePos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	//	Calculate delay
	float delayProj = delay
	float delayTarget = delay

	if( resultProj.fraction < 1.0 ) {
		delayProj *= resultProj.fraction
		delayProj -= 0.1
	}

	if( resultTarget.fraction < 1.0 ) {
		delayTarget *= resultTarget.fraction
		delayTarget += 0.1

		targetTracePos = resultTarget.endPos
	}

	delayTarget = delay - delayTarget
	targetTracePos -= endNormal * MORTAR_OFFSET

	wait delayProj

	//		Projectile handling
	//	Handle projectile deletion
	float fuse = delay*0.5 //+ expect float( proj.s.fuse )
	if( IsValid(proj) )
		proj.Destroy()

	wait delayTarget

	//	Handle projectile creation
	entity owner = weapon.GetWeaponOwner()
	int damageFlags = weapon.GetWeaponDamageFlags()

	vector vel = -endNormal * projSpeed
	vector angVel = Vector(0., 0., 0.)

	entity newProj = weapon.FireWeaponGrenade( targetTracePos, -vel,
		angVel, 0.0, damageFlags, damageFlags, false, false, false )
	if( newProj ) {
		newProj.kv.gravity = 0.0

		//	Table init
		if( "phase" in newProj.s ) {
			newProj.s.phase = false
		} else { newProj.s.phase <- false }

		//	Grenade init
		#if SERVER
		Grenade_Init( newProj, weapon )
		#else
		entity weaponOwner = weapon.GetWeaponOwner()
		SetTeam( newProj, weaponOwner.GetTeam() )
		#endif
	}
}