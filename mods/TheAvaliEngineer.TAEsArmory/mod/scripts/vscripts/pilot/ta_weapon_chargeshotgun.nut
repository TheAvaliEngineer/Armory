untyped


global function TArmory_Init_Weapon_ChargeShotgun

global function OnWeaponActivate_Weapon_ChargeShotgun
global function OnWeaponDeactivate_Weapon_ChargeShotgun

global function OnWeaponPrimaryAttack_Weapon_ChargeShotgun
#if SERVER
global function OnWeaponNpcPrimaryAttack_Weapon_ChargeShotgun
#endif // #if SERVER

//			Data
//		Constants
//	Player settings
const float CHARGE_MISFIRE_DELAY_TIME = 2.5

const int CHARGE_SG_MAX_PELLETS = 15 // 20
const float CHARGE_TIME_PER_PELLET = 0.125

const int CHARGE_SG_PELLETS_PER_AMMO = 5

//	NPC settings
#if SERVER
const int SG_NPC_PELLET_COUNT = 10
#endif // #if SERVER

//	Math
const float phi = ( 1.0 + sqrt(5.0) ) / 2.0

//		Structs
//	Pellet offsets (this is calculated in the init function)
struct {
    float[2][20] boltOffsetsSunflower = [
		[0, 0], 				[-0.368684, -0.337745],		[0.0618193, 0.704399],	[0.526923, -0.687279],
		[-0.984713, 0.174182],	[0.943347, 0.600081], 		[-0.31795, -1.18275], 	[-0.609722, 1.17398],
		[1.3284, -0.48513], 	[-1.38652, -0.572333], 		[0.670158, 1.43209],	[0.496306, -1.5823],
		[-1.49859, 0.868466], 	[1.76073, 0.387092], 		[-1.07597, -1.53045], 	[-0.248863, 1.92043],
		[1.5293, -1.28889], 	[-2.05979, -0.0851847], 	[1.50366, 1.49633], 	[-0.100672, -2.17712]
	]

	float[2][15] boltOffsetsHex = [
		[0, 0],				//	1
		[-1.5, 0.8660254],	//	2
		[1.5, -0.8660254],	//	3
		[-1.5, -0.8660254],	//	4
		[1.5, 0.8660254],	//	5
		[0, 1.7320508],		//	6
		[0, -1.7320508],	//	7
		[-1, 0],			//	8
		[1, 0],				//	9
		[-0.5, 0.8660254],	//	10
		[0.5, 0.8660254],	//	11
		[-0.5, -0.8660254],	//	12
		[0.5, -0.8660254],	//	13
		[2, 0],				//	14
		[-2, 0],			//	15

	]
} boltData

//	UI
struct {
	//x axis: 0.0 is max left, 1.0 is max right; y axis: 0.0 is max top, 1.0 is max down; z doesn't do anything
    vector displayPos = Vector(0.495, 0.525, 0.0)

	float xPos = 0.495
	float yPos = 0.525
	//standard rgb format, range: min - 0.0 to max - 1.0
    vector displayWhite = Vector(1.0, 1.0, 1.0)
	vector displayRed = Vector(1.0, 0.0, 0.0)

	//alpha of the text, range: 0.0 to 1.0
    float displayAlpha = 0.9
	//size of the text
    float displaySize = 25.0
} uiSettings

//		SFX
//	Pellet addition handling
const string ACPW_TICK_SOUND_1P = "Vortex_Shield_AbsorbBulletSmall"
const string ACPW_TICK_SOUND_3P = "Vortex_Shield_AbsorbBulletSmall_1P_VS_3P"

const string ACPW_FINAL_TICK_SOUND_1P = "Vortex_Shield_AbsorbBulletSmall"
const string ACPW_FINAL_TICK_SOUND_3P = "Vortex_Shield_AbsorbBulletSmall_1P_VS_3P"

const string CHARGE_SG_WARNING_SOUND = "lstar_lowammowarning"
const int CHARGE_SG_WARNING_LEVEL = 18

//	Burnout effects - this will play if you overcharge the weapon
const string CHARGE_SG_BURNOUT_SOUND_1P = "LSTAR_LensBurnout"		    	// should be "LSTAR_LensBurnout"
const string CHARGE_SG_BURNOUT_SOUND_3P = "LSTAR_LensBurnout_3P"

//		Assets
//	Overcharge
const CHARGE_SG_COOLDOWN_EFFECT_1P = $"wpn_mflash_snp_hmn_smokepuff_side_FP"
const CHARGE_SG_COOLDOWN_EFFECT_3P = $"wpn_mflash_snp_hmn_smokepuff_side"
const CHARGE_SG_BURNOUT_EFFECT_1P = $"xo_spark_med"
const CHARGE_SG_BURNOUT_EFFECT_3P = $"xo_spark_med"

