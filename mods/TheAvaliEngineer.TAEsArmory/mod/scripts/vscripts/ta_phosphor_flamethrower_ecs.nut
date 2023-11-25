untyped

//		Function definitions
global function TArmory_Init_ThermiteECS

global function ThermiteECS_CreateThermiteEnt
global function ThermiteECS_RegisterFXGroup

//		Variables
/**		Fire Effects
 * 	Spread out flames: $"P_ash_tree_fire"	$"ash_fire_med_base"	$"cfire_med_base"	$"fire_pyro_licks"	$"fire_pyro_licks_sm"
 * 	Tight flames: $"env_smoke_plume_SM_CH_fire"	$"env_smoke_plume_SM_CH_fire"	$"fire_med_base"
 * 	Orb/Trail:	$"crashing_ship_smoke_CH_fire"	$"Rocket_Smoke_Large_fire"	$"vDeath_CH_fire"	$"hTrail_CH_fire"
 * 	Point:	$"cfire_small_CH_ring"
 * 	Jet: $"bt_injector_dam_body_fire"	$"P_veh_engine_fire_spurt"
 */

/**		Spark Effects
 * 	Spread out:	$"ash_fire_embers"	$"fire_pyro_embers"
 * 	Point:	$"fire_med_low_embers"
 */

/**		Heat Distortion Effects
 * 	$"P_tunnel_heat_edges"
 */

/**		Full Fire Effects
 * 	Large:	$"P_fire_pyro_ground"
 * 	Medium:	$"P_fire_med_FULL"		$"zOLD_P_fire_med"
 * 	Small:	$"P_fire_small_FULL"
 * 	Tiny:	$"P_fire_tiny_FULL"
 */

//	$"Rocket_Smoke_Large_fire_Alt"	Purple fire

//
//
//	Orb/Trail:
//	Puffy: $"env_smoke_plume_CH_fire"

//	FX
const asset THERMITE_FX_BASE = $"P_wpn_meteor_exp"
const asset THERMITE_FX_TRAIL = $"P_wpn_meteor_exp_trail"

//	FX
struct {
	int count = 0

	array< array<asset> > fxTable

	array<int> staticFxIdx
} EcsFxResource


//	Fire struct def
struct {
	int count = 0

	//	Physics
	array<vector> pos
	array<vector> vel

	float g = 375.0
	float friction = 0.8

	//	Fluid behavior
	float cohesionDistance = 300.0
	float cohesionFactor = 0.25

	float sepDist = 50.0
	float sepFactor = 1.0

	float alignmentFactor = 0.125

	//	Locality
	array<int> localIDs
	table< int, array<int> > neighbor

	vector localTransform = <0.001, 0.001, 0.0>

	//	Other behavior
	array<bool> isAnchored
	float anchorCheckHeight = 20.0

	array<bool> shouldDestroy

	//	FX
	array<bool> replaceFX

	array<int> fxTable
	array<int> fxID

	array<entity> fxArr

	//	Damage
	array<int> damage
	array<int> titanDamage

	array<float> innerRadius
	array<float> outerRadius

	array<float> startTime
	array<float> duration

	//	Ticking
	table< entity, array<int> > entsToDamage
	table< entity, float > lastDamageTime

	float tickTime = 0.2
	float timeout = 0.5

	//	Ent data
	array<entity> owner
	array<entity> weapon
} ThermiteData

//		Functions
//	Init
void function TArmory_Init_ThermiteECS() {
	//	FX precache
	PrecacheParticleSystem( THERMITE_FX_TRAIL )

	PrecacheParticleSystem( THERMITE_FX_BASE )

	array<asset> thermiteMovingFx = [ THERMITE_FX_TRAIL ]
	array<asset> thermiteStaticFx = [ THERMITE_FX_BASE ]

	#if SERVER
	thread ThermiteSystemLoop()
	#endif
}

#if SERVER
//	Thermite System
void function ThermiteSystemLoop() {
	while( 1 ) {
		ThermiteKillSystem()

		ThermiteSystem()
		ThermiteFXSystem()
		ThermiteDamageSystem()

		WaitFrame()
	}
}

