//		Function Declarations
global function TArmory_Init_GeistRonin_HoloDistract

global function OnWeaponPrimaryAttack_GeistRonin_HoloDistract
#if SERVER
global function OnWeaponNpcPrimaryAttack_GeistRonin_HoloDistract
#endif

//		Data
//	AI perams
const string HOLO_AI_NAME = "npc_titan_stryder_leadwall"

//	Holo perams
const int HOLO_AI_HEALTH = 2500

const float HOLO_AI_LIFETIME = 15.0
const float HOLO_AI_DECAY_TICK = 0.5

const float HOLO_OFFSET_DISTANCE = 60.0

//	EMP explosion effect
const string EMP_EXPLOSION_SFX = "Explo_ProximityEMP_Impact_3P"

const asset EMP_EXPLOSION_FX = $"P_xo_EMP"	//$"P_body_emp"

//	Slow stuff (implement later?)

//		Functions
//	Init
void function TArmory_Init_GeistRonin_HoloDistract() {
	//	FX Precache
	PrecacheParticleSystem( EMP_EXPLOSION_FX )

	#if SERVER
	//	Weapon Precache
	PrecacheWeapon( "ta_geist_titanability_holodistract" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_geist_titanability_holodistract = "Hologram EMP Pulse",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	//	Damage callback
	AddDamageCallbackSourceID( eDamageSourceId.ta_geist_titanability_holodistract, HoloDistractOnDamage )
	#endif
}

//	Attack handling
var function OnWeaponPrimaryAttack_GeistRonin_HoloDistract( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return HoloDistractPlayerOrNpc( weapon, attackParams, true )
}
#if SERVER
var function OnWeaponNpcPrimaryAttack_GeistRonin_HoloDistract( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return HoloDistractPlayerOrNpc( weapon, attackParams, false )
}
#endif

int function HoloDistractPlayerOrNpc( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0

	//	Choose to do holos or just smoke
	int currentAmmo = weapon.GetWeaponPrimaryClipCount()
	int maxAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	bool isMaxed = currentAmmo == maxAmmo
	bool doSmoke = owner.IsPlayer() || isMaxed
	if( owner.IsPlayer() && isMaxed ) {
		#if SERVER
		int decoyCount = weapon.GetWeaponSettingInt( eWeaponVar.projectiles_per_shot )
		CreateHoloDistractDecoys( owner, weapon, decoyCount )
		#else
		Rumble_Play( "rumble_titan_electric_smoke", {} )
		Rumble_Play( "rumble_holopilot_activate", {} )
		#endif

		PlayerUsedOffhand( owner, weapon )
	}

	#if SERVER
	if( doSmoke )
		TitanHoloSmokescreen( owner, weapon )
	#endif

	//	Consume ammo
	int consumeAmt = isMaxed ? maxAmmo : ( doSmoke ? weapon.GetAmmoPerShot() : 0 )
	return consumeAmt
}

#if SERVER
void function TitanHoloSmokescreen( entity owner, entity weapon ) {
	SmokescreenStruct smokescreen

	//	Damage
	smokescreen.isElectric = false
	smokescreen.dpsPilot = 0
	smokescreen.dpsTitan = 0

	smokescreen.ownerTeam = owner.GetTeam()
	smokescreen.attacker = owner
	smokescreen.inflictor = owner
	smokescreen.weaponOrProjectile = weapon

	//	Pos & angles
	vector eyeAngles = <0.0, owner.EyeAngles().y, 0.0>
	smokescreen.angles = eyeAngles

	vector forward = AnglesToForward( eyeAngles )
	vector testPos = owner.GetOrigin() + owner.GetVelocity() * 0.2 + forward * 240.0
	vector basePos = testPos + <0., 0., 50.>

	float trace = TraceLineSimple( owner.EyePosition(), testPos, owner )
	if( trace < 1. ) basePos = owner.GetOrigin() + owner.GetVelocity() * 0.2

	smokescreen.origin = basePos

	//	FX
	float fxOffset = 200.0
	float fxHeightOffset = 148.0

	smokescreen.smokescreenFX = FX_GRENADE_SMOKESCREEN

	smokescreen.fxOffsets = [
		< -fxOffset, 0.0, 20.0 >,
		<  0.0, fxOffset, 20.0 >,
		<  0.0, -fxOffset, 20.0 >,
		<  0.0, 0.0, fxHeightOffset >,
		< -fxOffset, 0.0, fxHeightOffset >
	]

	//	Spawn
	Smokescreen( smokescreen )
}

void function CreateHoloDistractDecoys( entity player, entity decoyWeapon, int decoysToMake = 1 ) {
	TitanLoadoutDef playerLoadout = GetActiveTitanLoadout( player )

	print("[TAEsArmory] CreateHoloDistractDecoys: Called")

	//	Create titans
	for( int i = 0; i < decoysToMake; i++ ) {
		CreateTitanAIDecoy( player, decoyWeapon )
	}

}

void function CreateTitanAIDecoy( entity player, entity decoyWeapon ) {
	entity playerSoul = player.GetTitanSoul()
	int team = player.GetTeam()

	//	Calculate offset
	vector normAngles = player.GetAngles()
	normAngles.y = AngleNormalize( normAngles.y )

	vector fwd = AnglesToForward( normAngles )
	fwd *= HOLO_OFFSET_DISTANCE

	vector spawnPos = player.GetOrigin() + player.GetVelocity() * 0.2 + fwd

	//	Create ent
	entity aiDecoy = CreateNPCTitan( HOLO_AI_NAME, team, spawnPos, normAngles )
	SetSpawnOption_AISettings( aiDecoy, HOLO_AI_NAME )
	SetSpawnOption_NPCTitan( aiDecoy, TITAN_HENCH )

	DispatchSpawn( aiDecoy )

	PutEntityInSafeSpot( aiDecoy, player, null, spawnPos, aiDecoy.GetOrigin()  )

	//	AI settings
	SetupDecoyAI( player, aiDecoy )
	SetupDecoyLoadout( player, aiDecoy )

	//	Collision settings
	aiDecoy.kv.CollisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS

	//	Holo settings
	aiDecoy.SetDeathNotifications( true )
	aiDecoy.SetPassThroughThickness( 0 )

	aiDecoy.SetNameVisibleToOwner( true )
	aiDecoy.SetNameVisibleToFriendly( true )
	aiDecoy.SetNameVisibleToEnemy( true )

	//	Holo highlight
	Highlight_SetFriendlyHighlight( aiDecoy, "friendly_player_decoy" )
	Highlight_SetOwnedHighlight( aiDecoy, "friendly_player_decoy" )
	SetDefaultMPEnemyHighlight( aiDecoy )

	//	Holo Trail
	int attachID = aiDecoy.LookupAttachment( "CHESTFOCUS" )

	entity holoTrailFX = StartParticleEffectOnEntity_ReturnEntity( aiDecoy, HOLO_PILOT_TRAIL_FX, FX_PATTACH_POINT_FOLLOW, attachID )
	holoTrailFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY
	SetTeam( holoTrailFX, team )

	//	SFX
	EmitSoundOnEntityToTeam( aiDecoy, "holopilot_loop", team )
	EmitSoundOnEntityToEnemies( aiDecoy, "holopilot_loop_enemy", team )

	//	End stuff
	float decayRate = aiDecoy.GetHealth() / HOLO_AI_LIFETIME
	thread AIDecoyDecay( player, aiDecoy, decoyWeapon, decayRate )
}

void function SetupDecoyAI( entity player, entity aiDecoy ) {
	entity playerSoul = player.GetTitanSoul()

	//	Follow behavior
	int followBehavior = GetDefaultNPCFollowBehavior( aiDecoy )
	aiDecoy.InitFollowBehavior( player, followBehavior )

	//	AI settings
//	aiDecoy.SetFollowGoalTolerance( 700 )
//	aiDecoy.SetFollowGoalCombatTolerance( 700 )
//	aiDecoy.SetFollowTargetMoveTolerance( 200 )

	aiDecoy.AssaultSetFightRadius( 5000 )
	aiDecoy.AssaultSetGoalRadius( 450 )
	aiDecoy.AssaultSetArrivalTolerance( 250 )

//	aiDecoy.EnableBehavior( "Follow" )
	aiDecoy.EnableBehavior( "Assault" )

	//	Pet titan to player
	string settings = GetSoulPlayerSettings( playerSoul )
	string playerTitle = expect string( GetPlayerSettingsFieldForClassName( settings, "printname" ) )

	aiDecoy.SetTitle( playerTitle )
	aiDecoy.SetBossPlayer( player )

	ShowName( aiDecoy )

	//	Health
	aiDecoy.SetMaxHealth( player.GetMaxHealth() ) //playerSoul.GetMaxHealth() )
	aiDecoy.SetHealth( player.GetHealth() ) //playerSoul.GetHealth() )

	//Melee_Disable( aiDecoy )
}

void function SetupDecoyLoadout( entity player, entity aiDecoy ) {
	TitanLoadoutDef loadout = GetActiveTitanLoadout( player )

	//	Equipment
	ActuallyCopyWeapons( player, aiDecoy )

	array<entity> weapons = aiDecoy.GetMainWeapons()
	foreach( weapon in weapons ) {
		print("[TAEsArmory] SetupDecoyLoadout: weapon = " + weapon )
	}

	//	Body appearance
	aiDecoy.SetSkin( loadout.skinIndex )
	aiDecoy.SetCamo( loadout.camoIndex )
	aiDecoy.SetDecal( loadout.decalIndex )

	//	Weapon appearance
	entity primary = aiDecoy.GetActiveWeapon()
	primary.SetSkin( loadout.primarySkinIndex )
	primary.SetCamo( loadout.primaryCamoIndex )
}

void function AIDecoyDecay( entity owner, entity aiDecoy, entity decoyWeapon, float decayRate ) {
	aiDecoy.EndSignal( "OnDestroy" )
	aiDecoy.EndSignal( "OnDeath" )

	OnThreadEnd( function() : ( owner, aiDecoy, decoyWeapon ) {
		OnAIDecoyDestroyed( owner, aiDecoy, decoyWeapon )
	})

	int maxHealth = aiDecoy.GetMaxHealth()

	float prevTime = Time()
	float decayStack = 0
	while( 1 ) {
		WaitFrame()

		//	Wait to tick
		if( Time() - prevTime < HOLO_AI_DECAY_TICK )
			continue

		//	Set health
		decayStack += (Time() - prevTime) * decayRate

		int newHp = aiDecoy.GetHealth() - decayStack.tointeger()
		newHp = minint( maxint( newHp, 0 ), maxHealth )
		aiDecoy.SetHealth( newHp )

		decayStack -= float( decayStack.tointeger() )

		prevTime = Time()
	}
}

void function OnAIDecoyDestroyed( entity owner, entity aiDecoy, entity decoyWeapon ) {
	//		Death explosion
	//	Get data
	vector origin = aiDecoy.GetOrigin()

	int damage 						= decoyWeapon.GetWeaponSettingInt( eWeaponVar.explosion_damage )
	int titanDamage					= decoyWeapon.GetWeaponSettingInt( eWeaponVar.explosion_damage_heavy_armor )
	float explosionInnerRadius 		= decoyWeapon.GetWeaponSettingFloat( eWeaponVar.explosion_inner_radius )
	float explosionRadius 			= decoyWeapon.GetWeaponSettingFloat( eWeaponVar.explosionradius )

	//	Deal damage
	RadiusDamage(
		origin,														//	origin
		owner,														//	attacker
		decoyWeapon,		 										//	inflictor
		damage,														//	normal damage
		titanDamage,												//	heavy armor damage
		explosionInnerRadius,										//	inner radius
		explosionRadius,											//	outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,							//	explosion flags
		0, 															//	distanceFromAttacker
		0, 															//	explosionForce
		DF_EXPLOSION | DF_ELECTRICAL | DF_INSTANT,					//	damage flags
		eDamageSourceId.ta_geist_titanability_holodistract	//	damage source id
	)

	//		FX
	//	Explosion FX
	int attachID = aiDecoy.LookupAttachment( "CHESTFOCUS" )
	vector fxOrigin = aiDecoy.GetAttachmentOrigin( attachID )

	PlayFX( EMP_EXPLOSION_FX, fxOrigin )

	EmitSoundAtPosition( aiDecoy.GetTeam(), fxOrigin, EMP_EXPLOSION_SFX )

	//	SFX
	EmitSoundAtPosition( TEAM_ANY, aiDecoy.GetOrigin(), "holopilot_end_3P" )
	if( IsValid(owner) ) {
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "holopilot_end_1P" )
	}

	//	Actually destroy
	aiDecoy.Destroy()
}

void function ActuallyCopyWeapons( entity fromEnt, entity toEnt ) {
	TakeAllWeapons( toEnt )

	array<entity> mainWeapons = fromEnt.GetMainWeapons()
	foreach( i, weapon in mainWeapons ) {
		string name = weapon.GetWeaponClassName()
		toEnt.GiveWeapon( name, weapon.GetMods() )

		entity newWeapon = fromEnt.GetMainWeapons()[i]
		newWeapon.SetSkin( weapon.GetSkin() )
		newWeapon.SetCamo( weapon.GetCamo() )
	}

	array<entity> offhandWeapons = fromEnt.GetOffhandWeapons()
	foreach( i, weapon in offhandWeapons ) {
		string name = weapon.GetWeaponClassName()
		toEnt.GiveOffhandWeapon( name, i, weapon.GetMods() )
	}
}

//	Damage Handling
void function HoloDistractOnDamage( entity target, var damageInfo ) {
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	if( attacker == target ) {
		DamageInfo_ScaleDamage( damageInfo, 0. )
	}
}
#endif