//		Function declarations
global function TArmory_Init_AntiTitan_MineLauncher

global function OnWeaponPrimaryAttack_AntiTitan_MineLauncher
#if SERVER
global function OnWeaponNpcPrimaryAttack_AntiTitan_MineLauncher
#endif

global function OnProjectileCollision_AntiTitan_MineLauncher

//		Vars
//	Mine detection vars
const float MINE_ARM_DELAY = 1.5

const float MINE_TICKRATE = 5.0

const float MINE_DETECT_RADIUS = 150.0
const float MINE_DETECT_HEIGHT = 25.0

const float MINE_TRIGGER_DELAY = 0.5

//	SFX
const string MINE_TRIGGER_SFX = "Weapon_ProximityMine_CloseWarning"

//	Other
const int MINE_HEALTH = 50
const float MINE_ANGLE_LIMIT = 0.5

//		Functions
//	Init
void function TArmory_Init_AntiTitan_MineLauncher() {
    #if SERVER
	//  Precache weapon
	PrecacheWeapon( "ta_weapon_minelauncher" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_weapon_minelauncher = "Mine Launcher",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Fire handling
var function OnWeaponPrimaryAttack_AntiTitan_MineLauncher( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() ) {
		vector offset = Vector( 30.0, 6.0, -4.0 ) // forward, right, up
		if ( weapon.IsWeaponInAds() )
			offset = Vector( 30.0, 0.0, -3.0 )

		vector attackPos = player.OffsetPositionFromView( attackParams[ "pos" ], offset )

		FireLandmine( weapon, attackParams, true )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_AntiTitan_MineLauncher( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireLandmine( weapon, attackParams, false )
}
#endif // #if SERVER

void function FireLandmine( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	vector angVel = Vector( 450, 0, 0 )

	float fuse = weapon.GetWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	int damageFlags = weapon.GetWeaponDamageFlags()

	entity mine = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir,
			angVel, fuse, damageFlags, damageFlags, false, true, false )

	if ( mine ) {
		entity player = weapon.GetWeaponOwner()
		#if SERVER
		mine.SetOwner( player )
		Grenade_Init( mine, weapon )
		#else
		SetTeam( mine, player.GetTeam() )
		#endif
	}

}

//	Collision handling
void function OnProjectileCollision_AntiTitan_MineLauncher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
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
			mine.GrenadeExplode( mine.GetForwardVector() )
	})
	//thread TrapExplodeOnDamage( mine, MINE_HEALTH )

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

	if ( !other.IsTitan() )
		return false

	//	Linetrace visibility check
	TraceResults results = TraceLine( mine.GetOrigin(), other.EyePosition(), mine, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )
	if ( results.fraction >= 1 || results.hitEnt == other )
		return true

	return false
}
#endif