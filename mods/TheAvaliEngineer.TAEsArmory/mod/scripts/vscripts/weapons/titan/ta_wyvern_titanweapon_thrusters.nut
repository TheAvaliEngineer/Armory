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

//	Activation costs
const float FLIGHT_COST = 0.05
const float AFTERBURNERS_COST = 0.45

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

//		FX
array<string> FX_ATTACH_POINTS = [
	"FX_L_TOP_THRUST", "FX_R_TOP_THRUST",
	"FX_L_BOT_THRUST", "FX_R_BOT_THRUST"
]


//		Funcs
//	Init
void function TAInit_Wyvern_Thrusters() {
	//	FX Precache
	PrecacheModel( THRUSTER_HITBOX )

	//	Signaling
	RegisterSignal( "StartFlight" )
	RegisterSignal( "StopFlight" )
	RegisterSignal( "BreakFlight" )

	RegisterSignal( "Backblast" )

    #if SERVER
	//  Precache weapon
    PrecacheWeapon( "ta_wyvern_titanweapon_thrusters" )

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

	owner.SetSharedEnergyTotal( FLIGHT_ENERGY )
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
	OnWeaponActivate_Wyvern_Thrusters( weapon )

	//	Check afterburners
	float chargeFrac = GetChargeFraction( weapon )

	#if SERVER
	//	Update flight state
	bool flyState = weapon.s.changeRate < 0.
	bool isBoosted = chargeFrac >= 1.

	bool hasMods = false
	if( weapon.HasMod( "TArmory_Flight_DiveHelper" ) ) {
		weapon.RemoveMod( "TArmory_Flight_DiveHelper" )
		hasMods = true
	}
	if( weapon.HasMod( "TArmory_Flight_RiseHelper" ) ) {
		weapon.RemoveMod( "TArmory_Flight_RiseHelper" )
		hasMods = true
	}

	if( flyState ) {
		if( isBoosted && !hasMods ) {
			flyState = ApplyActivationCost( weapon, AFTERBURNERS_COST )

			if( flyState ) {
				weapon.AddMod( "TArmory_Flight_DiveHelper" )	//	Add mod to modify behavior
				weapon.Signal( "Backblast" )					//	Signal to do damage
			}
		} else {
			weapon.Signal( "StopFlight" )	//	Signal to stop flight logic (dive needs flight to continue)
		}
	} else if( weapon.s.flightReady ) {
		float cost = (isBoosted && !hasMods) ? AFTERBURNERS_COST : FLIGHT_COST
		flyState = ApplyActivationCost( weapon, cost )

		if( flyState ) {
			if( isBoosted && !hasMods ) {
				weapon.AddMod( "TArmory_Flight_RiseHelper" )	//	Add mod to modify behavior
				weapon.Signal( "Backblast" )					//	Signal to do damage
			}

			weapon.Signal( "StartFlight" )
		}
	}

	if( !flyState ) {
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "coop_sentrygun_deploymentdeniedbeep" )
	}
	#endif

	if( owner.IsPlayer() ) {
		PlayerUsedOffhand( owner, weapon )
	}

	return weapon.GetAmmoPerShot()
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
float function GetChargeFraction( entity weapon ) {
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
		flightWeapon.s.flying = true

		if( owner.IsPlayer() ) {
			owner.SetTitanDisembarkEnabled( false )
			SetFlightPhysics( owner, true )
		}

		StartFlightFX( owner, flightWeapon )
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
		flightWeapon.s.flying = false

		if( owner.IsPlayer() ) {
			owner.SetTitanDisembarkEnabled( true )
			SetFlightPhysics( owner, false )
		}

		StopFlightFX( owner, flightWeapon )
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
		flightWeapon.s.flying = false

		if( owner.IsPlayer() ) {
			owner.SetTitanDisembarkEnabled( true )
			SetFlightPhysics( owner, false )
		}

		StopFlightFX( owner, flightWeapon )
	}
}

//		Helper functions
void function SetFlightPhysics( entity owner, bool flying ) {
	if( flying ) {
		owner.kv.airSpeed = FLIGHT_AIR_SPEED
		owner.kv.airAcceleration = FLIGHT_AIR_ACCEL

		owner.kv.gravity = 0

		owner.SetGroundFrictionScale( FLIGHT_FRICTION )
	} else {
		owner.kv.airSpeed = owner.GetPlayerSettingsField( "airSpeed" )
		owner.kv.airAcceleration = owner.GetPlayerSettingsField( "airAcceleration" )

		owner.kv.gravity = owner.GetPlayerSettingsField( "gravityScale" )

		owner.SetGroundFrictionScale( 1. )
	}
}

