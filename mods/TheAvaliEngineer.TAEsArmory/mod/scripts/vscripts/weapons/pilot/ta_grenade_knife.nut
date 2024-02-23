untyped

global function TArmory_Init_GrenadeKnife

global function OnWeaponTossReleaseAnimEvent_grenade_knife
global function OnWeaponPrimaryAttack_grenade_knife

global function OnProjectileCollision_grenade_knife

const float KNIFE_DESTROY_TIME = 5.0

// Bounce handling consts
const float KNIFE_HEADSEEK_FACTOR_CLOSE = 0.1
const float KNIFE_HEADSEEK_FACTOR_FAR = 0.05

const float KNIFE_HEADSEEK_MIN_ANGLE_CLOSE = 4.5
const float KNIFE_HEADSEEK_MIN_ANGlE_FAR = 1.5

const float KNIFE_HEADSEEK_MAX_ANGLE_CLOSE = 150
const float KNIFE_HEADSEEK_MAX_ANGLE_FAR = 120

const float KNIFE_VEL_FRAC_NORMAL = 0.3
const float KNIFE_VEL_FRAC_PARALLEL = 1.0

//      Functions
//  Init
void function TArmory_Init_GrenadeKnife() {
    #if SERVER
    //  Precache weapon
    PrecacheWeapon( "ta_grenade_knife" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_grenade_knife = "Throwing Knife",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//  Toss handling
var function OnWeaponTossReleaseAnimEvent_grenade_knife( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    var consume = OnWeaponPrimaryAttack_grenade_knife( weapon, attackParams )
    return consume
}

//  Just copying from _grenade.nut Grenade_OnWeaponToss_
int function OnWeaponPrimaryAttack_grenade_knife( entity weapon, WeaponPrimaryAttackParams attackParams ) {
    // sounds
    weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

    // some bs
    vector angularVelocity = Vector(0, 2000, 0)
    int damageFlags = weapon.GetWeaponDamageFlags()

    // grenade creation
	entity knife = weapon.FireWeaponGrenade(
        attackParams.pos, attackParams.dir, angularVelocity,
        0.0, damageFlags, damageFlags, true, true, false )

    if ( knife ) {
        #if SERVER
            //knife.kv.solid = SOLID_BBOX

			Grenade_Init( knife, weapon )
        #else
            entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( knife, weaponOwner.GetTeam() )
        #endif
    }

    // Signal stuff
    entity weaponOwner = weapon.GetWeaponOwner()
    weaponOwner.Signal( "ThrowGrenade" )
	PlayerUsedOffhand( weaponOwner, weapon ) // intentionally here and in Hack_DropGrenadeOnDeath - accurate for when cooldown actually begins

    // ammo consumption
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

// Collision + ignition
void function OnProjectileCollision_grenade_knife( entity knife, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical ) {
    if( knife.GrenadeHasIgnited() )
        return

    if ( !IsValid( hitEnt ) )
		return

    // get owner, weapon
    entity owner = knife.GetOwner();
    if ( !IsValid( owner ) || !owner.IsPlayer() )
		return

    entity weapon = owner.GetOffhandWeapons() [0]

    // modify knife
    #if SERVER
    // get bounces
    int maxBounces = knife.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )
    int bounceCount = knife.proj.projectileBounceCount

    // damage
    int damage = knife.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value )
    if( ( hitEnt.IsNPC() || hitEnt.IsPlayer() ) && IsAlive( hitEnt ) ) {
        // && ( hitEnt.GetTeam() != owner.GetTeam() || hitEnt == owner ) // && bounceCount != 0
        hitEnt.TakeDamage( damage * knife.proj.damageScale, owner, knife, { origin = owner.GetOrigin() } ) // damage, attacker, inflictor, additionalParams
    }

    // end if over bounce max
    if( knife.proj.projectileBounceCount >= maxBounces ) {
        print("[OnProjectileCollision_grenade_knife] Knife bounces >= ")
        knife.GrenadeIgnite()
        //knife.Destroy()
        //thread DestroyKnifeAfterTime( knife, normal, KNIFE_DESTROY_TIME )
        return
    }

    // set multipler
    float bounceMultipler = knife.GetProjectileWeaponSettingFloat( eWeaponVar.projectile_damage_reduction_per_bounce )
    knife.proj.damageScale = pow( bounceMultipler, bounceCount + 1 )

    // set trail
    knife.SetProjectilTrailEffectIndex( bounceCount + 1 )

    // increment bounceCount
    knife.proj.projectileBounceCount++
    #endif
}

void function OnProjectileIgnite_grenade_knife( entity knife ) {
    //knife.SetDoesExplode( false )
    knife.Destroy()
}

#if SERVER
void function DestroyKnifeAfterTime( entity knife, vector normal, float delay ) {
    wait delay
	if ( IsValid( knife ) )
		//knife.GrenadeExplode( normal )
        knife.Destroy()
}
#endif

// Headseeking
vector function KnifeHeadseek( entity knife, entity owner, vector pos, vector velocity ) {
    vector velDir = Normalize( velocity )
    float velMag = Magnitude( velocity )

    // Grab seeking data
    RadiusDamageData radiusDamage = GetRadiusDamageDataFromProjectile( knife, owner )
    float closeSeekRadius = radiusDamage.explosionInnerRadius
    float farSeekRadius = radiusDamage.explosionRadius

    // Get all the players the knife can see
    int teamNum = knife.GetTeam()
    array<entity> nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, pos, farSeekRadius )

    // Check if there are players we can seek
    array<entity> seekablePlayers
    foreach( ent in nearbyPlayers ) {
        if( ShouldHeadseek( knife, ent ) )
            seekablePlayers.append( ent )
    }

    // No headseek if no players
    if( seekablePlayers.len() == 0 )
        return velocity

    // Get the degrees to the closest (angle-wise) target
    float minAngleDist
    int minIndex

    for( int i = 0; i < seekablePlayers.len(); i++ ) {
        entity ent = seekablePlayers[i]

        float angleDist = DegreesToTarget( pos, velDir, ent.EyePosition() )

        minAngleDist = min(angleDist, minAngleDist)
        if( minAngleDist == angleDist )
            minIndex = i
    }

    vector toTarget = nearbyPlayers[minIndex].GetOrigin() - pos
    vector targetDir = Normalize( toTarget )
    float targetDist = Distance( pos, nearbyPlayers[minIndex].GetOrigin() )

    float minAng = KNIFE_HEADSEEK_MIN_ANGlE_FAR
    float maxAng = KNIFE_HEADSEEK_MAX_ANGLE_FAR
    float maxSeekFactor = KNIFE_HEADSEEK_FACTOR_FAR

    if(targetDist <= closeSeekRadius) {
        minAng = KNIFE_HEADSEEK_MAX_ANGLE_CLOSE
        maxAng = KNIFE_HEADSEEK_MAX_ANGLE_CLOSE
        maxSeekFactor = KNIFE_HEADSEEK_FACTOR_CLOSE
    }

    float dLerp = clamp((minAngleDist - minAng) / (maxAng - minAng), 0.0, 1.0)

    vector minAssist = VectorLerp( velDir, targetDir, maxSeekFactor )
    //vector minAssist = Normalize( velDir * (1 - maxSeekFactor) + targetDir * maxSeekFactor )
    vector assisted = VectorLerp( minAssist, targetDir, dLerp )
    //vector assisted = Normalize( minAssist * (1 - dLerp) + targetDir * dLerp )

    vector newVelocity = assisted * velMag
    return newVelocity
}

bool function ShouldHeadseek( entity knife, entity ent ) {
    if ( !IsAlive( ent ) )
		return false

	if ( ent.IsPhaseShifted() )
		return false

	TraceResults results = TraceLine( knife.GetOrigin(), ent.EyePosition(), knife, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )
	if ( results.fraction >= 1 || results.hitEnt == ent )
		return true

	return false
}

float function Magnitude( vector v ) {
    return Distance( Vector(0, 0, 0), v )
}

vector function VectorLerp( vector a, vector b, float lerp ) {
    return Normalize( a * (1 - lerp) + b * lerp )
}