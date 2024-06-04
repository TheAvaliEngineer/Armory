untyped

//		Function declarations
global function TArmory_Init_MortarTone_Rockets

global function OnWeaponPrimaryAttack_MortarTone_Rockets
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_Rockets
#endif

global function OnProjectileCollision_MortarTone_Rockets

//		Data
//	Consts
const float SALVO_INACCURACY = 0.75
const float SALVO_MAX_SPREAD = 750.0

const float SALVO_SPEED = 750.0
const float SALVO_DELAY = 1.0

//			Functions
//		Init
void function TArmory_Init_MortarTone_Rockets() {
	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titanweapon_rockets" )

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

	//	Fire mortar in look direction if no flares have been fired
	array<entity> flares = flareData[owner]
	if( flares.len() == 0 ) {
		print("[TAEsArmory] FireMortarRockets: No flares")

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

		//	Get fire params
		vector playerPos = attackParams.pos
		vector targetPos = flare.GetOrigin()

		//	Apply inaccuracy
		vector up = Vector(0.0, 0.0, 1.0)
		vector spreadVec = ApplyVectorSpread( up, SALVO_INACCURACY * 180 )
		vector spreadXY = Vector(spreadVec.x, spreadVec.y, 0.0) * SALVO_MAX_SPREAD

		targetPos += spreadXY

		//	Fire rocket
		float fuse = -0.1
		vector vel = Vector(0, 0, 1) * SALVO_SPEED
		vector angVel = Vector(0, 0, 0)

		int damageFlags = weapon.GetWeaponDamageFlags()

		entity rocket = weapon.FireWeaponGrenade( attackParams.pos, vel, angVel, 
			fuse, damageFlags, damageFlags, playerFired, playerFired, false )
		if( rocket ) {
			//	Table init
			if( "fuse" in weapon.s ) {
				weapon.s.fuse = fuse
			} else { weapon.s.fuse <- fuse }
			
			//	Other

		}

		thread TeleportProjectile( rocket, weapon, targetPos, SALVO_DELAY )
	}

	if( weapon.GetBurstFireShotsPending() == 1 ) {
		foreach( flare in flares ) {
			flareData[owner].fastremovebyvalue(flare)

			if( IsValid(flare) )
				flare.Destroy()
		}
	}
	#endif

	//	Player handling
	if( playerFired )
		PlayerUsedOffhand( owner, weapon )

	//	
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

//		Collision handling
void function OnProjectileCollision_MortarTone_Rockets( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	//		Phasing check
	//	Check fuse time left: If above or below certain threshold - explode (at end / as punishment for poor positioning)
	//

}