void function StartFlightFX( entity owner, entity weapon ) {
	//		FX
	if( !("thrusterFX" in weapon.s) )
		weapon.s.thrusterFX <- []

	//	Attachment check
	if( owner.LookupAttachment( "FX_L_BOT_THRUST" ) != 0 ) {
		int largeJetIdx = GetParticleSystemIndex( $"P_xo_jet_fly_large" )
		int smallJetIdx = GetParticleSystemIndex( $"P_xo_jet_fly_small" )

		array<int> attachIdxs = [ smallJetIdx, smallJetIdx, largeJetIdx, largeJetIdx ]

		for( int i = 0; i < 4; i++ ) {
			int thrusterFXattachID = owner.LookupAttachment( FX_ATTACH_POINTS[i] )
			entity fx = StartParticleEffectOnEntity_ReturnEntity( owner, attachIdxs[i], FX_PATTACH_POINT_FOLLOW, thrusterFXattachID )

			fx.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER

			weapon.s.thrusterFX.append( fx )
		}
	}

	//		SFX
	//	Liftoff
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "titan_flight_liftoff_1p" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "titan_flight_liftoff_3p" )

	//	Ambient
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "titan_flight_hover_1p" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "titan_flight_hover_3p" )
}

void function StopFlightFX( entity owner, entity weapon ) {
	//	FX
	foreach( fx in weapon.s.thrusterFX ) {
		if( IsValid(fx) )
			fx.Destroy()
	}

	//	SFX
	StopSoundOnEntity( owner, "titan_flight_hover_1p" )
	StopSoundOnEntity( owner, "titan_flight_hover_3p" )
}

//		Management thread
void function FlightSystem( entity flightWeapon ) {
	print("[TAEsArmory] FlightSystem: Started FlightSystem")

	//	Owner validation
	entity owner = flightWeapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	//	Signals
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	OnThreadEnd( function() : (owner, flightWeapon) {
		print("[TAEsArmory] FlightSystem: Stopped FlightSystem")

		if( IsValid(owner) && owner.IsPlayer() ) {
			owner.SetTitanDisembarkEnabled( true )
			SetFlightPhysics( owner, false )
		}

		if( IsValid(flightWeapon) ) {
			flightWeapon.s.flying = false
			flightWeapon.s.shouldStartThreads = true

			StopFlightFX( owner, flightWeapon )
		}
	})

	//	Listeners
	thread FlightStartListener( owner, flightWeapon )
	thread FlightStopListener( owner, flightWeapon )
	thread FlightBreakListener( owner, flightWeapon )

	//	System
	float prevTime = Time()
	float changeStack = 0
	while(1) {
		WaitFrame()

		FlightStateSystem( flightWeapon, FLIGHT_DRAIN_TIME, FLIGHT_REGEN_TIME )
		FlightPhysicsSystem( owner, flightWeapon )
		changeStack = FlightAmmoSystem( flightWeapon, changeStack, prevTime )

		prevTime = Time()
	}
}


void function FlightStateSystem( entity flightWeapon, float dischargeTime, float chargeTime ) {
	//		Change state
	int ammo = flightWeapon.GetWeaponPrimaryClipCount()
	int maxAmmo = flightWeapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	float dischargeRate = maxAmmo / dischargeRate
	float chargeRate = maxAmmo / chargeTime

	//	Flight battery is empty & draining (negates startFlight)
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
		return
	}

	//	Flight battery is off cooldown - allow user to fly
	//	Regen is paused
	if( flightWeapon.s.changeRate == 0. ) {
		flightWeapon.s.changeRate = chargeRate
	}

	flightWeapon.s.flightReady = true
}