void function ThermiteSystem() {
	//	Locality stuff
	ThermiteData.neighbor.clear()

	for( int i = 0; i < ThermiteData.count; i++ ) {
		int localID = GetLocalID( ThermiteData.pos[i] )
		ThermiteData.localIDs[i] = localID

		//	Table checks
		if( localID in ThermiteData.neighbor ) {
			ThermiteData.neighbor[localID].append(i)
		} else { ThermiteData.neighbor[localID] <- [i] }
	}

	//print("\n\n[TAEsArmory] ThermiteSystem: Locality handling complete\n\n")

	vector anchorOffset = <0, 0, ThermiteData.anchorCheckHeight>
	float frictionPerFrame = pow( ThermiteData.friction, FrameTime() ) //log(ThermiteData.friction) / log(FrameTime())

	//	Physics part 1: Velocity handling
	for( int i = 0; i < ThermiteData.count; i++ ) {
		//	Ignore anchored fires
		if( ThermiteData.isAnchored[i] )
			continue

		// ==== BOID/FLUID STUFF ====
		int localID = ThermiteData.localIDs[i]
		int neighborCount = ThermiteData.neighbor[localID].len()

		if( neighborCount == 1 )
			continue

		//	Cohesion & seperation force
		vector centerOfMass = <0, 0, 0>
		vector avgVel = <0, 0, 0>
		vector sepForce = <0, 0, 0>

		for( int j = 0; j < neighborCount; j++ ) {
			int neighbor = ThermiteData.neighbor[localID][j]

			//	Skip self
			if( neighbor == i ) {
				//print("[TAEsArmory] Skipping self (i = " + i + ", n = " + neighbor + ")")
				continue
			}

			vector pos = ThermiteData.pos[neighbor]
			vector vel = ThermiteData.vel[neighbor]

			//	Cohesion & Alignment
			centerOfMass += pos
			avgVel += vel

			//	Seperation
			vector sepVec = ThermiteData.pos[i] - pos
			if( Length(sepVec) <= ThermiteData.sepDist ) {
				sepForce += sepVec
			}
		}

		centerOfMass /= (neighborCount - 1)
		vector cohesionForce = centerOfMass - ThermiteData.pos[i]
		cohesionForce *= ThermiteData.cohesionFactor / ( Length(cohesionForce) * Length(cohesionForce) )

		avgVel /= (neighborCount - 1)
		vector alignmentForce = ThermiteData.alignmentFactor * (avgVel - ThermiteData.vel[i])

		sepForce *= ThermiteData.sepFactor

		//	Set addVel
		ThermiteData.vel[i] += cohesionForce + alignmentForce + sepForce

		// ==== REGULAR PHYSICS ====
		//	Trace line
		TraceResults traceNormal = TraceLine(
			ThermiteData.pos[i],
			ThermiteData.pos[i] - anchorOffset,
			null,
			(TRACE_MASK_SHOT | CONTENTS_BLOCKLOS),
			TRACE_COLLISION_GROUP_NONE
		)

		vector gravity = <0, 0, -ThermiteData.g>
		ThermiteData.vel[i] += gravity * traceNormal.fraction

		//	Continue if no slope to slide on
		if( traceNormal.fraction >= 1 ) {
			continue
		}

		//	Calculate gradient velocity
		if( traceNormal.hitEnt.IsWorld() ) {
			vector slopeAngles = VectorToAngles( traceNormal.surfaceNormal ) //* <1, 1, 0>
			vector slopeVel = Normalize( VecMultiply( traceNormal.surfaceNormal, <1, 1, 0> ) )
			slopeVel = VecMultiply( slopeVel, CrossProduct( slopeVel, gravity ) / ThermiteData.g )

			ThermiteData.vel[i] += slopeVel

			ThermiteData.vel[i] *= frictionPerFrame
		}
	}

	//print("\n\n[TAEsArmory] ThermiteSystem: Velocity handling complete\n\n")

	//	Physics part 2: Collisions
	for( int i = 0; i < ThermiteData.count; i++ ) {
		//	Ignore anchored fires
		if( ThermiteData.isAnchored[i] )
			continue

		//	Find next position
		vector nextPos = ThermiteData.pos[i] + ThermiteData.vel[i] * FrameTime()

		//	Collision trace
		TraceResults traceVel = TraceLine(
			ThermiteData.pos[i],
			nextPos,
			null,
			(TRACE_MASK_SHOT | CONTENTS_BLOCKLOS),
			TRACE_COLLISION_GROUP_NONE
		)

		//	If collision
		if( traceVel.fraction < 1 ) {
			//print("\n\n[TAEsArmory] ThermiteSystem: Collision @ index #" + i)
			ThermiteData.pos[i] = traceVel.endPos

			//	Check if can anchor
			ThermiteData.isAnchored[i] = CanAnchor(i)
			if( ThermiteData.isAnchored[i] ) {
				// ==== DO ON ANCHOR STARTUP ====
				ThermiteData.vel[i] = <0, 0, 0>
			}

			//	Reflect if can't anchor
			vector reflected = ThermiteData.vel[i] - 2 * DotProduct(ThermiteData.vel[i], traceVel.surfaceNormal) * traceVel.surfaceNormal
			reflected *= frictionPerFrame * frictionPerFrame

			ThermiteData.vel[i] = reflected

			//	Continue to next (don't want to set final position again)
			continue
		}

		ThermiteData.pos[i] = nextPos

		//	Check if can anchor
		ThermiteData.isAnchored[i] = CanAnchor(i)
		if( ThermiteData.isAnchored[i] ) {
			// ==== DO ON ANCHOR STARTUP ====
			ThermiteData.vel[i] = <0, 0, 0>
		}
	}

	//print("\n\n[TAEsArmory] ThermiteSystem: Collision handling complete\n\n")

	//	Timekeeping
	for( int i = 0; i < ThermiteData.count; i++ ) {
		float endTime = ThermiteData.startTime[i] + ThermiteData.duration[i]
		ThermiteData.shouldDestroy[i] = ThermiteData.shouldDestroy[i] || (Time() > endTime)
	}

	//print("\n\n[TAEsArmory] ThermiteSystem: Timekeep handling complete\n\n\n\n")
}

