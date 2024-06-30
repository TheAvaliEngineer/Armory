untyped

//		Function declarations
global function DomeShield_Create
global function DomeShield_Destroy

//		Data
//	FX - Assets
const asset DOME_SHIELD_ASSET = $"models/fx/xo_shield.mdl"

const string DOME_SHIELD_SFX = "BubbleShield_Sustain_Loop"

//	FX - Colors
const vector DOME_COLOR_FULL = <92, 155, 200>
const vector DOME_COLOR_MED = <255, 128, 80>
const vector DOME_COLOR_LOW = <255, 80, 80>

const float DOME_COLOR_LERP1 = 0.75 //1 - 0.25
const float DOME_COLOR_LERP2 = 0.95 //1 - 0.05

//		Functions
//	Instancing
entity function DomeShield_Create( entity proj, entity weapon, entity owner ) {
	#if SERVER
	//	Info retrieval
	vector origin = proj.GetOrigin()
	vector angles = proj.GetAngles()
	
	//		Create shield
	//	Setup
	entity shieldEnt = CreatePropScript( DOME_SHIELD_ASSET, origin, angles, SOLID_VPHYSICS )
	shieldEnt.kv.CollisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS

	SetTeam( shieldEnt, owner.GetTeam() )
	shieldEnt.SetOwner( owner )

	//	Health
	int health = weapon.GetWeaponSettingInt( eWeaponVar.damage_far_value )
	shieldEnt.SetMaxHealth( health )
	shieldEnt.SetHealth( health )

	shieldEnt.SetTakeDamageType( DAMAGE_YES )
	shieldEnt.SetArmorType( ARMOR_TYPE_HEAVY )

	//	Damage handling
	shieldEnt.SetDamageNotifications( true )
	shieldEnt.SetDeathNotifications( true )

	SetObjectCanBeMeleed( shieldEnt, true )
	SetVisibleEntitiesInConeQueriableEnabled( shieldEnt, true )
	SetCustomSmartAmmoTarget( shieldEnt, false )

	shieldEnt.e.noOwnerFriendlyFire = true

	AddEntityCallback_OnPostDamaged( shieldEnt, DomeShield_OnPostDamaged )

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

	EmitSoundOnEntity( shieldEnt, DOME_SHIELD_SFX )

	//	Return
	return shieldEnt
	#endif
}

void function DomeShield_Destroy( entity shieldEnt ) {
	//	Sanity checks
	if( !IsValid( shieldEnt ) )
		return
	
	#if SERVER
	//	Functionality
	RemoveEntityCallback_OnPostDamaged( shieldEnt, DomeShield_OnPostDamaged )

	ClearChildren( shieldEnt )
	shieldEnt.Destroy()
	#endif
}

#if SERVER
//	Damage handling
void function DomeShield_OnPostDamaged( entity shieldEnt, var _ ) {
	DomeShield_UpdateColor( shieldEnt )
}

//	FX
void function DomeShield_UpdateColor( entity shieldEnt ) {
	float domeHealth = 1 - GetHealthFrac( shieldEnt )
	vector domeColor = TriLerpColor( domeHealth, DOME_COLOR_FULL, DOME_COLOR_MED, DOME_COLOR_LOW )

	entity vortexFX = expect entity( shieldEnt.s.vortexFX )
	EffectSetControlPointVector( vortexFX, 1, domeColor )
}
#endif

vector function TriLerpColor( float fraction, vector color1, vector color2, vector color3 ) {	//	Copied from vortex - not global
	float l1 = DOME_COLOR_LERP1  // from zero to this fraction, fade between color1 and color2
	float l2 = DOME_COLOR_LERP2 // from l1 to this fraction, fade between color2 and color3

	float r, g, b

	// 0 = full charge, 1 = no charge remaining
	if ( fraction < l1 ) {
		r = Graph( fraction, 0, l1, color1.x, color2.x )
		g = Graph( fraction, 0, l1, color1.y, color2.y )
		b = Graph( fraction, 0, l1, color1.z, color2.z )
		return <r, g, b>
	} else if ( fraction < l2 ) {
		r = Graph( fraction, l1, l2, color2.x, color3.x )
		g = Graph( fraction, l1, l2, color2.y, color3.y )
		b = Graph( fraction, l1, l2, color2.z, color3.z )
		return <r, g, b>
	} 
	// for the last bit of overload timer, keep it max danger color
	r = color3.x
	g = color3.y
	b = color3.z
	return <r, g, b>
}