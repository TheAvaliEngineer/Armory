untyped

//		Func Declarations
global function TAInit_Wyvern_Thrusters

global function OnWeaponActivate_Wyvern_Thrusters

global function OnWeaponPrimaryAttack_Wyvern_Thrusters
#if SERVER
global function OnWeaponNpcPrimaryAttack_Wyvern_Thrusters
#endif

//		Flight Data
//	Flight usage perams
const int FLIGHT_ENERGY = 1500

const float FLIGHT_DRAIN_TIME = 10.0
const float FLIGHT_REGEN_TIME = 15.0

const float CHARGE_RATE = FLIGHT_ENERGY / FLIGHT_REGEN_TIME
const float DRAIN_RATE = FLIGHT_ENERGY / FLIGHT_DRAIN_TIME

const float FLIGHT_COOL_DELAY = 2.5
const float FLIGHT_BREAK_DELAY = 10.0

const float ACTIVATION_COST_FRAC = 0.05

//	Flight physics perams (normal)
const float FLIGHT_MAX_ALTI_DRY = 750
const float FLIGHT_MAX_ALTI_RIS = 900
const float FLIGHT_MAX_ALTI_DIV = 0

const float FLIGHT_VERT_VEL_DRY = 450
const float FLIGHT_VERT_VEL_WET = 4500 //2250

//	Flight movement params
const float FLIGHT_AIR_SPEED = 200
const float FLIGHT_AIR_ACCEL = 1000
const float FLIGHT_FRICTION = 0.2

//	Thruster hitbox
const asset THRUSTER_HITBOX = $"models/weapons/titan_trip_wire/titan_trip_wire.mdl"
const int THRUSTER_MAX_HEALTH = 1500

const float PLAYER_DMG_RATIO = 0.5

//	Thruster explosion data
const float THRUSTER_EXP_INNER_RADIUS = 150
const float THRUSTER_EXP_OUTER_RADIUS = 800

const int THRUSTER_EXP_DAMAGE_HUMAN = 250
const int THRUSTER_EXP_DAMAGE_TITAN = 1500

const float THRUSTER_EXP_FORCE = 5000000

//	Thruster explosion FX
const asset THRUSTER_EXP_FX = $"exp_rocket_shoulder_large" //$"P_impact_exp_XLG_metal" $"exp_large"
const string THRUSTER_EXP_SFX = "Wpn_LaserTripMine_MineDestroyed"

const asset THRUSTER_FLAMEOUT_FX = $""

//		Blast Data
//	Status effects
const float BLAST_SLOW_STRENGTH = 0.5
const float BLAST_SLOW_DURATION = 2.0

