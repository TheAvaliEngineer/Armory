untyped

//		Function declarations
global function TArmory_Init_GeistRonin_TitanCloak

//global function OnWeaponChargeBegin_GeistRonin_TitanCloak
//global function OnWeaponChargeEnd_GeistRonin_TitanCloak

global function OnWeaponActivate_GeistRonin_TitanCloak

global function OnWeaponOwnerChanged_GeistRonin_TitanCloak

global function OnWeaponPrimaryAttack_GeistRonin_TitanCloak
#if SERVER
global function OnWeaponNpcPrimaryAttack_GeistRonin_TitanCloak
#endif

//		Data
//	Cloak time
const float TITAN_CLOAK_DRAIN_TIME = 15.0
const float TITAN_CLOAK_REGEN_TIME = 20.0

const float TITAN_CLOAK_REGEN_DELAY = 1.5
const float TITAN_CLOAK_BREAK_DELAY = 1.5

const float TITAN_CLOAK_RETRIGGER_WINDOW = 1.5

//	Activation
const float ACTIVATION_COST_FRAC = 0.05

//		Functions
//	Init
void function TArmory_Init_GeistRonin_TitanCloak() {
	#if SERVER
	//	Weapon precache
	PrecacheWeapon( "ta_geist_titanability_titancloak" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_geist_titanability_titancloak = "Titan Cloak",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Activate/deactivate
void function OnWeaponActivate_GeistRonin_TitanCloak( entity weapon ) {
	//	Insert table slots
	if( !("lastUseTime" in weapon.s) ) {
		weapon.s.lastUseTime <- 0.
	}
	if( !("cloakReady" in weapon.s) ) {
		weapon.s.cloakReady <- true
	}

	if( !("startCloak" in weapon.s) ) {
		weapon.s.startCloak <- false
	}
	if( !("breakCloak" in weapon.s) ) {
		weapon.s.breakCloak <- false
	}

	if( !("changeRate" in weapon.s) ) {
		weapon.s.changeRate <- 0.
	}
	if( !("nextUseTime" in weapon.s) ) {
		weapon.s.nextUseTime <- 0.
	}

	if( !("shouldStartThreads" in weapon.s) ) {
		weapon.s.shouldStartThreads <- true
	}

	#if SERVER
	//	Start management threads
	if( weapon.s.shouldStartThreads ) {
		thread TitanCloakSystem( weapon )
		//thread TitanCloak_ManipulateState( weapon )
		//thread TitanCloak_ManipulateAmmo( weapon )

		weapon.s.shouldStartThreads = false
	}
	#endif
}

//	Owner change
void function OnWeaponOwnerChanged_GeistRonin_TitanCloak( entity weapon, WeaponOwnerChangedParams changeParams ) {
	#if SERVER
	if( IsValid( changeParams.newOwner ) && IsValid( changeParams.oldOwner ) && IsCloaked( changeParams.oldOwner ) ) {
		CloakerDeCloaksGuy( changeParams.oldOwner )

		if( changeParams.newOwner.IsPlayer() ) {
			EnableCloak( changeParams.newOwner, TITAN_CLOAK_DRAIN_TIME )
		} else { CloakerCloaksGuy( changeParams.newOwner ) }
	}
	#endif
}


//	Fire handling
var function OnWeaponPrimaryAttack_GeistRonin_TitanCloak( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return TitanCloak_OnFire( weapon, attackParams, true )
}
#if SERVER
var function OnWeaponNpcPrimaryAttack_GeistRonin_TitanCloak( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return 0 //TitanCloak_OnFire( weapon, attackParams, false )
}
#endif

int function TitanCloak_OnFire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner validation
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return 0

	//	Insert table slots
	OnWeaponActivate_GeistRonin_TitanCloak( weapon )

	#if SERVER
	bool success = true

	if( IsCloaked( owner ) ) {
		bool canUse = Time() - weapon.s.lastUseTime > TITAN_CLOAK_RETRIGGER_WINDOW
		success = weapon.s.changeRate < 0. && canUse
		weapon.s.breakCloak = success
	} else if( weapon.s.cloakReady ) {
		//	Sets to true if can be activated, otherwise false
		success = ApplyActivationCost( weapon, ACTIVATION_COST_FRAC )
		weapon.s.startCloak = success
	} else { success = false }

	if( success ) weapon.s.lastUseTime = Time()
	else EmitSoundOnEntityOnlyToPlayer( owner, owner, "coop_sentrygun_deploymentdeniedbeep" )
	#endif

	if( owner.IsPlayer() ) {
		PlayerUsedOffhand( owner, weapon )
	}

	return 0
}

bool function ApplyActivationCost( entity weapon, float frac ) {
	//	Get ammo frac left
	int currentAmmo = weapon.GetWeaponPrimaryClipCount()
	int maxAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	float fracLeft = 1.0 - currentAmmo.tofloat() / maxAmmo.tofloat()

	int consumeAmt = (maxAmmo * frac).tointeger()

	bool canActivate = (currentAmmo - consumeAmt) > 0
	if( canActivate ) {
		weapon.SetWeaponPrimaryClipCount( currentAmmo - consumeAmt )
	} else {
		weapon.ForceRelease()
		weapon.SetWeaponPrimaryClipCount( 0 )
	}

	return canActivate
}

//	Logic
#if SERVER
void function TitanCloakSystem( entity weapon ) {
	//	Owner validation
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	//	Signals
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	weapon.EndSignal( "OnDestroy" )

	//	Math
	int maxAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	float dischargeRate = -(maxAmmo / TITAN_CLOAK_DRAIN_TIME)
	float chargeRate = maxAmmo / TITAN_CLOAK_REGEN_TIME

	//	Loop
	float prevTime = Time()
	float changeStack = 0
	while(1) {
		WaitFrame()

		//		Change state
		//	Cloak is broken - start cooldown, set to 0
		if( weapon.s.breakCloak ) {
			weapon.s.nextUseTime = Time() + TITAN_CLOAK_BREAK_DELAY

			weapon.s.cloakReady = false
			weapon.s.startCloak = false
			weapon.s.breakCloak = false
		}

		int ammo = weapon.GetWeaponPrimaryClipCount()

		//	Cloak battery is empty (negates startCloak)
		if( ammo == 0 && weapon.s.changeRate < 0. ) {
			weapon.s.nextUseTime = Time() + TITAN_CLOAK_REGEN_DELAY

			weapon.s.cloakReady = false
		}

		//	Cloak battery is full or on cooldown
		float nextUseTime = expect float( weapon.s.nextUseTime )
		bool stillOnCooldown = nextUseTime - Time() > 0.

		if( ammo == maxAmmo || stillOnCooldown ) {
			weapon.s.changeRate = 0.
		}

		//	Cloak battery is off cooldown - allow user to cloak
		if( !stillOnCooldown  ) {
			//	Regen is paused
			if( weapon.s.changeRate == 0. ) {
				weapon.s.changeRate = chargeRate
			}

			weapon.s.cloakReady = true
		}

		//	Set to discharge & remove readiness if startCloak & cloakReady
		bool shouldDischarge = expect bool( weapon.s.startCloak ) && expect bool( weapon.s.cloakReady )
		if( shouldDischarge ) {
			weapon.s.changeRate = dischargeRate

			weapon.s.startCloak = false
			weapon.s.cloakReady = false
		}

		//	Retrieve changeRate
		float changeRate = expect float( weapon.s.changeRate )

		//	Cloak/uncloak handling (cloak only when discharging)
		bool shouldCloak = changeRate < 0.
		if( IsCloaked( owner ) != shouldCloak ) {
			if( shouldCloak ) {
				EnableCloak( owner, TITAN_CLOAK_DRAIN_TIME )
			} else {
				DisableCloak( owner )
			}
		}

		//	Ammo math
		changeStack += ( Time() - prevTime ) * changeRate

		int newAmmoCount = weapon.GetWeaponPrimaryClipCount() + changeStack.tointeger()
		newAmmoCount = minint( maxint( newAmmoCount, 0 ), maxAmmo )
		weapon.SetWeaponPrimaryClipCount( newAmmoCount )

		changeStack -= float( changeStack.tointeger() )

		prevTime = Time()
	}
}
#endif