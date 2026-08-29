local _, ns = ...

ns.PortalHubItems = ns.PortalHubItems or {}
local ItemDetection = ns.PortalHubItems

function ItemDetection:GetRings(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	local rings = ns.PortalData:GetItemsByCategory(ns.PortalData.Categories.RINGS)
	for _, ring in ipairs(rings) do
		if showAll or ns.PortalData:IsItemAvailable(ring) then
			table.insert(portals, {type = ring.type, id = ring.id, name = ring.name, category = "rings"})
		end
	end

	return portals
end

function ItemDetection:GetCloaks(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	local cloaks = ns.PortalData:GetItemsByCategory(ns.PortalData.Categories.CLOAKS)
	for _, cloak in ipairs(cloaks) do
		if showAll or ns.PortalData:IsItemAvailable(cloak) then
			table.insert(portals, {type = cloak.type, id = cloak.id, name = cloak.name, category = "cloaks"})
		end
	end

	return portals
end

function ItemDetection:GetTabards(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	local tabards = ns.PortalData:GetItemsByCategory(ns.PortalData.Categories.TABARDS)
	for _, tabard in ipairs(tabards) do
		if showAll or ns.PortalData:IsItemAvailable(tabard) then
			table.insert(portals, {type = tabard.type, id = tabard.id, name = tabard.name, category = "tabards"})
		end
	end

	return portals
end

function ItemDetection:GetEngineeringItems(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	if not ns.PortalHubDetection:HasProfession("Engineering") and not showAll then
		return portals
	end

	if ns.PortalData.Items.engineering.wormholes then
		for _, wormhole in ipairs(ns.PortalData.Items.engineering.wormholes) do
			if showAll or (PlayerHasToy(wormhole.id) and C_ToyBox.IsToyUsable(wormhole.id)) then
				table.insert(portals, {type = "toy", id = wormhole.id, name = wormhole.name, category = "wormholes"})
			end
		end
	end

	if ns.PortalData.Items.engineering.rippers then
		for _, ripper in ipairs(ns.PortalData.Items.engineering.rippers) do
			if showAll or (PlayerHasToy(ripper.id) and C_ToyBox.IsToyUsable(ripper.id)) then
				table.insert(portals, {type = "toy", id = ripper.id, name = ripper.name, category = "rippers"})
			end
		end
	end

	if ns.PortalData.Items.engineering.transporters then
		for _, transporter in ipairs(ns.PortalData.Items.engineering.transporters) do
			if transporter.type == "toy" then
				if showAll or (PlayerHasToy(transporter.id) and C_ToyBox.IsToyUsable(transporter.id)) then
					table.insert(portals, {type = "toy", id = transporter.id, name = transporter.name, category = "transporters"})
				end
			else
				if showAll or C_Item.GetItemCount(transporter.id) > 0 then
					table.insert(portals, {type = "item", id = transporter.id, name = transporter.name, category = "transporters"})
				end
			end
		end
	end

	if ns.PortalData.Items.engineering.other then
		for _, other in ipairs(ns.PortalData.Items.engineering.other) do
			if showAll or C_Item.GetItemCount(other.id) > 0 then
				table.insert(portals, {type = "item", id = other.id, name = other.name, category = "engineering_other"})
			end
		end
	end

	return portals
end

function ItemDetection:GetConsumables(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	local consumables = ns.PortalData:GetItemsByCategory(ns.PortalData.Categories.CONSUMABLES)
	for _, consumable in ipairs(consumables) do
		if showAll or C_Item.GetItemCount(consumable.id) > 0 then
			table.insert(portals, {type = "item", id = consumable.id, name = consumable.name, category = "consumables"})
		end
	end

	return portals
end

function ItemDetection:GetSpecialItems(showAll)
	local portals = {}
	if not ns.PortalData then return portals end

	local specials = ns.PortalData:GetItemsByCategory(ns.PortalData.Categories.SPECIAL_ITEMS)
	for _, special in ipairs(specials) do
		if showAll or ns.PortalData:IsItemAvailable(special) then
			table.insert(portals, {type = special.type, id = special.id, name = special.name, category = "special"})
		end
	end

	return portals
end

function ItemDetection:GetAllItems(showAll, excludeFromOtherCategories)
	local allItems = {}
	-- Same item can live in more than one subcategory; keep one copy on the combined list.
	local seen = {}

	local function AppendUnique(list)
		for _, item in ipairs(list) do
			local key = (item.type or "item") .. ":" .. item.id
			if not seen[key] then
				seen[key] = true
				table.insert(allItems, item)
			end
		end
	end

	AppendUnique(self:GetRings(showAll))
	AppendUnique(self:GetCloaks(showAll))
	AppendUnique(self:GetTabards(showAll))
	AppendUnique(self:GetConsumables(showAll))
	AppendUnique(self:GetSpecialItems(showAll))

	if not excludeFromOtherCategories then
		AppendUnique(self:GetEngineeringItems(showAll))
	end

	return allItems
end

function ItemDetection:GetItemsBySubcategory(subcategory, showAll)
	if subcategory == "wormholes" or subcategory == "rippers" or subcategory == "transporters" or subcategory == "engineering_other" then
		local allEng = self:GetEngineeringItems(showAll)
		local filtered = {}
		for _, item in ipairs(allEng) do
			if item.category == subcategory then
				table.insert(filtered, item)
			end
		end
		return filtered
	elseif subcategory == "rings" then
		return self:GetRings(showAll)
	elseif subcategory == "cloaks" then
		return self:GetCloaks(showAll)
	elseif subcategory == "tabards" then
		return self:GetTabards(showAll)
	elseif subcategory == "consumables" then
		return self:GetConsumables(showAll)
	elseif subcategory == "special" then
		return self:GetSpecialItems(showAll)
	end

	return {}
end
