//		Func declarations
global function TArmory_Init_PhosphorScorch_Flamethrower

global function OnWeaponPrimaryAttack_PhosphorScorch_Flamethrower
#if SERVER
global function OnWeaponNpcPrimaryAttack_PhosphorScorch_Flamethrower
#endif

global function OnProjectileCollision_PhosphorScorch_Flamethrower

//			Data
const bool DEBUG = true

//		Consts
//	Physics
const float PROJECTILE_MIN_SPEED = 2500

const float PROJECTILE_SPEEDSCALE_SP = 0.35
const float PROJECTILE_SPEEDSCALE_MP = 0.25

//	Jet ammo consumption
const float[3] JET_AMMO_EFFICIENCY_MOD = [1.0, 0.5, 1.0]

//	FX
const asset GASOLINE_FX_MOVING = $"P_fire_small_FULL"

const asset GASOLINE_FX_STATIC_MD = $"P_fire_med_FULL"
const asset GASOLINE_FX_STATIC_SM = $"P_fire_small_FULL"

int gasolineTableIdx = 0

//		Functions
//	Init
void function TArmory_Init_PhosphorScorch_Flamethrower() {
	//	Register FX
	PrecacheParticleSystem( GASOLINE_FX_MOVING )

	PrecacheParticleSystem( GASOLINE_FX_STATIC_MD )
	PrecacheParticleSystem( GASOLINE_FX_STATIC_SM )

	array<asset> movingFX = [ GASOLINE_FX_MOVING ]
	array<asset> staticFX = [ GASOLINE_FX_STATIC_MD, GASOLINE_FX_STATIC_MD, GASOLINE_FX_STATIC_SM ]
	gasolineTableIdx = ThermiteECS_RegisterFXGroup( movingFX, staticFX )

	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_phosphor_titanweapon_flamethrower" )

	//	Add eDamageSourceId using Dinorush's server code
	table<string, string> customDamageSourceIds = {
		ta_phosphor_titanweapon_flamethrower = "T-257 Inferno",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	//	Add damage callback(s)
	AddDamageCallbackSourceID( eDamageSourceId.ta_phosphor_titanweapon_flamethrower, Flamethrower_DamagedEntity )

	//	Add flags
	FlagInit( "SP_MeteorIncreasedDuration" )
	FlagSet( "SP_MeteorIncreasedDuration" )
	#endif
}

//	Augment tracking
int function GetAugmentVariant( entity weapon ) {
	bool jetSpray = weapon.HasMod("tarmory_flamethrower_aug_jetspray")
	bool volatile = weapon.HasMod("tarmory_flamethrower_aug_volatile")

	Assert( !(jetSpray && volatile) )

	return (!volatile) ? ( (!jetSpray) ? 0 : 1 ) : 2
}

//	Attack handling
var function OnWeaponPrimaryAttack_PhosphorScorch_Flamethrower( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireFlamethrower( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_PhosphorScorch_Flamethrower( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return FireFlamethrower( weapon, attackParams, false )
}
#endif

int function FireFlamethrower( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner validation
	entity owner = weapon.GetWeaponOwner()

	//	Fire weapon
	int returnAmt = FlamethrowerStream( weapon, attackParams, playerFired )

	//	Apply Clean Burn mod
	if( weapon.HasMod( "tarmory_flamethrower_kit_cleanburn" ) ) {
		float returnFrac = returnAmt / (1 + 0.5)
		returnAmt = TArmory_WeightedRound( returnFrac )

		/* 		Explanation
		 * 	TArmory_WeightedRound rounds a float into an integer by preserving
		 * 	the integer component, then adding 1 with a chance equal to the
		 * 	number's decimal component. This function first multiplies ammo
		 * 	consumption by 2/3 (+50% ammo efficiency), then applies the
		 * 	WeightedRound function. If the original amount was 1, the function
		 *  will return 0 33.33% of the time and 1 66.67% of the time. If the
		 * 	amount was 2, it will return 1 33.33% of the time and 2 66.67% of
		 *  the time. Thus, we achieve 50% ammo efficiency; the weapon behaves
		 * 	as if it had a mag size of 150.
		 */
	}

	return returnAmt
}

//	Stream (alt fire) handling
int function FlamethrowerStream( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Test for projectile creation
	bool shouldCreateProjectiles = false
	if( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectiles = true
	#if CLIENT
		if( !playerFired )
			shouldCreateProjectiles = false
	#endif

	//	Projectile creation
	if( shouldCreateProjectiles ) {
		float boltSpeed = 1.0
		int damageFlags = weapon.GetWeaponDamageFlags()

		//entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
		vector angVel = <0, 0, 0>
		entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angVel, 0., damageFlags, damageFlags, playerFired, true, false )
		if( nade ) {
			entity owner = weapon.GetWeaponOwner()
			#if SERVER
			EmitSoundOnEntity( nade, "weapon_thermitelauncher_projectile_3p" )
			Grenade_Init( nade, weapon )
			nade.SetTakeDamageType( DAMAGE_NO )
			#else
			SetTeam( nade, owner.GetTeam() )
			#endif
		}
	}

	//	Ammo consumption
	return weapon.GetAmmoPerShot()
}

/*	mostly shamelessly copied from Respawn's code, but I'm going to have to redo
 *	it for Scorch: Phosphor Class anyway, so I don't care.
 */
#if SERVER
void function Flamethrower_DamagedEntity( entity target, var damageInfo ) {
	//	Validity check
	if ( !IsValid( target ) )
		return

	Thermite_DamagePlayerOrNPCSounds( target )
	//TArmory_TemperedPlating_OnSelfDamage( target, damageInfo )

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || attacker.GetTeam() == target.GetTeam() )
		return

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 ) {
		//	"Wildfire Launcher" mod
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		//	"Hot Streak" aegis rank
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
	}
}
#endif

//	Collisions
void function OnProjectileCollision_PhosphorScorch_Flamethrower( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	//	Owner validity check
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
		return

	#if SERVER
	if( hitEnt.IsWorld() ) {
		vector offsetPos = pos - <0, 0, 5>

		TraceResults results = TraceLineNoEnts( pos, offsetPos )
		if( results.fraction < 1 ) {
			vector velOffset = Vector(
				RandomFloatRange(-20.0, 20.0),
				RandomFloatRange(-20.0, 20.0),
				RandomFloatRange(-20.0, 20.0)
			)

			//	Create new thermite
			ThermiteECS_CreateThermiteEnt( projectile, owner, projectile.GetOrigin(), projectile.GetVelocity() + velOffset, gasolineTableIdx )

			//	Destroy projectile
			if( IsValid(projectile) )
				projectile.Destroy()
		}
	}
	#endif
}
