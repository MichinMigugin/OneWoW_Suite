local ADDON_NAME, OneWoW = ...
local L = OneWoW.L

OneWoW.PortalHubEsc = OneWoW.PortalHubEsc or {}
local EscMenu = OneWoW.PortalHubEsc

local leftFrame = nil
local rightFrame = nil
local secureButtons = {}
local flyoutButtons = {}
local instanceStatsFrame = nil
local lastAutoUpdatedInstance = nil
local autoUpdateFrame = nil

local issecretvalue = issecretvalue or function() return false end
local function IsSecret(value)
	return issecretvalue(value)
end

function EscMenu:Initialize()
	if not OneWoW.db.global.instanceStatsEsc then
		OneWoW.db.global.instanceStatsEsc = {enabled = false}
	end
	if not OneWoW.db.global.portalHub then
		OneWoW.db.global.portalHub = {}
	end
	self:HookGameMenu()
	self:RegisterAutoUpdateEvents()
end

function EscMenu:RegisterAutoUpdateEvents()
	if not autoUpdateFrame then
		autoUpdateFrame = CreateFrame("Frame")
		autoUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		autoUpdateFrame:SetScript("OnEvent", function(self, event, ...)
			if event == "PLAYER_ENTERING_WORLD" then
				C_Timer.After(2, function()
					EscMenu:AutoUpdateCurrentInstance()
				end)
			end
		end)
	end
end

function EscMenu:AutoUpdateCurrentInstance()
	local name, instanceType = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return end
	if not name or name == "" then return end
	if lastAutoUpdatedInstance == name then return end
	lastAutoUpdatedInstance = name

	local journalData = self:GetInstanceJournalData(name)
	if not journalData or not OneWoW.JournalModule then return end

	C_Timer.After(1, function()
		OneWoW.JournalModule:UpdateInstanceItems(journalData.journalInstanceID, journalData.expansion, function(success, updatedCount) end)
	end)
end

function EscMenu:HookGameMenu()
	hooksecurefunc("ToggleGameMenu", function()
		if not GameMenuFrame:IsShown() or InCombatLockdown() then return end
		if OneWoW.db.global.portalHub and OneWoW.db.global.portalHub.escEnabled then
			EscMenu:ShowPortalFrames()
		else
			EscMenu:HidePortalFrames()
		end
		if OneWoW.db.global.instanceStatsEsc and OneWoW.db.global.instanceStatsEsc.enabled then
			EscMenu:ShowInstanceStatsFrame()
		else
			EscMenu:HideInstanceStatsFrame()
		end
	end)

	if GameMenuFrame then
		GameMenuFrame:HookScript("OnHide", function()
			EscMenu:HideInstanceStatsFrame()
			EscMenu:HidePortalFrames()
		end)
	end
end

function EscMenu:HidePortalFrames()
	if OneWoW.PortalHubFlyouts then
		OneWoW.PortalHubFlyouts:RecycleAll()
	end
	if OneWoW.NestedFlyouts then
		OneWoW.NestedFlyouts:RecycleAll()
	end
	if OneWoW.EscPanels then
		OneWoW.EscPanels:HideAll()
	end
	if leftFrame then leftFrame:Hide() end
	if rightFrame then rightFrame:Hide() end
end

