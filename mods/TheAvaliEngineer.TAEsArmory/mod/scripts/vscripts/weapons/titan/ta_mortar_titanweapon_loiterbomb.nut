//	Function declarations
global function TArmory_Init_MortarTone_LoiterBomb

global function OnWeaponActivate_MortarTone_LoiterBomb

global function OnWeaponPrimaryAttack_MortarTone_LoiterBomb
#if SERVER
global function OnWeaponNpcPrimaryAttack_MortarTone_LoiterBomb
#endif

//		Vars
//	
const float FLIGHT_TIME = 1.0

//	Bomb
const float LOITER_RADIUS = 500.0
const float LOITER_HEIGHT = 300.0

const float BOMB_LIFETIME = 30.0

//		Functions
//	Init
void function TArmory_Init_MortarTone_LoiterBomb() {
	#if SERVER
	//  Precache weapon
	PrecacheWeapon( "ta_mortar_titanweapon_loiterbomb" )

	//	Damage source
	table<string, string> customDamageSourceIds = {
		ta_mortar_titanweapon_loiterbomb = "Loitering Munition",
	}
	RegisterWeaponDamageSources( customDamageSourceIds )
	#endif
}

//	Activate
void function OnWeaponActivate_MortarTone_LoiterBomb( entity weapon ) {

}

//	Fire handling
var function OnWeaponPrimaryAttack_MortarTone_LoiterBomb( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return LoiterBomb_Fire( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_MortarTone_LoiterBomb( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	return LoiterBomb_Fire( weapon, attackParams, false )
}
#endif

int function LoiterBomb_Fire( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {
	//	Sanity checks
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid(owner) || !IsAlive(owner) )
		return 0

	if(!(owner in flareData))
		return 0

	array<entity> flares = flareData[owner]
	if( flares.len() == 0 )
		return 0

	entity flare = flares[flares.len() - 1]
	if( !IsValid(flare) )
		return 0

	#if SERVER
	//	Place trigger
	LoiterBomb_Think( weapon, flare )
	#endif

	vector playerPos = attackParams.pos
	vector flarePos = flare.GetOrigin()

	int numProjectiles = weapon.GetProjectilesPerShot()

	int pendingShots = weapon.GetBurstFireShotsPending()
	int shotNum = weapon.GetWeaponSettingInt( eWeaponVar.burst_fire_count ) - pendingShots
	for ( int index = 0; index < numProjectiles; index++ ) {
		//	
		
		//	Calculate fire params
		vector angVel = Vector(0., 0., 0.)
		float fuse = FLIGHT_TIME + BOMB_LIFETIME

		int damageFlags = weapon.GetWeaponDamageFlags()
	}


	return weapon.GetAmmoPerShot()
}

#if SERVER
//	Functionality
void function LoiterBomb_Think( entity weapon, entity flare ) {
	//	Create trigger
	entity trig = CreateEntity( "trigger_cylinder" )

	trig.SetRadius( LOITER_RADIUS * 0.5 )
	trig.SetAboveHeight( 100 )
	trig.SetBelowHeight( 20 )

	trig.kv.triggerFilterNpc = "all"
	trig.kv.triggerFilterPlayer = "all"
	trig.kv.triggerFilterNonCharacter = "0"
	if ( flare.GetTeam() == TEAM_IMC )
		trig.kv.triggerFilterTeamIMC = "0"
	else if ( flare.GetTeam() == TEAM_MILITIA )
		trig.kv.triggerFilterTeamMilitia = "0"

	trig.SetOrigin( flare.GetOrigin() )
	DispatchSpawn( trig )

	bool safe = PutEntityInSafeSpot( trig, trig, weapon, trig.GetOrigin(), trig.GetOrigin() ) 
	if( !safe )
		return
}

void function LoiterBomb_Dive( entity weapon, ) {

}
#endif