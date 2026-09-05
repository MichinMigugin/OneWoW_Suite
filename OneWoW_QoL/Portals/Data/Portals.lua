local _, ns = ...

local Portals = {}
ns.PortalData = Portals

Portals.Categories = {
	RINGS = "rings",
	CLOAKS = "cloaks",
	TABARDS = "tabards",
	ENGINEERING = "engineering",
	CONSUMABLES = "consumables",
	SPECIAL_ITEMS = "special_items",
	CLASS_SPELLS = "class_spells",
	RACIAL = "racial",
	DUNGEONS = "dungeons",
	RAIDS = "raids",
	MAGE_TELEPORTS = "mage_teleports",
	MAGE_PORTALS = "mage_portals",
}

local function IsFaction(faction)
	return UnitFactionGroup("player") == faction
end

local function IsRace(race)
	local _, playerRace = UnitRace("player")
	return playerRace == race
end

local function IsDraenei()
	local _, _, raceId = UnitRace("player")
	return raceId == 11 or raceId == 30
end

local function IsWorgen()
	return IsRace("Worgen")
end

local function IsClass(classFile)
	local _, class = UnitClass("player")
	return class == classFile
end

Portals.Items = {
	rings = {
		{id = 32757, name = "Blessed Medallion of Karabor", type = "item"},
		{id = 40586, name = "Band of the Kirin Tor", type = "item"},
		{id = 44935, name = "Ring of the Kirin Tor", type = "item"},
		{id = 40585, name = "Signet of the Kirin Tor", type = "item"},
		{id = 44934, name = "Loop of the Kirin Tor", type = "item"},
		{id = 45688, name = "Inscribed Band of the Kirin Tor", type = "item"},
		{id = 45690, name = "Inscribed Ring of the Kirin Tor", type = "item"},
		{id = 45691, name = "Inscribed Signet of the Kirin Tor", type = "item"},
		{id = 45689, name = "Inscribed Loop of the Kirin Tor", type = "item"},
		{id = 48954, name = "Etched Band of the Kirin Tor", type = "item"},
		{id = 48955, name = "Etched Loop of the Kirin Tor", type = "item"},
		{id = 48956, name = "Etched Ring of the Kirin Tor", type = "item"},
		{id = 48957, name = "Etched Signet of the Kirin Tor", type = "item"},
		{id = 51557, name = "Runed Signet of the Kirin Tor", type = "item"},
		{id = 51558, name = "Runed Loop of the Kirin Tor", type = "item"},
		{id = 51559, name = "Runed Ring of the Kirin Tor", type = "item"},
		{id = 51560, name = "Runed Band of the Kirin Tor", type = "item"},
		{id = 52251, name = "Jaina's Locket", type = "item"},
		{id = 139599, name = "Empowered Ring of the Kirin Tor", type = "item"},
	},

	cloaks = {
		{id = 63206, name = "Wrap of Unity: Stormwind", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 63207, name = "Wrap of Unity: Orgrimmar", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 63352, name = "Shroud of Cooperation: Stormwind", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 63353, name = "Shroud of Cooperation: Orgrimmar", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 65274, name = "Cloak of Coordination: Orgrimmar", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 65360, name = "Cloak of Coordination: Stormwind", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 169064, name = "Mountebank's Colorful Cloak", type = "item"},
	},

	tabards = {
		{id = 46874, name = "Argent Crusader's Tabard", type = "item"},
		{id = 63378, name = "Hellscream's Reach Tabard", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 63379, name = "Baradin's Wardens Tabard", type = "item", condition = function() return IsFaction("Alliance") end},
	},

	engineering = {
		wormholes = {
			{id = 48933, name = "Wormhole Generator: Northrend", type = "toy"},
			{id = 87215, name = "Wormhole Generator: Pandaria", type = "toy"},
			{id = 112059, name = "Wormhole Centrifuge", type = "toy"},
			{id = 151652, name = "Wormhole Generator: Argus", type = "toy"},
			{id = 168807, name = "Wormhole Generator: Kul Tiras", type = "toy"},
			{id = 168808, name = "Wormhole Generator: Zandalar", type = "toy"},
			{id = 172924, name = "Wormhole Generator: Shadowlands", type = "toy"},
			{id = 198156, name = "Wyrmhole Generator: Dragon Isles", type = "toy"},
			{id = 221966, name = "Wormhole Generator: Khaz Algar", type = "toy"},
			{id = 248485, name = "Wormhole Generator: Quel'Thalas", type = "toy"},
		},
		rippers = {
			{id = 30542, name = "Dimensional Ripper - Area 52", type = "toy"},
			{id = 18984, name = "Dimensional Ripper - Everlook", type = "toy"},
		},
		transporters = {
			{id = 18986, name = "Ultrasafe Transporter: Gadgetzan", type = "toy"},
			{id = 30544, name = "Ultrasafe Transporter: Toshley's Station", type = "toy"},
			{id = 167075, name = "Ultrasafe Transporter: Mechagon", type = "item"},
		},
		other = {
			{id = 132523, name = "Reaves Battery", type = "item"},
			{id = 144341, name = "Rechargeable Reaves Battery", type = "item"},
		},
	},

	consumables = {
		{id = 37118, name = "Scroll of Recall", type = "item"},
		{id = 44314, name = "Scroll of Recall II", type = "item"},
		{id = 44315, name = "Scroll of Recall III", type = "item"},
		{id = 58487, name = "Potion of Deepholm", type = "item"},
		{id = 116413, name = "Scroll of Town Portal", type = "item"},
		{id = 119183, name = "Scroll of Risky Recall", type = "item"},
		{id = 141013, name = "Scroll of Town Portal: Shala'nir", type = "item"},
		{id = 141014, name = "Scroll of Town Portal: Sashj'tar", type = "item"},
		{id = 141015, name = "Scroll of Town Portal: Kal'delar", type = "item"},
		{id = 141016, name = "Scroll of Town Portal: Faronaar", type = "item"},
		{id = 141017, name = "Scroll of Town Portal: Lian'tril", type = "item"},
		{id = 142543, name = "Scroll of Town Portal", type = "item"},
		{id = 150733, name = "Scroll of Town Portal", type = "item"},
		{id = 160219, name = "Scroll of Town Portal", type = "item"},
		{id = 163694, name = "Scroll of Luxurious Recall", type = "item"},
		{id = 173528, name = "Gilded Hearthstone", type = "item"},
		{id = 173532, name = "Tirisfal Camp Scroll", type = "item"},
		{id = 173537, name = "Glowing Hearthstone", type = "item"},
		{id = 180817, name = "Cypher of Relocation", type = "item"},
		{id = 181163, name = "Scroll of Teleport: Theater of Pain", type = "item"},
		{id = 184500, name = "Attendant's Pocket Portal: Bastion", type = "item"},
		{id = 184501, name = "Attendant's Pocket Portal: Revendreth", type = "item"},
		{id = 184502, name = "Attendant's Pocket Portal: Maldraxxus", type = "item"},
		{id = 184503, name = "Attendant's Pocket Portal: Ardenweald", type = "item"},
		{id = 184504, name = "Attendant's Pocket Portal: Oribos", type = "item"},
		{id = 200613, name = "Aylaag Windstone Fragment", type = "item"},
		{id = 238727, name = "Nostwin's Voucher", type = "item"},
		{id = 162515, name = "Midnight Salmon", type = "item"},
		{id = 279550, name = "Potion of Venomous Return", type = "item"},
	},

	special_items = {
		{id = 37863, name = "Direbrew's Remote", type = "item"},
		{id = 50287, name = "Boots of the Bay", type = "item"},
		{id = 61379, name = "Gidwin's Hearthstone", type = "item"},
		{id = 64457, name = "The Last Relic of Argus", type = "item"},
		{id = 68808, name = "Hero's Hearthstone", type = "item"},
		{id = 68809, name = "Veteran's Hearthstone", type = "item"},
		{id = 87548, name = "Lorewalker's Lodestone", type = "item"},
		{id = 92510, name = "Vol'jin's Hearthstone", type = "item"},
		{id = 95050, name = "The Brassiest Knuckle", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 95051, name = "The Brassiest Knuckle", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 95567, name = "Kirin Tor Beacon", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 95568, name = "Sunreaver Beacon", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 103678, name = "Time-Lost Artifact", type = "item"},
		{id = 117389, name = "Draenor Archaeologist's Lodestone", type = "item"},
		{id = 118662, name = "Bladespire Relic", type = "item"},
		{id = 118663, name = "Relic of Karabor", type = "item"},
		{id = 118907, name = "Pit Fighter's Punching Ring", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 118908, name = "Pit Fighter's Punching Ring", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 128353, name = "Admiral's Compass", type = "item"},
		{id = 128502, name = "Hunter's Seeking Crystal", type = "item"},
		{id = 128503, name = "Master Hunter's Seeking Crystal", type = "item"},
		{id = 129276, name = "Beginner's Guide to Dimensional Rifting", type = "item"},
		{id = 132119, name = "Orgrimmar Portal Stone", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 132120, name = "Stormwind Portal Stone", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 132517, name = "Intra-Dalaran Wormhole Generator", type = "item"},
		{id = 138448, name = "Emblem of Margoss", type = "item"},
		{id = 139590, name = "Scroll of Teleport: Ravenholdt", type = "item"},
		{id = 140493, name = "Adept's Guide to Dimensional Rifting", type = "item"},
		{id = 140324, name = "Mobile Telemancy Beacon", type = "toy"},
		{id = 141324, name = "Talisman of the Shal'dorei", type = "item"},
		{id = 141605, name = "Flight Master's Whistle", type = "item"},
		{id = 142298, name = "Astonishingly Scarlet Slippers", type = "item"},
		{id = 142469, name = "Violet Seal of the Grand Magus", type = "item"},
		{id = 144391, name = "Pugilist's Powerful Punching Ring", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 144392, name = "Pugilist's Powerful Punching Ring", type = "item", condition = function() return IsFaction("Horde") end},
		{id = 151016, name = "Fractured Necrolyte Skull", type = "item"},
		{id = 159224, name = "Zuldazar Hearthstone", type = "item"},
		{id = 166559, name = "Commander's Signet of Battle", type = "item"},
		{id = 166560, name = "Captain's Signet of Command", type = "item"},
		{id = 168862, name = "G.E.A.R. Tracking Beacon", type = "item"},
		{id = 169297, name = "Stormpike Insignia", type = "item", condition = function() return IsFaction("Alliance") end},
		{id = 172203, name = "Cracked Hearthstone", type = "item"},
		{id = 173373, name = "Faol's Hearthstone", type = "item"},
		{id = 173430, name = "Nexus Teleport Scroll", type = "item"},
		{id = 173716, name = "Mossy Hearthstone", type = "item"},
		{id = 180817, name = "Cypher of Relocation", type = "item"},
		{id = 189827, name = "Cartel Xy's Proof of Initiation", type = "item"},
		{id = 191029, name = "Lilian's Hearthstone", type = "item"},
		{id = 193000, name = "Ring-Bound Hourglass", type = "item"},
		{id = 201957, name = "Thrall's Hearthstone", type = "item"},
		{id = 202046, name = "Lucky Tortollan Charm", type = "item"},
		{id = 204481, name = "Morqut Hearth Totem", type = "item"},
		{id = 205255, name = "Niffen Diggin' Mitts", type = "item"},
		{id = 205456, name = "Lost Dragonscale", type = "item"},
		{id = 205458, name = "Lost Dragonscale", type = "item"},
		{id = 211788, name = "Tess's Peacebloom", type = "item", condition = IsWorgen},
		{id = 230850, name = "Delve-O-Bot 7001", type = "toy"},
		{id = 234389, name = "Gallagio Loyalty Rewards Card: Silver", type = "item"},
		{id = 234390, name = "Gallagio Loyalty Rewards Card: Gold", type = "item"},
		{id = 234391, name = "Gallagio Loyalty Rewards Card: Platinum", type = "item"},
		{id = 234392, name = "Gallagio Loyalty Rewards Card: Black", type = "item"},
		{id = 234393, name = "Gallagio Loyalty Rewards Card: Diamond", type = "item"},
		{id = 234394, name = "Gallagio Loyalty Rewards Card: Legendary", type = "item"},
		{id = 243056, name = "Delver's Mana-Bound Ethergate", type = "item"},
		{id = 249699, name = "Shadowguard Translocator", type = "item"},
		{id = 253629, name = "Personal Key to the Arcantina", type = "toy"},
		{id = 276371, name = "Lightveil Recall Beacon", type = "toy"},
		{id = 266370, name = "Dundun's Abundant Travel Method", type = "toy"},
		{id = 43824, name = "The Schools of Arcane Magic - Mastery", type = "toy"},
		{id = 136849, name = "Nature's Beacon", type = "toy", condition = function() return IsClass("DRUID") end},
		{id = 28585, name = "Ruby Slippers", type = "item"},
		{id = 153226, name = "Observer's Locus Resonator", type = "item"},
		{id = 165581, name = "Crest of Pa'ku", type = "item"},
		{id = 169114, name = "Personal Time Displacer", type = "item"},
		{id = 21711, name = "Lunar Festival Invitation", type = "item"},
		{id = 17690, name = "Frostwolf Insignia Rank 1", type = "item"},
		{id = 17905, name = "Frostwolf Insignia Rank 2", type = "item"},
		{id = 17906, name = "Frostwolf Insignia Rank 3", type = "item"},
		{id = 17907, name = "Frostwolf Insignia Rank 4", type = "item"},
		{id = 17908, name = "Frostwolf Insignia Rank 5", type = "item"},
		{id = 17909, name = "Frostwolf Insignia Rank 6", type = "item"},
		{id = 17691, name = "Stormpike Insignia Rank 1", type = "item"},
		{id = 17900, name = "Stormpike Insignia Rank 2", type = "item"},
		{id = 17901, name = "Stormpike Insignia Rank 3", type = "item"},
		{id = 17902, name = "Stormpike Insignia Rank 4", type = "item"},
		{id = 17903, name = "Stormpike Insignia Rank 5", type = "item"},
		{id = 17904, name = "Stormpike Insignia Rank 6", type = "item"},
		{id = 18149, name = "Rune of Recall", type = "item"},
		{id = 18150, name = "Rune of Recall", type = "item"},
		{id = 22589, name = "Atiesh, Greatstaff of the Guardian", type = "item"},
		{id = 22630, name = "Atiesh, Greatstaff of the Guardian", type = "item"},
		{id = 22631, name = "Atiesh, Greatstaff of the Guardian", type = "item"},
		{id = 22632, name = "Atiesh, Greatstaff of the Guardian", type = "item"},
		{id = 54452, name = "Ethereal Portal", type = "item"},
		{id = 64488, name = "The Innkeeper's Daughter", type = "item"},
		{id = 93672, name = "Dark Portal", type = "item"},
		{id = 129929, name = "Ever-Shifting Mirror", type = "item"},
		{id = 210455, name = "Draenic Hologem", type = "item", condition = IsDraenei},
	},
}