function EscMenu:ShowPortalFrames()
	if not GameMenuFrame then return end

	for _, button in ipairs(secureButtons) do
		if button.Recycle then button:Recycle() end
	end
	for _, button in ipairs(flyoutButtons) do
		if button.Recycle then button:Recycle() end
	end
	secureButtons = {}
	flyoutButtons = {}

	if OneWoW.PortalHubFlyouts then
		OneWoW.PortalHubFlyouts:RecycleAll()
	end
	if OneWoW.NestedFlyouts then
		OneWoW.NestedFlyouts:RecycleAll()
	end

	if not leftFrame then
		leftFrame = CreateFrame("Frame", "OneWoWPortalLeft", GameMenuFrame)
		leftFrame:SetSize(1, 1)
	end
	if not rightFrame then
		rightFrame = CreateFrame("Frame", "OneWoWPortalRight", GameMenuFrame)
		rightFrame:SetSize(1, 1)
	end

	local iconSize = OneWoW.db.global.portalHub.escIconSize or 40
	local iconGap = 2
	local paddingLeft = 40
	local paddingRight = 10
	local yStart = -(iconSize / 2) - 10

	leftFrame:SetPoint("TOPRIGHT", GameMenuFrame, "TOPLEFT", -paddingLeft, yStart)
	rightFrame:SetPoint("TOPLEFT", GameMenuFrame, "TOPRIGHT", paddingRight, yStart)

	self:BuildLeftSide(leftFrame, iconSize, iconGap)
	self:BuildRightSide(rightFrame, iconSize, iconGap)

	leftFrame:Show()
	rightFrame:Show()
end

function EscMenu:BuildLeftSide(parent, iconSize, iconGap)
	if OneWoW.EscPanels then
		OneWoW.EscPanels:Build(parent)
	end
end