//	RUI
const PELLET_COUNTER_RUI = $"ui/cockpit_console_text_top_left.rpak"

/*	Things that haven't worked
	- $"ui/obituary_crawl_localized.rpak"
	- $"ui/fra_battery_icon.rpak"
	- $"ui/ammo_counter.rpak"
	- $"ui/cockpit_console_text_top_left.rpak"
	- $"ui/hit_indicator.rpak"
	- $"ui/reward_hud.rpak"
*/

//			Functions
//		Init
void function TArmory_Init_Weapon_ChargeShotgun() {
	//	FX precache
	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon_fp" )
	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon" )

	PrecacheParticleSystem( CHARGE_SG_COOLDOWN_EFFECT_1P )
	PrecacheParticleSystem( CHARGE_SG_COOLDOWN_EFFECT_3P )
	PrecacheParticleSystem( CHARGE_SG_BURNOUT_EFFECT_1P )
	PrecacheParticleSystem( CHARGE_SG_BURNOUT_EFFECT_3P )

	//	Weapon precache
	PrecacheWeapon( "ta_weapon_chargeshotgun" )

	#if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_weapon_chargeshotgun = "Sunflower",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	//	Damage callback
	AddDamageCallbackSourceID( eDamageSourceId.ta_weapon_chargeshotgun, ChargeShotgunOnDamage )
	#endif

	// calculate bolt offsets
	/*
    for( int boltIdx = 0; boltIdx < CHARGE_SG_MAX_PELLETS; boltIdx++ ) {
		float rho = sqrt(boltIdx) * 0.5
        float theta = (2.0 * PI * boltIdx) / phi

        float x = rho * cos(theta)
        float y = rho * sin(theta)

        boltData.boltOffsetsSunflower[boltIdx][0] = x
        boltData.boltOffsetsSunflower[boltIdx][1] = y
    } // */

	#if CLIENT
	//playerRUI.rui = RuiCreate( PELLET_COUNTER_RUI, clGlobal.topoFullScreen, RUI_DRAW_HUD, -1 )
	//SetUIVisible( false )
	#endif
}

//		Weapon handling
//	Activate/deactivate
void function OnWeaponActivate_Weapon_ChargeShotgun( entity weapon ) {
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) ) return

	//	NPCs don't need the UI
	if( owner.IsPlayer() ) {
		#if CLIENT
		//	Make sure owner is the player before doing anything
		entity player = GetLocalViewPlayer() //GetLocalViewPlayer()
		if( owner != player ) return

		//	Initialize player RUI
		if( !("pelletRui" in weapon.s) ) {
			weapon.s.pelletRui <- RuiCreate( PELLET_COUNTER_RUI, clGlobal.topoFullScreen, RUI_DRAW_HUD, -1 )

			thread ChargeShotgun_PelletCounterRui_Init( player, weapon )
			thread ChargeShotgun_UILoop( player, weapon )
		}

		SetUIVisible( weapon, true )
		#endif
	}
}

void function OnWeaponDeactivate_Weapon_ChargeShotgun( entity weapon ) {
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) ) return

	//	NPCs don't need the UI
	if ( owner != null && owner.IsPlayer() ) {
		#if CLIENT
		//	Make sure owner is the player before doing anything
		entity player = GetLocalViewPlayer()
		if( owner != player ) return

		SetUIVisible( weapon, false )
		#endif
	}
}


//	Attack triggers
var function OnWeaponPrimaryAttack_Weapon_ChargeShotgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    int chargeLevel = ChargeShotgun_GetChargeLevel( weapon )

	if( chargeLevel == 20 )
		return MisfireChargeShotgun( weapon, attackParams )

	int pelletCount = ChargeShotgun_GetPelletCount( weapon )
    return FireChargeShotgun( weapon, attackParams, true, pelletCount )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Weapon_ChargeShotgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    return FireChargeShotgun( weapon, attackParams, false, SG_NPC_PELLET_COUNT )
}
#endif // if SERVER

