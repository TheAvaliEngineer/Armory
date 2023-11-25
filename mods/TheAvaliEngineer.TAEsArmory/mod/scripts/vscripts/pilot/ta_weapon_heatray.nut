untyped

global function OnWeaponPrimaryAttack_weapon_heatray
global function OnWeaponBulletHit_weapon_heatray

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_heatray
#endif

const int HEAT_ZONE_RADIUS_START = 20 //480
const int HEAT_ZONE_RADIUS_END = 40 //960

const float HEAT_ZONE_MULTIPLIER_START = 1.25
const float HEAT_ZONE_MULTIPLIER_END = 2.5

const float HEAT_ZONE_WARMUP_TIME = 5.0 //2.5

const float HEAT_ZONE_INIT_TIME = 5.0 //1.0
const float HEAT_ZONE_TIME_PER_HIT = 0.1

const float HEAT_ZONE_TPS = 20.0

// Firing
var function OnWeaponPrimaryAttack_weapon_heatray( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    return FireHeatRay( weapon, attackParams )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_heatray( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    return FireHeatRay( weapon, attackParams )
}
#endif

int function FireHeatRay( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    int damageFlags = weapon.GetWeaponDamageFlags()

    weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageFlags )

	return 1
}


// Impact handling
void function OnWeaponBulletHit_weapon_heatray( entity weapon, WeaponBulletHitParams hitParams ) {
    entity player = weapon.GetWeaponOwner()
    entity hitEnt = hitParams.hitEnt

    if ( hitEnt == player )
		return

    if ( !IsValid( hitEnt ) )
        return

    if ( !hitEnt.IsWorld() ) { //hitEnt.IsTitan() ) {
        #if SERVER
        thread HeatZoneThink( player, weapon, hitParams )
        #endif
    }
}

