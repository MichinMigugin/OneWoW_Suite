local ADDON_NAME, OneWoW = ...

local Hearthstones = {}
OneWoW.PortalData_Hearthstones = Hearthstones

local function GetCovenantData(id)
	local _, _, completed = GetAchievementCriteriaInfo(15646, id)
	return completed
end

Hearthstones.List = {
	[6948] = true,
	[54452] = true,
	[64488] = true,
	[93672] = true,
	[142542] = true,
	[162973] = true,
	[163045] = true,
	[163206] = true,
	[165669] = true,
	[165670] = true,
	[165802] = true,
	[166746] = true,
	[166747] = true,
	[168907] = true,
	[172179] = true,
	[180290] = function()
		if GetCovenantData(3) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 3 then
			return true
		end
	end,
	[182773] = function()
		if GetCovenantData(2) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 4 then
			return true
		end
	end,
	[183716] = function()
		if GetCovenantData(4) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 2 then
			return true
		end
	end,
	[184353] = function()
		if GetCovenantData(1) then
			return true
		end
		local covenantID = C_Covenants.GetActiveCovenantID()
		if covenantID == 1 then
			return true
		end
	end,
	[188952] = true,
	[190196] = true,
	[190237] = true,
	[193588] = true,
	[200630] = true,
	[206195] = true,
	[208704] = true,
	[209035] = true,
	[210455] = function()
		local _, _, raceId = UnitRace("player")
		if raceId == 11 or raceId == 30 then
			return true
		end
	end,
	[212337] = true,
	[228940] = true,
	[235016] = true,
	[236687] = true,
	[245970] = true,
	[246565] = true,
	[263489] = true,
}

function Hearthstones:GetAvailable(showAll)
	local available = {}
	for id, condition in pairs(self.List) do
		local shouldInclude = false

		if PlayerHasToy(id) or showAll then
			if type(condition) == "function" then
				if condition() or showAll then
					shouldInclude = true
				end
			elseif condition == true then
				shouldInclude = true
			end

			if shouldInclude then
				table.insert(available, {type = "toy", id = id})
			end
		end
	end
	return available
end