void function FlightPhysicsSystem( entity owner, entity flightWeapon ) {
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

		//print("[TAEsArmory] FlightPhysicsSystem: altOffset = " + altOffset)
		if( fabs(altOffset) <= 37.5 ) {
			if( flightWeapon.HasMod("TArmory_Flight_RiseHelper") ) {
				print("[TAEsArmory] FlightPhysicsSystem: Removing RiseHelper")
				flightWeapon.RemoveMod( "TArmory_Flight_RiseHelper" )
			}

			if( flightWeapon.HasMod("TArmory_Flight_DiveHelper") ) {
				print("[TAEsArmory] FlightPhysicsSystem: Removing DiveHelper")
				flightWeapon.RemoveMod( "TArmory_Flight_DiveHelper" )
				flightWeapon.Signal( "StopFlight" )
			}

			zVel = 0.
		}

		vector vel = owner.GetVelocity()
		vel.z = zVel

		owner.SetVelocity(vel)
	}
}

float function FlightAmmoSystem( entity flightWeapon, float changeStack, float prevTime ) {
	int maxAmmo = flightWeapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	//	Retrieve changeRate
	float changeRate = expect float( flightWeapon.s.changeRate )

	//	Ammo math
	bool isAfterburn = flightWeapon.HasMod("TArmory_Flight_RiseHelper") || flightWeapon.HasMod("TArmory_Flight_DiveHelper")
	changeStack += ( Time() - prevTime ) * ( isAfterburn ? 0. : changeRate )

	int newAmmoCount = flightWeapon.GetWeaponPrimaryClipCount() + changeStack.tointeger()
	newAmmoCount = minint( maxint( newAmmoCount, 0 ), maxAmmo )
	flightWeapon.SetWeaponPrimaryClipCount( newAmmoCount )

	changeStack -= float( changeStack.tointeger() )

	return changeStack
}
#endif

//		      :::::::::      :::       :::   :::       :::      ::::::::  ::::::::::
//		     :+:    :+:   :+: :+:    :+:+: :+:+:    :+: :+:   :+:    :+: :+:
//		    +:+    +:+  +:+   +:+  +:+ +:+:+ +:+  +:+   +:+  +:+        +:+
//		   +#+    +:+ +#++:++#++: +#+  +:+  +#+ +#++:++#++: :#:        +#++:++#
//		  +#+    +#+ +#+     +#+ +#+       +#+ +#+     +#+ +#+   +#+# +#+
//		 #+#    #+# #+#     #+# #+#       #+# #+#     #+# #+#    #+# #+#
//		#########  ###     ### ###       ### ###     ###  ########  ##########

#if SERVER
void function BackblastListener( entity owner, entity flightWeapon ) {
	//	Signaling
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	flightWeapon.EndSignal( "OnDestroy" )

	//	Listener loop
	while(1) {
		flightWeapon.WaitSignal( "Backblast" )

		//	Signal recieved
		print("[TAEsArmory] BackblastListener: Doing blast")

		//	Play FX (stolen from FlyerHovers)
		CreateShake( owner.GetOrigin(), 80, 150, 0.50, 1500 )
		PlayFX( FLIGHT_CORE_IMPACT_FX, owner.GetOrigin() )

		//	Create radiusDamage
		int damageFlags = flightWeapon.GetWeaponDamageFlags()
	}
}

void function BackblastOnDamage( entity ent, var damageInfo ) {
	//	Add effects
	if( ent.IsPlayer() || ent.IsNPC() ) {
		//	Make sure titan is slowed (& not pilot)
		entity entToSlow = ent
		entity soul = ent.GetTitanSoul()

		if ( soul != null )
			entToSlow = soul

		//	Apply effects
		StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, BLAST_SLOW_STRENGTH, BLAST_SLOW_DURATION, 1.0 )
		StatusEffect_AddTimed( entToSlow, eStatusEffect.dodge_speed_slow, BLAST_SLOW_STRENGTH, BLAST_SLOW_DURATION, 1.0 )
	}
}
#endif


//			  :::    ::: ::::::::::     :::     :::    ::::::::::: :::    :::
//			 :+:    :+: :+:          :+: :+:   :+:        :+:     :+:    :+:
//			+:+    +:+ +:+         +:+   +:+  +:+        +:+     +:+    +:+
//		   +#++:++#++ +#++:++#   +#++:++#++: +#+        +#+     +#++:++#++
//		  +#+    +#+ +#+        +#+     +#+ +#+        +#+     +#+    +#+
//		 #+#    #+# #+#        #+#     #+# #+#        #+#     #+#    #+#
//		###    ### ########## ###     ### ########## ###     ###    ###

