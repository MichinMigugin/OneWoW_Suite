local _, ns = ...

local OneWoW = OneWoW

ns.PortalHubDetection = ns.PortalHubDetection or {}
local Detection = ns.PortalHubDetection

local ENGINEERING_TOYS = {
	[18984] = true,
	[18986] = true,
	[30542] = true,
	[30544] = true,
	[48933] = true,
	[87215] = true,
	[112059] = true,
	[151652] = true,
	[168807] = true,
	[168808] = true,
	[172924] = true,
	[198156] = true,
	[212337] = true,
	[221966] = true,
	[248485] = true,
}

local ENGINEERING_ITEMS = {
	[132523] = true,
	[144341] = true,
	[167075] = true,
}

local housingHouse = nil
local housingRequested = false
local housingLoaded = false
local housingCallbacks = {}
local housingButtons = {}
local housingEventFrame = CreateFrame("Frame")

local HOUSING_ATLAS_TELEPORT = "dashboard-panel-homestone-teleport-button"
local HOUSING_ATLAS_RETURN = "dashboard-panel-homestone-teleport-out-button"

local MAX_EXPANSION_SEASON_ORDINAL = 12

---@param portals table
---@param spellID number
---@param showAll boolean
local function AppendSpellPortal(portals, spellID, showAll)
	local known = C_SpellBook.IsSpellKnown(spellID)
	if known or showAll then
		tinsert(portals, {type = "spell", id = spellID, available = known})
	end
end

--- Per-expansion season ordinal from live Mythic+ APIs (1, 2, 3…).
---@return number|nil
function Detection:GetCurrentSeasonNumber()
	local displayNum = C_MythicPlus.GetCurrentSeasonValues()
	if displayNum and displayNum > 0 and displayNum <= MAX_EXPANSION_SEASON_ORDINAL then
		return displayNum
	end
	local uiSeason = C_MythicPlus.GetCurrentUIDisplaySeason()
	if uiSeason and uiSeason > 0 and uiSeason <= MAX_EXPANSION_SEASON_ORDINAL then
		return uiSeason
	end
	if C_MythicPlus.GetCurrentSeason() == -1 then
		C_MythicPlus.RequestMapInfo()
		displayNum = C_MythicPlus.GetCurrentSeasonValues()
		if displayNum and displayNum > 0 and displayNum <= MAX_EXPANSION_SEASON_ORDINAL then
			return displayNum
		end
		uiSeason = C_MythicPlus.GetCurrentUIDisplaySeason()
		if uiSeason and uiSeason > 0 and uiSeason <= MAX_EXPANSION_SEASON_ORDINAL then
			return uiSeason
		end
	end
	return nil
end

local function ApplyPendingHousingCallbacks()
	if OneWoW.Restriction.IsProtectedActionBlocked() then
		OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.housing", ApplyPendingHousingCallbacks)
		return
	end

	for _, callback in ipairs(housingCallbacks) do
		callback(housingHouse)
	end
	wipe(housingCallbacks)
end

local function TrackHousingButton(button, suffix)
	for i = 1, #housingButtons do
		local entry = housingButtons[i]
		if entry.button == button then
			entry.suffix = suffix
			return
		end
	end
	tinsert(housingButtons, { button = button, suffix = suffix })
end

local function RefreshTrackedHousingButtons()
	for i = #housingButtons, 1, -1 do
		local entry = housingButtons[i]
		local button = entry.button
		if not button or not button:GetParent() or not button:IsShown() then
			tremove(housingButtons, i)
		else
			Detection:ApplyHousingTeleportAttributes(button, entry.suffix)
		end
	end
end

housingEventFrame:RegisterEvent("HOUSE_PLOT_ENTERED")
housingEventFrame:RegisterEvent("HOUSE_PLOT_EXITED")
housingEventFrame:SetScript("OnEvent", function(self, event, houses)
	if event == "PLAYER_HOUSE_LIST_UPDATED" then
		housingHouse = houses and houses[1] or nil
		housingLoaded = true
		self:UnregisterEvent("PLAYER_HOUSE_LIST_UPDATED")
		ApplyPendingHousingCallbacks()
	elseif event == "HOUSE_PLOT_ENTERED" or event == "HOUSE_PLOT_EXITED" then
		RefreshTrackedHousingButtons()
	end
end)