// Heat zone handling
#if SERVER
entity function CreateHeatZone( entity player, entity weapon, WeaponBulletHitParams hitParams ) {
    // Do trace to find hitbox
    vector traceStartPos = player.EyePosition()
    vector traceEndPos = player.EyePosition() + player.GetViewVector() * 16000.0

    TraceResults traceResult = TraceLine( traceStartPos, traceEndPos, [player], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )

    table collisionParams = {
        pos = hitParams.hitPos, //traceResult.endPos,
        normal = traceResult.surfaceNormal,
        hitEnt = hitParams.hitEnt, //traceResult.hitEnt,
        hitbox = 0 // Default, don't know how to get hitbox yet.
    }

    //*
    entity zoneSphere = CreateEntity( "vortex_sphere" )
    zoneSphere.kv.spawnflags = SF_ABSORB_BULLETS //| SF_BLOCK_OWNER_WEAPON | SF_BLOCK_NPC_WEAPON_LOF //| SF_ABSORB_CYLINDER
    zoneSphere.kv.enabled = 0

    zoneSphere.kv.radius = HEAT_ZONE_RADIUS_START
    //zoneSphere.kv.height = HEAT_ZONE_RADIUS_START

    // Dunno what these are for. seem to be used everywhere
    zoneSphere.kv.bullet_fov = 360
	zoneSphere.kv.physics_pull_strength = 25
	zoneSphere.kv.physics_side_dampening = 6
	zoneSphere.kv.physics_fov = 360
	zoneSphere.kv.physics_max_mass = 2
	zoneSphere.kv.physics_max_size = 6

    SetVortexSphereBulletHitRules( zoneSphere, HeatZone_BulletHitRules ) //VortexBulletHitRules_Default )
	SetVortexSphereProjectileHitRules( zoneSphere, HeatZone_ProjectileHitRules ) //VortexProjectileHitRules_Default )

    zoneSphere.SetAngles( VectorToAngles( collisionParams.normal ) )
    zoneSphere.SetOrigin( collisionParams.pos )

    float startHealth = ( HEAT_ZONE_INIT_TIME * HEAT_ZONE_TPS ) //.tointeger()
    float maxHealth = ( HEAT_ZONE_WARMUP_TIME * HEAT_ZONE_TPS ) //.tointeger()

    zoneSphere.SetHealth( startHealth )
	zoneSphere.SetMaxHealth( maxHealth )
    zoneSphere.SetTakeDamageType( DAMAGE_YES )
    zoneSphere.SetBlocksRadiusDamage( true )

    DispatchSpawn( zoneSphere )

	//zoneSphere.Fire( "Kill", "", 10000 )
    //*/

    /*
    entity zoneSphere = CreateShieldWithSettings( traceResult.endPos, AnglesToUp( traceResult.surfaceNormal ),
        HEAT_ZONE_RADIUS_START, HEAT_ZONE_RADIUS_START,
        PLAYER_SHIELD_WALL_FOV, HEAT_ZONE_WARMUP_TIME * HEAT_ZONE_TPS, 100000, $"P_turret_shield_wall" )
    //*/

    //zoneSphere.EndSignal( "OnDestroy" )

    // real important stuff
    zoneSphere.SetOwner( player )
    zoneSphere.SetOwnerWeapon( weapon )
    weapon.SetWeaponUtilityEntity( zoneSphere )
    //  SetTeam( zoneSphere, player.GetTeam() )

    //
    zoneSphere.FireNow( "Enable" )

    // This can be used once I figure out how to get hitbox data
    //zoneSphere.SetParentWithHitbox( collisionParams.hitEnt, collisionParams.hitbox, true )
    //zoneSphere.SetParent( collisionParams.hitEnt )

    // Position of the sphere relative to the hit entity.
    //vector localOrigin = hitParams.hitPos - collisionParams.hitEnt.GetOrigin();
    //zoneSphere.SetLocalOrigin( localOrigin )

    // might not work. check later.
    //bool result = PlantStickyEntity( zoneSphere, collisionParams )

    //      Inline PlantStickyEntity implementation
    vector angleOffset = <0.0, 0.0, 0.0>

    if ( !EntityShouldStick( zoneSphere, expect entity( collisionParams.hitEnt ) ) )
		print("[tae_weapon_heatray] CreateHeatZone: Entity should not stick")

	// Don't allow parenting to another "sticky" entity to prevent them parenting onto each other
	if ( collisionParams.hitEnt.IsProjectile() )
		print("[tae_weapon_heatray] CreateHeatZone: Entity colliding with projectile")

	// Update normal from last bouce so when it explodes it can orient the effect properly

	vector plantAngles = AnglesCompose( VectorToAngles( collisionParams.normal ), angleOffset )
	vector plantPosition = expect vector( collisionParams.pos )

	if ( !LegalOrigin( plantPosition ) )
		print("[tae_weapon_heatray] CreateHeatZone: Origin is not legal")

	zoneSphere.SetAbsOrigin( plantPosition )
	zoneSphere.SetAbsAngles( plantAngles )
	zoneSphere.SetVelocity( Vector( 0, 0, 0 ) )

	//printt( " - Hitbox is:", collisionParams.hitbox, " IsWorld:", collisionParams.hitEnt )
    if ( !zoneSphere.IsMarkedForDeletion() && !collisionParams.hitEnt.IsMarkedForDeletion() ) {
        if ( collisionParams.hitbox > 0 )
            zoneSphere.SetParentWithHitbox( collisionParams.hitEnt, collisionParams.hitbox, true )

        // Hit a func_brush
        else
            zoneSphere.SetParent( collisionParams.hitEnt )

        if ( collisionParams.hitEnt.IsPlayer() ) {
            thread HandleDisappearingParent( zoneSphere, expect entity( collisionParams.hitEnt ) )
        }
	}

	//zoneSphere.Signal( "Planted" )

//	print("[tae_weapon_heatray] CreateHeatZone: Entity has been planted")
    //      End

    return zoneSphere
}