int function GetLocalID( vector pos ) {
	vector localVec = VecMultiply(pos, ThermiteData.localTransform)
	int x = localVec.x.tointeger(); int y = localVec.y.tointeger(); int z = localVec.z.tointeger();
	return x ^ y << 11 ^ z << 22
}

bool function CanAnchor( int fireIdx ) {
	TraceResults traceAnchor = TraceLineNoEnts( ThermiteData.pos[fireIdx],
		ThermiteData.pos[fireIdx] - <0, 0, ThermiteData.anchorCheckHeight> )

	//	Return if no collision (not on ground)
	if( traceAnchor.fraction >= 1 ) {
		return false
	}

	//	Check if has sufficient space
	int localID = ThermiteData.localIDs[fireIdx]
	array<int> neighbors = ThermiteData.neighbor[localID]

	for( int i = 0; i < neighbors.len(); i++ ) {
		int neighbor = neighbors[i]

		//	Skip self
		if( neighbor == fireIdx ) continue

		float dist = Distance( ThermiteData.pos[fireIdx], ThermiteData.pos[neighbor] )

		//	No space
		if( dist <= ThermiteData.sepDist ) {
			return false
		}

	}

	return true
}

void function ThermiteFXSystem() {
	//	Mark invalid FX
	for( int i = 0; i < ThermiteData.count; i++ ) {
		if( !IsValid( ThermiteData.fxArr[i] ) )
			ThermiteData.replaceFX[i] = true
	}

	//	Assign new FxIDs
	for( int i = 0; i < ThermiteData.count; i++ ) {
		if( ThermiteData.fxID[i] != -1 ) continue

		int tableNum = ThermiteData.fxTable[i]
		if( ThermiteData.isAnchored[i] ) {
			ThermiteData.fxID[i] = RandomIntRange( EcsFxResource.staticFxIdx[tableNum] - 1, EcsFxResource.fxTable[tableNum].len() )
		} else {
			ThermiteData.fxID[i] = RandomIntRange( 0, EcsFxResource.staticFxIdx[tableNum] )
		}
	}

	//	Check FX ID
	for( int i = 0; i < ThermiteData.count; i++ ) {
		//	Skip invalid FX
		if( ThermiteData.replaceFX[i] ) continue

		bool shouldReplace = (ThermiteData.fxArr[i].s.ecsFxTable != ThermiteData.fxTable[i])
		shouldReplace = (ThermiteData.fxArr[i].s.ecsFxID != ThermiteData.fxID[i]) || shouldReplace

		ThermiteData.replaceFX[i] = shouldReplace
	}

	//	Replace FX
	for( int i = 0; i < ThermiteData.count; i++ ) {
		if( ThermiteData.replaceFX[i] ) {
			printt("[ThermiteECS] Replacing FX #" + i)

			if( IsValid( ThermiteData.fxArr[i] ) )
				ThermiteData.fxArr[i].Destroy()

			int fxTable = ThermiteData.fxTable[i]
			int fxID = ThermiteData.fxID[i]

			entity fx = PlayFX( EcsFxResource.fxTable[fxTable][fxID], ThermiteData.pos[i] )
			fx.s.ecsFxTable <- fxTable
			fx.s.ecsFxID <- fxID

			ThermiteData.fxArr[i] = fx

			ThermiteData.replaceFX[i] = false
		}
	}

	//	Move FX
	for( int i = 0; i < ThermiteData.count; i++ ) {
		if( !IsValid( ThermiteData.fxArr[i] ) ) continue

		ThermiteData.fxArr[i].SetOrigin( ThermiteData.pos[i] )
	}
}

