//		Function declarations
global function TArmory_Init_MortarTone_DomeShield

global function OnWeaponPrimaryAttack_MortarTone_DomeShield
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_DomeShield
#endif

//		Data
//	FX
const asset PROJECTOR_MODEL = $"models/weapons/titan_trip_wire/titan_trip_wire.mdl"

const string PROJECTOR_LAND_SFX = "Wpn_LaserTripMine_Land"
const string PROJECTOR_LAND_ANIM = "trip_wire_closed_to_open"

//			Functions
//		Init
void function TArmory_Init_MortarTone_DomeShield() {
	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titanability_domeshield" )
	#endif
}

//		Fire handling
var function OnWeaponPrimaryAttack_MortarTone_DomeShield( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	#if SERVER
		return LaunchDomeShield( weapon, attackParams, true )
	#endif
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_DomeShield( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return LaunchDomeShield( weapon, attackParams, false )
}
#endif

int function LaunchDomeShield( entity weapon, WeaponPrimaryAttackParams params, bool playerFired ) {
	//	Sanity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0

	//	Direction handling
	vector dir = params.dir
	dir.z = min( dir.z, 0.2588 )
	params.dir = dir

	//	Create deployable
	entity deployable = ThrowDeployable( weapon, params, 1, OnDomeShieldPlanted )

	//Fire Grenade
	//vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )
	//int damageType = DF_RAGDOLL | DF_EXPLOSION
	//entity deployable = weapon.FireWeaponGrenade( params.pos, params.dir, angularVelocity, 0.0 , damageType, damageType, playerFired, true, false )

	#if SERVER
	deployable.SetOwner( weapon )
	#endif

	//	Offhand
	if( owner.IsPlayer() )
		PlayerUsedOffhand( owner, weapon )

	//	Ammo
	return weapon.GetAmmoPerShot()
}

//	Collision handling
void function OnDomeShieldPlanted( entity projectile ) {
	//	Sanity checks
	//entity owner = projectile.GetOwner()
	//if( !IsValid(owner) )
		//return

	printt("I AM PLANTED SIRRRRRRRRRRRRRR")

	/*	Handle angles
	vector pos = proj.GetOrigin()
	vector endPos = pos - <0., 0., 32.>
	vector norm = proj.proj.savedAngles

	bool setAngles = true

	TraceResults result = TraceLine( pos, endPos, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	if( result.fraction < 1.0 ) {
		norm = result.surfaceNormal

		float dot = norm.Dot( Vector( 0, 0, 1 ) )
		setAngles = setAngles && (dot > 0.8)
		if( setAngles )
			norm = proj.proj.savedAngles
	}
	proj.SetAngles(norm)
	//*/

	#if SERVER
		Assert( IsValid( projectile ) )
		vector origin = projectile.GetOrigin()

		vector endOrigin = origin - < 0.0, 0.0, 32.0 >
		vector surfaceAngles = projectile.proj.savedAngles
		vector oldUpDir = AnglesToUp( surfaceAngles )

		TraceResults traceResult = TraceLine( origin, endOrigin, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
		if ( traceResult.fraction < 1.0 )
		{
			vector forward = AnglesToForward( projectile.proj.savedAngles )
			surfaceAngles = AnglesOnSurface( traceResult.surfaceNormal, forward )

			vector newUpDir = AnglesToUp( surfaceAngles )
			if ( DotProduct( newUpDir, oldUpDir ) < 0.55 )
				surfaceAngles = projectile.proj.savedAngles
		}

		projectile.SetAngles( surfaceAngles )
	#endif

	#if SERVER
	//	Start thread
	thread DomeShieldThink( projectile )
	#endif
}

#if SERVER
void function DomeShieldThink( entity proj ) {
	//	Sanity checks
	entity weapon = proj.GetOwner()
	if( !IsValid(weapon) )
		return

	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return

	//		Dome shield
	//	Create
	float duration = proj.GetProjectileWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	entity shieldEnt = DomeShield_Create( proj, weapon, owner )
	entity towerEnt = Tower_Create( proj, weapon, owner )

	//	Parent
	entity projParent = proj.GetParent()

	shieldEnt.SetParent( proj )
	if( projParent != null )
		towerEnt.SetParent( projParent )

	//	Signaling
	shieldEnt.EndSignal( "OnDestroy" )
	towerEnt.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( shieldEnt, towerEnt ) {
		DomeShield_Destroy( shieldEnt )
		Tower_Destroy( towerEnt )
	})

	wait duration
	if( duration == -1 )
		WaitForever()

}
#endif

//		Tower logic
entity function Tower_Create( entity proj, entity weapon, entity owner ) {
	#if SERVER
	//	Retrieve
	vector origin = proj.GetOrigin()
	vector angles = proj.proj.savedAngles

	//		Setup deployable
	//	Setup
	entity tower = CreatePropScript( PROJECTOR_MODEL, origin, angles, SOLID_VPHYSICS )
	tower.kv.collisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS

	SetTeam( tower, owner.GetTeam() )
	tower.SetOwner( owner )

	SetTargetName( tower, "Shield Projector" )
	tower.SetTitle( "Shield Projector" )

	//	Health
	int health = 250
	tower.SetMaxHealth( health )
	tower.SetHealth( health )

	tower.SetTakeDamageType( DAMAGE_YES )
	tower.SetArmorType( ARMOR_TYPE_HEAVY )

	//	Damage handling
	tower.SetDamageNotifications( true )
	tower.SetDeathNotifications( true )

	SetObjectCanBeMeleed( tower, true )
	SetVisibleEntitiesInConeQueriableEnabled( tower, true )
	SetCustomSmartAmmoTarget( tower, false )

	tower.e.noOwnerFriendlyFire = true

	//	AI
	tower.EnableAttackableByAI( 20, 0, AI_AP_FLAG_NONE )

	//	FX
	EmitSoundOnEntity( tower, PROJECTOR_LAND_SFX )

	tower.Anim_Play( PROJECTOR_LAND_ANIM )
	tower.Anim_DisableUpdatePosition()

	//	Return
	return tower
	#endif
}

void function Tower_Destroy( entity tower ) {
	//	Sanity checks
	if( !IsValid( tower ) )
		return

	#if SERVER
	//	Functionality
	ClearChildren( tower )
	tower.Destroy()
	#endif
}