//		Func declarations
global function OnWeaponPrimaryAttack_MortarTone_ProxMines
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_ProxMines
#endif

global function OnProjectileCollision_MortarTone_ProxMines

//		Data
//	Mortar properties
const float MORTAR_GRAVITY = 375.0

const float PROX_MINES_INACCURACY = 0.35
const float PROX_MINES_MAX_SPREAD = 7.5
const float PROX_MINES_FIELD_RADIUS = 150.0

//	Mine detection vars
const float MINE_ARM_DELAY = 1.5
const float MINE_TICKRATE = 5.0

const float MINE_DETECT_RADIUS = 150.0

const float MINE_TRIGGER_DELAY = 0.5

//	Mine SFX
const string MINE_TRIGGER_SFX = "Weapon_ProximityMine_CloseWarning"

//	Other mine stats
const int MINE_HEALTH = 50
const float MINE_LIFETIME = 20.0
const float MINE_LIFETIME_RANDAMOUNT = 5.0

//	Mine pattern
const float phi = ( 1.0 + sqrt(5.0) ) / 2.0

float[2][20] mineOffsets = [
	[0, 0],
	[-0.368684, -0.337745],
	[0.0618193, 0.704399],
	[0.526923, -0.687279],
	[-0.984713, 0.174182],
	[0.943347, 0.600081],
	[-0.31795, -1.18275],
	[-0.609722, 1.17398],
	[1.3284, -0.48513],
	[-1.38652, -0.572333],
	[0.670158, 1.43209],
	[0.496306, -1.5823],
	[-1.49859, 0.868466],
	[1.76073, 0.387092],
	[-1.07597, -1.53045],
	[-0.248863, 1.92043],
	[1.5293, -1.28889],
	[-2.05979, -0.0851847],
	[1.50366, 1.49633],
	[-0.100672, -2.17712]
]

//		Functions
//	Init


//	Fire handling
var function OnWeaponPrimaryAttack_MortarTone_ProxMines( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireProxMinefield( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_ProxMines( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireProxMinefield( weapon, attackParams, false )
}
#endif

int function FireProxMinefield( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) || !IsAlive(owner) )
		return 0

	#if SERVER
	if(!(owner in flareData))
		return 0

	array<entity> flares = flareData[owner]
	if( flares.len() == 0 )
		return 0

	entity flare = flares[flares.len() - 1]

	//	Check if flare is valid
	if( !IsValid(flare) )
		return 0

	//	Get arc params
	vector playerPos = attackParams.pos
	vector flarePos = flare.GetOrigin()

	float gravityAmount = MORTAR_GRAVITY * weapon.GetWeaponSettingFloat( eWeaponVar.projectile_gravity_scale )

	//	Spawn projectiles
	int numProjectiles = weapon.GetProjectilesPerShot()

	int pendingShots = weapon.GetBurstFireShotsPending()
	int shotNum = weapon.GetWeaponSettingInt( eWeaponVar.burst_fire_count ) - pendingShots
	for ( int index = 0; index < numProjectiles; index++ ) {
		//	Apply offset
		int offsetIdx = shotNum * 3 + index

		float rho = sqrt(offsetIdx) * 0.5
        float theta = (2.0 * PI * offsetIdx) / phi

        float x = rho * cos(theta)
        float y = rho * sin(theta)

		vector offsetXY = Vector( x, y, 0.0 ) * PROX_MINES_FIELD_RADIUS
		flarePos += offsetXY

		//	Apply inaccuracy
		vector up = Vector(0.0, 0.0, 1.0)
		vector spreadVec = ApplyVectorSpread( up, PROX_MINES_INACCURACY * 180 )
		vector spreadXY = Vector(spreadVec.x, spreadVec.y, 0.0) * PROX_MINES_MAX_SPREAD

		//	Calculate trajectory
		MortarFireData fireData = CalculateFireArc( playerPos, flarePos, 1500.0, gravityAmount )

		//	Calculate fire params
		vector dir = fireData.launchDir * fireData.speed
		vector angVel = Vector(0., 0., 0.)
		float fuse = fireData.flightTime + MINE_LIFETIME + RandomFloatRange( 0, MINE_LIFETIME_RANDAMOUNT )

		int damageFlags = weapon.GetWeaponDamageFlags()

		entity mine = weapon.FireWeaponGrenade( attackParams.pos, dir,
			angVel, fuse, damageFlags, damageFlags, false, true, false )
		if( mine ) {
			//mine.kv.gravity = 1.0
			#if SERVER
			mine.SetOwner( owner )
			Grenade_Init( mine, weapon )
			#else
			SetTeam( mine, owner.GetTeam() )
			#endif
		}
	}

	//	Remove flare
	if( pendingShots == 1 ) {
		flareData[owner].fastremovebyvalue(flare)
	}
	#endif

	//	Consume ammo
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

//	Collision handling
void function OnProjectileCollision_MortarTone_ProxMines( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	table collisionParams = {
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool result = PlantStickyEntity( projectile, collisionParams )

	thread OnMinePlanted( projectile )
}

//	Mine functionality
void function OnMinePlanted( entity mine ) {
	//	Angles correct
	vector surfaceAngles = mine.GetAngles()

	vector origin = mine.GetOrigin()

	vector toForward = AnglesToForward( surfaceAngles )
	toForward = Normalize( toForward ) * 6

	mine.SetOrigin( origin - toForward )

	vector pitch = Vector( 90, 0, 0 )
	vector newAngles = AnglesCompose( surfaceAngles, pitch )

	mine.SetAngles( newAngles )

	#if SERVER
	thread MineThink( mine, origin + toForward, AnglesToForward( surfaceAngles ) )
	#endif
}

#if SERVER
void function MineThink( entity mine, vector searchPoint, vector normal ) {
	mine.EndSignal( "OnDestroy" )

	//	Trap damage handling
	OnThreadEnd( function() : ( mine ) {
			if ( IsValid( mine ) )
				mine.Destroy()
		}
	)
	thread TrapExplodeOnDamage( mine, MINE_HEALTH )

	//	Arming
	wait MINE_ARM_DELAY

	//	Vars
	float tickInterval = 1.0 / MINE_TICKRATE

	int teamNum = mine.GetTeam()
	float triggerRadius = MINE_DETECT_RADIUS

	//	Check
	bool shouldExplode = false
	while( IsValid(mine) ) {
		//	Check NPCs
		array<entity> nearbyNPCs = GetNPCArrayEx( "any", TEAM_ANY, teamNum, searchPoint, triggerRadius )
		foreach( ent in nearbyNPCs ) {
			shouldExplode = MineTriggerCheck( mine, ent )
		}

		//	Check players
		array<entity> nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, searchPoint, triggerRadius )
		foreach( ent in nearbyPlayers ) {
			shouldExplode = MineTriggerCheck( mine, ent )
		}

		if( shouldExplode )
			break

		wait tickInterval
	}

	//	Do explosion
	EmitSoundOnEntity( mine, MINE_TRIGGER_SFX )

	wait MINE_TRIGGER_DELAY

	if( IsValid( mine ) )
		mine.GrenadeExplode( mine.GetForwardVector() )
}

bool function MineTriggerCheck( entity mine, entity other ) {
	if ( !IsAlive(other) )
		return false

	if ( other.IsPhaseShifted() )
		return false

	//if ( !other.IsTitan() )
	//	return false

	//	Linetrace visibility check
	TraceResults results = TraceLine( mine.GetOrigin(), other.EyePosition(), mine, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )
	if ( results.fraction >= 1 || results.hitEnt == other )
		return true

	return false
}
#endif