-- 2-4 character ESC overlays. English community shorts (keys / RIO).
Portals.ShortNames = {
	[410080] = "VP",
	[424142] = "ToTT",
	[445424] = "GB",
	[131204] = "TJS",
	[131205] = "SB",
	[131206] = "SPM",
	[131222] = "MP",
	[131225] = "GATE",
	[131228] = "SoN",
	[131229] = "SM",
	[131231] = "SH",
	[131232] = "SCHL",
	[159901] = "EB",
	[159899] = "SBG",
	[159900] = "GD",
	[159896] = "ID",
	[159895] = "BSM",
	[159897] = "AUCH",
	[159898] = "SKY",
	[159902] = "UBRS",
	[1254557] = "SKY",
	[393764] = "HoV",
	[410078] = "NL",
	[393766] = "CoS",
	[373262] = "KARA",
	[424153] = "BRH",
	[424163] = "DHT",
	[1254551] = "SotT",
	[252631] = "SotT",
	[410071] = "FH",
	[410074] = "UR",
	[373274] = "MECH",
	[424167] = "WM",
	[424187] = "AD",
	[445418] = "SoB",
	[464256] = "SoB",
	[467553] = "ML",
	[467555] = "ML",
	[1286828] = "Seth",
	[1286831] = "KR",
	[354462] = "NW",
	[354463] = "PF",
	[354464] = "MoTS",
	[354465] = "HoA",
	[354466] = "SoA",
	[354467] = "ToP",
	[354468] = "DOS",
	[354469] = "SD",
	[367416] = "TAZ",
	[373190] = "CN",
	[373191] = "SoD",
	[373192] = "SoFO",
	[393256] = "RLP",
	[393262] = "NO",
	[393267] = "BH",
	[393273] = "AA",
	[393276] = "NELT",
	[393279] = "AV",
	[393283] = "HoI",
	[393222] = "ULD",
	[424197] = "DotI",
	[432254] = "VotI",
	[432257] = "Abb",
	[432258] = "Amir",
	[445416] = "CoT",
	[445414] = "DB",
	[445269] = "SV",
	[445443] = "ROOK",
	[445440] = "CBM",
	[445444] = "PoSF",
	[445417] = "AK",
	[445441] = "DFC",
	[1216786] = "FL",
	[1237215] = "EDA",
	[1226482] = "LOU",
	[1239155] = "MO",
	[1254400] = "WS",
	[1254559] = "MC",
	[1254563] = "NP",
	[1254572] = "MT",
	[1254555] = "PIT",
	[1286801] = "VALE",
	[1286804] = "VSA",
	[1286807] = "DEN",
	[1286809] = "MR",
	[1286812] = "AoF",
	[3561] = "SW",
	[3562] = "IF",
	[3563] = "UC",
	[3565] = "DS",
	[3566] = "TB",
	[3567] = "ORG",
	[32271] = "Ex",
	[32272] = "SMB",
	[33690] = "Shat",
	[35715] = "Shat",
	[49358] = "Sto",
	[49359] = "Th",
	[53140] = "DN",
	[88342] = "ToB",
	[88344] = "ToB",
	[120145] = "DAP",
	[132621] = "VEB",
	[132627] = "VEB",
	[176242] = "War",
	[176248] = "SS",
	[193759] = "HoG",
	[224869] = "DBI",
	[281403] = "Bor",
	[281404] = "Daz",
	[344587] = "Ori",
	[395277] = "Val",
	[446540] = "Dorn",
	[1259190] = "SMM",
	[10059] = "SW",
	[11416] = "IF",
	[11417] = "ORG",
	[11418] = "UC",
	[11419] = "DS",
	[11420] = "TB",
	[32266] = "Ex",
	[32267] = "SMB",
	[33691] = "Shat",
	[35717] = "Shat",
	[49360] = "Th",
	[49361] = "Sto",
	[53142] = "DN",
	[88345] = "ToB",
	[88346] = "ToB",
	[120146] = "DAP",
	[132620] = "VEB",
	[132626] = "VEB",
	[176244] = "War",
	[176246] = "SS",
	[224871] = "DBI",
	[281400] = "Bor",
	[281402] = "Daz",
	[344597] = "Ori",
	[395289] = "Val",
	[446534] = "Dorn",
	[1259194] = "SMM",
}

