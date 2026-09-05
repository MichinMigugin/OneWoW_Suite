local _, ns = ...

local OneWoW = OneWoW

local L = ns.L

ns.PortalHubModule = ns.PortalHubModule or {}
local PortalHub = ns.PortalHubModule

function PortalHub:Initialize()
	self:InitializeDatabase()
	self.initialized = true
end

function PortalHub:InitializeDatabase()
	local ph = OneWoW:GetPortalHub()
	if ph.hearthstoneChoiceMigrated then
		return
	end
	if ph.randomHearthstone == false then
		ph.hearthstoneChoice = "default"
	end
	ph.hearthstoneChoiceMigrated = true
end

local function CategorizePortal(portalData)
	local hearthstones = ns.PortalData_Hearthstones and ns.PortalData_Hearthstones.List or {}

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
			172924, 212337, 198156, 221966, 248485
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
	if not OneWoW:GetPortalHub().allFavorites then
		return false
	end
	local key = type .. ":" .. id
	return OneWoW:GetPortalHub().allFavorites[key] == true
end

function PortalHub:ToggleFavorite(type, id, name)
	if not OneWoW:GetPortalHub().allFavorites then
		OneWoW:GetPortalHub().allFavorites = {}
	end
	if not OneWoW:GetPortalHub().escFavorites then
		OneWoW:GetPortalHub().escFavorites = {}
	end

	local key = type .. ":" .. id
	local isFav = OneWoW:GetPortalHub().allFavorites[key]

	if isFav then
		OneWoW:GetPortalHub().allFavorites[key] = nil
		for i = #OneWoW:GetPortalHub().escFavorites, 1, -1 do
			local fav = OneWoW:GetPortalHub().escFavorites[i]
			if fav.type == type and fav.id == id then
				table.remove(OneWoW:GetPortalHub().escFavorites, i)
			end
		end
		return false
	else
		local category = CategorizePortal({type = type, id = id})

		local categoryCount = 0
		for _, fav in ipairs(OneWoW:GetPortalHub().escFavorites) do
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

		OneWoW:GetPortalHub().allFavorites[key] = true
		table.insert(OneWoW:GetPortalHub().escFavorites, {
			type = type,
			id = id,
			name = name
		})
		return true
	end
end

-- ============================================================================
-- Custom (user-added) teleport items
-- ============================================================================
-- Account-wide list at OneWoW:GetPortalHub().customItems. Each entry is a
-- flat record { id, type, category = "custom", name, addedAt } so the Account
-- Sync tool can read it straight out of SavedVariables. Type is auto-detected
-- from the item ID (toy if the toybox knows it, otherwise a plain item).

--- Returns the raw account-wide custom item list (live table, do not mutate externally).
---@return table[]
function PortalHub:GetCustomItems()
	return OneWoW:GetPortalHub().customItems
end

--- Auto-detects whether an item ID is a toy or a regular item.
---@param id number
---@return "toy"|"item"|nil
function PortalHub:DetectItemType(id)
	if C_ToyBox.GetToyInfo(id) then
		return "toy"
	end
	if C_Item.GetItemInfoInstant(id) then
		return "item"
	end
	return nil
end

--- True if the ID is already in the custom list.
---@param id number
---@return boolean
function PortalHub:IsCustomItem(id)
	for _, entry in ipairs(OneWoW:GetPortalHub().customItems) do
		if entry.id == id then
			return true
		end
	end
	return false
end

--- Adds a user-supplied item/toy to the custom list. Validates the ID, rejects
--- duplicates, auto-detects the type, and resolves a display name.
---@param id number|string item ID (numeric, or a string the caller typed)
---@return boolean success
---@return string|nil detectedType on success, or an error message key on failure
function PortalHub:AddCustomItem(id)
	id = tonumber(id)
	if not id or id <= 0 then
		return false, L["PORTAL_CUSTOM_ERR_INVALID_ID"]
	end
	if self:IsCustomItem(id) then
		return false, L["PORTAL_CUSTOM_ERR_DUPLICATE"]
	end

	local itemType = self:DetectItemType(id)
	if not itemType then
		return false, L["PORTAL_CUSTOM_ERR_NOT_FOUND"]
	end

	local name
	if itemType == "toy" then
		name = select(2, C_ToyBox.GetToyInfo(id))
	else
		name = C_Item.GetItemNameByID(id)
	end

	tinsert(OneWoW:GetPortalHub().customItems, {
		id = id,
		type = itemType,
		category = "custom",
		name = name or tostring(id),
		addedAt = time(),
	})
	return true, itemType
end

--- Removes a custom item by ID.
---@param id number|string
---@return boolean removed
function PortalHub:RemoveCustomItem(id)
	id = tonumber(id)
	local items = OneWoW:GetPortalHub().customItems
	for i = #items, 1, -1 do
		if items[i].id == id then
			tremove(items, i)
			return true
		end
	end
	return false
end

--- Returns the custom items as portal entries for the "custom" category.
---@param showAll boolean when false, only owned/usable items are returned
---@return table[]
function PortalHub:GetCustomPortals(showAll)
	local portals = {}
	for _, entry in ipairs(OneWoW:GetPortalHub().customItems) do
		if showAll or ns.PortalHubDetection:IsPortalUsable(entry.type, entry.id) then
			tinsert(portals, {type = entry.type, id = entry.id, name = entry.name, category = "custom", isCustom = true})
		end
	end
	return portals