int function FireChargeShotgun( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired, int pelletCount ) {
    //	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) ) return 0

	//	Projectile creation check
    bool shouldCreateProjectile = false
    if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

    //	Aim angle calculations
    vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	//	ADS spread tightening effect
	float zoomFrac = (playerFired) ? owner.GetZoomFrac() : 0.5
    float spreadFrac = Graph( zoomFrac, 0, 1, 0.05, 0.025 ) * 0.5

    //	Spawn projectiles
	array<entity> projectiles
    if( shouldCreateProjectile ) {
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		for( int index = 0; index < pelletCount; index++ ) {
			vector rightVec = baseUpVec * boltData.boltOffsetsHex[index][0] * spreadFrac
			vector upVec = baseRightVec * boltData.boltOffsetsHex[index][1] * spreadFrac

			vector attackDir = attackParams.dir + upVec + rightVec

			int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
			int damageFlags = weapon.GetWeaponDamageFlags()

			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackDir, boltSpeed, damageFlags, damageFlags, playerFired, index ) // index )
            if( bolt ) {
				float lifetimeMultiplier = !(playerFired && zoomFrac > 0.8) ? 1.0 : 1.25
				bolt.SetProjectileLifetime( RandomFloatRange( 0.65, 0.85 ) * lifetimeMultiplier )

				projectiles.append( bolt )
			}
		}
	}

	//	(S)FX
	weapon.PlayWeaponEffect( CHARGE_SG_COOLDOWN_EFFECT_1P, CHARGE_SG_COOLDOWN_EFFECT_3P, "SWAY_ROTATE" )
	weapon.EmitWeaponSound_1p3p( "LSTAR_VentCooldown", "LSTAR_VentCooldown_3p" )

	#if SERVER
	foreach( bolt in projectiles ) {
		EmitSoundOnEntity( bolt, "weapon_mastiff_projectile_crackle" )
	}
	#endif

	//	Ammo
//	int consumeAmt = (pelletCount + CHARGE_SG_PELLETS_PER_AMMO - 1) / CHARGE_SG_PELLETS_PER_AMMO
    return (pelletCount > 0) ? weapon.GetAmmoPerShot() : 0	//	consumeAmt.tointeger()
}

int function MisfireChargeShotgun( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//	(S)FX
	weapon.PlayWeaponEffect( CHARGE_SG_BURNOUT_EFFECT_1P, CHARGE_SG_BURNOUT_EFFECT_3P, "shell" )
	weapon.PlayWeaponEffect( CHARGE_SG_BURNOUT_EFFECT_1P, CHARGE_SG_BURNOUT_EFFECT_3P, "spinner" )
	weapon.PlayWeaponEffect( CHARGE_SG_BURNOUT_EFFECT_1P, CHARGE_SG_BURNOUT_EFFECT_3P, "vent_cover_L" )
	weapon.PlayWeaponEffect( CHARGE_SG_BURNOUT_EFFECT_1P, CHARGE_SG_BURNOUT_EFFECT_3P, "vent_cover_R" )

    weapon.EmitWeaponSound_1p3p( CHARGE_SG_BURNOUT_SOUND_1P, CHARGE_SG_BURNOUT_SOUND_3P )

	//	Do explosion
	print("[tae_Weapon_ChargeShotgun] Kaboom. I guess.")

	//	Delay next use
	float nextAllowedFireTime = weapon.GetNextAttackAllowedTime() + CHARGE_MISFIRE_DELAY_TIME
	weapon.SetNextAttackAllowedTime( nextAllowedFireTime )

	//	Ammo
	int consumeAmt = weapon.GetWeaponPrimaryClipCount()
    return consumeAmt
}

//	Charge level tracking
int function ChargeShotgun_GetChargeLevel( entity weapon ) {
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( !owner.IsPlayer() )
		return 3

	if ( !weapon.IsReadyToFire() )
		return 0

	int charge = weapon.GetWeaponChargeLevel()
	return charge // (1 + charge)
}

int function ChargeShotgun_GetPelletCount( entity weapon ) {
	int pelletCount = ChargeShotgun_GetChargeLevel( weapon )
	pelletCount = minint( pelletCount, CHARGE_SG_MAX_PELLETS )
	//pelletCount = minint( pelletCount, weapon.GetWeaponPrimaryClipCount() * CHARGE_SG_PELLETS_PER_AMMO )

	return pelletCount
}

//	Damage handling
void function ChargeShotgunOnDamage( entity ent, var damageInfo ) {
	if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
		return
}


