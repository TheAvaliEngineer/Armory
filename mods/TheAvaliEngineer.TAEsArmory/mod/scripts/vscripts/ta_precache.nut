untyped

//		Function definitions
global function TArmory_Precache

//		Functions
//	Precache
void function TArmory_Precache() {
	table<string, string> cdsIds

	//		Pilot
	//	Primaries
	PrecacheHelper( "ta_weapon_thermiteshotgun", "S-60", cdsIds )
	TArmory_Init_Weapon_ChargeShotgun()

	TArmory_Init_Weapon_PlasmaBurst()

	TArmory_Init_Weapon_Railgun()

	//	Secondaries
	TArmory_Init_Weapon_ChargePistol()
	PrecacheHelper( "ta_weapon_impulsegl", "Impulse Launcher", cdsIds )

	//	Anti-Titan
	TArmory_Init_AntiTitan_MineLauncher()
	PrecacheHelper( "ta_weapon_microgun", "Vulkan", cdsIds )
	PrecacheHelper( "ta_weapon_heatray", "Heat Ray", cdsIds )

	//	Grenades
	TArmory_Init_GrenadeKnife()
	TArmory_Init_GrenadeFuelTrail()


	//	Abilities

	//		Titan
	//	Mortar
	TArmory_Init_MortarTone_QuadRocket()

	TArmory_Init_MortarTone_FlareLauncher()
	TArmory_Init_MortarTone_Flares()
	TArmory_Init_MortarTone_Rockets()
	PrecacheHelper( "ta_mortar_titanweapon_proxmines", "Minefield", cdsIds )
	TArmory_Init_MortarTone_NuclearStrike()

	//	Geist
	TArmory_Init_GeistRonin_BurstSG()
	TArmory_Init_GeistRonin_HoloDistract()
	//
	TArmory_Init_GeistRonin_TitanCloak()
	//

	//	Wyvern
	PrecacheHelper( "ta_wyvern_titanweapon_autorocket", "Swarmer", cdsIds )
	TArmory_Init_WyvernNorthstar_Afterburners()
	//
	TArmory_Init_WyvernNorthstar_Flight()
	//

	//	Phosphor
	TArmory_Init_PhosphorScorch_Flamethrower()
	//
	TArmory_Init_PhosphorScorch_IncendiaryShell()
	//
	//


	//	Tyrant
	PrecacheHelper( "ta_tyrant_titanweapon_autocannon", "Autocannon", cdsIds )
	//
	//
	//
	//

	//	Bruiser
	//
	TArmory_Init_BruiserScorch_TitanGrapple()
	//
	//
	//



	//		Damage sources
	#if SERVER
	RegisterWeaponDamageSources( cdsIds )
	#endif
}

void function PrecacheHelper( string path, string name, table< string, string > ids ) {
	PrecacheWeapon( path )
	array<string> parts = split( "path", "_" )
	string id = parts[ parts.len() - 1 ]
	ids[id] <- name
}
