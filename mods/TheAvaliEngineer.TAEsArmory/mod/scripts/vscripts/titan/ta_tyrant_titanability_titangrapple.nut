untyped

//		Function declarations
global function TArmory_Init_BruiserScorch_TitanGrapple
global function OnWeaponOwnerChanged_BruiserScorch_TitanGrapple

global function OnWeaponAttemptOffhandSwitch_BruiserScorch_TitanGrapple

global function OnWeaponChargeBegin_BruiserScorch_TitanGrapple
global function OnWeaponPrimaryAttack_BruiserScorch_TitanGrapple
#if SERVER
global function OnWeaponNpcPrimaryAttack_BruiserScorch_TitanGrapple
#endif

global function OnProjectileCollision_BruiserScorch_TitanGrapple

//		Data
//	Struct def
struct {
	int count = 0

	int frame = 0
	string debugOut = ""

	//	Ownership
	array<entity> owner
	array<entity> weapon

	array< array<int> > ownerStatusIds

	//	Hooked entity
	array<entity> anchor

	array<bool> hasTarget
	array<entity> target

	array< array<int> > targetStatusIds

	array<float> attachTime
	array<float> pullDelay

	//	Damage
	array<bool> isTazer
	array<int> tazerDmg

	//	Timekeeping
	array<float> startTime
	array<float> duration

	float dmgTick = 0.2

	//	Rope config
	array<bool> ropeInit

	array<bool> ropesNeedUpdate
	array< array<entity> > ropeParents

	array<entity> startParent
	array<entity> endParent

	array<entity> ropeStart1p
	array<entity> ropeStart3p

	//	Other
	array<bool> shouldDestroy
} ecs

//	Rope FX data
const float ROPE_MOVESPEED = 32
const int ROPE_SUBDIVISIONS = 2
const int ROPE_SLACK = 0

const int ROPE_WIDTH = 4
const float ROPE_TEXURE_SCALE = 1.0
const string ROPE_MATERIAL = "cable/cable.vmt"

//	Status effects
const float SLOWTURN_STRENGTH_OWNER = 0.25
const float SLOWMOVE_STRENGTH_OWNER = 0.25

const float SLOWTURN_STRENGTH_TARGET = 0.1
const float SLOWMOVE_STRENGTH_TARGET = 0.1
const float STATUS_SLOW_FADETIME = 0.5

const float STATUS_TETHERED_STRENGTH = 1.0

const float STATUS_EMP_STRENGTH = 0.5
const float STATUS_EMP_FADETIME = 0.5

//	Pull data
const float PULL_RANGE_MIN = 150.0
const float PULL_RANGE_MAX = 8000.0

const float PULL_FORCE_MIN = 300.0
const float PULL_FORCE_MAX = 900.0

const float PULL_FORCE_Z = 220.0

const float PULL_SLOW_MIN = 0.2
const float PULL_SLOW_MAX = 1.0

const float PULL_DELAY = 0.5

//	FX assets
const asset TETHER_ROPE_MODEL = $"cable/tether.vmt"
const asset TETHER_3P_MODEL = $"models/weapons/caber_shot/caber_shot_thrown_xl.mdl"
const asset TETHER_1P_MODEL = $"models/weapons/caber_shot/caber_shot_tether_xl.mdl"

const asset TETHER_HOOK_MODEL = $"models/industrial/grappling_hook_end.mdl"

//		Functions
//	Init
void function TArmory_Init_BruiserScorch_TitanGrapple() {
	//	FX precache
	PrecacheMaterial( TETHER_ROPE_MODEL )
	PrecacheModel( TETHER_ROPE_MODEL )
	PrecacheModel( TETHER_HOOK_MODEL )

	//	Weapon precache
	PrecacheWeapon( "ta_tyrant_titanability_titangrapple" )

	#if SERVER
	//	Custom eDamageSourceId
	table<string, string> customDamageSourceIds = {
		ta_tyrant_titanability_titangrapple = "Heavy Grapple",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )

	//	ECS
	thread ECS_MainSystem()
	#endif
}

void function OnWeaponOwnerChanged_BruiserScorch_TitanGrapple( entity weapon, WeaponOwnerChangedParams changeParams ) {
	if( !("initialized" in weapon.s) ) {
		weapon.s.lastFireTime <- 0
		weapon.s.hadChargeWhenFired <- false

		#if CLIENT
		weapon.s.lastUseTime <- 0
		#endif

		weapon.s.initialized <- true
	}
}

bool function OnWeaponAttemptOffhandSwitch_BruiserScorch_TitanGrapple( entity weapon ) {
	//	Validity checks
	//	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid(owner) )
		return false

	if( ecs.owner.contains(owner) ) {
		return false
	}

	return true
}

//	Activation (starting grapple)
bool function OnWeaponChargeBegin_BruiserScorch_TitanGrapple( entity weapon ) {
	//	Validity checks
	//	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid(owner) )
		return false

	bool canActivate = ApplyActivationCost( weapon, 0.05 )
	if( canActivate ) {
		bool ownerIsPlayer = owner.IsPlayer()
		if( ownerIsPlayer ) {
			PlayerUsedOffhand( owner, weapon )
		}

		//	Get pos + dir + speed
		WeaponPrimaryAttackParams attackParams
		attackParams.pos = owner.EyePosition() //vector( owner.GetCameraPosition() ) //owner.GetAttackPosition() //weapon.GetAttachmentOrigin( attachIdx )
		attackParams.dir = owner.GetPlayerOrNPCViewVector() //vector( owner.GetAttackDirection() )

		LaunchTitanGrapple( weapon, attackParams, ownerIsPlayer )
	} else {
		//weapon.s.hadChargeWhenFired = false
	}

	#if CLIENT
	//weapon.s.lastUseTime = Time()
	#endif

	return canActivate
}

bool function ApplyActivationCost( entity weapon, float frac ) {
	float fracLeft = weapon.GetWeaponChargeFraction()
	bool canActivate = fracLeft + frac < 1.0

	if( canActivate ) {
		weapon.SetWeaponChargeFraction( fracLeft + frac )
	} else {
		weapon.ForceRelease()
		weapon.SetWeaponChargeFraction( 1.0 )
	}

	return canActivate
}