void function ThermiteDamageSystem() {
	//	Add entities to damage table
	table< entity, array<int> > targets

	for( int i = 0; i < ThermiteData.count; i++ ) {
		if( ThermiteData.isAnchored[i] ) {
			int teamNum = ThermiteData.owner[i].GetTeam()

			array<entity> nearbyEnts = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, ThermiteData.pos[i], ThermiteData.outerRadius[i] )
			nearbyEnts.extend( GetNPCArrayEx( "any", TEAM_ANY, teamNum, ThermiteData.pos[i], ThermiteData.outerRadius[i] ) )

			foreach( ent in nearbyEnts ) {
				//	Make sure that it can damage
				if( !ShouldDamageEnt(i, ent) )
					continue

				//	Add to local targets table
				if( ent in targets ) { targets[ent].append(i) }
				else { targets[ent] <- [i] }

				//	Update global timetable
				if( ent in ThermiteData.lastDamageTime ) {
					float oldTime = ThermiteData.lastDamageTime[ent]
					ThermiteData.lastDamageTime[ent] = min( oldTime, Time() )
				} else {
					ThermiteData.lastDamageTime[ent] <- 0.
				}
			}
		}
	}

	//	Deal damage
	foreach( target, arr in targets ) {
		//	Check timetable & skip if too soon
		float timeDiff = Time() - ThermiteData.lastDamageTime[target]
		if( timeDiff < ThermiteData.tickTime )
			continue

		//	Get damage amount
		int inflictorCount = arr.len()

		table< entity, float > damagePerWeapon
		foreach( idx in arr ) {
			float distance = Distance( target.GetOrigin(), ThermiteData.pos[idx] )

			//	Calculate damage w/ falloff
			float damage = GraphCapped(
				distance,
				ThermiteData.innerRadius[idx],
				ThermiteData.outerRadius[idx],
				(target.IsTitan()) ? ThermiteData.titanDamage[idx] : ThermiteData.damage[idx],
				0
			)

			//	Add to per-attacker table
			entity weapon = ThermiteData.weapon[idx]
			if( weapon in damagePerWeapon ) {
				damagePerWeapon[weapon] += damage / inflictorCount
			} else {
				damagePerWeapon[weapon] <- damage / inflictorCount
			}
		}

		//	Deal damage
		foreach( weapon, damage in damagePerWeapon ) {
			entity attacker = weapon.GetWeaponOwner()
			int damageSource = weapon.GetDamageSourceID()

			target.TakeDamage( damage, attacker, attacker, { force = Vector(0.0, 0.0, 0.0), damageSourceId = damageSource } )
		}

		//	Set timetable
		ThermiteData.lastDamageTime[target] = Time()
	}

	//	Remove old timetable entries
	table< entity, float > old = ThermiteData.lastDamageTime
	ThermiteData.lastDamageTime.clear()
	foreach( e, t in old ) {
		if( Time() - t < ThermiteData.timeout ) {
			ThermiteData.lastDamageTime[e] <- t
		}
	}
}

bool function ShouldDamageEnt( int fireIdx, entity ent ) {
	//	Validity check
	if( !IsValid(ent) )
		return false

	//	Alive check
	if ( !IsAlive(ent) || ent.IsPhaseShifted() )
		return false

	//	Line-of-sight check
	TraceResults results = TraceLine(
		ThermiteData.pos[fireIdx],
		ent.EyePosition(), null,
		(TRACE_MASK_SHOT | CONTENTS_BLOCKLOS),
		TRACE_COLLISION_GROUP_NONE
	)

	return results.fraction >= 1 || results.hitEnt == ent
}