function Detection:RequestHousingHouse(callback)
	if callback then
		if housingLoaded then
			callback(housingHouse)
			return
		end
		tinsert(housingCallbacks, callback)
	end

	if housingRequested then
		return
	end

	housingRequested = true
	housingEventFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
	C_Housing.GetPlayerOwnedHouses()
end

--- True when the housing button should return to the prior location (Blizzard dashboard rule).
---@param house table|nil
---@return boolean
function Detection:ShouldReturnAfterVisitingHouse(house)
	if not house or not house.neighborhoodGUID then
		return false
	end
	if not C_HousingNeighborhood.CanReturnAfterVisitingHouse() then
		return false
	end
	local currentNeighborhoodGUID = C_Housing.GetCurrentNeighborhoodGUID()
	return currentNeighborhoodGUID ~= nil and currentNeighborhoodGUID == house.neighborhoodGUID
end

function Detection:ApplyHousingTeleportAttributes(button, suffix)
	suffix = suffix or ""
	TrackHousingButton(button, suffix)
	button._onewowHousingRequestToken = (button._onewowHousingRequestToken or 0) + 1
	local requestToken = button._onewowHousingRequestToken
	button._onewowHousingIsReturn = false
	button:SetAttribute("type" .. suffix, nil)
	button:SetAttribute("house-neighborhood-guid" .. suffix, nil)
	button:SetAttribute("house-guid" .. suffix, nil)
	button:SetAttribute("house-plot-id" .. suffix, nil)

	local function applyHouse(house)
		if button._onewowHousingRequestToken ~= requestToken then
			return
		end

		if OneWoW.Restriction.IsProtectedActionBlocked() then
			tinsert(housingCallbacks, applyHouse)
			OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_QoL.portalhub.housing", ApplyPendingHousingCallbacks)
			return
		end

		button:SetAttribute("type" .. suffix, nil)
		button:SetAttribute("house-neighborhood-guid" .. suffix, nil)
		button:SetAttribute("house-guid" .. suffix, nil)
		button:SetAttribute("house-plot-id" .. suffix, nil)

		local shouldReturn = Detection:ShouldReturnAfterVisitingHouse(house)
		button._onewowHousingIsReturn = shouldReturn

		if shouldReturn then
			button:SetAttribute("type" .. suffix, "returnhome")
			button:SetNormalAtlas(HOUSING_ATLAS_RETURN)
			if button.cooldownFrame then
				button.cooldownFrame:Clear()
			end
			return
		end

		button:SetNormalAtlas(HOUSING_ATLAS_TELEPORT)

		if house and house.neighborhoodGUID and house.houseGUID and house.plotID then
			button:SetAttribute("type" .. suffix, "teleporthome")
			button:SetAttribute("house-neighborhood-guid" .. suffix, house.neighborhoodGUID)
			button:SetAttribute("house-guid" .. suffix, house.houseGUID)
			button:SetAttribute("house-plot-id" .. suffix, house.plotID)
		end

		if button.cooldownFrame then
			local cdInfo = C_Housing.GetVisitCooldownInfo()
			if cdInfo.isEnabled and not OneWoW.Restriction.IsSecret(cdInfo.duration) and cdInfo.duration > 0 then
				button.cooldownFrame:SetCooldown(cdInfo.startTime, cdInfo.duration)
			else
				button.cooldownFrame:Clear()
			end
		end
	end

	if housingHouse then
		applyHouse(housingHouse)
	else
		button:SetNormalAtlas(HOUSING_ATLAS_TELEPORT)
		self:RequestHousingHouse(applyHouse)
	end
end

function Detection:IsAvailable(type, id)
	if type == "toy" then
		return PlayerHasToy(id)
	elseif type == "item" then
		return C_Item.GetItemCount(id) > 0 or PlayerHasToy(id)
	elseif type == "spell" then
		return C_SpellBook.IsSpellKnown(id)
	elseif type == "housing" then
		return C_Housing.HasHousingExpansionAccess()
	end
	return false
end

local function IsKnownItemPortalUsable(portalType, id)
	local itemData = ns.PortalData.Items
	local groups = {
		itemData.rings,
		itemData.cloaks,
		itemData.tabards,
		itemData.consumables,
		itemData.special_items,
	}

	for _, group in ipairs(groups) do
		for _, portal in ipairs(group) do
			if portal.id == id and portal.type == portalType then
				if portal.condition and not portal.condition() then
					return false
				end
				if portalType == "toy" then
					return PlayerHasToy(id) and C_ToyBox.IsToyUsable(id)
				end
				if portalType == "item" then
					return C_Item.GetItemCount(id) > 0
				end
			end
		end
	end

	return nil
