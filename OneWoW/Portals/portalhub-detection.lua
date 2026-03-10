local ADDON_NAME, OneWoW = ...

OneWoW.PortalHubDetection = OneWoW.PortalHubDetection or {}
local Detection = OneWoW.PortalHubDetection

function Detection:IsAvailable(type, id)
	if type == "toy" then
		return PlayerHasToy(id)
	elseif type == "item" then
		return C_Item.GetItemCount(id) > 0 or PlayerHasToy(id)
	elseif type == "spell" then
		return IsSpellKnown(id)
	elseif type == "housing" then
		return C_Housing and C_Housing.HasHousingExpansionAccess()
	end
	return false
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
			local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, i)
			if spellID and (isKnown or showAll) then
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
			local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, i)
			if spellID and (isKnown or showAll) then
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

	if IsSpellKnown(18960) or showAll then
		table.insert(portals, {type = "spell", id = 18960})
	end

	if IsSpellKnown(193753) or showAll then
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

	if IsSpellKnown(50977) or showAll then
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

	if IsSpellKnown(126892) or showAll then
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

	if IsSpellKnown(556) or showAll then
		table.insert(portals, {type = "spell", id = 556})
	end

	return portals
end

function Detection:GetCovenantPortals(showAll)
	local portals = {}

	if IsSpellKnown(324547) or showAll then
		table.insert(portals, {type = "spell", id = 324547})
	end

	return portals
end

function Detection:GetRacePortals(showAll)
	local portals = {}
	local _, race = UnitRace("player")

	if race == "Dark Iron Dwarf" or showAll then
		if IsSpellKnown(265225) or showAll then
			table.insert(portals, {type = "spell", id = 265225})
		end
	end

	if race == "Vulpera" or showAll then
		if IsSpellKnown(312370) or showAll then
			table.insert(portals, {type = "spell", id = 312370})
		end
		if IsSpellKnown(312372) or showAll then
			table.insert(portals, {type = "spell", id = 312372})
		end
	end

	if race == "Haranir" or showAll then
		if IsSpellKnown(1238686) or showAll then
			table.insert(portals, {type = "spell", id = 1238686})
		end
	end

	return portals
end

function Detection:GetDungeonPortals(expansion, showAll)
	local portals = {}

	local dungeonsByExpansion = {
		mid = {1254572, 1254400, 1254563, 1254559},
		tww = {445417, 445440, 445416, 445441, 445414, 1237215, 1216786, 445444, 445443, 445269},
		df = {393273, 393279, 393267, 424197, 393283, 393276, 393262, 393256, 393222},
		sl = {354468, 354465, 354464, 354462, 354463, 354469, 354466, 367416, 354467},
		bfa = {424187, 410071, 373274, 410074, 424167},
		legion = {424153, 393766, 424163, 393764, 373262, 410078},
		wod = {159897, 159895, 159901, 159900, 159896, 159899, 159898, 159902},
		mop = {131225, 131222, 131232, 131231, 131229, 131228, 131206, 131205, 131204},
		cata = {445424, 424142, 410080},
		wotlk = {},
		bc = {},
		classic = {},
	}

	local spells = {}
	if expansion then
		if dungeonsByExpansion[expansion] then
			spells = dungeonsByExpansion[expansion]
		end
	else
		for _, dungeonList in pairs(dungeonsByExpansion) do
			for _, spellID in ipairs(dungeonList) do
				if spellID then
					table.insert(spells, spellID)
				end
			end
		end
	end

	local faction = UnitFactionGroup("player")
	for _, spellID in ipairs(spells) do
		if spellID then
			if IsSpellKnown(spellID) or showAll then
				table.insert(portals, {type = "spell", id = spellID})
			end
		end
	end

	if expansion == "bfa" or not expansion then
		local siegeID = faction == "Alliance" and 445418 or 464256
		local motherID = faction == "Alliance" and 467553 or 467555

		if IsSpellKnown(siegeID) or showAll then
			table.insert(portals, {type = "spell", id = siegeID})
		end
		if IsSpellKnown(motherID) or showAll then
			table.insert(portals, {type = "spell", id = motherID})
		end
	end

	return portals
end

function Detection:GetRaidPortals(expansion, showAll)
	local portals = {}

	local raidsByExpansion = {
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

	local spells = {}
	if expansion then
		if raidsByExpansion[expansion] then
			spells = raidsByExpansion[expansion]
		end
	else
		for _, raidList in pairs(raidsByExpansion) do
			for _, spellID in ipairs(raidList) do
				table.insert(spells, spellID)
			end
		end
	end

	for _, spellID in ipairs(spells) do
		if IsSpellKnown(spellID) or showAll then
			table.insert(portals, {type = "spell", id = spellID})
		end
	end

	return portals
end

function Detection:GetWormholes(showAll)
	local portals = {}
	local wormholes = {48933, 87215, 112059, 151652, 168807, 168808, 172924, 198156, 221966}

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

	if OneWoW.PortalData and OneWoW.PortalData.Items.engineering.other then
		for _, item in ipairs(OneWoW.PortalData.Items.engineering.other) do
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

	if IsSpellKnown(83958) or showAll then
		table.insert(portals, {type = "spell", id = 83958})
	end

	return portals
end

function Detection:GetHousingPortal(showAll)
	if C_Housing and C_Housing.HasHousingExpansionAccess() then
		return {type = "housing", id = 1233637}
	end
	return nil
end

function Detection:GetCurrentSeasonPortals(showAll)
	local portals = {}
	local seasonSpells = {
		1254400,
		1254572,
		1254559,
		1254563,
	}
	for _, spellID in ipairs(seasonSpells) do
		if IsSpellKnown(spellID) or showAll then
			table.insert(portals, {type = "spell", id = spellID})
		end
	end
	return portals
end
