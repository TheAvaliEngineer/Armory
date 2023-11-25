untyped

//		Func Declarations
global function TArmory_Init_WyvernNorthstar_Flight

global function OnWeaponActivate_WyvernNorthstar_Flight

global function OnWeaponPrimaryAttack_WyvernNorthstar_Flight
#if SERVER
global function OnWeaponNpcPrimaryAttack_WyvernNorthstar_Flight
#endif

//		Data
//	Flight usage perams
const float FLIGHT_DRAIN_TIME = 10.0
const float FLIGHT_REGEN_TIME = 15.0

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

//		Funcs
//	Init
void function TArmory_Init_WyvernNorthstar_Flight() {
	//	FX Precache
	PrecacheModel( THRUSTER_HITBOX )

	//  Precache weapon
    PrecacheWeapon( "ta_wyvern_titanability_flight" )

	//	Signaling
	RegisterSignal( "StartFlight" )
	RegisterSignal( "StopFlight" )
	RegisterSignal( "BreakFlight" )

    #if SERVER
	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_wyvern_titanability_flight = "Flare",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Activation handling
void function OnWeaponActivate_WyvernNorthstar_Flight( entity weapon ) {
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

	#if SERVER
	if( weapon.s.shouldStartThreads ) {
		thread FlightSystem( weapon )
		weapon.s.shouldStartThreads = false
	}
	#endif
}

//	Attack handling
var function OnWeaponPrimaryAttack_WyvernNorthstar_Flight( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return Flight_OnFire( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_WyvernNorthstar_Flight( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return Flight_OnFire( weapon, attackParams, false )
}
#endif

int function Flight_OnFire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Owner validation
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return 0

	//	Insert table slots
	OnWeaponActivate_WyvernNorthstar_Flight( weapon )

	#if SERVER
	//	Update flight state
	print("[TAEsArmory] Flight_OnFire: weapon.s.changeRate = " + weapon.s.changeRate)
	if( weapon.s.changeRate < 0. ) {
		weapon.Signal( "StopFlight" )
	} else if( weapon.s.flightReady ) {
		if( ApplyActivationCost( weapon, ACTIVATION_COST_FRAC ) ) {
			weapon.Signal( "StartFlight" )
		} else { EmitSoundOnEntityOnlyToPlayer( owner, owner, "coop_sentrygun_deploymentdeniedbeep" ) }
	} else { EmitSoundOnEntityOnlyToPlayer( owner, owner, "coop_sentrygun_deploymentdeniedbeep" ) }
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

//		      :::::::::: :::        ::::::::::: ::::::::  :::    ::: :::::::::::
//		     :+:        :+:            :+:    :+:    :+: :+:    :+:     :+:
//		    +:+        +:+            +:+    +:+        +:+    +:+     +:+
//		   :#::+::#   +#+            +#+    :#:        +#++:++#++     +#+
//		  +#+        +#+            +#+    +#+   +#+# +#+    +#+     +#+
//		 #+#        #+#            #+#    #+#    #+# #+#    #+#     #+#
//		###        ########## ########### ########  ###    ###     ###


#if SERVER
//	Flight start/stop handling
void function BeginFlight( entity owner, entity weapon ) {
	if( !("flying" in weapon.s) ) {
		weapon.s.flying <- true
	} else { weapon.s.flying = true }

	//	Embarkation
	if( owner.IsPlayer() )
		owner.SetTitanDisembarkEnabled( false )

	//	Physics
	if( owner.IsPlayer() ) {
		owner.kv.airSpeed = FLIGHT_AIR_SPEED
		owner.kv.airAcceleration = FLIGHT_AIR_ACCEL
		owner.kv.gravity = 0

		owner.SetGroundFrictionScale( FLIGHT_FRICTION )
	}

	//	Hitboxes
	thread ThrusterThink( owner, weapon )

	//	FX
	if( !("thrusterFX" in weapon.s) ) {
		weapon.s.thrusterFX <- []
	}

	if( owner.LookupAttachment( "FX_L_BOT_THRUST" ) != 0 ) {
		int largeJetIdx = GetParticleSystemIndex( $"P_xo_jet_fly_large" )
		int smallJetIdx = GetParticleSystemIndex( $"P_xo_jet_fly_small" )

		array<int> attachIdxs = [ largeJetIdx, largeJetIdx, smallJetIdx, smallJetIdx ]
		array<string> attachNames = [ "FX_L_BOT_THRUST", "FX_R_BOT_THRUST", "FX_L_TOP_THRUST", "FX_R_TOP_THRUST" ]

		for( int i = 0; i < 4; i++ ) {
			int thrusterFXattachID = owner.LookupAttachment( attachNames[i] )
			entity fx = StartParticleEffectOnEntity_ReturnEntity( owner, attachIdxs[i], FX_PATTACH_POINT_FOLLOW, thrusterFXattachID )

			fx.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER

			weapon.s.thrusterFX.append( fx )
		}
	}

	//	SFX
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "titan_flight_liftoff_1p" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "titan_flight_liftoff_3p" )

	EmitSoundOnEntityOnlyToPlayer( owner, owner, "titan_flight_hover_1p" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "titan_flight_hover_3p" )
}

void function EndFlight( entity owner, entity weapon ) {
	if( !("flying" in weapon.s) ) {
		weapon.s.flying <- false
	} else { weapon.s.flying = false }

	//	Validity check
	if( !IsValid(owner) )
		return

	//	Embarkation
	if( owner.IsPlayer() )
		owner.SetTitanDisembarkEnabled( true )

	//	Physics
	if( owner.IsPlayer() ) {
		owner.kv.airSpeed = owner.GetPlayerSettingsField( "airSpeed" )
		owner.kv.airAcceleration = owner.GetPlayerSettingsField( "airAcceleration" )
		owner.kv.gravity = owner.GetPlayerSettingsField( "gravityScale" )

		owner.SetGroundFrictionScale( 1. )
	}

	//	Hitboxes
	foreach( thruster in weapon.s.thrusters ) {
		if( IsValid(thruster) ) {
			print( "[TAEsArmory] Destroying thruster " + thruster )
			thruster.Destroy()
		}
	}

	//	FX
	foreach( fx in weapon.s.thrusterFX ) {
		if( IsValid(fx) ) {
			print( "[TAEsArmory] Destroying fx " + fx )
			fx.Destroy()
		}
	}

	//	SFX
	StopSoundOnEntity( owner, "titan_flight_hover_1p" )
	StopSoundOnEntity( owner, "titan_flight_hover_3p" )
}

//	Signaling
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

//	Management thread
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

	//	Math
	int maxAmmo = flightWeapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )

	float dischargeRate = -(maxAmmo / FLIGHT_DRAIN_TIME)
	float chargeRate = maxAmmo / FLIGHT_REGEN_TIME

	//	Loop
	thread FlightStartListener( owner, flightWeapon )
	thread FlightStopListener( owner, flightWeapon )
	thread FlightBreakListener( owner, flightWeapon )

	float prevTime = Time()
	float changeStack = 0
	while(1) {
		WaitFrame()

//		print("[TAEsArmory] FlightSystem: changeRate = " + flightWeapon.s.changeRate)

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

		//	Retrieve changeRate
		float changeRate = expect float( flightWeapon.s.changeRate )

		//	Flight/landing handling (flight only when discharging)
		bool shouldFly = changeRate < 0.
		if( shouldFly ) {
			vector origin = owner.GetOrigin()
			vector offsetOrigin = origin + <0, 0, -5000>

			TraceResults result = TraceLine( origin, offsetOrigin, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

			float targetAlt = flightWeapon.GetWeaponSettingFloat( eWeaponVar.damage_near_distance )
			float targetVel = flightWeapon.GetWeaponSettingFloat( eWeaponVar.damage_far_distance )

			float altOffset = ( origin.z - (result.endPos.z + targetAlt) )
			float zVel = GraphCapped( altOffset, -targetAlt, targetAlt, targetVel, -targetVel )

			print("[TAEsArmory] FlightSystem: altOffset = " + altOffset)
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

			//print("[TAEsArmory] FlightSystem: altOffset = " + altOffset)
			//print("[TAEsArmory] FlightSystem: zVel = " + zVel)
		}

		//	Ammo math
		bool isAfterburn = flightWeapon.HasMod("TArmory_Flight_RiseHelper") || flightWeapon.HasMod("TArmory_Flight_DiveHelper")
		changeStack += ( Time() - prevTime ) * ( isAfterburn ? 0. : changeRate )

		int newAmmoCount = flightWeapon.GetWeaponPrimaryClipCount() + changeStack.tointeger()
		newAmmoCount = minint( maxint( newAmmoCount, 0 ), maxAmmo )
		flightWeapon.SetWeaponPrimaryClipCount( newAmmoCount )

		changeStack -= float( changeStack.tointeger() )

		prevTime = Time()
	}
}

//		      :::    ::: ::::::::::: ::::::::::: :::::::::   ::::::::  :::    ::: :::::::::: ::::::::
//		     :+:    :+:     :+:         :+:     :+:    :+: :+:    :+: :+:    :+: :+:       :+:    :+:
//		    +:+    +:+     +:+         +:+     +:+    +:+ +:+    +:+  +:+  +:+  +:+       +:+
//		   +#++:++#++     +#+         +#+     +#++:++#+  +#+    +:+   +#++:+   +#++:++#  +#++:++#++
//		  +#+    +#+     +#+         +#+     +#+    +#+ +#+    +#+  +#+  +#+  +#+              +#+
//		 #+#    #+#     #+#         #+#     #+#    #+# #+#    #+# #+#    #+# #+#       #+#    #+#
//		###    ### ###########     ###     #########   ########  ###    ### ########## ########

void function ThrusterThink( entity owner, entity weapon ) {
	if( !("thrusters" in weapon.s) ) {
		weapon.s.thrusters <- []
	} else { weapon.s.thrusters = [] }

	array<string> attachPoints = [
		"FX_L_TOP_THRUST", "FX_R_TOP_THRUST",
		"FX_L_BOT_THRUST", "FX_R_BOT_THRUST"
	]

	//	Create thruster hitboxes
	print("[TAEsArmory] ThrusterThink: Creating thrusters")
	foreach( attachment in attachPoints ) {
		//	Get placement data
		int attachId = owner.LookupAttachment( attachment )
		vector origin = owner.GetAttachmentOrigin( attachId )
		vector angles = AnglesCompose( owner.GetAttachmentAngles( attachId ), < 0., 0., 90. > )

		//	Create ent
		entity thruster = CreatePropScript( THRUSTER_HITBOX, origin, angles, SOLID_VPHYSICS )
		thruster.SetParent( owner, attachment )
		thruster.SetOwner( weapon )
		SetTeam( thruster, owner.GetTeam() )

		thruster.s.attachment <- attachment
		thruster.s.thrusterBase <- weapon

		//	Manage thruster health
		thruster.SetMaxHealth( THRUSTER_MAX_HEALTH )
		thruster.SetHealth( THRUSTER_MAX_HEALTH )

		thruster.SetTakeDamageType( DAMAGE_YES )
		thruster.SetArmorType( ARMOR_TYPE_HEAVY )

		thruster.SetDamageNotifications( true )
		thruster.SetDeathNotifications( true )
		AddEntityCallback_OnDamaged( thruster, OnThrusterDamaged )
		AddEntityCallback_OnKilled( thruster, OnThrusterKilled )

		//	Collision stuff
		thruster.kv.collisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS

		//	Properties
		SetVisibleEntitiesInConeQueriableEnabled( thruster, true )
		thruster.EnableAttackableByAI( 10000, 0, AI_AP_FLAG_NONE )	//	int priority, int extraPriority, int extraPriorityFlags

		//	Visibility
		//thruster.Hide()

		//	Register
		weapon.s.thrusters.append(thruster)
	}

	foreach( thruster in weapon.s.thrusters ) {
		thruster.EndSignal( "OnDeath" )
	}

	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TitanEjectionStarted" )

	owner.EndSignal( "StopFlight" )

	OnThreadEnd( function() : ( weapon ) {
		print("[TAEsArmory] ThrusterThink: Destroying thrusters")
		foreach( thruster in weapon.s.thrusters ) {
			if( IsValid(thruster) ) {
				print( "[TAEsArmory] Destroying thruster " + thruster )
				thruster.Destroy()
			}
		}
	})

	WaitForever()
}

void function OnThrusterDamaged( entity thruster, var damageInfo ) {
	print("[TAEsArmory] OnThrusterDamaged: Recorded a damage event (dmg = "
		+ DamageInfo_GetDamage( damageInfo ) + ", hp = " + thruster.GetHealth() + ")")

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	int attackerTeam = attacker.GetTeam()

	if( thruster.GetTeam() != attackerTeam ) {
		//	Build damage table
		local dmgTable = {
			scriptType = DamageInfo_GetDamageFlags( damageInfo ),
			damageSourceId = DamageInfo_GetCustomDamageType( damageInfo ),

			origin = DamageInfo_GetDamagePosition( damageInfo ),
			hitbox = DamageInfo_GetHitBox( damageInfo ),
			force = Vector(0, 0, 0),

			weapon = DamageInfo_GetWeapon( damageInfo )
		}

		float damage = DamageInfo_GetDamage( damageInfo )
		entity inflictor  = DamageInfo_GetInflictor( damageInfo )

		int health = thruster.GetHealth()

		//	Check if health below 0
		if( health <= 0 ) {
			OnThrusterKilled( thruster, damageInfo )
		}

		//	Transfer damage to other thrusters
		foreach( other in thruster.s.thrusterBase.s.thrusters ) {
			if( IsValid(other) )
				other.SetHealth( health )
		}

		//	Transfer damage to owner
		entity owner = thruster.GetParent()
		owner.TakeDamage( damage * PLAYER_DMG_RATIO, attacker, inflictor, dmgTable )

		//	Notify attacker
		if( attacker.IsPlayer() ) {
			attacker.NotifyDidDamage( owner,
				DamageInfo_GetHitBox( damageInfo ),
				DamageInfo_GetDamagePosition( damageInfo ),
				DamageInfo_GetCustomDamageType( damageInfo ),
				DamageInfo_GetDamage( damageInfo ),
				DamageInfo_GetDamageFlags( damageInfo ),
				DamageInfo_GetHitGroup( damageInfo ),
				DamageInfo_GetWeapon( damageInfo ),
				DamageInfo_GetDistFromAttackOrigin( damageInfo )
			)
		}
	}
}

void function OnThrusterKilled( entity thruster, var damageInfo ) {
	print("[TAEsArmory] OnThrusterKilled: Called")

	//	Get others
	entity owner = thruster.GetParent()

	print(owner)

	entity weapon = thruster.GetOwner()

	//	Attachment math
	string attachment = expect string( thruster.s.attachment )
	int attachId = owner.LookupAttachment( attachment )

	vector attachOrigin = owner.GetAttachmentOrigin( attachId )
	vector attachAngles = owner.GetAttachmentAngles( attachId )

	//	Explosion (S)FX
	int team = owner.GetTeam()
	PlayFXOnEntity( THRUSTER_EXP_FX, owner, attachment, null, attachAngles )
	EmitSoundAtPosition( team, attachOrigin, THRUSTER_EXP_SFX )

	//	Flameout FX
	foreach( other in weapon.s.thrusters ) {
		//	Get attachment data
		string otherAttachment = expect string( other.s.attachment )
		int otherAttachId = owner.LookupAttachment( otherAttachment )
		vector otherAttachAngles = owner.GetAttachmentAngles( otherAttachId )

		//	Destroy
		if( IsValid(other) ) {
			print( "[TAEsArmory] Destroying thruster " + thruster )
			other.Destroy()
		}

		//	Skip if this is the exploded thruster
		if( other == thruster )
			continue

		//	Play FX (data still exists)
		PlayFXOnEntity( THRUSTER_FLAMEOUT_FX, owner, otherAttachment, null, attachAngles )
	}

	//	Damage
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity inflictor = DamageInfo_GetInflictor( damageInfo )

	int damageSourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )

	RadiusDamage(
		attachOrigin,										//	center
		attacker,											//	attacker
		inflictor,											//	inflictor
		THRUSTER_EXP_DAMAGE_HUMAN,							//	damage
		THRUSTER_EXP_DAMAGE_TITAN,							//	damageHeavyArmor
		THRUSTER_EXP_INNER_RADIUS,							//	innerRadius
		THRUSTER_EXP_OUTER_RADIUS,							//	outerRadius
		0,													//	flags
		0,													//	distanceFromAttacker
		THRUSTER_EXP_FORCE,									//	explosionForce
		DF_EXPLOSION | DF_BYPASS_SHIELD | DF_KNOCK_BACK,	//	scriptDamageFlags
		damageSourceId 										//	scriptDamageSourceIdentifier
	)

	//	Break flight
	weapon.s.breakFlight = true
}

void function DestroyThrusters( entity flightWeapon ) {
	print("[TAEsArmory] DestroyThrusters: Called")
	if( IsValid(flightWeapon) ) {
		if( !("thrusters" in flightWeapon.s) ) return

		foreach( thruster in flightWeapon.s.thrusters ) {
			print("[TAEsArmory] DestroyThrusters: Destroying thruster")
			if( IsValid(thruster) ) {
				print( "[TAEsArmory] Destroying thruster " + thruster )
				thruster.Destroy()
			}
		}
	}
}





#endif