//		UI
//	Init
void function ChargeShotgun_PelletCounterRui_Init( entity player, entity weapon ) {
	#if CLIENT
	WaitFrame()

	//   UI
	// Line config
	RuiSetInt(weapon.s.pelletRui, "maxLines", 1)
	RuiSetInt(weapon.s.pelletRui, "lineNum", 1)

	// Text params
	RuiSetFloat2(weapon.s.pelletRui, "msgPos", uiSettings.displayPos)

	RuiSetFloat(weapon.s.pelletRui, "msgFontSize", uiSettings.displaySize)
	RuiSetFloat(weapon.s.pelletRui, "thicken", 0.0)

	RuiSetFloat3(weapon.s.pelletRui, "msgColor", uiSettings.displayWhite)
	RuiSetFloat(weapon.s.pelletRui, "msgAlpha", uiSettings.displayAlpha)

	RuiSetString(weapon.s.pelletRui, "msgText", ":(")
	#endif
}

/*
    float pitchOffset = GetLocalViewPlayer().GetActiveWeapon().GetWeaponSettingFloat( eWeaponVar.projectile_launch_pitch_offset )
    if (GetLocalViewPlayer().CameraAngles().x - pitchOffset * 0.5 < -90.0)
        pitchOffset = (GetLocalViewPlayer().CameraAngles().x + 90.0) * 2
    //printt(GetLocalViewPlayer().CameraAngles().x, pitchOffset)
    if (disablePitchOffset)
        pitchOffset = 0

    vector crosshairPos = GetLocalViewPlayer().CameraPosition() + GetLocalViewPlayer().GetActiveWeapon().GetAttackDirection() * 500

    array pos = expect array( Hud.ToScreenSpace( crosshairPos ) )

    vector result = <pos[0], pos[1], 0 >
    return result
*/

#if CLIENT
//	Change utils
void function SetUIVisible( entity weapon, bool visible ) {
	float alpha = (visible) ? 0.9 : 0.0;
	RuiSetFloat(weapon.s.pelletRui, "msgAlpha", alpha)
}

void function SetUIRed( entity weapon, bool red ) {
	vector rgb = (red) ? uiSettings.displayRed : uiSettings.displayWhite;
	RuiSetFloat3(weapon.s.pelletRui, "msgColor", rgb)
}

//	Loop
void function ChargeShotgun_UILoop( entity player, entity weapon ) {
	int chargeLevelOld = -2
	int chargeLevelNew = -2

	int pelletCountOld = -2
	int pelletCountNew = -2

	player.EndSignal( "OnDeath" )
	weapon.EndSignal( "OnDestroy" )

	OnThreadEnd( function() : ( weapon ) {
		RuiDestroyIfAlive( weapon.s.pelletRui )
	})

	while( 1 ) {
		WaitFrame()

		//	Player validity checks
		if( !IsValid(player) )
			break
		if( player != GetLocalClientPlayer() )
			continue
		if( IsLobby() || IsMenuLevel() )
			continue

		//	Weapon validity checks
		entity activeWeapon = player.GetActiveWeapon()
		if ( !IsValid(activeWeapon) )
			continue
		if( activeWeapon != weapon ) //activeWeapon.GetWeaponClassName() != "tarmory_pilot_weapon_primary_chargeshotgun" )
			continue

		//	On charge level change
		if( chargeLevelOld != ChargeShotgun_GetChargeLevel( activeWeapon ) ) {
			chargeLevelOld = chargeLevelNew
			chargeLevelNew = ChargeShotgun_GetChargeLevel( activeWeapon )

			//	On increase
			if( chargeLevelNew == CHARGE_SG_WARNING_LEVEL ) {
				activeWeapon.EmitWeaponSound( CHARGE_SG_WARNING_SOUND )

				#if CLIENT
				SetUIRed( weapon, true )
				#endif
			} else if( chargeLevelNew < CHARGE_SG_WARNING_LEVEL ) {
				#if CLIENT
				SetUIRed( weapon, false )
				#endif
			}
		}

		//	On pellet count change
		if( pelletCountOld != ChargeShotgun_GetPelletCount( weapon ) ) {
			pelletCountOld = pelletCountNew
			pelletCountNew = ChargeShotgun_GetChargeLevel( weapon )

			//	On increase
			if( pelletCountOld == pelletCountNew ) {
				//	Do tick sound
				if( pelletCountNew == CHARGE_SG_MAX_PELLETS )
					weapon.EmitWeaponSound_1p3p( ACPW_FINAL_TICK_SOUND_1P, ACPW_FINAL_TICK_SOUND_3P )
				else if( pelletCountNew < CHARGE_SG_MAX_PELLETS )
					weapon.EmitWeaponSound_1p3p( ACPW_TICK_SOUND_1P, ACPW_TICK_SOUND_3P )
			}

			//	Update RUI
			RuiSetString( weapon.s.pelletRui, "msgText", format( "%0.2i", pelletCountNew ) )
		}
	}
}
#endif

// */