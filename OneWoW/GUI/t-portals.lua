local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local function T(key)
	if OneWoW.Constants and OneWoW.Constants.THEME and OneWoW.Constants.THEME[key] then
		return unpack(OneWoW.Constants.THEME[key])
	end
	return 0.5, 0.5, 0.5, 1.0
end

local selectedCategory = nil
local portalButtons = {}
local headerFrames = {}
local portalButtonPool = {}
local currentPortals = {}

function GUI:CreatePortalsTab(parent)
	local L = OneWoW.L or {}

	local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	controlPanel:SetHeight(45)
	controlPanel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	controlPanel:SetBackdropColor(T("BG_SECONDARY"))
	controlPanel:SetBackdropBorderColor(T("BORDER_SUBTLE"))

	if not OneWoW.db.global.portalHub then
		OneWoW.db.global.portalHub = {}
	end
	local ph = OneWoW.db.global.portalHub
	if ph.escEnabled == nil then ph.escEnabled = true end
	if ph.randomHearthstone == nil then ph.randomHearthstone = true end
	if ph.showAll == nil then ph.showAll = true end
	if ph.showAllOnEsc == nil then ph.showAllOnEsc = false end
	if ph.showSeasonal == nil then ph.showSeasonal = true end

	local escCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
	escCheckbox:SetPoint("LEFT", controlPanel, "LEFT", 10, 0)
	escCheckbox:SetSize(24, 24)
	escCheckbox:SetChecked(OneWoW.db.global.portalHub.escEnabled)
	escCheckbox:SetScript("OnClick", function(self)
		OneWoW.db.global.portalHub.escEnabled = self:GetChecked()
		if OneWoW.PortalHubEsc then
			if self:GetChecked() then
				OneWoW.PortalHubEsc:ShowPortalFrames()
			else
				OneWoW.PortalHubEsc:HidePortalFrames()
			end
		end
	end)

	local escLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	escLabel:SetPoint("LEFT", escCheckbox, "RIGHT", 5, 0)
	escLabel:SetText(L["Enable ESC Menu"])
	escLabel:SetTextColor(T("TEXT_PRIMARY"))

	local randomHearthCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
	randomHearthCheckbox:SetPoint("LEFT", escLabel, "RIGHT", 20, 0)
	randomHearthCheckbox:SetSize(24, 24)
	randomHearthCheckbox:SetChecked(OneWoW.db.global.portalHub.randomHearthstone)
	randomHearthCheckbox:SetScript("OnClick", function(self)
		OneWoW.db.global.portalHub.randomHearthstone = self:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local randomHearthLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	randomHearthLabel:SetPoint("LEFT", randomHearthCheckbox, "RIGHT", 5, 0)
	randomHearthLabel:SetText(L["PORTAL_RANDOM_HEARTHSTONE"])
	randomHearthLabel:SetTextColor(T("TEXT_PRIMARY"))

	local showAllCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
	showAllCheckbox:SetPoint("LEFT", randomHearthLabel, "RIGHT", 20, 0)
	showAllCheckbox:SetSize(24, 24)
	showAllCheckbox:SetChecked(OneWoW.db.global.portalHub.showAll)

	local showAllLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	showAllLabel:SetPoint("LEFT", showAllCheckbox, "RIGHT", 5, 0)
	showAllLabel:SetText(L["Show Unavailable"])
	showAllLabel:SetTextColor(T("TEXT_PRIMARY"))

	local showAllEscCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
	showAllEscCheckbox:SetPoint("LEFT", showAllLabel, "RIGHT", 20, 0)
	showAllEscCheckbox:SetSize(24, 24)
	showAllEscCheckbox:SetChecked(OneWoW.db.global.portalHub.showAllOnEsc or false)
	showAllEscCheckbox:SetScript("OnClick", function(self)
		OneWoW.db.global.portalHub.showAllOnEsc = self:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showAllEscLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	showAllEscLabel:SetPoint("LEFT", showAllEscCheckbox, "RIGHT", 5, 0)
	showAllEscLabel:SetText(L["PORTAL_SHOW_ALL_ESC"])
	showAllEscLabel:SetTextColor(T("TEXT_PRIMARY"))

	local showSeasonalCheckbox = CreateFrame("CheckButton", nil, controlPanel, "UICheckButtonTemplate")
	showSeasonalCheckbox:SetPoint("LEFT", showAllEscLabel, "RIGHT", 20, 0)
	showSeasonalCheckbox:SetSize(24, 24)
	showSeasonalCheckbox:SetChecked(OneWoW.db.global.portalHub.showSeasonal)
	showSeasonalCheckbox:SetScript("OnClick", function(self)
		OneWoW.db.global.portalHub.showSeasonal = self:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showSeasonalLabel = controlPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	showSeasonalLabel:SetPoint("LEFT", showSeasonalCheckbox, "RIGHT", 5, 0)
	showSeasonalLabel:SetText(L["PORTAL_SHOW_SEASONAL"])
	showSeasonalLabel:SetTextColor(T("TEXT_PRIMARY"))

	local categoryPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	categoryPanel:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -10)
	categoryPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 35)
	categoryPanel:SetWidth(233)
	categoryPanel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	categoryPanel:SetBackdropColor(T("BG_PRIMARY"))
	categoryPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

	local categoryTitle = categoryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	categoryTitle:SetPoint("TOP", categoryPanel, "TOP", 0, -10)
	categoryTitle:SetText(L["Categories"])
	categoryTitle:SetTextColor(T("ACCENT_PRIMARY"))

	local categoryScrollFrame = CreateFrame("ScrollFrame", nil, categoryPanel, "UIPanelScrollFrameTemplate")
	categoryScrollFrame:SetPoint("TOPLEFT", categoryPanel, "TOPLEFT", 10, -40)
	categoryScrollFrame:SetPoint("BOTTOMRIGHT", categoryPanel, "BOTTOMRIGHT", -30, 10)

	local categoryScrollChild = CreateFrame("Frame", nil, categoryScrollFrame)
	categoryScrollChild:SetSize(categoryScrollFrame:GetWidth(), 1)
	categoryScrollFrame:SetScrollChild(categoryScrollChild)

	local portalPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	portalPanel:SetPoint("TOPLEFT", categoryPanel, "TOPRIGHT", 10, 0)
	portalPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 35)
	portalPanel:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	portalPanel:SetBackdropColor(T("BG_PRIMARY"))
	portalPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

	local portalTitle = portalPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	portalTitle:SetPoint("TOP", portalPanel, "TOP", 0, -10)
	portalTitle:SetText(L["Select a Category"])
	portalTitle:SetTextColor(T("ACCENT_PRIMARY"))
	portalPanel.title = portalTitle

	local portalScrollFrame = CreateFrame("ScrollFrame", nil, portalPanel, "UIPanelScrollFrameTemplate")
	portalScrollFrame:SetPoint("TOPLEFT", portalPanel, "TOPLEFT", 10, -40)
	portalScrollFrame:SetPoint("BOTTOMRIGHT", portalPanel, "BOTTOMRIGHT", -30, 10)

	local portalScrollChild = CreateFrame("Frame", nil, portalScrollFrame)
	portalScrollChild:SetSize(portalScrollFrame:GetWidth(), 1)
	portalScrollFrame:SetScrollChild(portalScrollChild)
	portalPanel.scrollChild = portalScrollChild

	local leftStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	leftStatusBar:SetPoint("TOPLEFT", categoryPanel, "BOTTOMLEFT", 0, -5)
	leftStatusBar:SetPoint("TOPRIGHT", categoryPanel, "BOTTOMRIGHT", 0, -5)
	leftStatusBar:SetHeight(25)
	leftStatusBar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	leftStatusBar:SetBackdropColor(T("BG_SECONDARY"))
	leftStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

	local leftStatusText = leftStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
	leftStatusText:SetTextColor(T("TEXT_SECONDARY"))
	leftStatusText:SetText("")

	local rightStatusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	rightStatusBar:SetPoint("TOPLEFT", portalPanel, "BOTTOMLEFT", 0, -5)
	rightStatusBar:SetPoint("TOPRIGHT", portalPanel, "BOTTOMRIGHT", 0, -5)
	rightStatusBar:SetHeight(25)
	rightStatusBar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	rightStatusBar:SetBackdropColor(T("BG_SECONDARY"))
	rightStatusBar:SetBackdropBorderColor(T("BORDER_SUBTLE"))

	local rightStatusText = rightStatusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
	rightStatusText:SetTextColor(T("TEXT_SECONDARY"))
	rightStatusText:SetText("")
	portalPanel.statusText = rightStatusText

	local function UpdateCooldown(button, portal)
		if not button.cooldownFrame then
			return
		end

		local start, duration, enabled

		if portal.type == "toy" or portal.type == "item" then
			start, duration, enabled = C_Item.GetItemCooldown(portal.id)
		elseif portal.type == "spell" then
			local cooldown = C_Spell.GetSpellCooldown(portal.id)
			if cooldown then
				start = cooldown.startTime
				duration = cooldown.duration
				enabled = true
			end
		elseif portal.type == "housing" then
			if C_Housing and C_Housing.GetVisitCooldownInfo then
				local cdInfo = C_Housing.GetVisitCooldownInfo()
				start = cdInfo.startTime
				duration = cdInfo.duration
				enabled = cdInfo.isEnabled
			end
		end

		if enabled and duration and duration > 0 then
			button.cooldownFrame:SetCooldown(start, duration)
		else
			button.cooldownFrame:Clear()
		end
	end

	local function CreatePortalButton(parentFrame, portal, size)
		local button
		if #portalButtonPool > 0 then
			button = table.remove(portalButtonPool)
		else
			button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
			button.cooldownFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
			button.cooldownFrame:SetAllPoints()

			button.favoriteIcon = button:CreateTexture(nil, "OVERLAY")
			button.favoriteIcon:SetSize(16, 16)
			button.favoriteIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
			button.favoriteIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
			button.favoriteIcon:Hide()

			button.dimOverlay = button:CreateTexture(nil, "ARTWORK")
			button.dimOverlay:SetAllPoints()
			button.dimOverlay:SetColorTexture(0, 0, 0, 0.7)
			button.dimOverlay:Hide()
		end

		button:SetParent(parentFrame)
		button:SetSize(size, size)
		button:Show()

		if not button.dimOverlay then
			button.dimOverlay = button:CreateTexture(nil, "ARTWORK")
			button.dimOverlay:SetAllPoints()
			button.dimOverlay:SetColorTexture(0, 0, 0, 0.7)
		end
		button.dimOverlay:Hide()

		local isAvailable = portal.available ~= false

		if portal.type == "toy" then
			if isAvailable then
				button:SetAttribute("type", "toy")
				button:SetAttribute("toy", portal.id)
			end
			local _, name, icon = C_ToyBox.GetToyInfo(portal.id)
			if icon then
				button:SetNormalTexture(icon)
			else
				local item = Item:CreateFromItemID(portal.id)
				item:ContinueOnItemLoad(function()
					local loadedIcon = item:GetItemIcon()
					if loadedIcon then
						button:SetNormalTexture(loadedIcon)
					end
				end)
			end
		elseif portal.type == "item" then
			if isAvailable then
				button:SetAttribute("type", "item")
				button:SetAttribute("item", "item:" .. portal.id)
			end
			local item = Item:CreateFromItemID(portal.id)
			item:ContinueOnItemLoad(function()
				local icon = item:GetItemIcon()
				if icon then
					button:SetNormalTexture(icon)
				end
			end)
		elseif portal.type == "spell" then
			if isAvailable then
				button:SetAttribute("type", "spell")
				button:SetAttribute("spell", portal.id)
			end
			local icon = C_Spell.GetSpellTexture(portal.id)
			if icon then
				button:SetNormalTexture(icon)
			end
		elseif portal.type == "housing" then
			if isAvailable then
				button:SetAttribute("type", "macro")
				button:SetAttribute("macrotext", "/run local h=C_Housing.GetCurrentHouseInfo();if h and h.houseGUID then C_Housing.TeleportHome(h.neighborhoodGUID,h.houseGUID,h.plotID)else print('No house')end")
			end
			local icon = C_Spell.GetSpellTexture(1263273)
			if icon then
				button:SetNormalTexture(icon)
			end
		end

		if not isAvailable then
			button.dimOverlay:Show()
			button:SetAlpha(0.5)
		else
			button:SetAlpha(1.0)
		end

		local isFavorite = OneWoW.PortalHubModule:IsFavorite(portal.type, portal.id)
		if isFavorite then
			button.favoriteIcon:Show()
		else
			button.favoriteIcon:Hide()
		end

		button:RegisterForClicks("AnyDown", "AnyUp")

		button:SetScript("OnMouseUp", function(self, mouseButton)
			if mouseButton == "RightButton" then
				if not isAvailable then
					return
				end

				local spellName
				if portal.type == "toy" then
					local toyInfo = C_ToyBox.GetToyInfo(portal.id)
					spellName = toyInfo
				elseif portal.type == "item" then
					spellName = C_Item.GetItemNameByID(portal.id)
				elseif portal.type == "spell" then
					spellName = C_Spell.GetSpellName(portal.id)
				end

				local added = OneWoW.PortalHubModule:ToggleFavorite(portal.type, portal.id, spellName or "Unknown")
				if added then
					self.favoriteIcon:Show()
				else
					self.favoriteIcon:Hide()
				end

				local favCount = #OneWoW.db.global.portalHub.escFavorites or 0
				leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))

				if OneWoW.PortalHubEsc then
					OneWoW.PortalHubEsc:Reload()
				end
			end
		end)

		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if portal.type == "toy" then
				GameTooltip:SetToyByItemID(portal.id)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format(L["UI_PORTAL_ITEM_ID"], portal.id), 0.5, 0.5, 0.5)
			elseif portal.type == "item" then
				GameTooltip:SetItemByID(portal.id)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format(L["UI_PORTAL_ITEM_ID"], portal.id), 0.5, 0.5, 0.5)
			elseif portal.type == "spell" then
				GameTooltip:SetSpellByID(portal.id)
			elseif portal.type == "housing" then
				GameTooltip:SetText(L["UI_PORTAL_TITLE_TELEPORT"], 1, 1, 1)
				GameTooltip:AddLine(L["UI_PORTAL_TELEPORT_HOME"], 0.7, 0.7, 0.7, true)
				if C_Housing then
					local info = C_Housing.GetCurrentHouseInfo()
					if info and info.houseGUID then
						GameTooltip:AddLine(" ")
						GameTooltip:AddLine(string.format(L["UI_PORTAL_HOUSE_ID"], info.houseGUID), 0.5, 0.5, 0.5)
					end
				end
			end
			if isAvailable then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(L["Right-click to favorite"], 0.5, 0.8, 0.5)
			end
			GameTooltip:Show()
		end)

		button:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)

		if isAvailable then
			UpdateCooldown(button, portal)
		end

		return button
	end

	local function ShowCategory(categoryID, categoryName)
		selectedCategory = categoryID
		portalPanel.title:SetText(categoryName)

		for _, button in ipairs(portalButtons) do
			button:Hide()
			button:SetParent(nil)
			button:ClearAllPoints()
			table.insert(portalButtonPool, button)
		end
		portalButtons = {}

		for _, header in ipairs(headerFrames) do
			header:Hide()
			header:SetParent(nil)
		end
		headerFrames = {}

		local showAll = OneWoW.db.global.portalHub.showAll
		local allPortals = OneWoW.PortalHubModule:GetPortalsForCategory(categoryID, showAll)
		currentPortals = allPortals

		local available = {}
		local unavailable = {}

		for _, portal in ipairs(allPortals) do
			if portal.type == "header" then
				table.insert(available, portal)
			else
				local isAvailable = OneWoW.PortalHubDetection:IsAvailable(portal.type, portal.id)
				portal.available = isAvailable

				if isAvailable then
					table.insert(available, portal)
				else
					table.insert(unavailable, portal)
				end
			end
		end

		local displayPortals = {}
		for _, p in ipairs(available) do
			table.insert(displayPortals, p)
		end
		if showAll then
			for _, p in ipairs(unavailable) do
				table.insert(displayPortals, p)
			end
		end

		local iconSize = OneWoW.db.global.portalHub.iconSize or 40
		local columns = OneWoW.db.global.portalHub.gridColumns or 12
		local xOffset = 0
		local yOffset = 0
		local row = 0
		local col = 0

		for _, portal in ipairs(displayPortals) do
			if portal.type == "header" then
				if col > 0 then
					row = row + 1
					col = 0
					xOffset = 0
					yOffset = -row * (iconSize + 5)
				end

				local header = CreateFrame("Frame", nil, portalScrollChild)
				header:SetPoint("TOPLEFT", portalScrollChild, "TOPLEFT", 0, yOffset - 10)
				header:SetSize(portalScrollChild:GetWidth(), 30)

				local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
				headerText:SetPoint("LEFT", header, "LEFT", 5, 0)
				headerText:SetText(portal.name)
				headerText:SetTextColor(T("ACCENT_PRIMARY"))

				local headerLine = header:CreateTexture(nil, "ARTWORK")
				headerLine:SetPoint("LEFT", headerText, "RIGHT", 10, 0)
				headerLine:SetPoint("RIGHT", header, "RIGHT", -5, 0)
				headerLine:SetHeight(1)
				headerLine:SetColorTexture(T("ACCENT_PRIMARY"))

				table.insert(headerFrames, header)

				row = row + 1
				xOffset = 0
				yOffset = -row * (iconSize + 5) - 5
				col = 0
			else
				local button = CreatePortalButton(portalScrollChild, portal, iconSize)
				button:SetPoint("TOPLEFT", portalScrollChild, "TOPLEFT", xOffset, yOffset)
				table.insert(portalButtons, button)

				col = col + 1
				if col >= columns then
					col = 0
					row = row + 1
					xOffset = 0
					yOffset = -row * (iconSize + 5)
				else
					xOffset = col * (iconSize + 5)
				end
			end
		end

		local totalRows = math.ceil(#displayPortals / columns)
		portalScrollChild:SetHeight(math.max(totalRows * (iconSize + 5), portalScrollFrame:GetHeight()))

		local availableCount = 0
		local unavailableCount = 0
		for _, p in ipairs(available) do
			if p.type ~= "header" then
				availableCount = availableCount + 1
			end
		end
		for _, p in ipairs(unavailable) do
			if p.type ~= "header" then
				unavailableCount = unavailableCount + 1
			end
		end

		local favCount = #OneWoW.db.global.portalHub.escFavorites or 0
		local statusMsg = string.format("%s (%d available", categoryName, availableCount)
		if showAll then
			statusMsg = statusMsg .. string.format(", %d unavailable)", unavailableCount)
		else
			statusMsg = statusMsg .. ")"
		end
		portalPanel.statusText:SetText(statusMsg)
		leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))
	end

	local categoryItems = {}

	local function RefreshCategories()
		for _, item in ipairs(categoryItems) do
			item:Hide()
			item:SetParent(nil)
		end
		categoryItems = {}

		local categories = OneWoW.PortalHubModule:GetCategories()
		local showAll = OneWoW.db.global.portalHub.showAll

		local yOffset = 0
		for _, category in ipairs(categories) do
			local hasPortals = false
			if not showAll then
				if category.id == "professions" then
					local wormholes = OneWoW.PortalHubDetection:GetWormholes(true)
					local rippers = OneWoW.PortalHubDetection:GetDimensionalRippers(true)
					local transporters = OneWoW.PortalHubDetection:GetUltrasafeTransporters(true)
					for _, w in ipairs(wormholes) do
						if PlayerHasToy(w.id) then
							hasPortals = true
							break
						end
					end
					if not hasPortals then
						for _, r in ipairs(rippers) do
							if PlayerHasToy(r.id) then
								hasPortals = true
								break
							end
						end
					end
					if not hasPortals then
						for _, t in ipairs(transporters) do
							if PlayerHasToy(t.id) then
								hasPortals = true
								break
							end
						end
					end
				else
					local portals = OneWoW.PortalHubModule:GetPortalsForCategory(category.id, false)
					for _, portal in ipairs(portals) do
						if portal.type ~= "header" and OneWoW.PortalHubDetection:IsAvailable(portal.type, portal.id) then
							hasPortals = true
							break
						end
					end
				end
			else
				hasPortals = true
			end

			if hasPortals or category.id == "favorites" then
				local categoryFrame = CreateFrame("Frame", nil, categoryScrollChild, "BackdropTemplate")
				categoryFrame:SetSize(categoryScrollChild:GetWidth(), 40)
				categoryFrame:SetPoint("TOPLEFT", categoryScrollChild, "TOPLEFT", 0, yOffset)
				categoryFrame:SetBackdrop({
					bgFile = "Interface\\Buttons\\WHITE8x8",
					edgeFile = "Interface\\Buttons\\WHITE8x8",
					edgeSize = 1,
				})
				categoryFrame:SetBackdropColor(T("BG_SECONDARY"))
				categoryFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

				local icon = categoryFrame:CreateTexture(nil, "ARTWORK")
				icon:SetSize(24, 24)
				icon:SetPoint("LEFT", categoryFrame, "LEFT", 8, 0)
				icon:SetTexture(category.icon)

				local nameText = categoryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
				nameText:SetText(category.name)
				nameText:SetTextColor(T("TEXT_PRIMARY"))

				categoryFrame:EnableMouse(true)
				categoryFrame:SetScript("OnEnter", function(self)
					if selectedCategory ~= category.id then
						self:SetBackdropColor(T("BG_HOVER"))
					end
				end)
				categoryFrame:SetScript("OnLeave", function(self)
					if selectedCategory ~= category.id then
						self:SetBackdropColor(T("BG_SECONDARY"))
					end
				end)
				categoryFrame:SetScript("OnMouseDown", function(self)
					selectedCategory = category.id
					ShowCategory(category.id, category.name)
					for _, item in ipairs(categoryItems) do
						if item.categoryID == category.id then
							item:SetBackdropColor(T("BG_HOVER"))
							item:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
						else
							if item.isSubcat then
								item:SetBackdropColor(T("BG_PRIMARY"))
								item:SetBackdropBorderColor(T("BORDER_SUBTLE"))
							else
								item:SetBackdropColor(T("BG_SECONDARY"))
								item:SetBackdropBorderColor(T("BORDER_SUBTLE"))
							end
						end
					end
				end)

				categoryFrame.categoryID = category.id
				categoryFrame.isParent = category.subcategories ~= nil
				table.insert(categoryItems, categoryFrame)
				yOffset = yOffset - 45

				if category.subcategories then
					for _, subcat in ipairs(category.subcategories) do
						local hasSubPortals = false
						if not showAll then
							local subPortals = OneWoW.PortalHubModule:GetPortalsForCategory(subcat.id, false)
							for _, portal in ipairs(subPortals) do
								if portal.type ~= "header" and OneWoW.PortalHubDetection:IsAvailable(portal.type, portal.id) then
									hasSubPortals = true
									break
								end
							end
						else
							hasSubPortals = true
						end

						if hasSubPortals then
							local subcatFrame = CreateFrame("Frame", nil, categoryScrollChild, "BackdropTemplate")
							subcatFrame:SetSize(categoryScrollChild:GetWidth() - 20, 35)
							subcatFrame:SetPoint("TOPLEFT", categoryScrollChild, "TOPLEFT", 20, yOffset)
							subcatFrame:SetBackdrop({
								bgFile = "Interface\\Buttons\\WHITE8x8",
								edgeFile = "Interface\\Buttons\\WHITE8x8",
								edgeSize = 1,
							})
							subcatFrame:SetBackdropColor(T("BG_PRIMARY"))
							subcatFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

							local subcatText = subcatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
							subcatText:SetPoint("LEFT", subcatFrame, "LEFT", 10, 0)
							subcatText:SetText(subcat.name)
							subcatText:SetTextColor(T("TEXT_SECONDARY"))

							subcatFrame:EnableMouse(true)
							subcatFrame:SetScript("OnEnter", function(self)
								if selectedCategory ~= subcat.id then
									self:SetBackdropColor(T("BG_HOVER"))
								end
							end)
							subcatFrame:SetScript("OnLeave", function(self)
								if selectedCategory ~= subcat.id then
									self:SetBackdropColor(T("BG_PRIMARY"))
								end
							end)
							subcatFrame:SetScript("OnMouseDown", function(self)
								selectedCategory = subcat.id
								ShowCategory(subcat.id, subcat.name)
								for _, item in ipairs(categoryItems) do
									if item.categoryID == subcat.id then
										item:SetBackdropColor(T("BG_HOVER"))
										item:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
									else
										if item.isSubcat then
											item:SetBackdropColor(T("BG_PRIMARY"))
											item:SetBackdropBorderColor(T("BORDER_SUBTLE"))
										else
											item:SetBackdropColor(T("BG_SECONDARY"))
											item:SetBackdropBorderColor(T("BORDER_SUBTLE"))
										end
									end
								end
							end)

							subcatFrame.categoryID = subcat.id
							subcatFrame.isSubcat = true
							table.insert(categoryItems, subcatFrame)
							yOffset = yOffset - 40
						end
					end
				end
			end
		end

		categoryScrollChild:SetHeight(math.abs(yOffset) + 50)
	end

	showAllCheckbox:SetScript("OnClick", function(self)
		OneWoW.db.global.portalHub.showAll = self:GetChecked()
		if selectedCategory then
			local categories = OneWoW.PortalHubModule:GetCategories()
			for _, cat in ipairs(categories) do
				if cat.id == selectedCategory then
					ShowCategory(selectedCategory, cat.name)
					break
				end
				if cat.subcategories then
					for _, subcat in ipairs(cat.subcategories) do
						if subcat.id == selectedCategory then
							ShowCategory(selectedCategory, subcat.name)
							break
						end
					end
				end
			end
		end
		RefreshCategories()
	end)

	RefreshCategories()
	ShowCategory("favorites", L["Favorites"])

	parent.Cleanup = function()
	end

	parent.Activate = function()
	end

	parent.Deactivate = function()
	end
end