end

function PortalHub:GetFavorites()
	local favorites = {}
	if not OneWoW:GetPortalHub().escFavorites then
		return favorites
	end

	for _, fav in ipairs(OneWoW:GetPortalHub().escFavorites) do
		table.insert(favorites, {
			type = fav.type,
			id = fav.id,
			name = fav.name,
			available = ns.PortalHubDetection:IsPortalUsable(fav.type, fav.id)
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
			{id = "mid", name = EXPANSION_NAME11},
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

	table.insert(categories, {
		id = "custom",
		name = CUSTOM,
		icon = "Interface\\Icons\\Spell_arcane_portalstormwind",
	})

	return categories
end

function PortalHub:GetPortalsForCategory(categoryID, showAll)
	local portals = {}

	if categoryID == "favorites" then
		return self:GetFavorites()
	elseif categoryID == "hearth" then
		local hearthstones = ns.PortalData_Hearthstones:GetAvailable(showAll)
		for _, h in ipairs(hearthstones) do
			table.insert(portals, h)
		end
		table.insert(portals, {type = "header", name = L["Special"]})
		local specials = ns.PortalHubDetection:GetSpecialPortals(showAll)
		for _, s in ipairs(specials) do
			table.insert(portals, s)
		end
		return portals
	elseif categoryID == "professions" then
		local wormholes = ns.PortalHubDetection:GetWormholes(showAll)
		local rippers = ns.PortalHubDetection:GetDimensionalRippers(showAll)
		local transporters = ns.PortalHubDetection:GetUltrasafeTransporters(showAll)
		local engOther = ns.PortalHubDetection:GetEngineeringOtherItems(showAll)

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
		local ph = OneWoW:GetPortalHub()
		local allAbilities = {}
		if ph.showMageTeleports then
			local mageT = ns.PortalHubDetection:GetMageTeleports(showAll)
			if #mageT > 0 then
				table.insert(allAbilities, {type = "header", name = L["PORTAL_MAGE_TELEPORTS"]})
				for _, p in ipairs(mageT) do table.insert(allAbilities, p) end
			end
		end
		if ph.showMagePortals then
			local mageP = ns.PortalHubDetection:GetMagePortals(showAll)
			if #mageP > 0 then
				table.insert(allAbilities, {type = "header", name = L["PORTAL_MAGE_PORTALS"]})
				for _, p in ipairs(mageP) do table.insert(allAbilities, p) end
			end
		end
		local druid = ns.PortalHubDetection:GetDruidPortals(showAll)
		local dk = ns.PortalHubDetection:GetDeathKnightPortals(showAll)
		local monk = ns.PortalHubDetection:GetMonkPortals(showAll)
		local shaman = ns.PortalHubDetection:GetShamanPortals(showAll)
		local racial = ns.PortalHubDetection:GetRacePortals(showAll)
		for _, p in ipairs(druid) do table.insert(allAbilities, p) end
		for _, p in ipairs(dk) do table.insert(allAbilities, p) end
		for _, p in ipairs(monk) do table.insert(allAbilities, p) end
		for _, p in ipairs(shaman) do table.insert(allAbilities, p) end
		for _, p in ipairs(racial) do table.insert(allAbilities, p) end
		return allAbilities
	elseif categoryID == "instances" then
		local allPortals = {}
		local expansions = {"mid", "tww", "df", "sl", "bfa", "legion", "wod", "mop", "cata", "wotlk"}
		for _, exp in ipairs(expansions) do
			local dungeons = ns.PortalHubDetection:GetDungeonPortals(exp, showAll)
			for _, d in ipairs(dungeons) do
				table.insert(allPortals, d)
			end
			local raids = ns.PortalHubDetection:GetRaidPortals(exp, showAll)
			for _, r in ipairs(raids) do
				table.insert(allPortals, r)
			end
		end
		return allPortals
	elseif categoryID == "mid" or categoryID == "tww" or categoryID == "df" or categoryID == "sl" or
		   categoryID == "bfa" or categoryID == "legion" or categoryID == "wod" or
		   categoryID == "mop" or categoryID == "cata" or categoryID == "wotlk" then
		local allPortals = {}
		local dungeons = ns.PortalHubDetection:GetDungeonPortals(categoryID, showAll)
		local raids = ns.PortalHubDetection:GetRaidPortals(categoryID, showAll)

		for _, d in ipairs(dungeons) do
			table.insert(allPortals, d)
		end
		for _, r in ipairs(raids) do
			table.insert(allPortals, r)
		end
		return allPortals
	elseif categoryID == "items" then
		if ns.PortalHubItems then
			return ns.PortalHubItems:GetAllItems(showAll)
		end
		return portals
	elseif categoryID == "rings" or categoryID == "cloaks" or categoryID == "tabards" or
		   categoryID == "consumables" or categoryID == "special" then
		if ns.PortalHubItems then
			return ns.PortalHubItems:GetItemsBySubcategory(categoryID, showAll)
		end
		return portals
	elseif categoryID == "custom" then
		return self:GetCustomPortals(showAll)
	end

	return portals
end