function Portals:GetItemsByCategory(category)
	if category == self.Categories.RINGS then
		return self.Items.rings
	elseif category == self.Categories.CLOAKS then
		return self.Items.cloaks
	elseif category == self.Categories.TABARDS then
		return self.Items.tabards
	elseif category == self.Categories.ENGINEERING then
		local allEng = {}
		for _, wh in ipairs(self.Items.engineering.wormholes) do
			table.insert(allEng, wh)
		end
		for _, rip in ipairs(self.Items.engineering.rippers) do
			table.insert(allEng, rip)
		end
		for _, trans in ipairs(self.Items.engineering.transporters) do
			table.insert(allEng, trans)
		end
		for _, other in ipairs(self.Items.engineering.other) do
			table.insert(allEng, other)
		end
		return allEng
	elseif category == self.Categories.CONSUMABLES then
		return self.Items.consumables
	elseif category == self.Categories.SPECIAL_ITEMS then
		return self.Items.special_items
	end
	return {}
end

function Portals:GetShortName(spellId)
	return self.ShortNames[spellId]
end

function Portals:IsItemAvailable(itemData)
	if itemData.condition and type(itemData.condition) == "function" then
		if not itemData.condition() then
			return false
		end
	end

	if itemData.type == "toy" then
		return PlayerHasToy(itemData.id)
	elseif itemData.type == "item" then
		return C_Item.GetItemCount(itemData.id) > 0 or PlayerHasToy(itemData.id)
	end

	return false