void function LaunchTitanGrapple( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Validity checks
	//	Owner validity check
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid(owner) )
		return

	//	Test for projectile creation
	bool shouldCreateProjectiles = false
	if( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectiles = true
	#if CLIENT
		if( !playerFired )
			shouldCreateProjectiles = false
	#endif

	//	Fire projectile
	if( shouldCreateProjectiles ) {
		float speed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )

		vector vel = attackParams.dir * speed
		vector angVel = <0, 0, 0> //RandomFloatRange( -180.0, 180.0 )>
		entity projectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angVel, 0.0, 0, 0, playerFired, PROJECTILE_LAG_COMPENSATED, false )
		if( projectile ) {
			#if SERVER
			SetTeam( projectile, weapon.GetTeam() )
			projectile.SetAbsAngles( AnglesCompose( attackParams.dir, < -90.0, 0.0, 0.0> ) )

			//	Attach data to projectile
			ECS_CreateEnt( owner, weapon, projectile )
			#endif
		}
	}

	#if SERVER
	//	SFX
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "Wpn_TetherTrap_Deploy_1P" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "Wpn_TetherTrap_Deploy_3P" )
	#endif
}


//	Attack handling (ending grapple)
var function OnWeaponPrimaryAttack_BruiserScorch_TitanGrapple( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//return EndTitanGrapple( weapon, attackParams, true )
	return 0
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_BruiserScorch_TitanGrapple( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//return EndTitanGrapple( weapon, attackParams, false )
	return 0
}
#endif

int function EndTitanGrapple( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	return 1 //weapon.GetAmmoPerShot()
}


//	Collision handling
void function OnProjectileCollision_BruiserScorch_TitanGrapple( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
	//	Validity checks
	//	Owner validity check
	entity owner = projectile.GetOwner()
	if ( !IsValid(owner) )
		return

	entity weapon = owner.GetOffhandWeapon(1)

	//	Hit entity alive check
	if( !IsAlive(hitEnt) )
		return

	//	Only target titans & reapers
	if( hitEnt.IsTitan() || IsSuperSpectre(hitEnt) ) {
		//	Plant projectile on enemy
		bool result = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
		if( result ) {
			#if SERVER
			projectile.SetHealth( 1000 )

			//	Normal angle shenanigans
			projectile.proj.savedAngles = normal
			projectile.SetAbsAngles( AnglesCompose( normal, < -90.0, 0.0, 0.0> ) )
			#endif

			print("[TAEsArmory] OnProjectileCollision_BS_TG: frame = " + ecs.frame)

			return
		}
	}

	projectile.GrenadeIgnite()
}

#if SERVER
// ============== ECS VERSION ==============
void function ECS_MainSystem() {
	while(1) {
		ecs.debugOut = ""

		ECS_InitSystem()
		ECS_RopeSystem()
		ECS_AttachSystem()
		ECS_PullSystem()
		ECS_KillSystem()

		if( ecs.debugOut.len() > 0 ) {
			print("\n\n[TAEsArmory] ECS_MainSystem frame " + ecs.frame + " output:" + ecs.debugOut + "\n\t")
		}

		WaitFrame()
		ecs.frame ++
	}
}

void function ECS_InitSystem() {
	string debugOut = ""

	int startIdx = ecs.count - 1
	for( int i = startIdx; i >= 0; i-- ) {
		//	Skip ents marked for deletion
		if( ecs.shouldDestroy[i] )
			continue

		//	MFD step
		if( !IsValid(ecs.weapon[i]) ) {
			debugOut += "\n\tECS_InitSystem: Weapon invalid"
			ecs.shouldDestroy[i] = true
			continue
		}

		if( !IsValid(ecs.anchor[i]) ) {
			debugOut += "\n\tECS_InitSystem: Anchor invalid"
			ecs.shouldDestroy[i] = true
			continue
		}

		//	Make ropes & configure visibility, skipping already-init ents
		if( !ecs.ropeInit[i] ) {
			/*
			array<entity> initParents = MakeRopeStartEnd( ecs.weapon[i], ecs.anchor[i] )
			ecs.ropeParents[i].extend( initParents )

			SetTargetName( initParents[0], UniqueString( "rope_startpoint" ) )
			SetTargetName( initParents[1], UniqueString( "rope_endpoint" ) )

			ECS_UpdateRopes()
			// */

			//*
			array<entity> parents = MakeRopeStartEnd( ecs.weapon[i], ecs.anchor[i] )

			if( parents.len() != 2 ) {
				debugOut += "\n\tECS_InitSystem: Error occured when creating start/end ents"
				ecs.shouldDestroy[i] = true
				continue
			}

			ecs.startParent[i] = parents[0]
			ecs.endParent[i] = parents[1]

			entity rope1p = MakeRope( parents[0], parents[1] )
			entity rope3p = MakeRope( parents[0], parents[1] )

			SetForceDrawWhileParented( rope1p, true )
			SetForceDrawWhileParented( rope3p, true )
			rope1p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_ONLY_PARENT_PLAYER
			rope3p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER

			ecs.ropeStart1p[i] = rope1p
			ecs.ropeStart3p[i] = rope3p
			//*/

			ecs.ropeInit[i] = true
		}
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_InitSystem: Started init check" + debugOut : ""
}

void function ECS_RopeSystem() {
	//	Add new points if obstructed
	string debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip bad ents
		if( ecs.shouldDestroy[i] ) continue

		/*
		//	MFD if rope has no endpoint
		if( ecs.ropeParents[i].len() < 2 ) {
			debugOut += "\n\t\tEnt MFD check: No endpoint"
			ecs.shouldDestroy[i] = true
			continue
		}

		int checkIdx = 0
		array<entity> checkQueue = [ null, ecs.ropeParents[i][0] ]
		while( 1 ) {
			//	At end of rope
			if( checkIdx == ecs.ropeParents[i].len() - 2 )
				break

			//	Get and validify next parent
			entity nextParent = ecs.ropeParents[i][checkIdx + 2]
			if( !IsValid(nextParent) ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Invalid nextRope"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Advance queue
			checkQueue.append( nextParent )
			checkQueue.remove( 0 )
			checkIdx ++

			//	Get & validify parents
			entity startParent = checkQueue[0]

			ecs.shouldDestroy[i] = ecs.shouldDestroy[i] || !IsValid(startParent) || !IsValid(nextParent)
			if( ecs.shouldDestroy[i] ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Start or end parent invalid"
				continue
			}

			//	Trace
			vector startPos = startParent.GetOrigin()
			vector endPos = nextParent.GetOrigin()

			array<entity> ignoreEnts = [ ecs.owner[i], ecs.anchor[i] ]
			if( ecs.hasTarget[i] ) { ignoreEnts.append(ecs.target[i]) }

			TraceResults trace = TraceLine( endPos, startPos, ignoreEnts, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
			if( trace.fraction < 1 && trace.hitEnt.IsWorld() ) {
				float dist = Distance( startPos, trace.endPos )
				if( dist < 1.0 ) {
					debugOut += "\n\t\tPoint creation: Skipping - too close (dist = " + dist + ")"
					continue
				}

				entity pointEnt = CreateExpensiveScriptMover( trace.endPos, trace.surfaceNormal )
				SetTargetName( pointEnt, UniqueString( "rope_midpoint" ) )
				SetForceDrawWhileParented( pointEnt, true )

				ecs.ropeParents[i].insert( checkIdx + 1, pointEnt )
				ecs.ropesNeedUpdate[i] = true
			}
		}
		// */

		//*
		//	MFD if rope has no endpoint
		int ropeSize = RopeSize( ecs.ropeStart1p[i] )
		if( ropeSize < 2 ) {
			debugOut += "\n\t\tEnt MFD check: No endpoint"
			ecs.shouldDestroy[i] = true
			continue
		}

		int checkIdx = -1
		array<entity> checkQueue = [ null, ecs.ropeStart1p[i] ]
		while( 1 ) {
			//	At end of rope
			if( !("nextRope" in checkQueue[1].s) )
				break

			//	Get & validify next AddRopePoint
			entity nextRope = expect entity( checkQueue[1].s.nextRope )
			if( !IsValid(nextRope) ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Invalid nextRope"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Advance queue
			checkQueue.append( nextRope )
			checkQueue.remove( 0 )
			checkIdx ++

			//	Get & validify parents
			entity startParent = checkQueue[0].GetParent()
			entity endParent = checkQueue[1].GetParent()

			ecs.shouldDestroy[i] = ecs.shouldDestroy[i] || !IsValid(startParent) || !IsValid(endParent)
			if( ecs.shouldDestroy[i] ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Start or end parent invalid"
				continue
			}

			//	Skip too-close things
			vector startPos = startParent.GetOrigin()
			vector endPos = endParent.GetOrigin()

			//	Trace
			array<entity> ignoreEnts = [ ecs.owner[i], ecs.anchor[i] ]
			if( ecs.hasTarget[i] ) { ignoreEnts.append(ecs.target[i]) }

			TraceResults trace = TraceLine( endPos, startPos, ignoreEnts, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )	//TraceLineNoEnts( startPos, endPos )
			if( trace.fraction < 1 && trace.hitEnt.IsWorld() ) {
				float dist = Distance( startPos, trace.endPos )
				if( dist < 1.0 ) {
					debugOut += "\n\t\tPoint creation: Skipping - too close (dist = " + dist + ")"
					continue
				}

				entity pointEnt = CreateExpensiveScriptMover( trace.endPos, trace.surfaceNormal )
				SetForceDrawWhileParented( pointEnt, true )

				entity point1p = AddRopePoint( ecs.ropeStart1p[i], pointEnt, checkIdx )
				entity point3p = AddRopePoint( ecs.ropeStart3p[i], pointEnt, checkIdx )

				SetForceDrawWhileParented( point1p, true )
				SetForceDrawWhileParented( point3p, true )
				point1p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_ONLY_PARENT_PLAYER
				point3p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER

				debugOut += "\n\t\tSuccessfully created point! (checkIdx = " + checkIdx + ")"
			}
		}
		// */
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_RopeSystem: Starting path obstruction step" + debugOut : ""

	//	Delete points if there's slack
	debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip bad ents
		if( ecs.shouldDestroy[i] ) continue

		/*
		//	Skip if the rope has no extra points
		if( ecs.ropeParents[i].len() < 3 )
			continue

		//	Loop
		int checkIdx = -2
		array<entity> checkQueue = [ null, null, ecs.ropeParents[i][0] ]
		while( checkIdx < ecs.ropeParents[i].len() - 1 ) {
			//	At end of rope
			if( checkIdx == ecs.ropeParents[i].len() - 1 )
				break

			//	Get and validify next
			entity nextParent = ecs.ropeParents[i][checkIdx + 2]
			if( !IsValid(nextParent) ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Invalid nextRope"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Advance queue
			checkQueue.append( nextParent )
			checkQueue.remove( 0 )
			checkIdx ++

			//	Skip if negative index (not finished building checkQueue)
			if( checkIdx < 0 )
				continue

			//	Get vectors
			vector normal = checkQueue[1].GetAngles()
			vector cross = CrossProduct(
				checkQueue[0].GetOrigin() - checkQueue[1].GetOrigin(),
				checkQueue[2].GetOrigin() - checkQueue[1].GetOrigin()
			)

			//	Calculate "z" sign
			float normalDot = DotProduct( normal, <0, 0, 1> )
			float crossDot = DotProduct( cross, <0, 0, 1> )

			float num = (crossDot == 0) ? DotProduct( cross, <1, 0, 0> ) : crossDot
			num *= (normalDot == 0) ? 1. : normalDot

			/*  	Remove if positive (concave) or 0 (linear)
			 * idx from i     | i - 2 | i - 1 |  i  |
			 * searchEnts idx |   0   |   1   |  2  |
			 * name           | start |  mid  | end |
			 * ropeKeys idx   |       |   0   |  1  |
			 * /
			if( num > 0 ) {
				//	Shift linked list & destroy ropes + parent
				DestroyRopeParent( ecs.ropeParents[i][checkIdx] )
				ecs.ropeParents[i].remove(checkIdx)
				ecs.ropesNeedUpdate[i] = true

				//	Advance queue & repeat check
				checkQueue.append( nextParent )
				checkQueue.remove( 1 )

				continue
			}
		} // */

		//*
		//	Skip if the rope has no extra points
		int ropeSize = RopeSize( ecs.ropeStart1p[i] )
		if( ropeSize < 3 )
			continue

		int checkIdx = -2
		array<entity> checkQueue = [ null, null, ecs.ropeStart1p[i] ]
		while( checkIdx < ropeSize - 1 ) {
			//	At end of rope
			if( !("nextRope" in checkQueue[2].s) )
				break

			//	Get & validify next
			entity nextRope = expect entity( checkQueue[2].s.nextRope )
			if( !IsValid(nextRope) ) {
				debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Invalid nextRope"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Advance queue
			checkQueue.append( nextRope )
			checkQueue.remove( 0 )
			checkIdx ++

			//	Skip if negative index (not finished building checkQueue)
			if( checkIdx < 0 )
				continue

			//	Get vectors
			vector normal = checkQueue[1].GetAngles()
			vector cross = CrossProduct(
				checkQueue[0].GetOrigin() - checkQueue[1].GetOrigin(),
				checkQueue[2].GetOrigin() - checkQueue[1].GetOrigin()
			)

			//	Calculate "z" sign
			float normalDot = DotProduct( normal, <0, 0, 1> )
			float crossDot = DotProduct( cross, <0, 0, 1> )

			float num = (crossDot == 0) ? DotProduct( cross, <1, 0, 0> ) : crossDot
			num *= (normalDot == 0) ? 1. : normalDot

			/*  	Remove if positive (concave) or 0 (linear)
			 * idx from i     | i - 2 | i - 1 |  i  |
			 * searchEnts idx |   0   |   1   |  2  |
			 * name           | start |  mid  | end |
			 * ropeKeys idx   |       |   0   |  1  |
			 */
			if( num > 0 ) {
				//	Shift linked list & destroy ropes + parent
				debugOut += RemoveRopeKeyframe( ecs.ropeStart1p[i], checkIdx + 1 )
				debugOut += RemoveRopeKeyframe( ecs.ropeStart3p[i], checkIdx + 1 )

				if( IsValid(checkQueue[1].GetParent()) )
					checkQueue[1].GetParent().Destroy()

				//	Get & validify next
				if( !("nextRope" in checkQueue[2].s) )
					break

				nextRope = expect entity( checkQueue[2].s.nextRope )
				if( !IsValid(nextRope) ) {
					debugOut += "\n\t\tQueue (checkIdx = " + checkIdx + "): Cannot advance, invalid nextRope"
					ecs.shouldDestroy[i] = true
					continue
				}

				//	Advance queue & repeat check
				checkQueue.append( nextRope )
				checkQueue.remove( 1 )
				ropeSize --

				continue
			}
		} 	//*/
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_RopeSystem: Starting slack removal step" + debugOut : ""
}

void function ECS_AttachSystem() {
	string debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip ents w/ target
		if( ecs.hasTarget[i] )
			continue

		//	Skip if !isPlanted (the var used by Respawn to indicate it's attached to something)
		entity anchor = ecs.anchor[i]
		if( anchor.proj.isPlanted ) {
			//	MFD step
			if( !IsValid(anchor.GetParent()) ) {
				debugOut += "\n\t\tECS_InitSystem: Planted on invalid parent"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Target
			ecs.target[i] = anchor.GetParent()
			ecs.hasTarget[i] = true

			//	Visuals
//			ecs.endParent[i].SetParent( ecs.target[i] )
//			ecs.endParent[i].SetOrigin( anchor.GetOrigin() )
//			ecs.endParent[i].SetAngles( anchor.GetAngles() )

//			anchor.SetParent( ecs.startParent[i] )
//			anchor.SetOrigin( ecs.startParent[i].GetOrigin() )
//			anchor.SetAngles( ecs.startParent[i].GetAngles() )

			ecs.endParent[i].SetModel( TETHER_HOOK_MODEL )
			anchor.SetModel( $"models/dev/empty_model.mdl" )

			//	Timekeeping
			ecs.attachTime[i] = Time()

			//	Get effect data (b/c weapon mods)
			float slowFade = STATUS_SLOW_FADETIME

			float empStr = STATUS_EMP_STRENGTH
			float empFade = STATUS_EMP_FADETIME

			float duration = ecs.duration[i]

			//	Apply effects
			entity owner = ecs.owner[i].GetTitanSoul()
			entity target = HasSoul( ecs.target[i] ) ? ecs.target[i].GetTitanSoul() : ecs.target[i]

			ecs.ownerStatusIds[i].append( StatusEffect_AddTimed( owner, eStatusEffect.turn_slow, SLOWTURN_STRENGTH_OWNER, duration, slowFade ) )
			ecs.ownerStatusIds[i].append( StatusEffect_AddTimed( owner, eStatusEffect.move_slow, SLOWMOVE_STRENGTH_OWNER, duration, slowFade ) )

			ecs.targetStatusIds[i].append( StatusEffect_AddTimed( ecs.target[i], eStatusEffect.turn_slow, SLOWTURN_STRENGTH_TARGET, duration, 0. ) )
			ecs.targetStatusIds[i].append( StatusEffect_AddTimed( ecs.target[i], eStatusEffect.move_slow, SLOWMOVE_STRENGTH_TARGET, duration, 0. ) )

			ecs.targetStatusIds[i].append( StatusEffect_AddTimed( ecs.target[i], eStatusEffect.tethered, STATUS_TETHERED_STRENGTH, duration, 0. ) )
			if( ecs.isTazer[i] ) {
				ecs.targetStatusIds[i].append( StatusEffect_AddTimed( ecs.target[i], eStatusEffect.emp, empStr, duration, empFade ) )
			}

			//	Stop owner from dashing
			if( ecs.owner[i].IsPlayer() ) {
				ecs.owner[i].Server_TurnDodgeDisabledOn()
			}

			//	SFX
			if ( ecs.owner[i].IsPlayer() ) {
				//	Twice so it's louder
				EmitSoundOnEntityOnlyToPlayer( ecs.owner[i], ecs.owner[i], "Wpn_TetherTrap_PopOpen_3p" )
				EmitSoundOnEntityOnlyToPlayer( ecs.owner[i], ecs.owner[i], "Wpn_TetherTrap_PopOpen_3p" )
			}
		}
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_AttachSystem: Starting attach check step" + debugOut : ""

	//ECS_UpdateRopes()
}

void function ECS_PullSystem() {
	//	Mark ents with invalid or dead targets for deletion & skip
	string debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip MFD ents / ents w/o a target
		if( ecs.shouldDestroy[i] || !ecs.hasTarget[i] )
			continue

		if( !IsValid(ecs.target[i]) ) {
			debugOut += "\n\t\tInvalid target"
			ecs.shouldDestroy[i] = true
			continue
		}

		if( !IsAlive(ecs.target[i]) ) {
			debugOut += "\n\t\tDead target"
			ecs.shouldDestroy[i] = true
			continue
		}
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_PullSystem: Started MFD step" + debugOut : ""

	//	Remove reached ents
	debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip targetless ents & ents marked for deletion
		if( ecs.shouldDestroy[i] || !ecs.hasTarget[i] )
			continue

//		int ropeSize = ecs.ropeParents[i].len()
		int ropeSize = RopeSize( ecs.ropeStart1p[i] )
		/* 	Skip if pulling directly to attacker (& pulling doesn't stop once target is near enough)
		if( ropeSize < 3 ) {
			continue
		}
		// */

		/*
		//	Get second-to-last parent
		entity pullParent = ecs.ropeParents[i][ropeSize - 2]
		vector pullCenter = pullParent.GetOrigin()

		float dist = Distance( pullCenter, ecs.anchor[i].GetOrigin() )
		if( dist < PULL_RANGE_MIN ) {
			//*	MFD if pulling directly to attacker (& pulling stops once target is near)
			if( ropeSize < 3 ) {
				debugOut += "\n\t\tGrapple has fufilled its purpose, marking for deletion"
				ecs.shouldDestroy[i] = true
				continue
			}	//* /

			//	Remove rope key
			DestroyRopeParent( pullParent )
			ecs.ropeParents[i].remove(ropeSize - 2)
			ecs.ropesNeedUpdate[i] = true
		} //*/


		//*
		//	Get second-to-last parent
		entity pullRope = RopeAtIndex( ecs.ropeStart1p[i], -2 )
		vector pullCenter = pullRope.GetParent().GetOrigin()

		float dist = Distance( pullCenter, ecs.anchor[i].GetOrigin() )
		debugOut += "\n\t\tDistance between pullCenter & anchor = " + dist

		if( dist < PULL_RANGE_MIN ) {
			//	MFD if pulling directly to attacker (& pulling stops once target is near)
			if( ropeSize < 3 ) {
				debugOut += "\n\t\tGrapple has fufilled its purpose, marking for deletion"
				ecs.shouldDestroy[i] = true
				continue
			}

			//	Get parent
			entity pullParent = pullRope.GetParent()

			//	Remove keys
			debugOut += RemoveRopeKeyframe( ecs.ropeStart1p[i], -2 )
			debugOut += RemoveRopeKeyframe( ecs.ropeStart3p[i], -2 )

			//	Destroy parent
			if( IsValid(pullParent) )
				pullParent.Destroy()
		}	//*/
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_PullSystem: Started reached ent removal step" + debugOut : ""

	//	Apply force
	debugOut = ""
	for( int i = 0; i < ecs.count; i++ ) {
		//	Skip targetless ents & ents marked for deletion
		if( ecs.shouldDestroy[i] || !ecs.hasTarget[i] )
			continue

		//	Skip if pull hasn't started
		if( Time() - ecs.attachTime[i] < ecs.pullDelay[i] )
			continue

		//	Get data
		float totalDist =  RopeLength( ecs.ropeStart1p[i] )
		debugOut += "\n\t\ttotalDist = " + totalDist

		//entity pullParent = RecursiveRopeAtIndex( ecs.ropeStart1p[i], -2 ).GetParent()
		vector pullCenter = RopeAtIndex( ecs.ropeStart1p[i], -2 ).GetOrigin() //pullParent.GetOrigin()

		//	Calculate forces
		vector targetPos = ecs.target[i].GetOrigin()
		vector dir = Normalize( pullCenter - targetPos )

		float slowFrac = GraphCapped( totalDist, PULL_RANGE_MIN, PULL_RANGE_MAX, PULL_SLOW_MIN, PULL_SLOW_MAX )
		vector pullForce = dir * GraphCapped( totalDist, PULL_RANGE_MIN, PULL_RANGE_MAX, PULL_FORCE_MAX, PULL_FORCE_MIN  )
		pullForce.z = 0

		vector newVel = ecs.target[i].GetVelocity() * slowFrac + pullForce
		newVel.z = ecs.target[i].GetVelocity().z

		//	Apply
		ecs.target[i].SetVelocity( newVel )
	}
	ecs.debugOut += (debugOut.len() > 0) ? "\n\tECS_PullSystem: Started force application step" + debugOut : ""
}

void function ECS_KillSystem() {
	//	Timekeeping
	for( int i = 0; i < ecs.count; i++ ) {
		if( ecs.shouldDestroy[i] ) continue

		float speed = ecs.weapon[i].GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )
		float maxRange = ecs.weapon[i].GetWeaponSettingFloat( eWeaponVar.damage_far_distance )

		float flightEndTime = ecs.startTime[i] + maxRange / speed
		float totalEndTime = ecs.startTime[i] + ecs.duration[i]

		float endTime = (ecs.hasTarget[i]) ? totalEndTime : flightEndTime

		ecs.shouldDestroy[i] = ecs.shouldDestroy[i] || (Time() > endTime)
	}

	//	Handle ent deletion
	for( int i = 0; i < ecs.count; i++ ) {
		if( ecs.shouldDestroy[i] ) {
			ECS_RemoveEnt( i )
		}
	}
}

void function ECS_UpdateRopes() {
	//	For each grapple
	for( int i = 0; i < ecs.count; i++ ) {
		if( !ecs.ropesNeedUpdate[i] ) continue

		//	For each rope parent ent
		int maxIdx = ecs.ropeParents[i].len() - 1
		for( int j = 0; j < maxIdx; j++ ) {
			RopeBeams1p3p( ecs.owner[i], ecs.ropeParents[i][j], ecs.ropeParents[i][j + 1] )
		}
	}
}

void function ECS_CreateEnt( entity owner, entity weapon, entity anchor ) {
	int thisIndex = ecs.count

	//	Ownership
	ecs.owner.append( owner )
	ecs.weapon.append( weapon )

	ecs.ownerStatusIds.append([])

	//	Hooked ent
	ecs.anchor.append( anchor )

	ecs.hasTarget.append( false )
	ecs.target.append( null )

	ecs.targetStatusIds.append([])

	ecs.attachTime.append( 0 )
	ecs.pullDelay.append( PULL_DELAY )

	//	Damage
	ecs.isTazer.append( weapon.HasMod( "tarmory_electrified_grapple" ) )
	ecs.tazerDmg.append( weapon.GetWeaponSettingInt( eWeaponVar.explosion_damage ) )

	//	Timekeeping
	ecs.startTime.append( Time() )
	ecs.duration.append( weapon.GetWeaponSettingFloat( eWeaponVar.charge_time ) )

	//	Rope config
	ecs.ropeInit.append( false )

	ecs.ropesNeedUpdate.append( false )
	ecs.ropeParents.append( [] )

	ecs.startParent.append( null )
	ecs.endParent.append( null )

	ecs.ropeStart1p.append( null )
	ecs.ropeStart3p.append( null )

	//	Other
	ecs.shouldDestroy.append( false )

	//	Increment count
	ecs.count ++
}

void function ECS_RemoveEnt( int t ) {
	print("[TAEsArmory] ECS_RemoveEnt: Removing ECS entity #" + t)
	//	Remove status effects on owner
	if( IsValid(ecs.owner[t]) ) {
		foreach( status in ecs.ownerStatusIds[t] ) {
			StatusEffect_Stop( ecs.owner[t], status )
		}
		ecs.ownerStatusIds.remove(t)
	}

	if( ecs.owner[t].IsPlayer() ) {
		ecs.owner[t].Server_TurnDodgeDisabledOff()
	}

	ecs.owner.remove(t)

	//	Set weapon charge frac to 1
	if( IsValid(ecs.weapon[t]) ) {
		ecs.weapon[t].ForceRelease()
		ecs.weapon[t].SetWeaponChargeFraction( 1.0 )
	}
	ecs.weapon.remove(t)

	//	Hooked ent
	if( IsValid(ecs.anchor[t]) ) {
		if( !ecs.anchor[t].GrenadeHasIgnited() ) {
			ecs.anchor[t].GrenadeIgnite()
		}
	}
	ecs.anchor.remove(t)

	//	Remove status effects on target
	if( IsValid(ecs.target[t]) ) {
		foreach( status in ecs.targetStatusIds[t] ) {
			StatusEffect_Stop( ecs.target[t], status )
		}
		ecs.targetStatusIds.remove(t)
	}

	ecs.hasTarget.remove(t)
	ecs.target.remove(t)

	//	Damage
	ecs.isTazer.remove(t)
	ecs.tazerDmg.remove(t)

	//	Timekeeping
	ecs.startTime.remove(t)
	ecs.duration.remove(t)

	//	Rope config
	ecs.ropeInit.remove(t)

	if( IsValid(ecs.ropeStart1p[t]) )
		RecursiveRopeDestroy( ecs.ropeStart1p[t] )
	if( IsValid(ecs.ropeStart3p[t]) )
		RecursiveRopeDestroy( ecs.ropeStart3p[t] )

	ecs.startParent.remove(t)
	ecs.endParent.remove(t)

	ecs.ropeStart1p.remove(t)
	ecs.ropeStart3p.remove(t)

	ecs.ropesNeedUpdate.remove(t)
	foreach( toKill in ecs.ropeParents[t] ) { DestroyRopeParent( toKill ) }
	ecs.ropeParents.remove(t)

	//	Other
	ecs.shouldDestroy.remove(t)

	//	Deinc count
	ecs.count --
}

array<entity> function MakeRopeStartEnd( entity weapon, entity anchor ) {
	const string START_ATTACH = "muzzle_flash"
	const string END_ATTACH = "origin"

	//	Validity checks
	if( !IsValid(weapon) ) {
		print("[TAEsArmory] MakeRopeStartEnd: invalid wepaon")
		return []
	}

	if( !IsValid(anchor) ) {
		print("[TAEsArmory] MakeRopeStartEnd: invalid anchor projectile")
		return []
	}

	//	Create start ent
	int startAttachId = weapon.LookupAttachment( START_ATTACH )
	vector startAttachPos = weapon.GetAttachmentOrigin( startAttachId )

	entity startEnt = CreateExpensiveScriptMover( startAttachPos )
	startEnt.SetParent( weapon, START_ATTACH )
	SetForceDrawWhileParented( startEnt, true )

	//	Create end ent
	int endAttachId = anchor.LookupAttachment( END_ATTACH )
	vector endAttachPos = anchor.GetOrigin() //anchor.GetAttachmentOrigin( endAttachId )

	entity endEnt = CreateExpensiveScriptMover( endAttachPos )
	endEnt.SetParent( anchor ) //, END_ATTACH )
	SetForceDrawWhileParented( endEnt, true )

	//	Return
	return [ startEnt, endEnt ]
}

entity function MakeRope( entity startEnt, entity endEnt ) {
	string startName = UniqueString( "rope_startpoint" )
	string endName = UniqueString( "rope_endpoint" )

	//	Create start rope
	entity ropeStart = CreateEntity( "move_rope" )
	SetTargetName( ropeStart, startName )

	ropeStart.kv.NextKey = endName
	ropeStart.kv.MoveSpeed = ROPE_MOVESPEED

	ropeStart.kv.Slack = ROPE_SLACK
	ropeStart.kv.Subdiv = ROPE_SUBDIVISIONS
	ropeStart.kv.Width = ROPE_WIDTH

	ropeStart.kv.TextureScale = ROPE_TEXURE_SCALE
	ropeStart.kv.RopeMaterial = ROPE_MATERIAL
	ropeStart.kv.PositionInterpolator = 2

	ropeStart.kv.renderamt = 255
	ropeStart.kv.rendercolor = "255 255 255"

	ropeStart.SetOrigin( startEnt.GetOrigin() )
	ropeStart.SetAngles( startEnt.GetAngles() )
	ropeStart.SetParent( startEnt )

//	string endName = UniqueString( "rope_endpoint" )

	//	Create end rope
	entity ropeEnd = CreateEntity( "keyframe_rope" )
	SetTargetName( ropeEnd, endName )

	ropeEnd.kv.MoveSpeed = ROPE_MOVESPEED

	ropeEnd.kv.Slack = ROPE_SLACK
	ropeEnd.kv.Subdiv = ROPE_SUBDIVISIONS
	ropeEnd.kv.Width = ROPE_WIDTH

	ropeEnd.kv.TextureScale = ROPE_TEXURE_SCALE
	ropeEnd.kv.RopeMaterial = ROPE_MATERIAL
	ropeEnd.kv.PositionInterpolator = 2

	ropeEnd.kv.renderamt = 255
	ropeEnd.kv.rendercolor = "255 255 255"

	ropeEnd.SetOrigin( endEnt.GetOrigin() )
	ropeEnd.SetAngles( endEnt.GetAngles() )
	ropeEnd.SetParent( endEnt )

	//	Spawn ents
	DispatchSpawn( ropeStart )
	DispatchSpawn( ropeEnd )

	//	Set values in ropeStart & return
//	ropeStart.kv.NextKey = endName
	ropeStart.s.nextRope <- ropeEnd
	ropeEnd.s.parents <- [startEnt, endEnt]

	return ropeStart
}

entity function AddRopePoint( entity startRope, entity pointEnt, int index = -1 ) {
	//	Find prevRope & nextRope
	entity prevRope = RopeAtIndex( startRope, index )
	bool atEnd = (index == -1) || !("nextRope" in prevRope.s)

	/*
	if( index == 0 && atEnd ) {
		return "\n\t\tAddRopePoint: no endpoint"
	}
	// */

	//	Create rope at point
	string pointName = UniqueString( "rope_midpoint" )

	entity newRope = CreateEntity( "keyframe_rope" )
	SetTargetName( newRope, pointName )

	newRope.kv.MoveSpeed = ROPE_MOVESPEED

	newRope.kv.Slack = ROPE_SLACK
	newRope.kv.Subdiv = ROPE_SUBDIVISIONS
	newRope.kv.Width = ROPE_WIDTH

	newRope.kv.TextureScale = ROPE_TEXURE_SCALE
	newRope.kv.RopeMaterial = ROPE_MATERIAL
	newRope.kv.PositionInterpolator = 2

	newRope.kv.renderamt = 255
	newRope.kv.rendercolor = "255 255 255"

	//	Manipulate linked-list
	entity prevParent = prevRope.GetParent()	//	prevRope.s.parents[1]

	//	This creates a midpoint that replaces prevKeyframe so prevRope can become the
	//	new endpoint - changing a rope_midpoint to a rope_endpoint isn't possible. A
	//	better explanation is contained within Diagram 1 at the end of the function.
	if( atEnd ) {
		entity grandparent = expect entity( prevRope.s.parents[0] )

		//	Data transfer
		newRope.SetOrigin( prevParent.GetOrigin() )
		newRope.SetAngles( prevParent.GetAngles() )
		newRope.SetParent( prevParent )

		prevRope.SetOrigin( pointEnt.GetOrigin() )
		prevRope.SetAngles( pointEnt.GetAngles() )
		prevRope.SetParent( pointEnt )

		//	Spawn
		DispatchSpawn( newRope )

		//	Index swap
		newRope.s.parents <- [grandparent, prevParent]
		prevRope.s.parents = [prevParent, pointEnt]

		newRope.kv.NextKey = prevParent.GetTargetName()
		grandparent.kv.NextKey = pointName

		newRope.s.nextRope <- prevRope
		grandparent.s.nextRope = newRope

		//	Return
		return newRope
	} else {
		entity nextRope = expect entity( prevRope.s.nextRope )
		entity nextParent = nextRope.GetParent()
		string nextName = expect string( prevRope.kv.NextKey )

		//	Data transfer
		newRope.SetOrigin( pointEnt.GetOrigin() )
		newRope.SetAngles( pointEnt.GetAngles() )
		newRope.SetParent( pointEnt )

		//	Spawn
		DispatchSpawn( newRope )

		//	Index swap
		newRope.s.parents <- [prevParent, pointEnt]
		nextRope.s.parents = [pointEnt, nextParent]

		prevRope.kv.NextKey = pointName
		newRope.kv.NextKey = nextName

		prevRope.s.nextRope = newRope
		newRope.s.nextRope <- nextRope

		//	Return
		return newRope
	}
	//return ""

	/*	Diagram 1
	 *	╔════╤════════════════════════════════════════════════════════╦════╤════════════════════════════════════════════════════════╗
	 *	║ #1 │ New key to insert in the rope (ropes ~= linked lists)  ║ #2 │ Swap the new data with the data from the old rope end  ║
	 *	╠════╧════════════════════════════════════════════════════════╬════╧════════════════════════════════════════════════════════╣
	 *	║                                               ┌───────┐     ║                                               ┌───────┐     ║
	 *	║                                               │  N/A  │     ║                                               │  N/A  │     ║
	 *	║                                               │ key94 │     ║                                               │ key94 │     ║
	 *	║                                               │ data4 │     ║                                            ┌─>> data4 │     ║
	 *	║                                               └───┬───┘     ║                                            │  └───────┘     ║
	 *	║                                                   V         ║                                            │                ║
	 *	║     ┌───────┐     ┌───────┐     ┌───────┐     ╶╶╶╶╶╶╶╶╷     ║     ┌───────┐     ┌───────┐     ┌───────┐  │  ╶╶╶╶╶╶╶╶╷     ║
	 *	║     │ n - 2 │     │ n - 1 │     │   n   │     ╵ (n+1) ╷     ║     │ n - 2 │     │ n - 1 │     │   n   │  │  ╵ (n+1) ╷     ║
	 *	║ ──> │ key35 │ ──> │ key67 │ ──> │  end  │     ╵       ╷     ║ ──> │ key35 │ ──> │ key67 │ ──> │  end  │  │  ╵       ╷     ║
	 *	║     │ data1 │     │ data2 │     │ data3 │     ╵       ╷     ║     │ data1 │     │ data2 │     │ data3 <<─┘  ╵       ╷     ║
	 *	║     └───────┘     └───────┘     └───────┘     ╵╴╴╴╴╴╴╴╴     ║     └───────┘     └───────┘     └───────┘     ╵╴╴╴╴╴╴╴╴     ║
	 *	╠════╤════════════════════════════════════════════════════════╬════╤════════════════════════════════════════════════════════╣
	 *	║ #3 │ Make/break connections, move old end ahead in the list ║ #4 │ Finished rope                                          ║
	 *	╠════╧════════════════════════════════════════════════════════╬════╧════════════════════════════════════════════════════════╣
	 *	║                                               ┏━━━━━━━┓     ║                                                             ║
	 *	║                       ╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶> ┃  N/A  ┃     ║                                                             ║
	 *	║                       ╵             ┌─────<<<─┨ key94 ┃     ║                                                             ║
	 *	║                       ╵             │         ┃ data3 ┃     ║                                                             ║
	 *	║                       ╵             │         ┗━━━━━━━┛     ║                                                             ║
	 *	║                       ╵             v                       ║                                                             ║
	 *	║     ┌───────┐     ┌───────┐     ┏━━━━━━━┓     ╶╶╶╶╶╶╶╶╷     ║     ┌───────┐     ┌───────┐     ┌───────┐     ┌───────┐     ║
	 *	║     │ n - 2 │     │ n - 1 │     ┃   n   ┃     ╵ (n+1) ╷     ║     │ n - 2 │     │ n - 1 │     │   n   │     │ n + 1 │     ║
	 *	║ ──> │ key35 │ ──> │ key67 │ ─╳> ┃  end  ┠─>>>─┘       ╷     ║ ──> │ key35 │ ──> │ key67 │ ──> │ key94 │ ──> │  end  │     ║
	 *	║     │ data1 │     │ data2 │     ┃ data4 ┃     ╵       ╷     ║     │ data1 │     │ data2 │     │ data3 │     │ data4 │     ║
	 *	║     └───────┘     └───────┘     ┗━━━━━━━┛     ╵╴╴╴╴╴╴╴╴     ║     └───────┘     └───────┘     └───────┘     └───────┘     ║
	 *	╚═════════════════════════════════════════════════════════════╩═════════════════════════════════════════════════════════════╝
	 */
}

string function RemoveRopeKeyframe( entity startRope, int index = 1 ) {
	string debugOut = "\n\t\tRemoveRopeKeyframe: index = " + index

	if( !(index > 0 || index <= -2) ) {
		return debugOut + "\n\t\tRemoveRopeKeyframe: Cannot remove start or end keyframe"
	}

	entity prevRope = RopeAtIndex( startRope, index - 1 )

	int fillIdx = -2
	array<entity> ropeQueue = [null, null, prevRope]
	while( fillIdx < 0 ) {
		//	Debug out
		if( !("nextRope" in ropeQueue[2].s) ) {
			return debugOut + "\n\t\tRemoveRopeKeyframe: Error encountered while building ropeQueue - no next item"
		}

		//	Debug out
		if( !IsValid(ropeQueue[2].s.nextRope) ) {
			return debugOut + "\n\t\tRemoveRopeKeyframe: Error encountered while building ropeQueue - invalid next item"
		}

		ropeQueue.append( expect entity(ropeQueue[2].s.nextRope) )
		ropeQueue.remove( 0 )
		fillIdx ++
	}

	if( !("nextRope" in ropeQueue[0].s) ) {
		ropeQueue[0].s.nextRope <- ropeQueue[2]
	} else { ropeQueue[0].s.nextRope = ropeQueue[2] }

	//	Debug out
	if( !IsValid(ropeQueue[0].GetParent()) || !IsValid(ropeQueue[2].GetParent()) ) {
		return debugOut + "\n\t\tRemoveRopeKeyframe: Parents of adjacent keyframes must be valid"
	}

	if( !("parents" in ropeQueue[0].s) ) {
		ropeQueue[0].s.parents <- [ ropeQueue[0].GetParent(), ropeQueue[2].GetParent() ]
	} else { ropeQueue[0].s.parents = [ ropeQueue[0].GetParent(), ropeQueue[2].GetParent() ] }

	if( IsValid(ropeQueue[1]) )
		ropeQueue[1].Destroy()

	return ""
}



void function RopeBeams1p3p( entity owner, entity startEnt, entity endEnt ) {
	entity beam1p = RopeBeam( owner, startEnt, endEnt )
	entity beam3p = RopeBeam( owner, startEnt, endEnt )

	SetForceDrawWhileParented( beam1p, true )
	SetForceDrawWhileParented( beam3p, true )
	beam1p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_ONLY_PARENT_PLAYER
	beam3p.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE | ENTITY_VISIBLE_EXCLUDE_PARENT_PLAYER

	if( "ropes1p3p" in startEnt.s ) {
		startEnt.s.ropes1p3p = [ beam1p, beam3p ]
	} else { startEnt.s.ropes1p3p <- [ beam1p, beam3p ] }
}

entity function RopeBeam( entity owner, entity startEnt, entity endEnt ) {
	entity beam = CreateEntity( "env_laser" )
	beam.kv.LaserTarget = endEnt.GetTargetName()

	beam.SetValueForTextureKey( TETHER_ROPE_MODEL )
	beam.kv.TextureScroll = 35
	beam.kv.width = 2

	beam.kv.renderamt = 255
	beam.kv.rendercolor = "255 255 255"

	beam.kv.damage = "0"
	beam.kv.dissolvetype = -1	//	-1 to 2 - none, energy, heavy elec, light elec
	beam.kv.spawnflags = 1		// 	32 end sparks

	beam.SetOrigin( startEnt.GetOrigin() )
	beam.SetAngles( startEnt.GetAngles() )

	beam.SetParent( startEnt )
	beam.s.parents <- [startEnt, endEnt]

	SetTeam( beam, owner.GetTeam() )
	DispatchSpawn( beam )

	return beam
}

void function DestroyRopeParent( entity toKill ) {
	if( !IsValid(toKill) )
		return

	if( "ropes1p3p" in toKill.s ) {
		if( IsValid(toKill.s.ropes1p3p[0]) )
			toKill.s.ropes1p3p[0].Destroy()

		if( IsValid(toKill.s.ropes1p3p[1]) )
			toKill.s.ropes1p3p[1].Destroy()
	}

	toKill.Destroy()
}



//	Traversal
entity function RopeAtIndex( entity startRope, int index ) {
	//	Add whole rope to array
	int last = 0
	array<entity> ropes = [ startRope ]
	while( "nextRope" in ropes[last].s ) {
		//	Validify
		if( !IsValid(ropes[last].s.nextRope) ) {
			print("[TAEsArmory] RopeAtIndex: Invalid next rope")
			return null
		}

		ropes.append( expect entity(ropes[last].s.nextRope) )
		last++
	}

	if( last < index ) {
		print("[TAEsArmory] RopeAtIndex: Index > rope size")
	}

	print("[TAEsArmory] RopeAtIndex: last = " + last + ", index = " + index)

	return ((index < 0) ? ropes[last + 1 + index] : ropes[index])
}

int function RopeSize( entity startRope ) {
	int size = 1
	entity rope = startRope
	while( "nextRope" in rope.s ) {
		//	Validify
		if( !IsValid(rope.s.nextRope) ) {
			print("[TAEsArmory] RopeAtIndex: Invalid next rope")
			return -1
		}

		rope = expect entity(rope.s.nextRope)
		size++
	}

	return size
}

float function RopeLength( entity startRope, int index = -1 ) {
	float length = 0

	int size = RopeSize( startRope )
	int distance = ((index < 0) ? size + index : index) + 1

	array<entity> ropes = [ null, startRope ]
	while( distance > 0 ) {
		//	Validify
		if( !("nextRope" in ropes[1].s) ) {
			break
		}

		if( !IsValid(ropes[1].s.nextRope) ) {
			print("[TAEsArmory] RopeLength: Invalid next rope")
			return -1
		}

		//	Shift queue
		ropes.append( expect entity(ropes[1].s.nextRope) )
		ropes.remove(0)
		distance --

		//	Get parents
		entity prevParent = ropes[0].GetParent()
		entity nextParent = ropes[1].GetParent()

		if( !IsValid(prevParent) || !IsValid(nextParent) ) {
			print("[TAEsArmory] RopeLength: Invalid parent")
			return -1
		}

		//	Calculate + add length
		length += Distance( prevParent.GetOrigin(), nextParent.GetOrigin() )
	}

	return length
}

entity function RecursiveRopeAtIndex( entity current, int index, entity previous = null, bool reverse = false, int depth = 0 ) {
	print("[TAEsArmory] RecursiveRopeAtIndex: recursion depth = " + depth + ", index = " + index )
	if( !("nextRope" in current.s) && index < 0 ) reverse = true
	if( index == 0 ) { return current }

	index += (index < 0) ? (reverse ? 1 : 0) : -1
	current = reverse ? previous : current

	return RecursiveRopeAtIndex( expect entity( current.s.nextRope ), index, current, reverse, depth + 1 )
}

int function RecursiveRopeSize( entity startRope, int depth = 0 ) {
	//print("[TAEsArmory] RecursiveRopeSize: recursion depth = " + depth )
	if( !("nextRope" in startRope.s) ) { return 1 }
	if( !IsValid(startRope.s.nextRope) ) { return 1 }
	return RecursiveRopeSize( expect entity( startRope.s.nextRope ), depth + 1 ) + 1
}

float function RecursiveRopeLength( entity startRope, int index = -1, int depth = 0 ) {
	//print("[TAEsArmory] RecursiveRopeLength: recursion depth = " + depth )
	if( !("nextRope" in startRope.s) || index == 0 ) { return 0. }
	float dist = Distance( startRope.GetOrigin(), expect entity( startRope.s.nextRope ).GetOrigin() )
	return dist + RecursiveRopeLength( expect entity( startRope.s.nextRope ), index - 1, depth + 1 )
}

void function RecursiveRopeDestroy( entity startRope, int depth = 0 ) {
	//print("[TAEsArmory] RecursiveRopeDestroy: recursion depth = " + depth )
	if( !IsValid(startRope) ) return

	if( "nextRope" in startRope.s ) {
		if( IsValid(startRope.s.nextRope) ) {
			RecursiveRopeDestroy( expect entity( startRope.s.nextRope ), depth + 1 )
		}
	}

	if( IsValid(startRope.GetParent()) ) startRope.GetParent().Destroy()
	if( IsValid(startRope) ) startRope.Destroy()
}
#endif