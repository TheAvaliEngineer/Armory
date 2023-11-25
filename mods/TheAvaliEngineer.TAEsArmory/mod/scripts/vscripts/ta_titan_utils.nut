//		Function definitions
global function TArmory_Init_TitanUtils

//		Data
//	Struct def
struct {
	table< string, string > titanClass

	table< string, table< string, string > > weapons
	table< string, int > slot


	table< string, table< int, string > > giveTable
} file

//		Functions
//	Init
void function TArmory_Init_TitanUtils() {
	//	Fill table
	file.giveTable["ronin"] <- {}
	file.giveTable["ronin"][-7] <- "ta_geist_titanweapon_burstsg"
	file.giveTable["ronin"][OFFHAND_ANTIRODEO] <- "ta_geist_titanability_holodistract"
//	file.giveTable["ronin"][OFFHAND_ORDNANCE] <- "titancloak"
	file.giveTable["ronin"][OFFHAND_SPECIAL] <- "ta_geist_titanability_titancloak"
//	file.giveTable["ronin"][OFFHAND_EQUIPMENT] <- "titancloak"

	file.giveTable["tone"] <- {}
	file.giveTable["tone"][-7] <- "ta_mortar_titanweapon_quadrocket"
	file.giveTable["tone"][OFFHAND_ANTIRODEO] <- "ta_mortar_titanability_flares"
	file.giveTable["tone"][OFFHAND_ORDNANCE] <- "ta_mortar_titanweapon_rockets"
	file.giveTable["tone"][OFFHAND_SPECIAL] <- "ta_mortar_titanweapon_proxmines"
	file.giveTable["tone"][OFFHAND_EQUIPMENT] <- "ta_mortar_titancore_nuclearstrike"

	file.giveTable["scorch"] <- {}
	file.giveTable["scorch"][-7] <- "ta_phosphor_titanweapon_flamethrower"
//	file.giveTable["scorch"][OFFHAND_ANTIRODEO] <- "ta_tyrant_titanability_titangrapple"
	file.giveTable["scorch"][OFFHAND_ORDNANCE]	<- "ta_phosphor_titanweapon_incendiaryshell"
//	file.giveTable["scorch"][OFFHAND_SPECIAL] <- ""
//	file.giveTable["scorch"][OFFHAND_EQUIPMENT] <- ""

	file.giveTable["legion"] <- {}
	file.giveTable["legion"][-7] <- "ta_tyrant_titanweapon_autocannon"
//	file.giveTable["legion"][OFFHAND_ANTIRODEO] <- "ta_mortar_titanability_flares"
//	file.giveTable["legion"][OFFHAND_ORDNANCE] <- "ta_mortar_titanweapon_rockets"
//	file.giveTable["legion"][OFFHAND_SPECIAL] <- "ta_mortar_titanweapon_proxmines"
//	file.giveTable["legion"][OFFHAND_EQUIPMENT] <- "ta_mortar_titancore_nuclearstrike"

	file.giveTable["northstar"] <- {}
	file.giveTable["northstar"][-7] <- "ta_wyvern_titanweapon_autorocket"
	file.giveTable["northstar"][OFFHAND_ANTIRODEO] <- "ta_wyvern_titanweapon_afterburners"
	file.giveTable["northstar"][OFFHAND_ORDNANCE] <- "mp_titanweapon_shoulder_rockets" //"mp_titanweapon_homing_rockets"
	file.giveTable["northstar"][OFFHAND_SPECIAL] <- "ta_wyvern_titanability_flight"
//	file.giveTable["northstar"][OFFHAND_EQUIPMENT] <- "ta_mortar_titancore_nuclearstrike"

	#if SERVER
	AddSpawnCallback( "npc_titan", ReplaceTitanIfEnabled )
	#endif
}

#if SERVER
void function ReplaceTitanIfEnabled( entity titan ) {
	//	Validity checks
	if ( !IsValid( titan ) )
		return

	entity player = GetPetTitanOwner( titan )
	if ( !IsValid( player ) )
		return

	//	Check if replacement is enabled (has arm badge)
	TitanLoadoutDef loadout = GetActiveTitanLoadout( player ) //GetTitanLoadoutFromPersistentData( player, GetPersistentSpawnLoadoutIndex( player, "titan" ) )
	print("[TAEsArmory] ReplaceTitanIfEnabled: loadout.showArmBadge = " + loadout.showArmBadge)
	if( loadout.showArmBadge ) {
		//	Get replacement data
		if( loadout.titanClass in file.giveTable ) {
			//	Take all but melee
			TakeAllWeapons( titan )
			titan.GiveOffhandWeapon( loadout.melee, OFFHAND_MELEE )

			//	Index giveTable
			table< int, string > weapons = file.giveTable[loadout.titanClass]

			//	Replace primary
			titan.GiveWeapon( file.giveTable[loadout.titanClass][-7] )

			entity primary = titan.GetActiveWeapon()
			primary.SetSkin( loadout.primarySkinIndex )
			primary.SetCamo( loadout.primaryCamoIndex )

			//	Replace offhands
			foreach( idx, name in weapons ) {
				if( idx == -7 ) continue

				titan.TakeOffhandWeapon( idx )
				titan.GiveOffhandWeapon( name, idx )
			}
		}
	}
}
#endif