void function HandleDisappearingParent( entity ent, entity parentEnt ) {
	parentEnt.EndSignal( "OnDeath" )
	ent.EndSignal( "OnDestroy" )

	OnThreadEnd(
	    function() : ( ent ) {
			ent.ClearParent()
		}
	)

	parentEnt.WaitSignal( "StartPhaseShift" )
}



void function HeatZoneThink( entity player, entity weapon, WeaponBulletHitParams hitParams ) {
    entity zoneEnt = CreateHeatZone( player, weapon, hitParams )

    //zoneEnt.EndSignal( "OnDestroy" )
    //zoneEnt.SetDamageNotifications( true )

    if ( !IsValid( zoneEnt ) ) {
        print("[tae_weapon_heatray] HeatZoneThink: Given zoneEnt entity is not valid.")
        return
    }

    // Attached
    //entity attachedEnt = hitParams.hitEnt

    // Update on damage
    thread HeatZoneUpdateOnDamage( player, zoneEnt )

    // FX
    const vector ROTATE_FX = <90.0, 0.0, 0.0>
    entity fx = PlayFXOnEntity( THERMITE_GRENADE_FX, zoneEnt, "", null, ROTATE_FX )
    fx.SetOwner( zoneEnt.GetOwner() )
	fx.EndSignal( "OnDestroy" )

    // End
    OnThreadEnd(
		function() : ( zoneEnt, fx ) {
//            print("[tae_weapon_heatray] HeatZoneThink: Destroying heat zone")
//            print("[tae_weapon_heatray] HeatZoneThink: Measured end time = " + Time())

			if ( IsValid( zoneEnt ) )
				zoneEnt.Destroy()

			if ( IsValid( fx ) )
				fx.Destroy()
		}
	)

    float startTime = Time();
    float endTime = startTime + (zoneEnt.GetHealth() / HEAT_ZONE_TPS)

//    print("[tae_weapon_heatray] HeatZoneThink: Start time = " + startTime)
//    print("[tae_weapon_heatray] HeatZoneThink: Predicted end time = " + endTime)

//    float tickTime = 1. / HEAT_ZONE_TPS
    while( Time() < endTime ) {
        endTime = startTime + (zoneEnt.GetHealth() / HEAT_ZONE_TPS)
        WaitFrame()
    }
}

