//untyped

//		Function definitions
global function TArmory_Init_Weapon_ChargePistol

global function OnWeaponPrimaryAttack_Weapon_ChargePistol
#if SERVER
global function OnWeaponNpcPrimaryAttack_Weapon_ChargePistol
#endif

//		Functions
// 	Init
void function TArmory_Init_Weapon_ChargePistol() {
	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_weapon_chargepistol" )

	//	Custom damage type
	table<string, string> customDamageSourceIds = {
		ta_weapon_chargepistol = "Electron",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	AddDamageCallbackSourceID( eDamageSourceId.ta_weapon_chargepistol, ChargePistolOnDamage )
	#endif
}

//	Weapon firing handling
var function OnWeaponPrimaryAttack_Weapon_ChargePistol( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireChargePistol( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Weapon_ChargePistol( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireChargePistol( weapon, attackParams, false )
}
#endif

int function FireChargePistol( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
    //	Validity check
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) )
		return 0

	//	Projectile creation check
    bool shouldCreateProjectile = false
    if ( IsServer() || weapon.ShouldPredictProjectiles() ) {
		shouldCreateProjectile = true
		#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
		#endif
	}

	if( shouldCreateProjectile ) {
		int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
		int damageFlags = weapon.GetWeaponDamageFlags()

		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
		if ( bolt ) {
			#if SERVER
			Assert( owner == owner.GetWeaponOwner() )
			bolt.SetOwner( owner )
			#endif
		}
	}

    // Ammo
    return 1
}

//	Damage handling
void function ChargePistolOnDamage( entity ent, var damageInfo ) {
	if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
		return
}

//		Vars
/*	Explosion damage constants
const int LARGE_BALL_EXPLOSION_DMG = 30
const int LARGE_BALL_EXPLOSION_DMG_TITAN = 180

const float LARGE_BALL_RADIUS = 75.0
const float LARGE_BALL_INNER_RADIUS = 35.0

const int LARGE_BALL_IMPULSE = 1500

// 	Fx
const ARC_BALL_AIRBURST_FX = $"P_impact_exp_emp_med_air"
const ARC_BALL_AIRBURST_SOUND = "Explo_ProximityEMP_Impact_3P"
const ARC_BALL_COLL_MODEL = $"models/Weapons/bullets/projectile_arc_ball.mdl"
*/

/*
		bool isExplosiveShot = ChargePistol_GetChargeLevel( weapon ) == 1
		if ( isExplosiveShot ) {
			damageLevel = weapon.GetWeaponPrimaryClipCount()
			consumeAmt = weapon.GetWeaponPrimaryClipCount()

			boltSpeed *= 5
		}

			bolt.s.bulletsToFire <- damageLevel //+ 1

			bolt.s.extraDamagePerBullet <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets )
			bolt.s.extraDamagePerBullet_Titan <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets_titanarmor )

			if ( isExplosiveShot ) {
				int trailLevel = ( damageLevel + 1 ) / 2
				print("[TAEsArmory] FireChargePistol: trailLevel = " + trailLevel)
				bolt.SetProjectilTrailEffectIndex( trailLevel )
			}
*/

/*	 Charge level handling
int function ChargePistol_GetChargeLevel( entity weapon ) {
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

int function ChargePistol_GetDamageLevel( entity projectile ) {
	if ( !( "bulletsToFire" in projectile.s ) )
		return 0

	float level = float ( projectile.s.bulletsToFire )
	return int( level ) //- 1
}

float function ChargePistol_GetDirectDamage( entity projectile, entity hitent ) {
	if ( !( "bulletsToFire" in projectile.s ) )
		return 0
	if ( !( "extraDamagePerBullet" in projectile.s ) )
		return 0
	if ( !( "extraDamagePerBullet_Titan" in projectile.s ) )
		return 0

	int damagePerBullet = expect int( projectile.s.extraDamagePerBullet )
	if ( hitent.IsTitan() )
		damagePerBullet = expect int( projectile.s.extraDamagePerBullet_Titan )

	float damageAmt = float( projectile.s.bulletsToFire * damagePerBullet )
	if ( damageAmt <= 0 )
		return 0
	return damageAmt
} // */

/*	Projectile collision handling
void function OnProjectileCollision_Weapon_ChargePistol( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	// Validation
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) ) {
		projectile.Destroy()
		return
	}

	if ( !IsValid( projectile ) )
		return

	// Get damage level, return early if no explosion
	int damageLevel = ChargePistol_GetDamageLevel( projectile )
	if ( damageLevel == 0 ) return

	// Calculate explosion vars
	RadiusDamageData data = GetRadiusDamageDataFromProjectile( projectile, owner )

	int explosionDamage = data.explosionDamage * damageLevel
	int explosionDamageTitan = data.explosionDamageHeavyArmor  * damageLevel

	float explosionInnerRadius = LARGE_BALL_INNER_RADIUS * damageLevel
	float explosionRadius = LARGE_BALL_RADIUS * damageLevel

	// fx
	vector origin = projectile.GetOrigin()

	EmitSoundAtPosition( projectile.GetTeam(), origin, ARC_BALL_AIRBURST_SOUND )

	#if SERVER
	PlayFX( ARC_BALL_AIRBURST_FX, origin )

	// explosion stuffs
	RadiusDamage(
		pos,											// center
		owner,											// attacker
		projectile,										// inflictor

		explosionDamage,								// damage
		explosionDamageTitan,							// damageHeavyArmor
		explosionInnerRadius,							// innerRadius
		explosionRadius,								// outerRadius

		0,												// flags
		0,												// distanceFromAttacker
		0,												// explosionForce (replace later)

		DF_EXPLOSION | DF_CRITICAL | DF_ELECTRICAL, 	// scriptDamageFlags
		projectile.ProjectileGetDamageSourceID()		// scriptDamageSourceIdentifier
	)

	projectile.Destroy()
	#endif
} // */

/*
#if SERVER
void function OnHit_Weapon_ChargePistol( entity victim, var damageInfo ) {
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( !inflictor.IsProjectile() )
		return

	int extraDamage = int( ChargePistol_GetDirectDamage( inflictor, victim ) )
	float damage = DamageInfo_GetDamage( damageInfo )
	float f_extraDamage = float( extraDamage )

	bool isCritical = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), victim, DamageInfo_GetHitBox( damageInfo ), damage, DamageInfo_GetDamageType( damageInfo ) )
	if ( isCritical ) {
		f_extraDamage *= expect float( inflictor.ProjectileGetWeaponInfoFileKeyField( "critical_hit_damage_scale" ) )
	}

	//Check to see if damage has been see to zero so we don't override it.
	if ( damage > 0 && extraDamage > 0 ) {
		damage += f_extraDamage
		DamageInfo_SetDamage( damageInfo, damage )
	}

	// knockback? dunno what this does
	float nearRange = 1000
	float farRange = 1500
	float nearScale = 0.5
	float farScale = 0

	if ( victim.IsTitan() )
		PushEntWithDamageInfoAndDistanceScale( victim, damageInfo, nearRange, farRange, nearScale, farScale, 0.25 )
}
#endif
// */