//		Funcs
//	Init
void function TAInit_Wyvern_Thrusters() {
	//	FX Precache
	PrecacheModel( THRUSTER_HITBOX )

	//  Precache weapon
    PrecacheWeapon( "ta_wyvern_titanweapon_thrusters" )

	//	Signaling
	RegisterSignal( "StartFlight" )
	RegisterSignal( "StopFlight" )
	RegisterSignal( "BreakFlight" )

    #if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_wyvern_titanweapon_thrusters = "Backblast",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Activation handling
void function OnWeaponActivate_Wyvern_Thrusters( entity weapon ) {
	//		Table
	//	Insert table slots for ammo control
	if( !("flying" in weapon.s) ) {
		weapon.s.flying <- false
	}
	if( !("flightReady" in weapon.s) ) {
		weapon.s.flightReady <- true
	}

	if( !("changeRate" in weapon.s) ) {
		weapon.s.changeRate <- 0.
	}
	if( !("nextUseTime" in weapon.s) ) {
		weapon.s.nextUseTime <- 0.
	}

	//	Insert table slots for fx control
	if( !("thrusters" in weapon.s) ) {
		weapon.s.thrusters <- []
	} else { weapon.s.thrusters = [] }

	//	Insert table slots for thread control
	if( !("shouldStartThreads" in weapon.s) ) {
		weapon.s.shouldStartThreads <- true
	}

	//		Shared energy
	entity owner = weapon.GetWeaponOwner()

	owner.SetSharedEnergyTotal(FLIGHT_ENERGY)
	owner.SetSharedEnergyRegenRate(100)

	#if SERVER
	if( weapon.s.shouldStartThreads ) {
		thread FlightSystem( weapon )
		weapon.s.shouldStartThreads = false
	}
	#endif
}

//	Attack handling
var function OnWeaponPrimaryAttack_Wyvern_Thrusters( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	Thrusters_OnFire( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_Wyvern_Thrusters( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	Thrusters_OnFire( weapon, attackParams, false )
}
#endif

int function Thrusters_OnFire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner validation
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return 0

	//	Insert table slots
	OnWeaponActivate_WyvernNorthstar_Flight( weapon )

	#if SERVER
	//	Update flight state
	print("[TAEsArmory] Thrusters_OnFire: weapon.s.changeRate = " + weapon.s.changeRate)

	bool changeState = weapon.s.changeRate < 0.;
	if( changeState ) {
		weapon.Signal( "StopFlight" )
	} else if( weapon.s.flightReady ) {
		changeState = ApplyActivationCost( weapon, ACTIVATION_COST_FRAC )
		if( changeState ) {
			weapon.Signal( "StartFlight" )
		}
	}

	if( !changeState ) {
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "coop_sentrygun_deploymentdeniedbeep" )
	}
	#endif

	if( owner.IsPlayer() ) {
		PlayerUsedOffhand( owner, weapon )
	}
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

//	Charge level handling
float function GetChargeLevel( entity weapon ) {
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

//		      :::::::::: :::        ::::::::::: ::::::::  :::    ::: :::::::::::
//		     :+:        :+:            :+:    :+:    :+: :+:    :+:     :+:
//		    +:+        +:+            +:+    +:+        +:+    +:+     +:+
//		   :#::+::#   +#+            +#+    :#:        +#++:++#++     +#+
//		  +#+        +#+            +#+    +#+   +#+# +#+    +#+     +#+
//		 #+#        #+#            #+#    #+#    #+# #+#    #+#     #+#
//		###        ########## ########### ########  ###    ###     ###

#if SERVER

//		Signaling functions
//	This function listens for the StartFlight signal, triggered whenever flight
//	is *started,* either by the user starting flight or via ascent ability.
void function FlightStartListener( entity owner, entity flightWeapon ) {
	//	Math
	int maxAmmo = flightWeapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )
	float dischargeRate = -(maxAmmo / FLIGHT_DRAIN_TIME)

	//	Signaling
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	flightWeapon.EndSignal( "OnDestroy" )

	//	Listener loop
	while(1) {
		flightWeapon.WaitSignal( "StartFlight" )

		//	Signal recieved
		if( !flightWeapon.s.flightReady ) continue

		print("[TAEsArmory] FlightSystem: Flight started (via signal)")

		flightWeapon.s.changeRate = dischargeRate
		flightWeapon.s.flightReady = false

		//	Begin flight
		BeginFlight( owner, flightWeapon )
	}
}

//	This function listens for the StopFlight signal, triggered whenever flight
//	is *stopped,* either by the user stopping flight or via ground slam.
void function FlightStopListener( entity owner, entity flightWeapon ) {
	//	Signaling
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	flightWeapon.EndSignal( "OnDestroy" )

	//	Listener loop
	while(1) {
		flightWeapon.WaitSignal( "StopFlight" )

		//	Signal recieved
		print("[TAEsArmory] FlightSystem: Flight stopped (via signal)")

		flightWeapon.s.nextUseTime = Time() + FLIGHT_COOL_DELAY
		flightWeapon.s.flightReady = false

		//	End flight
		EndFlight( owner, flightWeapon )
	}
}

//	This function listens for the BreakFlight signal, triggered whenever flight
//	is specifically *interrupted,* e.g. destruction of the thrusters.
void function FlightBreakListener( entity owner, entity flightWeapon ) {
	//	Signaling
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	flightWeapon.EndSignal( "OnDestroy" )

	//	Listener loop
	while(1) {
		flightWeapon.WaitSignal( "BreakFlight" )

		//	Signal recieved
		print("[TAEsArmory] FlightSystem: Flight broken (via signal)")

		flightWeapon.SetWeaponPrimaryClipCount( 0 )

		flightWeapon.s.nextUseTime = Time() + FLIGHT_BREAK_DELAY
		flightWeapon.s.flightReady = false

		//	End flight
		EndFlight( owner, flightWeapon )
	}
}

//		Management thread
void function FlightSystem( entity flightWeapon ) {
	print("[TAEsArmory] FlightSystem: Started FlightSystem")

	//	Owner validation
	entity owner = flightWeapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	//	Get afterburner weapon
	entity blastWeapon = owner.GetOffhandWeapon( OFFHAND_ANTIRODEO )

	//	Signals
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	OnThreadEnd( function() : (owner, flightWeapon) {
		print("[TAEsArmory] FlightSystem: Stopped FlightSystem")
		if( IsValid(flightWeapon) ) {
			EndFlight( owner, flightWeapon )
			flightWeapon.s.shouldStartThreads = true
		}
	})

	//	Listeners
	thread FlightStartListener( owner, flightWeapon )
	thread FlightStopListener( owner, flightWeapon )
	thread FlightBreakListener( owner, flightWeapon )

	//	Math
	int maxAmmo = flightWeapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	float dischargeRate = -(maxAmmo / FLIGHT_DRAIN_TIME)
	float chargeRate = maxAmmo / FLIGHT_REGEN_TIME

	//	System
	float changeStack = 0
	while(1) {
		WaitFrame()

		FlightStateSystem( flightWeapon, dischargeRate, chargeRate )
		FlightPhysicsSystem( flightWeapon, blastWeapon )
		changeStack = FlightAmmoSystem( flightWeapon, changeStack )
	}
}


void function FlightStateSystem( entity flightWeapon, float dischargeRate, float chargeRate ) {
	//		Change state
	int ammo = flightWeapon.GetWeaponPrimaryClipCount()

	//	Flight battery is empty (negates startFlight)
	if( ammo == 0 && flightWeapon.s.changeRate < 0. ) {
		flightWeapon.s.nextUseTime = Time() + FLIGHT_COOL_DELAY

		flightWeapon.Signal( "StopFlight" )
		flightWeapon.s.flightReady = false
	}

	//	Flight battery is full or on cooldown
	float nextUseTime = expect float( flightWeapon.s.nextUseTime )
	bool stillOnCooldown = nextUseTime - Time() > 0.

	if( ammo == maxAmmo || stillOnCooldown ) {
		flightWeapon.s.changeRate = 0.
	}

	//	Flight battery is off cooldown - allow user to fly
	if( !stillOnCooldown  ) {
		//	Regen is paused
		if( flightWeapon.s.changeRate == 0. ) {
			flightWeapon.s.changeRate = chargeRate
		}

		flightWeapon.s.flightReady = true
	}
}

void function FlightPhysicsSystem( entity flightWeapon, entity blastWeapon ) {
	//	Retrieve changeRate
	float changeRate = expect float( flightWeapon.s.changeRate )

	//	Flight/landing handling (flight only when discharging)
	bool shouldFly = changeRate < 0.
	if( shouldFly ) {
		//	Z
		vector origin = owner.GetOrigin()
		vector offsetOrigin = origin + <0, 0, -5000>

		TraceResults result = TraceLine( origin, offsetOrigin, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

		float targetAlt = flightWeapon.GetWeaponSettingFloat( eWeaponVar.damage_near_distance )
		float targetVel = flightWeapon.GetWeaponSettingFloat( eWeaponVar.damage_far_distance )

		float altOffset = ( origin.z - (result.endPos.z + targetAlt) )
		float zVel = GraphCapped( altOffset, -targetAlt, targetAlt, targetVel, -targetVel )

		print("[TAEsArmory] FlightPhysicsSystem: altOffset = " + altOffset)
		if( fabs(altOffset) <= 37.5 ) {
			if( flightWeapon.HasMod("TArmory_Flight_RiseHelper") ) {
				flightWeapon.RemoveMod( "TArmory_Flight_RiseHelper" )
			}

			if( flightWeapon.HasMod("TArmory_Flight_DiveHelper") ) {
				flightWeapon.RemoveMod( "TArmory_Flight_DiveHelper" )
				flightWeapon.Signal( "StopFlight" )

				blastWeapon.Signal( "AfterburnerBlast" )
			}

			zVel = 0.
		}

		vector vel = owner.GetVelocity()
		vel.z = zVel

		owner.SetVelocity(vel)
	}
}

float function FlightAmmoSystem( entity flightWeapon, float changeStack ) {
	//	Retrieve changeRate
	float changeRate = expect float( flightWeapon.s.changeRate )

	//	Ammo math
	bool isAfterburn = flightWeapon.HasMod("TArmory_Flight_RiseHelper") || flightWeapon.HasMod("TArmory_Flight_DiveHelper")
	changeStack += ( Time() - prevTime ) * ( isAfterburn ? 0. : changeRate )

	int newAmmoCount = flightWeapon.GetWeaponPrimaryClipCount() + changeStack.tointeger()
	newAmmoCount = minint( maxint( newAmmoCount, 0 ), maxAmmo )
	flightWeapon.SetWeaponPrimaryClipCount( newAmmoCount )

	changeStack -= float( changeStack.tointeger() )

	prevTime = Time()
}
#endif

//		      :::    ::: ::::::::::: ::::::::::: :::::::::   ::::::::  :::    ::: :::::::::: ::::::::
//		     :+:    :+:     :+:         :+:     :+:    :+: :+:    :+: :+:    :+: :+:       :+:    :+:
//		    +:+    +:+     +:+         +:+     +:+    +:+ +:+    +:+  +:+  +:+  +:+       +:+
//		   +#++:++#++     +#+         +#+     +#++:++#+  +#+    +:+   +#++:+   +#++:++#  +#++:++#++
//		  +#+    +#+     +#+         +#+     +#+    +#+ +#+    +#+  +#+  +#+  +#+              +#+
//		 #+#    #+#     #+#         #+#     #+#    #+# #+#    #+# #+#    #+# #+#       #+#    #+#
//		###    ### ###########     ###     #########   ########  ###    ### ########## ########