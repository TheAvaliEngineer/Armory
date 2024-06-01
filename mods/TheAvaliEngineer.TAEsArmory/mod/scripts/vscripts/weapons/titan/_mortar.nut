//		Function declarations
global function TeleportProjectile
global function CalculateFireArc

//		Data
//	Struct
global struct MortarFireData {
	vector launchDir
	float speed

	float flightTime
}

//	Settings
const float MORTAR_GRAVITY = 375.0
const float MORTAR_OFFSET = 50.0

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

//	New method - teleport rockets to the new point after a delay
void function TeleportProjectile( entity proj, entity weapon, vector target, float delay ) {
	//		Calculation
	//	Raytraces
	vector startNormal = Normalize( proj.GetVelocity() ) 
	vector endNormal = Vector(0, 0, 1)

	float projSpeed = Length( proj.GetVelocity() )
	float traceRange = projSpeed * delay * 0.5

	vector startProj = proj.GetOrigin()
	vector endProj = startProj + startNormal * (traceRange + MORTAR_OFFSET)
	vector endTarget = target + startNormal * (traceRange + MORTAR_OFFSET)

	TraceResults resultProj = TraceLine( startProj, endProj, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	TraceResults resultTarget = TraceLine( target, endTarget, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

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

		endTarget = resultTarget.endPos
	}

	delayTarget = delay - delayTarget
	endTarget -= endNormal * MORTAR_OFFSET

	wait delayProj

	//		Projectile handling
	//	Handle projectile deletion
	float fuse = proj.s.fuse
	proj.Destroy()

	wait delayTarget

	//	Handle projectile creation
	entity owner = weapon.GetWeaponOwner()
	int damageFlags = weapon.GetWeaponDamageFlags()
	bool playerFired = weapon.GetWeaponOwner().IsPlayer()

	entity newProj = weapon.FireWeaponBolt( endTarget, -endNormal,
		projSpeed, damageFlags, damageFlags, playerFired, 0 )
	if( newProj ) {
		//newProj.kv.gravity = 1.0
		newProj.SetProjectileLifetime( delay + fuse )

		#if SERVER
		Grenade_Init( newProj, weapon )
		#else
		SetTeam( newProj, owner.GetTeam() )
		#endif
	}
}