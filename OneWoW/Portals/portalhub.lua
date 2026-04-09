local ADDON_NAME, OneWoW = ...
local L = OneWoW.L

OneWoW.PortalHubModule = OneWoW.PortalHubModule or {}
local PortalHub = OneWoW.PortalHubModule

function PortalHub:Initialize()
	self:InitializeDatabase()
	self.initialized = true
end

function PortalHub:InitializeDatabase()
end

local function CategorizePortal(portalData)
	local hearthstones = OneWoW.PortalData_Hearthstones and OneWoW.PortalData_Hearthstones.List or {}

	if hearthstones[portalData.id] then
		return "hearth"
	end

	if portalData.type == "housing" then
		return "hearth"
	end

	if portalData.type == "spell" then
		local classSpells = {18960, 193753, 50977, 126892, 556, 120145, 3565, 32271, 32272, 49358, 49359, 176248, 176242, 224869, 193759, 312370, 312372, 265225, 1238686}
		for _, spellID in ipairs(classSpells) do
			if portalData.id == spellID then
				return "class"
			end
		end

		local mageSpells = {
			3561, 3562, 3563, 3565, 3566, 3567, 32271, 32272, 33690, 35715, 49358, 49359,
			53140, 88342, 88344, 120145, 132621, 132627, 176242, 176248, 224869, 281403,
			281404, 344587, 395277
		}
		for _, spellID in ipairs(mageSpells) do
			if portalData.id == spellID then
				return "class"
			end
		end

		return "instances"
	end

	if portalData.type == "toy" then
		local professionToys = {
			18984, 18986, 30542, 30544, 48933, 87215, 112059, 151652, 168807, 168808,
			168807, 251662, 412555, 212337, 198156, 221966, 248485
		}
		for _, toyID in ipairs(professionToys) do
			if portalData.id == toyID then
				return "professions"
			end
		end
	end

	if portalData.type == "item" then
		local professionItems = {132523, 144341, 167075}
		for _, itemID in ipairs(professionItems) do
			if portalData.id == itemID then
				return "professions"
			end
		end
	end

	return "other"
end

function PortalHub:IsFavorite(type, id)
	if not OneWoW.db.global.portalHub.allFavorites then
		return false
	end
	local key = type .. ":" .. id
	return OneWoW.db.global.portalHub.allFavorites[key] == true
end

function PortalHub:ToggleFavorite(type, id, name)
	if not OneWoW.db.global.portalHub.allFavorites then
		OneWoW.db.global.portalHub.allFavorites = {}
	end
	if not OneWoW.db.global.portalHub.escFavorites then
		OneWoW.db.global.portalHub.escFavorites = {}
	end

	local key = type .. ":" .. id
	local isFav = OneWoW.db.global.portalHub.allFavorites[key]

	if isFav then
		OneWoW.db.global.portalHub.allFavorites[key] = nil
		for i = #OneWoW.db.global.portalHub.escFavorites, 1, -1 do
			local fav = OneWoW.db.global.portalHub.escFavorites[i]
			if fav.type == type and fav.id == id then
				table.remove(OneWoW.db.global.portalHub.escFavorites, i)
			end
		end
		return false
	else
		local category = CategorizePortal({type = type, id = id})

		local categoryCount = 0
		for _, fav in ipairs(OneWoW.db.global.portalHub.escFavorites) do
			local favCategory = CategorizePortal({type = fav.type, id = fav.id})
			if favCategory == category then
				categoryCount = categoryCount + 1
			end
		end

		if categoryCount >= 10 then
			local categoryNames = {
				hearth = L["SETTINGS_PORTALHUB_HEARTHSTONE"],
				class = L["SETTINGS_PORTALHUB_CLASS_RACIAL"],
				professions = L["SETTINGS_PORTALHUB_PROFESSION"],
				instances = L["SETTINGS_PORTALHUB_DUNGEON_RAID"],
				other = L["SETTINGS_PORTALHUB_OTHER"]
			}
			local categoryName = categoryNames[category] or category
			print("|cFF00FF00OneWoW:|r " .. string.format(L["SETTINGS_PORTALHUB_MAX_FAVORITES"], categoryName))
			return false
		end

		OneWoW.db.global.portalHub.allFavorites[key] = true
		table.insert(OneWoW.db.global.portalHub.escFavorites, {
			type = type,
			id = id,
			name = name
		})
		return true
	end
end

function PortalHub:GetFavorites()
	local favorites = {}
	if not OneWoW.db.global.portalHub.escFavorites then
		return favorites
	end

	for _, fav in ipairs(OneWoW.db.global.portalHub.escFavorites) do
		table.insert(favorites, {
			type = fav.type,
			id = fav.id,
			name = fav.name,
			available = OneWoW.PortalHubDetection:IsAvailable(fav.type, fav.id)
		})
	end

	return favorites
end