function EscMenu:BuildRightSide(parent, iconSize, iconGap)
	local ph = OneWoW.db.global.portalHub
	if not ph or not ph.escPortalsEnabled then return end
	local showAll = ph.showAllOnEsc or false
	local yOffset = 0
	local xOffset = 0

	if not OneWoW.PortalHubFlyouts then return end

	local hearthButtons = {}
	if OneWoW.db.global.portalHub.showHearthstone or showAll then
		local hsType = OneWoW.db.global.portalHub.randomHearthstone and "randomhearth" or "item"
		table.insert(hearthButtons, {type = hsType, id = 6948})
	end
	if showAll or (PlayerHasToy(140192) and C_QuestLog.IsQuestFlaggedCompleted(44663)) then
		table.insert(hearthButtons, {type = "toy", id = 140192})
	end
	if showAll or (PlayerHasToy(110560) and C_QuestLog.IsQuestFlaggedCompleted(34378)) then
		table.insert(hearthButtons, {type = "toy", id = 110560})
	end
	if showAll or C_Item.GetItemCount(141605) > 0 or PlayerHasToy(141605) then
		table.insert(hearthButtons, {type = "item", id = 141605})
	end
	local housingPortal = OneWoW.PortalHubDetection:GetHousingPortal(showAll)
	if housingPortal then
		table.insert(hearthButtons, housingPortal)
	end

	xOffset = 0
	for _, hearth in ipairs(hearthButtons) do
		local button = self:CreatePortalButton(parent, hearth, xOffset, yOffset, iconSize, "RIGHT")
		table.insert(secureButtons, button)
		xOffset = xOffset + iconSize + iconGap
	end
	yOffset = yOffset - (iconSize + iconGap)
	xOffset = 0

	local favorites = OneWoW.PortalHubModule:GetFavorites()
	local favAvailable = {}
	for _, fav in ipairs(favorites) do
		if fav.available then
			table.insert(favAvailable, fav)
		end
	end
	if #favAvailable > 0 or showAll then
		local displayFav = #favAvailable > 0 and favAvailable or {{type = "spell", id = 6948}}
		local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, 1506458, iconSize, 0, yOffset, displayFav, "RIGHT", "Fav"
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	local druid = OneWoW.PortalHubDetection:GetDruidPortals(showAll)
	local dk = OneWoW.PortalHubDetection:GetDeathKnightPortals(showAll)
	local monk = OneWoW.PortalHubDetection:GetMonkPortals(showAll)
	local shaman = OneWoW.PortalHubDetection:GetShamanPortals(showAll)
	local covenant = OneWoW.PortalHubDetection:GetCovenantPortals(showAll)
	local racial = OneWoW.PortalHubDetection:GetRacePortals(showAll)

	local allAbilities = {}
	for _, p in ipairs(druid) do table.insert(allAbilities, p) end
	for _, p in ipairs(dk) do table.insert(allAbilities, p) end
	for _, p in ipairs(monk) do table.insert(allAbilities, p) end
	for _, p in ipairs(shaman) do table.insert(allAbilities, p) end
	for _, p in ipairs(covenant) do table.insert(allAbilities, p) end
	for _, p in ipairs(racial) do table.insert(allAbilities, p) end

	if #allAbilities > 0 or showAll then
		local displayAbilities = #allAbilities > 0 and allAbilities or {{type = "spell", id = 556}}
		local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, "Interface\\Icons\\Achievement_BG_winAB_underXminutes", iconSize, 0, yOffset, displayAbilities, "RIGHT", "Abilities"
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	local wormholes = OneWoW.PortalHubDetection:GetWormholes(showAll)
	local rippers = OneWoW.PortalHubDetection:GetDimensionalRippers(showAll)
	local transporters = OneWoW.PortalHubDetection:GetUltrasafeTransporters(showAll)
	local engOther = OneWoW.PortalHubDetection:GetEngineeringOtherItems(showAll)
	local allEng = {}
	for _, w in ipairs(wormholes) do table.insert(allEng, w) end
	for _, r in ipairs(rippers) do table.insert(allEng, r) end
	for _, t in ipairs(transporters) do table.insert(allEng, t) end
	for _, o in ipairs(engOther) do table.insert(allEng, o) end
	if #allEng > 0 or showAll then
		local displayEng = #allEng > 0 and allEng or {{type = "toy", id = 48933}}
		local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, "Interface\\Icons\\Trade_Engineering", iconSize, 0, yOffset, displayEng, "RIGHT", "Prof"
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	local mageT = OneWoW.PortalHubDetection:GetMageTeleports(showAll)
	local mageP = OneWoW.PortalHubDetection:GetMagePortals(showAll)
	local allMage = {}
	for _, t in ipairs(mageT) do table.insert(allMage, t) end
	for _, p in ipairs(mageP) do table.insert(allMage, p) end
	if #allMage > 0 or showAll then
		local icon = C_Spell.GetSpellTexture(3561) or 237509
		local displayMage = #allMage > 0 and allMage or {{type = "spell", id = 3561}}
		local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, icon, iconSize, 0, yOffset, displayMage, "RIGHT", "Mage"
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	yOffset = yOffset - (iconSize + iconGap)

	if OneWoW.NestedFlyouts then
		local dungeonExpansions = {
			{id = "mid", label = "MID", icon = "Interface\\Icons\\Spell_Arcane_Portal_Silvermoon", portals = OneWoW.PortalHubDetection:GetDungeonPortals("mid", showAll)},
			{id = "tww", label = "TWW", icon = 5872031, portals = OneWoW.PortalHubDetection:GetDungeonPortals("tww", showAll)},
			{id = "df", label = "DF", icon = 4640496, portals = OneWoW.PortalHubDetection:GetDungeonPortals("df", showAll)},
			{id = "sl", label = "SL", icon = 236798, portals = OneWoW.PortalHubDetection:GetDungeonPortals("sl", showAll)},
			{id = "bfa", label = "BFA", icon = 1869493, portals = OneWoW.PortalHubDetection:GetDungeonPortals("bfa", showAll)},
			{id = "legion", label = "LEG", icon = 1260827, portals = OneWoW.PortalHubDetection:GetDungeonPortals("legion", showAll)},
			{id = "wod", label = "WoD", icon = 1413856, portals = OneWoW.PortalHubDetection:GetDungeonPortals("wod", showAll)},
			{id = "mop", label = "MoP", icon = 328269, portals = OneWoW.PortalHubDetection:GetDungeonPortals("mop", showAll)},
			{id = "cata", label = "CAT", icon = 574788, portals = OneWoW.PortalHubDetection:GetDungeonPortals("cata", showAll)},
		}

		local hasDungeons = false
		for _, exp in ipairs(dungeonExpansions) do
			if #exp.portals > 0 or (showAll and exp.id == "mid") then
				hasDungeons = true
				break
			end
		end

		if hasDungeons then
			local dungeonButton = OneWoW.NestedFlyouts:CreateDungeonsButton(parent, iconSize, yOffset, dungeonExpansions, showAll)
			table.insert(flyoutButtons, dungeonButton)
			yOffset = yOffset - (iconSize + iconGap)
		end

		local raidExpansions = {
			{id = "mid", label = "MID", icon = "Interface\\Icons\\Spell_Arcane_Portal_Silvermoon", portals = OneWoW.PortalHubDetection:GetRaidPortals("mid", showAll)},
			{id = "tww", label = "TWW", icon = 5872031, portals = OneWoW.PortalHubDetection:GetRaidPortals("tww", showAll)},
			{id = "df", label = "DF", icon = 4640496, portals = OneWoW.PortalHubDetection:GetRaidPortals("df", showAll)},
			{id = "sl", label = "SL", icon = 236798, portals = OneWoW.PortalHubDetection:GetRaidPortals("sl", showAll)},
			{id = "bfa", label = "BFA", icon = 1869493, portals = OneWoW.PortalHubDetection:GetRaidPortals("bfa", showAll)},
			{id = "legion", label = "LEG", icon = 1260827, portals = OneWoW.PortalHubDetection:GetRaidPortals("legion", showAll)},
			{id = "wod", label = "WoD", icon = 1413856, portals = OneWoW.PortalHubDetection:GetRaidPortals("wod", showAll)},
			{id = "mop", label = "MoP", icon = 328269, portals = OneWoW.PortalHubDetection:GetRaidPortals("mop", showAll)},
			{id = "cata", label = "CAT", icon = 574788, portals = OneWoW.PortalHubDetection:GetRaidPortals("cata", showAll)},
		}

		local hasRaids = false
		for _, exp in ipairs(raidExpansions) do
			if #exp.portals > 0 or (showAll and exp.id == "mid") then
				hasRaids = true
				break
			end
		end

		if hasRaids then
			local raidButton = OneWoW.NestedFlyouts:CreateRaidsButton(parent, iconSize, yOffset, raidExpansions, showAll)
			table.insert(flyoutButtons, raidButton)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end

	local showSeasonal = OneWoW.db.global.portalHub.showSeasonal ~= false
	local seasonPortals = OneWoW.PortalHubDetection:GetCurrentSeasonPortals(showAll or showSeasonal)
	if (#seasonPortals > 0) then
		local displaySeason = #seasonPortals > 0 and seasonPortals or {{type = "spell", id = 1254400}}
		local seasonIcon = C_Spell.GetSpellTexture(1254400) or "Interface\\Icons\\Achievement_Boss_Archaedas"
		local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
			parent, seasonIcon, iconSize, 0, yOffset, displaySeason, "RIGHT", "S.1"
		)
		table.insert(flyoutButtons, button)
		yOffset = yOffset - (iconSize + iconGap)
	end

	if OneWoW.PortalHubItems then
		local allItems = OneWoW.PortalHubItems:GetAllItems(showAll, true)
		if #allItems > 0 or showAll then
			local displayItems = #allItems > 0 and allItems or {{type = "item", id = 6948}}
			local button = OneWoW.PortalHubFlyouts:CreateFlyoutParentButton(
				parent, "Interface\\Icons\\INV_Misc_Bag_10", iconSize, 0, yOffset, displayItems, "RIGHT", "Items"
			)
			table.insert(flyoutButtons, button)
			yOffset = yOffset - (iconSize + iconGap)
		end
	end

	yOffset = yOffset - (iconSize + iconGap)

	local openButton = self:CreateOpenHubButton(parent, 0, yOffset, iconSize)
	table.insert(secureButtons, openButton)
