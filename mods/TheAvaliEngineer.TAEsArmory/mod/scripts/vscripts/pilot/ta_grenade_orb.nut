//		Function Definitions
global function TArmory_Init_Grenade_Orb

global function OnWeaponTossReleaseAnimEvent_grenade_orb


//		Functions
//	Init
void function TArmory_Init_Grenade_Orb() {

}

//	Toss handling
var function OnWeaponTossReleaseAnimEvent_grenade_orb( entity weapon, WeaponPrimaryAttackParams attackParams ) {
	//	sfx
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	//	Lag compensation
	bool isPredicted = PROJECTILE_PREDICTED
	bool isLagCompensated = PROJECTILE_LAG_COMPENSATED
	#if SERVER
	if ( weapon.IsForceReleaseFromServer() ) {
		isPredicted = false
		isLagCompensated = false
	}
	#endif

	#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 0
	#endif
}