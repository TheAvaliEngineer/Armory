//		Func declarations
global function TArmory_Init_MortarTone_QuadRocket

#if CLIENT
global function OnClientAnimEvent_MortarTone_QuadRocket
#endif

global function OnWeaponOwnerChanged_MortarTone_QuadRocket
global function OnWeaponDeactivate_MortarTone_QuadRocket

global function OnWeaponStartZoomIn_MortarTone_QuadRocket
global function OnWeaponStartZoomOut_MortarTone_QuadRocket

global function OnWeaponPrimaryAttack_MortarTone_QuadRocket
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_QuadRocket
#endif

//		Data
//	Rocket properties
const float ROCKET_LIFETIME = 8.0

//		Functions
//	Init
void function TArmory_Init_MortarTone_QuadRocket() {
	//	FX Precache
	PrecacheParticleSystem( $"wpn_muzzleflash_xo_rocket_FP" )
	PrecacheParticleSystem( $"wpn_muzzleflash_xo_rocket" )
	PrecacheParticleSystem( $"wpn_muzzleflash_xo_fp" )
	PrecacheParticleSystem( $"P_muzzleflash_xo_mortar" )

	//	Weapon precache
	PrecacheWeapon( "ta_mortar_titanweapon_quadrocket" )

	#if SERVER
	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_mortar_titanweapon_quadrocket = "Quad Rocket",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

#if CLIENT
//	Animation (shouldn't this be a setting in kvs, Respawn?)
void function OnClientAnimEvent_MortarTone_QuadRocket( entity weapon, string name ) {
	if ( name == "muzzle_flash" ) {
		weapon.PlayWeaponEffect( $"wpn_muzzleflash_xo_fp", $"wpn_muzzleflash_xo_rocket", "muzzle_flash" )
	}
}
#endif

//	Enable/disable/change handling
void function OnWeaponOwnerChanged_MortarTone_QuadRocket( entity weapon, WeaponOwnerChangedParams changeParams ) {
	#if SERVER
	weapon.w.missileFiredCallback = null
	#endif
}

void function OnWeaponDeactivate_MortarTone_QuadRocket( entity weapon ) {}

//	Scoping functionality
void function OnWeaponStartZoomIn_MortarTone_QuadRocket( entity weapon ) {
	#if SERVER
	//	Add mod
	weapon.AddMod( "rocketstream_fast" )
	#else
	//	Play sound
	entity owner = weapon.GetWeaponOwner()
	if ( owner == GetLocalViewPlayer() )
		EmitSoundOnEntity( owner, "Weapon_Particle_Accelerator_WindUp_1P" )
	#endif
}

void function OnWeaponStartZoomOut_MortarTone_QuadRocket( entity weapon ) {
	#if SERVER
	//	Remove mod
	weapon.RemoveMod( "rocketstream_fast" )
	#endif
}

//	Attack handling
var function OnWeaponPrimaryAttack_MortarTone_QuadRocket( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	#if CLIENT
	//	IDK what this does.
	if ( !weapon.ShouldPredictProjectiles() )
		return 1
	#endif

	return FireQuadRocket( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_QuadRocket( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireQuadRocket( weapon, attackParams, false )
}
#endif

int function FireQuadRocket( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner check
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	//	Scoped check
	bool isSpiral = !weapon.IsWeaponAdsButtonPressed()

	//	Sounds
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	string sound1P = "Weapon_Titan_Rocket_Launcher.RapidFire_1P"
	string sound3P = "Weapon_Titan_Rocket_Launcher.RapidFire_3P"

	if ( isSpiral ) {
		sound1P = "Weapon_Titan_Rocket_Launcher_Amped_Fire_1P"
		sound3P = "Weapon_Titan_Rocket_Launcher_Amped_Fire_3P"
	}

	weapon.EmitWeaponSound_1p3p( sound1P, sound3P )

	//	Calculate # of rockets
	int rocketCount = minint( weapon.GetProjectilesPerShot(), weapon.GetWeaponPrimaryClipCount() )
	if( !isSpiral )
		rocketCount = 1

	//	Get stats
	float rocketSpeed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )

	int damageFlags = weapon.GetWeaponDamageFlags()
	int explosionFlags = damageTypes.explosive | DF_KNOCK_BACK

	//	Spawn rockets
	array<entity> rockets
	for(int i = 0; i < rocketCount; i++) {
		entity rocket = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir,
			1.0, damageFlags, explosionFlags, false, playerFired )
		if( rocket ) {
			if( isSpiral ) {
				//	Rocket spiral stuff
				int rocketNum = GetIdealRocketNum( rocketCount, i )
				rocket.InitMissileSpiral( attackParams.pos, attackParams.dir, rocketNum, false, false )

				rocket.kv.lifetime = ROCKET_LIFETIME
				rocket.SetSpeed( rocketSpeed )
			}

			//	Rocket initialization stuffs
			SetTeam( rocket, owner.GetTeam() )
			rockets.append(rocket)

			#if SERVER
			//	Sounds
			EmitSoundOnEntity( rocket, "Weapon_Sidwinder_Projectile" )

			//	I have no fucking clue what this does.
			if( weapon.w.missileFiredCallback != null && !isSpiral )
				weapon.w.missileFiredCallback( rocket, owner )
			#endif
		}
	}

	return rocketCount
}

int function GetIdealRocketNum( int num, int i ) {
	if( num != 2 ) return i
	return ( i == 0 ) ? 1 : 3
}