end

function EscMenu:CreatePortalButton(parent, portalData, xOffset, yOffset, iconSize, side)
	local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	button:SetSize(iconSize, iconSize)

	if side == "LEFT" then
		button:SetPoint("TOPLEFT", parent, "TOPRIGHT", xOffset, yOffset)
	else
		button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
	end

	button.cooldownFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldownFrame:SetAllPoints()

	button.text = button:CreateFontString(nil, "OVERLAY")
	button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
	button.text:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
	button.text:SetTextColor(1, 1, 1, 1)
	button.text:SetShadowColor(0, 0, 0, 1)
	button.text:SetShadowOffset(1, -1)

	button:EnableMouse(true)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAttribute("useOnKeyDown", true)

	if portalData.type == "randomhearth" then
		local hasHearthstoneItem = C_Item.GetItemCount(6948) > 0
		local randomEnabled = OneWoW.db.global.portalHub.randomHearthstone
		local hearthstones = OneWoW.PortalData_Hearthstones and OneWoW.PortalData_Hearthstones.List or {}
		local availableToys = {}

		for id, condition in pairs(hearthstones) do
			if id ~= 6948 and PlayerHasToy(id) then
				if type(condition) == "function" then
					if condition() then table.insert(availableToys, id) end
				elseif condition == true then
					table.insert(availableToys, id)
				end
			end
		end

		if randomEnabled then
			local available = {}
			if hasHearthstoneItem then table.insert(available, 6948) end
			for _, toyID in ipairs(availableToys) do table.insert(available, toyID) end

			if #available == 0 then
				button:SetAttribute("type", "macro")
				button:SetAttribute("macrotext", "/run print('|cFF00FF00OneWoW:|r No hearthstones available!')")
			else
				local selectedID = available[math.random(1, #available)]
				if selectedID == 6948 then
					button:SetAttribute("type", "item")
					button:SetAttribute("item", "item:6948")
				else
					button:SetAttribute("type", "toy")
					button:SetAttribute("toy", selectedID)
				end
			end
		else
			if hasHearthstoneItem then
				button:SetAttribute("type", "item")
				button:SetAttribute("item", "item:6948")
			elseif #availableToys > 0 then
				button:SetAttribute("type", "toy")
				button:SetAttribute("toy", availableToys[math.random(1, #availableToys)])
			else
				button:SetAttribute("type", "macro")
				button:SetAttribute("macrotext", "/run print('|cFF00FF00OneWoW:|r No hearthstones available!')")
			end
		end

		local item = Item:CreateFromItemID(6948)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then button:SetNormalTexture(icon) end
		end)
	elseif portalData.type == "toy" then
		button:SetAttribute("type", "toy")
		button:SetAttribute("toy", portalData.id)
		local _, name, icon = C_ToyBox.GetToyInfo(portalData.id)
		if icon then
			button:SetNormalTexture(icon)
		else
			local item = Item:CreateFromItemID(portalData.id)
			item:ContinueOnItemLoad(function()
				local itemIcon = item:GetItemIcon()
				if itemIcon then
					button:SetNormalTexture(itemIcon)
				end
			end)
		end
	elseif portalData.type == "item" then
		if OneWoW.PortalHubEquip and OneWoW.PortalHubEquip:IsItemEquippable(portalData.id) then
			button:SetAttribute("type", "macro")
			if OneWoW.PortalHubEquip:IsItemEquipped(portalData.id) then
				button:SetAttribute("macrotext", "/use " .. portalData.id)
			else
				button:SetAttribute("macrotext", "/equip " .. portalData.id)
			end
		else
			button:SetAttribute("type", "item")
			button:SetAttribute("item", "item:" .. portalData.id)
		end
		local item = Item:CreateFromItemID(portalData.id)
		item:ContinueOnItemLoad(function()
			local icon = item:GetItemIcon()
			if icon then button:SetNormalTexture(icon) end
		end)
	elseif portalData.type == "spell" then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", portalData.id)
		local icon = C_Spell.GetSpellTexture(portalData.id)
		if icon then button:SetNormalTexture(icon) end
		if OneWoW.PortalData and OneWoW.PortalData:GetShortName(portalData.id) then
			button.text:SetText(OneWoW.PortalData:GetShortName(portalData.id))
		end
	elseif portalData.type == "housing" then
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", "/run local h=C_Housing.GetCurrentHouseInfo();if h and h.houseGUID then C_Housing.TeleportHome(h.neighborhoodGUID,h.houseGUID,h.plotID)end")
		local icon = C_Spell.GetSpellTexture(1263273)
		if icon then button:SetNormalTexture(icon) end
	end

	button:SetScript("PostClick", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			if portalData.type == "item" and OneWoW.PortalHubEquip then
				if OneWoW.PortalHubEquip:IsItemEquippable(portalData.id) and not OneWoW.PortalHubEquip:IsItemEquipped(portalData.id) then
					return
				end
			end
			if GameMenuFrame and GameMenuFrame:IsShown() then
				C_Timer.After(0.1, function() HideUIPanel(GameMenuFrame) end)
			end
		end
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
		if portalData.type == "randomhearth" or portalData.type == "item" then
			GameTooltip:SetItemByID(portalData.id)
		elseif portalData.type == "toy" then
			GameTooltip:SetToyByItemID(portalData.id)
		elseif portalData.type == "spell" then
			GameTooltip:SetSpellByID(portalData.id)
		elseif portalData.type == "housing" then
			GameTooltip:SetText(L["SETTINGS_PORTALHUB_TELEPORT_HOME"], 1, 1, 1)
		end
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	self:UpdateCooldown(button, portalData)

	function button:Recycle()
		self:Hide()
		self:ClearAllPoints()
		self:SetParent(nil)
		self.text:SetText("")
	end

	button:Show()
	return button
end

function EscMenu:UpdateCooldown(button, portalData)
	if not button.cooldownFrame then return end

	local start, duration, enabled

	if portalData.type == "randomhearth" or portalData.type == "toy" or portalData.type == "item" then
		start, duration, enabled = C_Item.GetItemCooldown(portalData.id)
	elseif portalData.type == "spell" then
		local cooldown = C_Spell.GetSpellCooldown(portalData.id)
		if cooldown then
			start = cooldown.startTime
			duration = cooldown.duration
			enabled = true
		end
	elseif portalData.type == "housing" then
		if C_Housing and C_Housing.GetVisitCooldownInfo then
			local cdInfo = C_Housing.GetVisitCooldownInfo()
			start = cdInfo.startTime
			duration = cdInfo.duration
			enabled = cdInfo.isEnabled
		end
	end

	if enabled and not IsSecret(duration) and duration > 0 then
		button.cooldownFrame:SetCooldown(start, duration)
	else
		button.cooldownFrame:Clear()
	end
end

function EscMenu:CreateOpenHubButton(parent, xOffset, yOffset, iconSize)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(iconSize, iconSize)
	button:SetPoint("LEFT", parent, "TOPLEFT", xOffset, yOffset)
	button:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")

	button:SetScript("OnClick", function()
		HideUIPanel(GameMenuFrame)
		C_Timer.After(0.15, function()
			if OneWoW.GUI then
				OneWoW.GUI:Show("settings")
				C_Timer.After(0.1, function()
					OneWoW.GUI:SelectSubTab("settings", "portals")
				end)
			end
		end)
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Open Portal Hub"], 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)

	function button:Recycle()
		self:Hide()
		self:ClearAllPoints()
		self:SetParent(nil)
	end

	button:Show()
	return button
end

function EscMenu:Reload()
	-- Only refresh when ESC menu is actually open; otherwise ShowPortalFrames would display
	-- panels (CHARACTER INFO, ALERTS, ZONE NOTES) as stray UI outside the menu
	if GameMenuFrame and GameMenuFrame:IsShown() then
		self:ShowPortalFrames()
	end
end

function EscMenu:HideInstanceStatsFrame()
	if instanceStatsFrame then instanceStatsFrame:Hide() end
end

function EscMenu:ShowInstanceStatsFrame()
	local name, instanceType, difficultyID, difficultyName, maxPlayers = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then
		self:HideInstanceStatsFrame()
		return
	end
	if not name or name == "" then
		self:HideInstanceStatsFrame()
		return
	end
	self:CreateOrUpdateInstanceStatsFrame(name, instanceType, difficultyName, maxPlayers)
end

function EscMenu:CreateOrUpdateInstanceStatsFrame(instanceName, instanceType, difficultyName, maxPlayers, refreshCount)
	if not instanceName then return end
	refreshCount = refreshCount or 0

	local journalData, collectiblesStats = self:GetInstanceJournalData(instanceName)
	local statsText = instanceType == "party" and L["SETTINGS_PORTALHUB_DUNGEON"] or L["SETTINGS_PORTALHUB_RAID"]
	if difficultyName and difficultyName ~= "" then
		statsText = statsText .. " - " .. difficultyName
	end
	if maxPlayers and maxPlayers > 0 then
		statsText = statsText .. " (" .. maxPlayers .. " players)"
	end

	if collectiblesStats then
		statsText = statsText .. "\n\n"
		local statLines = {}
		if collectiblesStats.mounts.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_MOUNTS_FORMAT"], collectiblesStats.mounts.collected, collectiblesStats.mounts.total))
		end
		if collectiblesStats.pets.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_PETS_FORMAT"], collectiblesStats.pets.collected, collectiblesStats.pets.total))
		end
		if collectiblesStats.recipes.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_RECIPES_FORMAT"], collectiblesStats.recipes.collected, collectiblesStats.recipes.total))
		end
		if collectiblesStats.tmog.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_TMOGS_FORMAT"], collectiblesStats.tmog.collected, collectiblesStats.tmog.total))
		end
		if collectiblesStats.housing.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_HOUSING_FORMAT"], collectiblesStats.housing.collected, collectiblesStats.housing.total))
		end
		if collectiblesStats.toys.total > 0 then
			table.insert(statLines, string.format(L["SETTINGS_PORTALHUB_TOYS_FORMAT"], collectiblesStats.toys.collected, collectiblesStats.toys.total))
		end
		if #statLines > 0 then
			statsText = statsText .. table.concat(statLines, "\n")
		end
	end

	if not instanceStatsFrame then
		instanceStatsFrame = CreateFrame("Frame", "OneWoWInstanceStatsFrame", UIParent, "BackdropTemplate")
		instanceStatsFrame:SetSize(375, 250)
		instanceStatsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		instanceStatsFrame:SetFrameLevel(1000)
		instanceStatsFrame:EnableMouse(true)
		instanceStatsFrame:SetMovable(true)
		instanceStatsFrame:SetClampedToScreen(true)
		instanceStatsFrame:RegisterForDrag("LeftButton")

		instanceStatsFrame.bgTexture = instanceStatsFrame:CreateTexture(nil, "BACKGROUND")
		instanceStatsFrame.bgTexture:SetAllPoints(instanceStatsFrame)
		instanceStatsFrame.bgTexture:SetAtlas("GarrMissionLocation-Maw-bg-01", true)

		local title = instanceStatsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
		title:SetPoint("TOP", instanceStatsFrame, "TOP", 0, -15)
		title:SetJustifyH("CENTER")
		title:SetTextColor(1, 1, 1)
		title:SetShadowColor(0, 0, 0, 1)
		title:SetShadowOffset(2, -2)
		instanceStatsFrame.title = title

		local subtitle = instanceStatsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
		subtitle:SetJustifyH("CENTER")
		subtitle:SetTextColor(0.8, 0.9, 1)
		subtitle:SetShadowColor(0, 0, 0, 1)
		subtitle:SetShadowOffset(1, -1)
		instanceStatsFrame.subtitle = subtitle

		local statsTextObj = instanceStatsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		statsTextObj:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
		statsTextObj:SetWidth(350)
		statsTextObj:SetJustifyH("CENTER")
		statsTextObj:SetWordWrap(true)
		statsTextObj:SetTextColor(1, 1, 0.5)
		statsTextObj:SetShadowColor(0, 0, 0, 1)
		statsTextObj:SetShadowOffset(1, -1)
		statsTextObj:SetSpacing(3)
		instanceStatsFrame.statsText = statsTextObj

		local divider = instanceStatsFrame:CreateTexture(nil, "ARTWORK")
		divider:SetAtlas("Options_HorizontalDivider", true)
		divider:SetPoint("BOTTOM", instanceStatsFrame, "BOTTOM", 0, 48)
		divider:SetSize(350, 8)

		local openJournalButton = CreateFrame("Button", nil, instanceStatsFrame, "UIPanelButtonTemplate")
		openJournalButton:SetSize(150, 30)
		openJournalButton:SetPoint("BOTTOM", instanceStatsFrame, "BOTTOM", 0, 10)
		openJournalButton:SetText(L["SETTINGS_PORTALHUB_UPDATE_DATA"])
		openJournalButton:SetScript("OnClick", function(self)
			HideUIPanel(GameMenuFrame)
		end)

		instanceStatsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
		instanceStatsFrame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			EscMenu:SaveInstanceStatsPosition()
		end)

		EscMenu:RestoreInstanceStatsPosition()
	end

	instanceStatsFrame.title:SetText(instanceName)
	instanceStatsFrame.subtitle:SetText(L["SETTINGS_PORTALHUB_INSTANCE_STATISTICS"])
	instanceStatsFrame.statsText:SetText(statsText)
	instanceStatsFrame:Show()

	if refreshCount < 3 then
		C_Timer.After(0.3, function()
			if instanceStatsFrame and instanceStatsFrame:IsVisible() then
				EscMenu:CreateOrUpdateInstanceStatsFrame(instanceName, instanceType, difficultyName, maxPlayers, refreshCount + 1)
			end
		end)
	end
end

function EscMenu:GetInstanceJournalData(instanceName)
	if not OneWoW.JournalModule then return nil, nil end
	local allInstances, error = OneWoW.JournalModule:GetJournalData()
	if error or not allInstances then return nil, nil end

	for _, instance in ipairs(allInstances) do
		if instance.name and instance.name:lower() == instanceName:lower() then
			local stats = {
				mounts = {collected = 0, total = 0},
				pets = {collected = 0, total = 0},
				recipes = {collected = 0, total = 0},
				tmog = {collected = 0, total = 0},
				housing = {collected = 0, total = 0},
				toys = {collected = 0, total = 0}
			}
			return instance, stats
		end
	end
	return nil, nil
end

function EscMenu:SaveInstanceStatsPosition()
	if not instanceStatsFrame then return end
	local point, _, relativePoint, x, y = instanceStatsFrame:GetPoint()
	if not OneWoW.db.global.instanceStatsPosition then
		OneWoW.db.global.instanceStatsPosition = {}
	end
	OneWoW.db.global.instanceStatsPosition.point = point
	OneWoW.db.global.instanceStatsPosition.relativePoint = relativePoint
	OneWoW.db.global.instanceStatsPosition.x = x
	OneWoW.db.global.instanceStatsPosition.y = y
end

function EscMenu:RestoreInstanceStatsPosition()
	if not instanceStatsFrame then return end
	local savedPos = OneWoW.db and OneWoW.db.global and OneWoW.db.global.instanceStatsPosition
	if savedPos and savedPos.point then
		instanceStatsFrame:ClearAllPoints()
		instanceStatsFrame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)
	else
		instanceStatsFrame:ClearAllPoints()
		instanceStatsFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
	end
end
