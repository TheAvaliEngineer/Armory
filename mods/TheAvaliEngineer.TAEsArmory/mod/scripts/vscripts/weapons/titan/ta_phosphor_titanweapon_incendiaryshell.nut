//		Function declaratiosn
global function TArmory_Init_PhosphorScorch_IncendiaryShell

global function OnWeaponAttemptOffhandSwitch_PhosphorScorch_IncendiaryShell

global function OnWeaponPrimaryAttack_PhosphorScorch_IncendiaryShell
#if SERVER
global function OnWeaponNpcPrimaryAttack_PhosphorScorch_IncendiaryShell
#endif

global function OnProjectileCollision_PhosphorScorch_IncendiaryShell
global function OnProjectileIgnite_PhosphorScorch_IncendiaryShell

//		Consts
//	FX
const asset PHOSPHORUS_FX_MOVING = $"runway_light_white"

const asset PHOSPHORUS_FX_STATIC_MD = $"runway_light_white"
const asset PHOSPHORUS_FX_STATIC_SM = $"acl_light_white"

/**		Phosphorus FX
 * 	Point: $"runway_light_white" $"acl_light_white"
 *	Glow: $"light_cluster_large_white"
 *	Smoke: $"xo_health_smoke_white_mist"
 */


int phosphorusTableIdx = 0

//	Shell
const float SHELL_SPEED_MIN = 1600
const float SHELL_SPEED_MAX = 3200

const float SHELL_LIFETIME = 0.5

//	Fire
const float FIRE_SPEED = 1200

//		Functions
//	Init
void function TArmory_Init_PhosphorScorch_IncendiaryShell() {
	//	FX precache
	PrecacheParticleSystem( PHOSPHORUS_FX_MOVING )

	PrecacheParticleSystem( PHOSPHORUS_FX_STATIC_MD )
	PrecacheParticleSystem( PHOSPHORUS_FX_STATIC_SM )

	array<asset> movingFX = [ PHOSPHORUS_FX_MOVING ]
	array<asset> staticFX = [ PHOSPHORUS_FX_STATIC_MD, PHOSPHORUS_FX_STATIC_MD, PHOSPHORUS_FX_STATIC_SM ]
	phosphorusTableIdx = ThermiteECS_RegisterFXGroup( movingFX, staticFX )

	//	Weapon precache
	PrecacheWeapon( "ta_phosphor_titanweapon_incendiaryshell" )

	#if SERVER
	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_phosphor_titanweapon_incendiaryshell = "Incendiary Shell",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Activate/deactivate
bool function OnWeaponAttemptOffhandSwitch_PhosphorScorch_IncendiaryShell( entity weapon ) {
	return true //weapon.GetWeaponChargeFraction() <= 0.8
}

//	Charge level handling
float function IncendiaryShell_GetChargeLevel( entity weapon ) {
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( !owner.IsPlayer() )
		return 3

	if ( !weapon.IsReadyToFire() )
		return 0

	float charge = weapon.GetWeaponChargeFraction()
	return charge // (1 + charge)
}


//	Weapon firing
var function OnWeaponPrimaryAttack_PhosphorScorch_IncendiaryShell( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//	Get fire speed
	float minSpeed = pow( SHELL_SPEED_MIN, 0.5 )
	float maxSpeed = pow( SHELL_SPEED_MAX, 0.5 )

	float chargeFrac = IncendiaryShell_GetChargeLevel( weapon )
	float vel = Graph( chargeFrac, 0.0, 1.0, minSpeed, maxSpeed )

	FireIncendiaryShell( weapon, attackParams, vel * vel, true )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_PhosphorScorch_IncendiaryShell( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	FireIncendiaryShell( weapon, attackParams, 2200.0, false )

	return weapon.GetAmmoPerShot()
}
#endif

void function FireIncendiaryShell( entity weapon, WeaponPrimaryAttackParams attackParams, float throwStrength, bool playerFired ) {
	//	Validity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return

	//	Test for projectile creation
	bool shouldCreateProjectile = false
	if( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if( !playerFired )
			shouldCreateProjectile = false
	#endif

	//	Create projectile
	if( shouldCreateProjectile ) {
		int damageFlags = weapon.GetWeaponDamageFlags()

		vector angVel = Vector(0, 2000, 0)
		vector attackVel = Normalize(attackParams.dir) * throwStrength

		float fuse = weapon.GetGrenadeFuseTime()

		entity shell = weapon.FireWeaponGrenade( attackParams.pos, attackVel, angVel, SHELL_LIFETIME,
			damageFlags, damageFlags, playerFired, PROJECTILE_LAG_COMPENSATED, false )
		if( shell ) {
			EmitSoundOnEntity( shell, "weapon_thermitelauncher_projectile_3p" )

			#if SERVER
			Grenade_Init( shell, weapon )
        	#else
			SetTeam( shell, owner.GetTeam() )
        	#endif
		}
	}
}

//	Collision
void function OnProjectileCollision_PhosphorScorch_IncendiaryShell( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	//	Owner validity check
	entity owner = projectile.GetOwner()
	if( !IsValid( owner ) )
		return

	#if SERVER
	//	White Phosphorus burst
	int fireCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectiles_per_shot )
	CreateThermiteBurst( projectile, owner, normal * FIRE_SPEED, 30, fireCount, phosphorusTableIdx )

	if( IsValid(projectile) )
		projectile.Destroy()
	#endif
}

//	Ignition
void function OnProjectileIgnite_PhosphorScorch_IncendiaryShell( entity projectile ) {
	projectile.SetDoesExplode( false )

	//	Owner validity check
	entity owner = projectile.GetOwner()
	if( !IsValid( owner ) )
		return

	#if SERVER
	//	White Phosphorus burst
	int fireCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectiles_per_shot )
	CreateThermiteBurst( projectile, owner, <0, 0, FIRE_SPEED>, 30, fireCount, phosphorusTableIdx )

	if( IsValid(projectile) )
		projectile.Destroy()
	#endif
}