end

function Detection:IsPortalUsable(portalType, id)
	if portalType == "toy" and ENGINEERING_TOYS[id] then
		return self:HasProfession("Engineering") and PlayerHasToy(id) and C_ToyBox.IsToyUsable(id)
	end

	if portalType == "item" and ENGINEERING_ITEMS[id] then
		return self:HasProfession("Engineering") and C_Item.GetItemCount(id) > 0
	end

	local hearthstoneCondition = ns.PortalData_Hearthstones.List[id]
	if hearthstoneCondition then
		if id == 6948 then
			return C_Item.GetItemCount(id) > 0
		end
		if not PlayerHasToy(id) then
			return false
		end
		if type(hearthstoneCondition) == "function" then
			return hearthstoneCondition() == true
		end
		return hearthstoneCondition == true
	end

	if portalType == "toy" and id == 140192 then
		return PlayerHasToy(id) and C_QuestLog.IsQuestFlaggedCompleted(44663)
	end

	if portalType == "toy" and id == 110560 then
		return PlayerHasToy(id) and C_QuestLog.IsQuestFlaggedCompleted(34378)
	end

	local knownItemUsable = IsKnownItemPortalUsable(portalType, id)
	if knownItemUsable ~= nil then
		return knownItemUsable
	end

	return self:IsAvailable(portalType, id)
end

function Detection:HasProfession(professionName)
	local prof1, prof2 = GetProfessions()

	if prof1 then
		local name = GetProfessionInfo(prof1)
		if name == professionName then
			return true
		end
	end

	if prof2 then
		local name = GetProfessionInfo(prof2)
		if name == professionName then
			return true
		end
	end

	return false
end

function Detection:GetMageTeleports(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "MAGE" and not showAll then
		return portals
	end

	local faction = UnitFactionGroup("player")
	local flyoutID = faction == "Alliance" and 8 or 1

	local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)
	if not isKnown and not showAll then
		return portals
	end

	if numSlots then
		for i = 1, numSlots do
			local spellID, _, slotKnown = GetFlyoutSlotInfo(flyoutID, i)
			if spellID and (slotKnown or showAll) then
				table.insert(portals, {type = "spell", id = spellID})
			end
		end
	end

	return portals
end

function Detection:GetMagePortals(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "MAGE" and not showAll then
		return portals
	end

	local faction = UnitFactionGroup("player")
	local flyoutID = faction == "Alliance" and 12 or 11

	local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)
	if not isKnown and not showAll then
		return portals
	end

	if numSlots then
		for i = 1, numSlots do
			local spellID, _, slotKnown = GetFlyoutSlotInfo(flyoutID, i)
			if spellID and (slotKnown or showAll) then
				table.insert(portals, {type = "spell", id = spellID})
			end
		end
	end

	return portals
end