function PortalHub:GetCategories()
	local categories = {}

	table.insert(categories, {
		id = "favorites",
		name = L["Favorites"],
		iconAtlas = "auctionhouse-icon-favorite",
	})

	table.insert(categories, {
		id = "hearth",
		name = L["Hearthstones & Specials"],
		icon = "Interface\\Icons\\INV_Misc_Rune_01"
	})

	table.insert(categories, {
		id = "abilities",
		name = L["Class & Racial Abilities"],
		icon = "Interface\\Icons\\Achievement_BG_winAB_underXminutes"
	})

	table.insert(categories, {
		id = "professions",
		name = L["Professions"],
		icon = "Interface\\Icons\\Trade_Engineering"
	})

	table.insert(categories, {
		id = "instances",
		name = L["Dungeons & Raids"],
		icon = "Interface\\Icons\\Achievement_Boss_Archaedas",
		subcategories = {
			{id = "tww", name = L["The War Within"]},
			{id = "df", name = L["Dragonflight"]},
			{id = "sl", name = L["Shadowlands"]},
			{id = "bfa", name = L["Battle for Azeroth"]},
			{id = "legion", name = L["Legion"]},
			{id = "wod", name = L["Warlords of Draenor"]},
			{id = "mop", name = L["Mists of Pandaria"]},
			{id = "cata", name = L["Cataclysm"]},
			{id = "wotlk", name = L["Wrath of the Lich King"]},
		}
	})

	table.insert(categories, {
		id = "items",
		name = L["Item Teleports"],
		icon = "Interface\\Icons\\INV_Misc_Bag_10",
		subcategories = {
			{id = "rings", name = L["Rings & Jewelry"]},
			{id = "cloaks", name = L["Cloaks"]},
			{id = "tabards", name = L["Tabards"]},
			{id = "consumables", name = L["Consumables"]},
			{id = "special", name = L["Special Items"]},
		}
	})

	return categories
end

function PortalHub:GetPortalsForCategory(categoryID, showAll)
	local portals = {}

	if categoryID == "favorites" then
		return self:GetFavorites()
	elseif categoryID == "hearth" then
		local hearthstones = OneWoW.PortalData_Hearthstones:GetAvailable(showAll)
		for _, h in ipairs(hearthstones) do
			table.insert(portals, h)
		end
		table.insert(portals, {type = "header", name = L["Special"]})
		local specials = OneWoW.PortalHubDetection:GetSpecialPortals(showAll)
		for _, s in ipairs(specials) do
			table.insert(portals, s)
		end
		return portals
	elseif categoryID == "professions" then
		local wormholes = OneWoW.PortalHubDetection:GetWormholes(showAll)
		local rippers = OneWoW.PortalHubDetection:GetDimensionalRippers(showAll)
		local transporters = OneWoW.PortalHubDetection:GetUltrasafeTransporters(showAll)
		local engOther = OneWoW.PortalHubDetection:GetEngineeringOtherItems(showAll)

		table.insert(portals, {type = "header", name = L["Wormhole Generators"]})
		for _, w in ipairs(wormholes) do
			table.insert(portals, w)
		end
		table.insert(portals, {type = "header", name = L["Dimensional Rippers"]})
		for _, r in ipairs(rippers) do
			table.insert(portals, r)
		end
		table.insert(portals, {type = "header", name = L["Ultrasafe Transporters"]})
		for _, t in ipairs(transporters) do
			table.insert(portals, t)
		end
		if #engOther > 0 or showAll then
			table.insert(portals, {type = "header", name = L["Engineering Devices"]})
			for _, o in ipairs(engOther) do
				table.insert(portals, o)
			end
		end
		return portals
	elseif categoryID == "abilities" then
		local allAbilities = {}
		local mageT = OneWoW.PortalHubDetection:GetMageTeleports(showAll)
		local mageP = OneWoW.PortalHubDetection:GetMagePortals(showAll)
		local druid = OneWoW.PortalHubDetection:GetDruidPortals(showAll)
		local dk = OneWoW.PortalHubDetection:GetDeathKnightPortals(showAll)
		local monk = OneWoW.PortalHubDetection:GetMonkPortals(showAll)
		local shaman = OneWoW.PortalHubDetection:GetShamanPortals(showAll)
		local racial = OneWoW.PortalHubDetection:GetRacePortals(showAll)
		for _, p in ipairs(mageT) do table.insert(allAbilities, p) end
		for _, p in ipairs(mageP) do table.insert(allAbilities, p) end
		for _, p in ipairs(druid) do table.insert(allAbilities, p) end
		for _, p in ipairs(dk) do table.insert(allAbilities, p) end
		for _, p in ipairs(monk) do table.insert(allAbilities, p) end
		for _, p in ipairs(shaman) do table.insert(allAbilities, p) end
		for _, p in ipairs(racial) do table.insert(allAbilities, p) end
		return allAbilities
	elseif categoryID == "instances" then
		local allPortals = {}
		local expansions = {"tww", "df", "sl", "bfa", "legion", "wod", "mop", "cata", "wotlk"}
		for _, exp in ipairs(expansions) do
			local dungeons = OneWoW.PortalHubDetection:GetDungeonPortals(exp, showAll)
			for _, d in ipairs(dungeons) do
				table.insert(allPortals, d)
			end
			local raids = OneWoW.PortalHubDetection:GetRaidPortals(exp, showAll)
			for _, r in ipairs(raids) do
				table.insert(allPortals, r)
			end
		end
		return allPortals
	elseif categoryID == "tww" or categoryID == "df" or categoryID == "sl" or
		   categoryID == "bfa" or categoryID == "legion" or categoryID == "wod" or
		   categoryID == "mop" or categoryID == "cata" or categoryID == "wotlk" then
		local allPortals = {}
		local dungeons = OneWoW.PortalHubDetection:GetDungeonPortals(categoryID, showAll)
		local raids = OneWoW.PortalHubDetection:GetRaidPortals(categoryID, showAll)

		for _, d in ipairs(dungeons) do
			table.insert(allPortals, d)
		end
		for _, r in ipairs(raids) do
			table.insert(allPortals, r)
		end
		return allPortals
	elseif categoryID == "items" then
		if OneWoW.PortalHubItems then
			return OneWoW.PortalHubItems:GetAllItems(showAll)
		end
		return portals
	elseif categoryID == "rings" or categoryID == "cloaks" or categoryID == "tabards" or
		   categoryID == "consumables" or categoryID == "special" then
		if OneWoW.PortalHubItems then
			return OneWoW.PortalHubItems:GetItemsBySubcategory(categoryID, showAll)
		end
		return portals
	end

	return portals
end
