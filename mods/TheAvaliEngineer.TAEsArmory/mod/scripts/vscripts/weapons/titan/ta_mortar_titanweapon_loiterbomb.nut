//	Function declarations
global function TArmory_Init_TitanWeapon_LoiterBomb

global function OnWeaponPrimaryAttack_TitanWeapon_LoiterBomb
#if SERVER
global function OnWeaponNpcPrimaryAttack_TitanWeapon_LoiterBomb
#endif

//		Vars

//		Functions
//	Init
void function TArmory_Init_TitanWeapon_LoiterBomb() {
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

//	Fire handling
var function OnWeaponPrimaryAttack_TitanWeapon_LoiterBomb( entity weapon, WeaponPrimaryAttackParams attackParams ) {

}

#if SERVER
var function OnWeaponNpcPrimaryAttack_TitanWeapon_LoiterBomb( entity weapon, WeaponPrimaryAttackParams attackParams ) {

}
#endif

int function LoiterBomb_Fire(entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired ) {

}