function Detection:GetDruidPortals(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "DRUID" and not showAll then
		return portals
	end

	if C_SpellBook.IsSpellKnown(18960) or showAll then
		table.insert(portals, {type = "spell", id = 18960})
	end

	if C_SpellBook.IsSpellKnown(193753) or showAll then
		table.insert(portals, {type = "spell", id = 193753})
	end

	return portals
end

function Detection:GetDeathKnightPortals(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "DEATHKNIGHT" and not showAll then
		return portals
	end

	if C_SpellBook.IsSpellKnown(50977) or showAll then
		table.insert(portals, {type = "spell", id = 50977})
	end

	return portals
end

function Detection:GetMonkPortals(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "MONK" and not showAll then
		return portals
	end

	if C_SpellBook.IsSpellKnown(126892) or showAll then
		table.insert(portals, {type = "spell", id = 126892})
	end

	return portals
end

function Detection:GetShamanPortals(showAll)
	local portals = {}
	local _, class = UnitClass("player")
	if class ~= "SHAMAN" and not showAll then
		return portals
	end

	if C_SpellBook.IsSpellKnown(556) or showAll then
		table.insert(portals, {type = "spell", id = 556})
	end

	return portals
end

function Detection:GetCovenantPortals(showAll)
	local portals = {}

	if C_SpellBook.IsSpellKnown(324547) or showAll then
		table.insert(portals, {type = "spell", id = 324547})
	end

	return portals
end

function Detection:GetRacePortals(showAll)
	local portals = {}
	local _, race = UnitRace("player")

	if race == "Dark Iron Dwarf" or showAll then
		if C_SpellBook.IsSpellKnown(265225) or showAll then
			table.insert(portals, {type = "spell", id = 265225})
		end
	end

	if race == "Vulpera" or showAll then
		if C_SpellBook.IsSpellKnown(312370) or showAll then
			table.insert(portals, {type = "spell", id = 312370})
		end
		if C_SpellBook.IsSpellKnown(312372) or showAll then
			table.insert(portals, {type = "spell", id = 312372})
		end
	end

	if race == "Haranir" or showAll then
		if C_SpellBook.IsSpellKnown(1238686) or showAll then
			table.insert(portals, {type = "spell", id = 1238686})
		end
	end

	return portals
end

local HARDCODED_DUNGEONS = {
	mid = {1254572, 1254400, 1254563, 1254559, 1286812, 1286809, 1286807, 1286801, 1286804},
	tww = {445417, 445440, 445416, 445441, 445414, 1237215, 1216786, 445444, 445443, 445269},
	df = {393273, 393279, 393267, 424197, 393283, 393276, 393262, 393256, 393222},
	sl = {354468, 354465, 354464, 354462, 354463, 354469, 354466, 367416, 354467},
	bfa = {424187, 410071, 373274, 410074, 424167, 1286831, 1286828},
	legion = {424153, 393766, 424163, 393764, 373262, 410078, 252631, 1254551},
	wod = {159897, 159895, 159901, 159900, 159896, 159899, 159898, 159902, 1254557},
	mop = {131225, 131222, 131232, 131231, 131229, 131228, 131206, 131205, 131204},
	cata = {445424, 424142, 410080},
	wotlk = {1254555},
	bc = {},
	classic = {},
}

local HARDCODED_RAIDS = {
	mid = {},
	tww = {1226482, 1239155},
	df = {432254, 432257, 432258},
	sl = {373190, 373191, 373192},
	bfa = {},
	legion = {},
	wod = {},
	mop = {},
	cata = {},
	wotlk = {},
	bc = {},
	classic = {},
}

-- Blizzard Hero's Path flyouts. New Path of X spells on these flyouts appear
-- without a list edit. Hardcoded IDs above stay as extras (faction variants,
-- older paths that are not on a flyout).
local PATH_FLYOUTS = {
	mid = {dungeons = 246},
	tww = {dungeons = 232, raids = 242},
	df = {dungeons = 227, raids = 231},
	sl = {dungeons = 220, raids = 222},
	bfa = {dungeons = 223},
	legion = {dungeons = 224},
	wod = {dungeons = 96},
	mop = {dungeons = 84},
	cata = {dungeons = 230},
}

local CURRENT_PATH_EXPANSION = "mid"

local CHALLENGE_MAP_SPELLS = {
	[161] = 159898,
	[239] = 1254551,
	[249] = 1286831,
	[250] = 1286828,
	[399] = 393256,
	[402] = 393273,
	[556] = 1254555,
	[557] = 1254400,
	[558] = 1254572,
	[559] = 1254563,
	[560] = 1254559,
	[584] = 1286801,
	[585] = 1286804,
	[586] = 1286807,
	[587] = 1286809,
	[588] = 1286812,
}

local function CollectFlyoutSpellIDs(flyoutID)
	local spells = {}
	if not flyoutID then
		return spells
	end
	local _, _, numSlots = GetFlyoutInfo(flyoutID)
	if not numSlots then
		return spells
	end
	for i = 1, numSlots do
		local spellID = GetFlyoutSlotInfo(flyoutID, i)
		if spellID then
			tinsert(spells, spellID)
		end
	end
	return spells
end

local function MergeSpellIDs(...)
	local seen = {}
	local out = {}
	for i = 1, select("#", ...) do
		local list = select(i, ...)
		if list then
			for _, spellID in ipairs(list) do
				if spellID and not seen[spellID] then
					seen[spellID] = true
					tinsert(out, spellID)
				end
			end
		end
	end
	return out
end

function Detection:GetHearthstoneChoice()
	local choice = OneWoW:GetPortalHub().hearthstoneChoice
	if choice == "none" or choice == "disabled" or choice == "random" or choice == "default" then
		return choice
	end
	local id = tonumber(choice)
	if id then
		return id
	end
	return "random"
end

function Detection:GetCurrentPathExpansion()
	return CURRENT_PATH_EXPANSION
end

function Detection:UsesLivePathFlyouts()
	return OneWoW:GetPortalHub().useLivePathFlyouts ~= false
end

function Detection:IsSeasonalOnly()
	return OneWoW:GetPortalHub().seasonalOnly == true
end

local function GetExpansionSpellIDs(expansion, kind)
	local hardcoded = kind == "raids" and HARDCODED_RAIDS or HARDCODED_DUNGEONS
	local flyoutKey = kind == "raids" and "raids" or "dungeons"
	local extras = hardcoded[expansion] or {}
	if not Detection:UsesLivePathFlyouts() then
		return extras
	end
	local flyoutInfo = PATH_FLYOUTS[expansion]
	local flyoutID = flyoutInfo and flyoutInfo[flyoutKey]
	return MergeSpellIDs(CollectFlyoutSpellIDs(flyoutID), extras)
end

function Detection:GetDungeonPortals(expansion, showAll)
	local portals = {}
	local spells = {}
	if expansion then
		spells = GetExpansionSpellIDs(expansion, "dungeons")
	else
		for expKey in pairs(HARDCODED_DUNGEONS) do
			spells = MergeSpellIDs(spells, GetExpansionSpellIDs(expKey, "dungeons"))
		end
	end

	local faction = UnitFactionGroup("player")
	for _, spellID in ipairs(spells) do
		AppendSpellPortal(portals, spellID, showAll)
	end

	if expansion == "bfa" or not expansion then
		local siegeID = faction == "Alliance" and 445418 or 464256
		local motherID = faction == "Alliance" and 467553 or 467555
		AppendSpellPortal(portals, siegeID, showAll)
		AppendSpellPortal(portals, motherID, showAll)
	end

	return portals
end

function Detection:GetRaidPortals(expansion, showAll)
	local portals = {}
	local spells = {}
	if expansion then
		spells = GetExpansionSpellIDs(expansion, "raids")
	else
		for expKey in pairs(HARDCODED_RAIDS) do
			spells = MergeSpellIDs(spells, GetExpansionSpellIDs(expKey, "raids"))
		end
	end

	for _, spellID in ipairs(spells) do
		AppendSpellPortal(portals, spellID, showAll)
	end

	return portals
end

local function NormalizeDungeonName(name)
	name = name:lower()
	name = name:gsub("%s*%b()%s*$", "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	return name
end

local function PathNamesMatch(dungeonName, spellName)
	if dungeonName == spellName then
		return true
	end
	if spellName:find(dungeonName, 1, true) then
		return true
	end
	local pathRest = spellName:match("^path of the (.+)$") or spellName:match("^path of (.+)$")
	if not pathRest then
		return false
	end
	return pathRest == dungeonName or dungeonName:find(pathRest, 1, true) or pathRest:find(dungeonName, 1, true)
end

function Detection:ResolvePathSpellByName(displayName)
	if type(displayName) ~= "string" or displayName == "" then
		return nil
	end
	local dungeonName = NormalizeDungeonName(displayName)
	if dungeonName == "" then
		return nil
	end

	for mapID, spellID in pairs(CHALLENGE_MAP_SPELLS) do
		local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
		if mapName and NormalizeDungeonName(mapName) == dungeonName then
			return spellID
		end
	end

	local maps = C_ChallengeMode.GetMapTable()
	for _, mapID in ipairs(maps) do
		local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
		local spellID = CHALLENGE_MAP_SPELLS[mapID]
		if spellID and mapName and NormalizeDungeonName(mapName) == dungeonName then
			return spellID
		end
	end

	local pathSpells = MergeSpellIDs(
		GetExpansionSpellIDs("mid", "dungeons"),
		GetExpansionSpellIDs("tww", "dungeons"),
		GetExpansionSpellIDs("df", "dungeons"),
		GetExpansionSpellIDs("sl", "dungeons"),
		GetExpansionSpellIDs("bfa", "dungeons"),
		GetExpansionSpellIDs("legion", "dungeons"),
		GetExpansionSpellIDs("wod", "dungeons"),
		GetExpansionSpellIDs("mop", "dungeons"),
		GetExpansionSpellIDs("cata", "dungeons"),
		GetExpansionSpellIDs("wotlk", "dungeons")
	)
	for _, spellID in ipairs(pathSpells) do
		local spellName = C_Spell.GetSpellName(spellID)
		if spellName and PathNamesMatch(dungeonName, NormalizeDungeonName(spellName)) then
			return spellID
		end
	end

	return nil
end

function Detection:GetWormholes(showAll)
	local portals = {}
	local wormholes = {48933, 87215, 112059, 151652, 168807, 168808, 172924, 198156, 221966, 248485}

	if not self:HasProfession("Engineering") and not showAll then
		return portals
	end

	for _, toyID in ipairs(wormholes) do
		if PlayerHasToy(toyID) or showAll then
			if showAll or C_ToyBox.IsToyUsable(toyID) then
				table.insert(portals, {type = "toy", id = toyID})
			end
		end
	end

	return portals
end

function Detection:GetDimensionalRippers(showAll)
	local portals = {}
	local rippers = {30542, 18984}

	if not self:HasProfession("Engineering") and not showAll then
		return portals
	end

	for _, toyID in ipairs(rippers) do
		if PlayerHasToy(toyID) or showAll then
			if showAll or C_ToyBox.IsToyUsable(toyID) then
				table.insert(portals, {type = "toy", id = toyID})
			end
		end
	end

	return portals
end

function Detection:GetUltrasafeTransporters(showAll)
	local portals = {}
	local transporters = {18986, 30544}

	if not self:HasProfession("Engineering") and not showAll then
		return portals
	end

	for _, toyID in ipairs(transporters) do
		if PlayerHasToy(toyID) or showAll then
			if showAll or C_ToyBox.IsToyUsable(toyID) then
				table.insert(portals, {type = "toy", id = toyID})
			end
		end
	end

	return portals
end

function Detection:GetEngineeringOtherItems(showAll)
	local portals = {}

	if not self:HasProfession("Engineering") and not showAll then
		return portals
	end

	if ns.PortalData and ns.PortalData.Items.engineering.other then
		for _, item in ipairs(ns.PortalData.Items.engineering.other) do
			if showAll or C_Item.GetItemCount(item.id) > 0 then
				table.insert(portals, {type = "item", id = item.id, name = item.name})
			end
		end
	end

	return portals
end

function Detection:GetSpecialPortals(showAll)
	local portals = {}

	if PlayerHasToy(230850) or showAll then
		table.insert(portals, {type = "toy", id = 230850})
	end

	if PlayerHasToy(266370) or showAll then
		table.insert(portals, {type = "toy", id = 266370})
	end

	if PlayerHasToy(140192) then
		if C_QuestLog.IsQuestFlaggedCompleted(44663) or showAll then
			table.insert(portals, {type = "toy", id = 140192})
		end
	elseif showAll then
		table.insert(portals, {type = "toy", id = 140192})
	end

	if PlayerHasToy(110560) then
		if C_QuestLog.IsQuestFlaggedCompleted(34378) or showAll then
			table.insert(portals, {type = "toy", id = 110560})
		end
	elseif showAll then
		table.insert(portals, {type = "toy", id = 110560})
	end

	if C_SpellBook.IsSpellKnown(83958) or showAll then
		table.insert(portals, {type = "spell", id = 83958})
	end

	return portals
end

function Detection:GetHousingPortal()
	if C_Housing.HasHousingExpansionAccess() then
		return {type = "housing", id = 1233637}
	end
	return nil
end

local SEASON_PORTAL_SPELLS = {
	[1] = {
		1254400,
		1254572,
		1254559,
		1254563,
		393273,
		1254555,
		1254551,
		1254557,
	},
	[2] = {
		1286812,
		1286809,
		1286807,
		1286801,
		1286804,
		393256,
		1286831,
		1286828,
	},
}

function Detection:GetSeasonPortals(season, showAll)
	local portals = {}
	local seasonSpells = SEASON_PORTAL_SPELLS[season]
	if not seasonSpells then
		return portals
	end
	for _, spellID in ipairs(seasonSpells) do
		AppendSpellPortal(portals, spellID, showAll)
	end
	return portals
end

function Detection:GetCurrentSeasonPortals(showAll)
	return self:GetSeasonPortals(self:GetCurrentSeasonNumber() or 2, showAll)
end
