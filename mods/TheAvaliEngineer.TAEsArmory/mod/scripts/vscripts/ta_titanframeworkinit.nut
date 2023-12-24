global function TA_TitanFramework_UIInit
void function TA_TitanFramework_UIInit() {
	#if TARMORY_HAS_TITANFRAMEWORK
	//	font is "alligator"

	//	      :::       ::: :::   ::: :::     ::: :::::::::: :::::::::  ::::    :::
	//	     :+:       :+: :+:   :+: :+:     :+: :+:        :+:    :+: :+:+:   :+:
	//	    +:+       +:+  +:+ +:+  +:+     +:+ +:+        +:+    +:+ :+:+:+  +:+
	//	   +#+  +:+  +#+   +#++:   +#+     +:+ +#++:++#   +#++:++#:  +#+ +:+ +#+
	//	  +#+ +#+#+ +#+    +#+     +#+   +#+  +#+        +#+    +#+ +#+  +#+#+#
	//	  #+#+# #+#+#     #+#      #+#+#+#   #+#        #+#    #+# #+#   #+#+#
	//	  ###   ###      ###        ###     ########## ###    ### ###    ####

	ModdedTitanData Wyvern

	//	Menu text
	Wyvern.Name = "#DEFAULT_TITAN_WYVERN"
	Wyvern.Description = "Your mother"
	Wyvern.passiveDisplayNameOverride = "#TITAN_OS_WYVERN_NAME"

	//	Menu hints
	Wyvern.difficulty = 2
	Wyvern.speedStat = 3
	Wyvern.damageStat = 2
	Wyvern.healthStat = 1
	Wyvern.titanHints = []

	//	Images

	//	Base titan
	Wyvern.BaseSetFile = "titan_stryder_sniper"
	Wyvern.BaseName = "northstar"

	//	Weapon
	ModdedTitanWeaponAbilityData AutoRocket
	AutoRocket.custom = true
	AutoRocket.displayName = "#TA_TITAN_WYVERN_WEAPON_AUTOROCKET"
	AutoRocket.weaponName = "ta_wyvern_titanweapon_autorocket"
	AutoRocket.description = "#TA_TITAN_WYVERN_WEAPON_AUTOROCKET_DESC"
	AutoRocket.image = $""
	Wyvern.Primary = AutoRocket

	//	Tactical
	ModdedTitanWeaponAbilityData WyvernThrusters
	WyvernThrusters.custom = true
	WyvernThrusters.displayName = "#TA_TITAN_WYVERN_TACTICAL_THRUSTERS"
	WyvernThrusters.weaponName = "ta_wyvern_titanweapon_thrusters"
	WyvernThrusters.description = "#TA_TITAN_WYVERN_TACTICAL_THRUSTERS_DESC"
	WyvernThrusters.image = $""
	Wyvern.Mid = WyvernThrusters

	//	Ordinance
	ModdedTitanWeaponAbilityData ChargeBall
	ChargeBall.custom = true
	ChargeBall.displayName = "#WPN_TITAN_CHARGE_BALL"
	ChargeBall.weaponName = "mp_titanweapon_charge_ball"
	ChargeBall.description = "#WPN_TITAN_CHARGE_BALL_DESC"
	ChargeBall.image = $"archon/menu/charge_ball"
	Wyvern.Right = ChargeBall

	//	Defensive
	ModdedTitanWeaponAbilityData TitanCloak2
	TitanCloak2.custom = true
	TitanCloak2.displayName = "#TA_TITAN_GEIST_DEFENSIVE_TITANCLOAK"
	TitanCloak2.weaponName = "ta_geist_titanability_titancloak" //"ta_wyvern_titanability_flight"
	TitanCloak2.description = "#TA_TITAN_GEIST_DEFENSIVE_TITANCLOAK_DESC"
	TitanCloak2.image = $""
	Wyvern.Left = TitanCloak2

	//Core
	ModdedTitanWeaponAbilityData StormCore
	StormCore.custom = true
	StormCore.weaponName = "mp_titancore_storm_core"
	StormCore.displayName = "#TITANCORE_STORM"
	StormCore.description = "#TITANCORE_STORM_DESC"
	StormCore.image = $"archon/hud/storm_core"
	Wyvern.Core = StormCore
	//*/

	CreateModdedTitanSimple(Wyvern)


	//		  	   	::::::::  :::::::::: ::::::::::: :::::::: :::::::::::
	//		      :+:    :+: :+:            :+:    :+:    :+:    :+:
	//		     +:+        +:+            +:+    +:+           +:+
	//		    :#:        +#++:++#       +#+    +#++:++#++    +#+
	//		   +#+   +#+# +#+            +#+           +#+    +#+
	//		  #+#    #+# #+#            #+#    #+#    #+#    #+#
	//		  ########  ########## ########### ########     ###

	ModdedTitanData Geist

	//	Menu text
	Geist.Name = "#DEFAULT_TITAN_GEIST"
	Geist.Description = "Your father"
	Geist.passiveDisplayNameOverride = "#TITAN_OS_GEIST_NAME"

	//	Menu hints
	Geist.difficulty = 2
	Geist.speedStat = 3
	Geist.damageStat = 2
	Geist.healthStat = 1
	Geist.titanHints = []

	//	Images

	//	Base titan
	Geist.BaseSetFile = "titan_stryder_shotgun"
	Geist.BaseName = "ronin"

	//	Weapon
	ModdedTitanWeaponAbilityData HeavyShotgun
	HeavyShotgun.custom = true
	HeavyShotgun.displayName = "#TA_TITAN_GEIST_WEAPON_BURSTSG"
	HeavyShotgun.weaponName = "ta_geist_titanweapon_burstsg"
	HeavyShotgun.description = "#TA_TITAN_GEIST_WEAPON_BURSTSG_DESC"
	HeavyShotgun.image = $""
	Geist.Primary = HeavyShotgun

	//	Tactical
	ModdedTitanWeaponAbilityData Holo
	Holo.custom = true
	Holo.displayName = "#TA_TITAN_GEIST_TACTICAL_HOLODISTRACT"
	Holo.weaponName = "ta_geist_titanability_holodistract"
	Holo.description = "#TA_TITAN_GEIST_TACTICAL_HOLODISTRACT_DESC"
	Holo.image = $""
	Geist.Mid = Holo

	//	Ordinance
	ModdedTitanWeaponAbilityData ChargeBall2
	ChargeBall2.custom = true
	ChargeBall2.displayName = "#WPN_TITAN_CHARGE_BALL"
	ChargeBall2.weaponName = "mp_titanweapon_charge_ball"
	ChargeBall2.description = "#WPN_TITAN_CHARGE_BALL_DESC"
	ChargeBall2.image = $"archon/menu/charge_ball"
	Geist.Right = ChargeBall2

	//	Defensive
	ModdedTitanWeaponAbilityData TitanCloak
	TitanCloak.custom = true
	TitanCloak.displayName = "#TA_TITAN_GEIST_DEFENSIVE_TITANCLOAK"
	TitanCloak.weaponName = "ta_geist_titanability_titancloak"
	TitanCloak.description = "#TA_TITAN_GEIST_DEFENSIVE_TITANCLOAK_DESC"
	TitanCloak.image = $""
	Geist.Left = TitanCloak

	//Core
	ModdedTitanWeaponAbilityData StormCore2
	StormCore2.custom = true
	StormCore2.weaponName = "mp_titancore_storm_core"
	StormCore2.displayName = "#TITANCORE_STORM"
	StormCore2.description = "#TITANCORE_STORM_DESC"
	StormCore2.image = $"archon/hud/storm_core"
	Geist.Core = StormCore2
	//*/

	CreateModdedTitanSimple(Geist)
	#endif
}