void function HeatZoneUpdateOnDamage( entity player, entity zoneEnt ) {
    if ( !IsValid( zoneEnt ) ) {
        print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: Given zoneEnt entity is not valid.")
        return
    }

    // zoneEnt init
    //zoneEnt.EndSignal( "OnDestroy" )
    zoneEnt.SetDamageNotifications( true )

    // Attached
    entity attachedEnt = zoneEnt.GetParent()

    // Event handling stuffs
    var incomingDamageInfo
    entity attacker
    entity inflictor

    while ( true ) {
        if( !IsValid(zoneEnt) )
            return

        print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: before WaitSignal")

        incomingDamageInfo = WaitSignal( zoneEnt, "OnDamaged" )
        attacker = expect entity( incomingDamageInfo.activator )
        inflictor = expect entity( incomingDamageInfo.inflictor )

        print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: Damage event recorded!")

        // Dunno what this does
        if ( IsValid( inflictor ) && inflictor == zoneEnt ) {
            print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: inflictor valid, inflictor == zoneEnt")
            continue
        }

        bool shouldDoDamage = false
        bool shouldAddTime = false
        if ( IsValid( attacker ) ) {
            // Test if friendly
            if ( zoneEnt.GetTeam() == attacker.GetTeam() ) {
                entity attackerWeapon = attacker.GetActiveWeapon()

                // Make sure weapon is valid
                if ( !IsValid( attackerWeapon ) ) {
                    print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: attack weapon invalid")
                    continue
                }

                // Add time if possible
                shouldAddTime = attackerWeapon.GetWeaponClassName() == "tae_weapon_heatray"

                // Check if valid
                shouldDoDamage = IsValid( inflictor ) && (inflictor.IsProjectile() || (inflictor instanceof CWeaponX))
            }
        }

        float warmupFraction = zoneEnt.GetHealth() / (HEAT_ZONE_WARMUP_TIME * HEAT_ZONE_TPS)
        warmupFraction = clamp( warmupFraction, 0.0, 1.0 )

        float heatRadius = ( 1. - warmupFraction ) * HEAT_ZONE_RADIUS_START + warmupFraction * HEAT_ZONE_RADIUS_END
        zoneEnt.kv.radius = heatRadius.tointeger()
        //zoneEnt.kv.height = heatRadius.tointeger()

        if ( shouldDoDamage ) {
            // Get damage amount
            float incomingDamage = float ( incomingDamageInfo.value )
            float multiplier = ( 1. - warmupFraction ) * HEAT_ZONE_MULTIPLIER_START + warmupFraction * HEAT_ZONE_MULTIPLIER_END
            int damageAmt = int ( incomingDamage * multiplier )

            // Get source ID
            int dmgSourceID = inflictor.GetDamageSourceID()
            if ( inflictor.IsProjectile() )
                dmgSourceID = inflictor.ProjectileGetDamageSourceID()

            print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: Dealing " + damageAmt + " damage; multiplier = " + multiplier)

            // Deal damage
            attachedEnt.TakeDamage( damageAmt, attacker, inflictor, { damageSourceId = dmgSourceID, origin = attacker.GetOrigin() } )

            if ( attacker.IsPlayer() ) {
                attacker.NotifyDidDamage(
                    attachedEnt, 0,
                    DamageInfo_GetDamagePosition( incomingDamageInfo ),
                    DamageInfo_GetCustomDamageType( incomingDamageInfo ),
                    damageAmt,
                    DamageInfo_GetDamageFlags( incomingDamageInfo ),
                    DamageInfo_GetHitGroup( incomingDamageInfo ),
                    DamageInfo_GetWeapon( incomingDamageInfo ),
                    DamageInfo_GetDistFromAttackOrigin( incomingDamageInfo )
                )
            }

        }

        if ( shouldAddTime ) {
            print("[tae_weapon_heatray] HeatZoneUpdateOnDamage: adding time")
            float offsetAmt = (HEAT_ZONE_TIME_PER_HIT * HEAT_ZONE_TPS) //.tointeger()
            zoneEnt.SetHealth( zoneEnt.GetHealth() + offsetAmt )
        }
    }
}

//*
var function HeatZone_BulletHitRules( entity zoneEnt, var damageInfo ) {
    print("[tae_weapon_heatray] HeatZone_BulletHitRules: Hit recorded")
    return damageInfo
    //DamageInfo_SetDamage( damageInfo, 0 )
}

bool function HeatZone_ProjectileHitRules( entity zoneEnt, entity attacker, bool takesDamageByDefault ) {
    print("[tae_weapon_heatray] HeatZone_ProjectileHitRules: Hit recorded")
    return takesDamageByDefault
    //return false
} //*/

