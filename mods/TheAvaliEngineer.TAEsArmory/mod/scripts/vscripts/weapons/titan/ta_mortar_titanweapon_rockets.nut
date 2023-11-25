//		Function declarations
global function TArmory_Init_MortarTone_Rockets

global function OnWeaponPrimaryAttack_MortarTone_Rockets
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_Rockets
#endif

global function OnProjectileCollision_MortarTone_Rockets

global function CalculateFireArc


//		Data
//	Struct
global struct MortarFireData {
	vector launchDir
	float speed

	float flightTime
}

//	Consts
const float MORTAR_GRAVITY = 375.0

const float MORTAR_INACCURACY = 0.50
const float MORTAR_MAX_SPREAD = 250.0

//			Functions
//		Init
void function TArmory_Init_MortarTone_Rockets() {
	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titanweapon_rockets" )

	#if SERVER
	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_mortar_titanweapon_rockets = "Rocket Salvo",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}


//		Fire handling
var function OnWeaponPrimaryAttack_MortarTone_Rockets( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireMortarRockets( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_Rockets( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireMortarRockets( weapon, attackParams, false )
}
#endif

int function FireMortarRockets( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) || !IsAlive(owner) )
		return 0

	#if SERVER
	//	Add owner to flareData if they aren't in there already
	if( !(owner in flareData) ) {
		flareData[owner] <- []
	}

	//	Variables
	float arcHeight = 1500.0

	//	Fire mortar in look direction if no flares have been fired
	array<entity> flares = flareData[owner]
	if( flares.len() == 0 ) {
		print("[TAEsArmory] FireMortarRockets: No flares")

		//	Adjust variables
		arcHeight /= 2.5

		//	Create flare ent
		vector viewDir = owner.GetPlayerOrNPCViewVector()
		vector searchPos = owner.EyePosition() + viewDir * 2500

		TraceResults trace = TraceLine( owner.EyePosition(), searchPos, owner, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )
		flares.append( CreateScriptMover( trace.endPos ) )
	}

	foreach( flare in flares ) {
		//	Check if owner is alive
		if( !IsAlive(owner) )
			return 0

		//	Check if flare is valid
		if( !IsValid(flare) )
			continue

		//	Get arc params
		vector playerPos = attackParams.pos
		vector flarePos = flare.GetOrigin()

		float gravityAmount = MORTAR_GRAVITY * weapon.GetWeaponSettingFloat( eWeaponVar.projectile_gravity_scale )

		//	Apply inaccuracy
		vector up = Vector(0.0, 0.0, 1.0)
		vector spreadVec = ApplyVectorSpread( up, MORTAR_INACCURACY * 180 )
		vector spreadXY = Vector(spreadVec.x, spreadVec.y, 0.0) * MORTAR_MAX_SPREAD

		flarePos += spreadXY

		//	Calculate trajectory
		MortarFireData fireData = CalculateFireArc( playerPos, flarePos, 1500.0, gravityAmount )

		//	Calculate fire params
		vector dir = fireData.launchDir * fireData.speed
		vector angVel = Vector(0., 0., 0.)
		float fuse = fireData.flightTime + 0.25

		int damageFlags = weapon.GetWeaponDamageFlags()

		//entity rocket = weapon.FireWeaponGrenade( attackParams.pos, dir, angVel, fuse,
		//	damageTypes.pinkMist, damageTypes.pinkMist, false, true, false )
		entity rocket = weapon.FireWeaponBolt( attackParams.pos, fireData.launchDir,
			fireData.speed, damageFlags, damageFlags, playerFired, 0 )
		if( rocket ) {
			//rocket.kv.gravity = 1.0
			rocket.SetProjectileLifetime( fuse )

			#if SERVER
			Grenade_Init( rocket, weapon )
			#else
			SetTeam( rocket, owner.GetTeam() )
			#endif
		}
	}

	if( weapon.GetBurstFireShotsPending() == 1 ) {
		foreach( flare in flares ) {
			flareData[owner].fastremovebyvalue(flare)

			if( IsValid(flare) )
				flare.Destroy()
		}
	}
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

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


//		Collision handling
void function OnProjectileCollision_MortarTone_Rockets( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	//		Phasing check
	//	Check fuse time left: If above or below certain threshold - explode (at end / as punishment for poor positioning)
	//

}

void function PhasedProjectileThink( entity projectile ) {

}