void function ThermiteKillSystem() {
	//	Remove ents
	int startIdx = ThermiteData.count - 1
	for( int i = startIdx; i >= 0; i-- ) {
		if( ThermiteData.shouldDestroy[i] ) {
			print("[TAEsArmory] ThermiteKillSystem: Removing index #" + i)
			RemoveThermiteEnt( i )
		}
	}
}

void function CreateThermiteEnt_Internal( entity projectile, entity owner, vector newOrigin, vector newVelocity, int fxTable ) {
	//	Validity checks
	if( !IsValid(owner) )
		return

	if( !IsValid(projectile) )
		return

	//	Data
	entity weapon = owner.GetActiveWeapon()

	vector origin = newOrigin //projectile.GetOrigin()
	vector velocity = newVelocity //projectile.GetVelocity()

	//	Physics
	ThermiteData.pos.append(origin)
	ThermiteData.vel.append(velocity)

	//	Locality data
	int localID = GetLocalID( origin )
	ThermiteData.localIDs.append(localID)

	//	Other data
	ThermiteData.isAnchored.append(false)

	ThermiteData.shouldDestroy.append(false)

	//	FX data
	ThermiteData.replaceFX.append(true)

	ThermiteData.fxTable.append(fxTable)
	ThermiteData.fxID.append(-1)

	ThermiteData.fxArr.append(null)

	//	Damage/etc
	RadiusDamageData r = GetRadiusDamageDataFromProjectile( projectile, owner )

	ThermiteData.damage.append(r.explosionDamage)
	ThermiteData.titanDamage.append(r.explosionDamageHeavyArmor)

	ThermiteData.innerRadius.append(r.explosionInnerRadius)
	ThermiteData.outerRadius.append(r.explosionRadius)

	ThermiteData.startTime.append( Time() )
	ThermiteData.duration.append( projectile.GetProjectileWeaponSettingFloat( eWeaponVar.grenade_fuse_time ) )

	//	Entity data
	ThermiteData.owner.append(owner)
	ThermiteData.weapon.append(weapon)

	//	Add 1 to count
	ThermiteData.count ++
}

void function RemoveThermiteEnt( int fireIdx ) {
	//	Physics
	ThermiteData.pos.remove(fireIdx)
	ThermiteData.vel.remove(fireIdx)

	//	Locality data
	ThermiteData.localIDs.remove(fireIdx)

	//	Anchoring
	ThermiteData.isAnchored.remove(fireIdx)

	//	Destroy FX
	ThermiteData.replaceFX.remove(fireIdx)

	ThermiteData.fxTable.remove(fireIdx)
	ThermiteData.fxID.remove(fireIdx)

	if( IsValid(ThermiteData.fxArr[fireIdx]) )
		ThermiteData.fxArr[fireIdx].Destroy()
	ThermiteData.fxArr.remove(fireIdx)

	//	Destruction bool
	ThermiteData.shouldDestroy.remove(fireIdx)

	//	Damage/etc
	ThermiteData.damage.remove(fireIdx)
	ThermiteData.titanDamage.remove(fireIdx)

	ThermiteData.innerRadius.remove(fireIdx)
	ThermiteData.outerRadius.remove(fireIdx)

	ThermiteData.startTime.remove(fireIdx)
	ThermiteData.duration.remove(fireIdx)

	//	Entity data
	ThermiteData.owner.remove(fireIdx)
	ThermiteData.weapon.remove(fireIdx)

	//	Remove 1 from count
	ThermiteData.count --
}
#endif

void function ThermiteECS_CreateThermiteEnt( entity proj, entity owner, vector origin, vector velocity, int fxTable ) {
	#if SERVER
	CreateThermiteEnt_Internal( proj, owner, origin, velocity, fxTable )
	#endif
}

//		FX Resorce
int function RegisterFXGroup_Internal( array<asset> movingFxTable, array<asset> staticFxTable ) {
	int nextIdx = EcsFxResource.count

	//	FX table
	EcsFxResource.fxTable.append(movingFxTable)
	EcsFxResource.fxTable[nextIdx].extend(staticFxTable)

	//	Indices
	EcsFxResource.staticFxIdx.append( movingFxTable.len() )

	//	Add 1 to count
	EcsFxResource.count ++

	return nextIdx
}

int function ThermiteECS_RegisterFXGroup( array<asset> movingFxTable, array<asset> staticFxTable ) {
	return RegisterFXGroup_Internal( staticFxTable, movingFxTable )
}