/*
var function HeatZone_BulletHitRules( entity zoneEnt, var damageInfo ) {
    attacker = expect entity( damageInfo.activator )
	inflictor = expect entity( damageInfo.inflictor )

    // Dunno what this does
    if ( IsValid( inflictor ) && inflictor == zoneEnt ) {
        print("[tae_weapon_heatray] HeatZone_BulletHitRules: inflictor valid, inflictor == zoneEnt")
        continue
    }


    bool shouldDoDamage = false
    bool shouldAddTime = false
    if ( IsValid( attacker ) ) {
        // Test if friendly
        if ( zoneEnt.GetTeam() == attacker.GetTeam() ) {
            entity attackerWeapon = attacker.GetActiveWeapon()

            // Make sure weapon is valid
            if ( !IsValid( attackerWeapon ) ) {
                print("[tae_weapon_heatray] HeatZone_BulletHitRules: attack weapon invalid")
                continue
            }

            // Add time if possible
            shouldAddTime = attackerWeapon.GetWeaponClassName() == "tae_weapon_heatray"

            // Check if valid
            shouldDoDamage = IsValid( inflictor ) && (inflictor.IsProjectile() || (inflictor instanceof CWeaponX))
        }
    }

    warmupFraction = zoneEnt.GetHealth() / ( HEAT_ZONE_WARMUP_TIME * HEAT_ZONE_TPS )
    warmupFraction = clamp( warmupFraction, 0.0, 1.0 )

    float heatRadius = ( 1. - warmupFraction ) * HEAT_ZONE_RADIUS_START + warmupFraction * HEAT_ZONE_RADIUS_END
    zoneEnt.kv.radius = heatRadius.tointeger()
    zoneEnt.kv.height = heatRadius.tointeger()

    if ( shouldDoDamage ) {
        // Get damage amount
        float incomingDamage = float ( damageInfo.value )
        float multiplier = ( 1. - warmupFraction ) * HEAT_ZONE_MULTIPLIER_START + warmupFraction * HEAT_ZONE_MULTIPLIER_END
        int damageAmt = int ( incomingDamage * multiplier )

        // Get source ID
        int dmgSourceID = inflictor.GetDamageSourceID()
        if ( inflictor.IsProjectile() )
            dmgSourceID = inflictor.ProjectileGetDamageSourceID()

        print("[tae_weapon_heatray] HeatZone_BulletHitRules: Dealing " + damageAmt + " damage; multiplier = " + multiplier)

        // Deal damage
        entity attachedEnt = zoneEnt.GetParent()
        attachedEnt.TakeDamage( damageAmt, attacker, inflictor, { damageSourceId = dmgSourceID, origin = attacker.GetOrigin() } )

        if ( attacker.IsPlayer() ) {
            attacker.NotifyDidDamage(
                attachedEnt, 0,
                DamageInfo_GetDamagePosition( damageInfo ),
                DamageInfo_GetCustomDamageType( damageInfo ),
                damageAmt,
                DamageInfo_GetDamageFlags( damageInfo ),
                DamageInfo_GetHitGroup( damageInfo ),
                DamageInfo_GetWeapon( damageInfo ),
                DamageInfo_GetDistFromAttackOrigin( damageInfo )
            )
        }

    }

    if ( shouldAddTime ) {
        int ticksAdd = (HEAT_ZONE_TIME_PER_HIT * HEAT_ZONE_TPS).tointeger()
        zoneEnt.SetHealth( zoneEnt.GetHealth() + ticksAdd )

        print("[tae_weapon_heatray] HeatZone_BulletHitRules: Added " + ticksAdd + " ticks")
    }

    //  Holdover from GunShield_InvulBulletHitRules
    DamageInfo_SetDamage( damageInfo, 0 )
    return damageInfo
}

bool function HeatZone_ProjectileHeatRules( entity zoneEnt, entity attacker, bool takesDamageByDefault ) {
    if ( zoneEnt.GetTeam() == attacker.GetTeam() ) {
        entity attackerWeapon = attacker.GetActiveWeapon()

        // Make sure weapon is valid
        if ( !IsValid( attackerWeapon ) ) {
            print("[tae_weapon_heatray] HeatZone_BulletHitRules: attack weapon invalid")
            continue
        }


    }

    // Deal damage
    entity attachedEnt = zoneEnt.GetParent()
    attachedEnt.TakeDamage( damageAmt, attacker, inflictor, { damageSourceId = dmgSourceID, origin = attacker.GetOrigin() } )

    if ( attacker.IsPlayer() ) {
        attacker.NotifyDidDamage(
            attachedEnt, 0,
            DamageInfo_GetDamagePosition( damageInfo ),
            DamageInfo_GetCustomDamageType( damageInfo ),
            damageAmt,
            DamageInfo_GetDamageFlags( damageInfo ),
            DamageInfo_GetHitGroup( damageInfo ),
            DamageInfo_GetWeapon( damageInfo ),
            DamageInfo_GetDistFromAttackOrigin( damageInfo )
        )
    }

    //  Holdover from GunShield_InvulProjectileHitRules
    return false
} //*/

#endif