end

local InvTypeToSlot = {
	["INVTYPE_HEAD"] = 1,
	["INVTYPE_NECK"] = 2,
	["INVTYPE_SHOULDER"] = 3,
	["INVTYPE_BODY"] = 4,
	["INVTYPE_CHEST"] = 5,
	["INVTYPE_ROBE"] = 5,
	["INVTYPE_WAIST"] = 6,
	["INVTYPE_LEGS"] = 7,
	["INVTYPE_FEET"] = 8,
	["INVTYPE_WRIST"] = 9,
	["INVTYPE_HAND"] = 10,
	["INVTYPE_FINGER"] = 11,
	["INVTYPE_TRINKET"] = 13,
	["INVTYPE_CLOAK"] = 15,
	["INVTYPE_2HWEAPON"] = 16,
	["INVTYPE_WEAPONMAINHAND"] = 16,
	["INVTYPE_TABARD"] = 19
}

function Portals:GetItemSlot(itemId)
	local _, _, _, _, _, _, _, _, equipSlot = C_Item.GetItemInfo(itemId)
	if equipSlot and InvTypeToSlot[equipSlot] then
		return InvTypeToSlot[equipSlot]
	end
	return nil
end

function Portals:IsItemEquippable(itemId)
	return C_Item.IsEquippableItem(itemId)
end

function Portals:IsItemEquipped(itemId)
	return C_Item.IsEquippableItem(itemId) and C_Item.IsEquippedItem(itemId)
end
