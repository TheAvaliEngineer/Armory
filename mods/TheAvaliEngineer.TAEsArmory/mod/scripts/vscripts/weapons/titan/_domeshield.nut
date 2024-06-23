//		Function declarations

//		Data
//	FX
const asset DOME_SHIELD_ASSET = $"models/fx/xo_shield.mdl"

const string DOME_SHIELD_SFX = "BubbleShield_Sustain_Loop"

//		Functions
//	Instancing
entity function DomeShield_Create( entity parent, entity weapon, entity owner ) {
	//	Sanity checks
	
	//	Info retrieval
	vector origin = parent.GetOrigin()
	vector angles = parent.GetAngles()
	
	//		Create shield
	//	Setup
	entity shieldEnt = CreatePropScript( DOME_SHIELD_ASSET, origin, angles, SOLID_VPHYSICS )
	shieldEnt.kv.CollisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS

	SetTeam( shieldEnt, owner.GetTeam() )
	shieldEnt.SetOwner( owner )

	//	Health
	int health = weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value )
	shieldEnt.SetMaxHealth( settings.health )
	shieldEnt.SetHealth( settings.health )

	shieldEnt.SetTakeDamageType( DAMAGE_YES )
	shieldEnt.SetArmorType( ARMOR_TYPE_HEAVY )

	//	Damage handling
	shieldEnt.SetDamageNotifications( true )
	shieldEnt.SetDeathNotifications( true )

	SetObjectCanBeMeleed( shieldEnt, true )
	SetVisibleEntitiesInConeQueriableEnabled( shieldEnt, true )
	SetCustomSmartAmmoTarget( shieldEnt, false )

	//	AI
	#if MP
	DisableTitanfallForLifetimeOfEntityNearOrigin( shieldEnt, 
		origin, TITANHOTDROP_DISABLE_ENEMY_TITANFALL_RADIUS )
	#endif

	//	FX
	array<entity> shieldFX
	vector fxOrigin = origin + Vector( 0, 0, 25 )

	entity vortexFX = StartParticleEffectInWorld_ReturnEntity(
		BUBBLE_SHIELD_FX_PARTICLE_SYSTEM_INDEX, fxOrigin, <0, 0, 0> )
	shieldEnt.s <- vortexFX

	EmitSoundOnEntity( bubbleShield, DOME_SHIELD_SFX )
}