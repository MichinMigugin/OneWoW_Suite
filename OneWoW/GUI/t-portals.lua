local _, OneWoW = ...

local GUI = OneWoW.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local selectedCategory = nil
local portalButtons = {}
local headerFrames = {}
local portalButtonPool = {}

function GUI:CreatePortalsTab(parent)
	local L = OneWoW.L or {}

	local split = OneWoW_GUI:CreateSplitPanel(parent, {
		showSearch = true,
		searchPlaceholder = L["SEARCH_PLACEHOLDER"] or "Search...",
	})
	split.listTitle:SetText(L["PORTALS_LIST_TITLE"] or L["Categories"])
	split.detailTitle:SetText(L["PORTALS_DETAIL_TITLE"] or L["PORTALS_SUBTAB"] or "Portals")

	local categoryScrollChild = split.listScrollChild
	local portalPanel = split.detailPanel
	local portalScrollFrame = split.detailScrollFrame
	local portalScrollChild = split.detailScrollChild
	local leftStatusText = split.leftStatusText
	local rightStatusText = split.rightStatusText
	local selectedCategoryRow = nil

	local controlPanel = OneWoW_GUI:CreateFrame(portalPanel, {
		height = 118,
		backdrop = BACKDROP_INNER_NO_INSETS,
		bgColor = "BG_SECONDARY",
		borderColor = "BORDER_SUBTLE",
	})
	controlPanel:SetPoint("TOPLEFT", portalPanel, "TOPLEFT", 8, -32)
	controlPanel:SetPoint("TOPRIGHT", portalPanel, "TOPRIGHT", -22, -32)

	portalScrollFrame:ClearAllPoints()
	portalScrollFrame:SetPoint("TOPLEFT", portalPanel, "TOPLEFT", 8, -158)
	portalScrollFrame:SetPoint("BOTTOMRIGHT", portalPanel, "BOTTOMRIGHT", -22, 8)

	local ph = OneWoW.db.global.portalHub

	local optionsTitle = OneWoW_GUI:CreateFS(controlPanel, 12)
	optionsTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -10)
	optionsTitle:SetText(L["PORTAL_DISPLAY_OPTIONS"] or L["Show Unavailable"])
	optionsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

	local escCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["Show Portals on ESC"] })
	escCheckbox:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -34)
	escCheckbox:SetChecked(OneWoW.db.global.portalHub.escPortalsEnabled)
	escCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.escPortalsEnabled = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and GameMenuFrame and GameMenuFrame:IsShown() then
			OneWoW.PortalHubEsc:ShowPortalFrames()
		end
	end)

	local escLabel = escCheckbox.label

	local randomHearthCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_RANDOM_HEARTHSTONE"] })
	randomHearthCheckbox:SetPoint("LEFT", escLabel, "RIGHT", 20, 0)
	randomHearthCheckbox:SetChecked(OneWoW.db.global.portalHub.randomHearthstone)
	randomHearthCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.randomHearthstone = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local randomHearthLabel = randomHearthCheckbox.label

	local showAllCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["Show Unavailable"] })
	showAllCheckbox:SetPoint("LEFT", randomHearthLabel, "RIGHT", 20, 0)
	showAllCheckbox:SetChecked(OneWoW.db.global.portalHub.showAll)

	local showAllEscCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_SHOW_ALL_ESC"] })
	showAllEscCheckbox:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -62)
	showAllEscCheckbox:SetChecked(OneWoW.db.global.portalHub.showAllOnEsc or false)
	showAllEscCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showAllOnEsc = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showAllEscLabel = showAllEscCheckbox.label

	local showSeasonalCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_SHOW_SEASONAL"] })
	showSeasonalCheckbox:SetPoint("LEFT", showAllEscLabel, "RIGHT", 20, 0)
	showSeasonalCheckbox:SetChecked(OneWoW.db.global.portalHub.showSeasonal)
	showSeasonalCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showSeasonal = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local topRowLabel = OneWoW_GUI:CreateFS(controlPanel, 10)
	topRowLabel:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -91)
	topRowLabel:SetText(L["PORTAL_ESC_TOP_ROW"])
	topRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

	local showDalaranCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_DALARAN_HEARTH"] })
	showDalaranCheckbox:SetPoint("LEFT", topRowLabel, "RIGHT", 10, 0)
	showDalaranCheckbox:SetChecked(ph.showDalaranHearth ~= false)
	showDalaranCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showDalaranHearth = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showDalaranLabel = showDalaranCheckbox.label

	local showGarrisonCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_GARRISON_HEARTH"] })
	showGarrisonCheckbox:SetPoint("LEFT", showDalaranLabel, "RIGHT", 15, 0)
	showGarrisonCheckbox:SetChecked(ph.showGarrisonHearth ~= false)
	showGarrisonCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showGarrisonHearth = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showGarrisonLabel = showGarrisonCheckbox.label

	local showWhistleCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_FLIGHT_WHISTLE"] })
	showWhistleCheckbox:SetPoint("LEFT", showGarrisonLabel, "RIGHT", 15, 0)
	showWhistleCheckbox:SetChecked(ph.showFlightWhistle ~= false)
	showWhistleCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showFlightWhistle = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local showWhistleLabel = showWhistleCheckbox.label

	local showHousingCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_HOUSING_PORTAL"] })
	showHousingCheckbox:SetPoint("LEFT", showWhistleLabel, "RIGHT", 15, 0)
	showHousingCheckbox:SetChecked(ph.showHousingPortal ~= false)
	showHousingCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showHousingPortal = checkbox:GetChecked()
		if OneWoW.PortalHubEsc and OneWoW.PortalHubEsc.Reload then
			OneWoW.PortalHubEsc:Reload()
		end
	end)

	local secureOverlay = CreateFrame("ScrollFrame", nil, UIParent)
	secureOverlay:SetPoint("TOPLEFT", portalScrollFrame, "TOPLEFT")
	secureOverlay:SetPoint("BOTTOMRIGHT", portalScrollFrame, "BOTTOMRIGHT")
	secureOverlay:SetFrameStrata("HIGH")
	secureOverlay:EnableMouseWheel(true)

	local secureScrollChild = CreateFrame("Frame", nil, secureOverlay)
	secureScrollChild:SetSize(portalScrollFrame:GetWidth(), 1)
	secureOverlay:SetScrollChild(secureScrollChild)
	portalScrollFrame:HookScript("OnSizeChanged", function(_, width)
		secureScrollChild:SetWidth(width)
	end)

	secureOverlay:SetScript("OnMouseWheel", function(_, delta)
		local scrollBar = portalScrollFrame.ScrollBar
		if scrollBar then
			local current = scrollBar:GetValue()
			local minVal, maxVal = scrollBar:GetMinMaxValues()
			local step = scrollBar:GetValueStep() or 20
			local newVal = math.max(minVal, math.min(maxVal, current - (delta * step * 3)))
			scrollBar:SetValue(newVal)
		end
	end)

	portalScrollFrame:HookScript("OnVerticalScroll", function(_, offset)
		secureOverlay:SetVerticalScroll(offset)
	end)

	local function ShowSecureOverlay()
		secureOverlay:SetAlpha(1)
		secureOverlay:ClearAllPoints()
		secureOverlay:SetPoint("TOPLEFT", portalScrollFrame, "TOPLEFT")
		secureOverlay:SetPoint("BOTTOMRIGHT", portalScrollFrame, "BOTTOMRIGHT")
		local w = portalScrollChild:GetWidth()
		if w and w > 0 then
			secureScrollChild:SetWidth(w)
		end
	end

	local function HideSecureOverlay()
		secureOverlay:SetAlpha(0)
		secureOverlay:ClearAllPoints()
		secureOverlay:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 0)
		secureOverlay:SetSize(1, 1)
	end

	HideSecureOverlay()

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

	local function CreatePortalButton(portal, size)
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
			OneWoW_GUI:SetFavoriteAtlasTexture(button.favoriteIcon)
			button.favoriteIcon:Hide()

			button.dimOverlay = button:CreateTexture(nil, "ARTWORK")
			button.dimOverlay:SetAllPoints()
			button.dimOverlay:SetColorTexture(0, 0, 0, 0.7)
			button.dimOverlay:Hide()
		end

		button:SetParent(secureScrollChild)
		button:SetSize(size, size)
		button:Show()
		button._onewowHousingRequestToken = (button._onewowHousingRequestToken or 0) + 1

		if not button.dimOverlay then
			button.dimOverlay = button:CreateTexture(nil, "ARTWORK")
			button.dimOverlay:SetAllPoints()
			button.dimOverlay:SetColorTexture(0, 0, 0, 0.7)
		end
		button.dimOverlay:Hide()

		local isAvailable = portal.available ~= false

		if portal.type == "toy" then
			if isAvailable then
				button:SetAttribute("type1", "toy")
				button:SetAttribute("toy1", portal.id)
			end
			local _, _, icon = C_ToyBox.GetToyInfo(portal.id)
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
				button:SetAttribute("type1", "item")
				button:SetAttribute("item1", "item:" .. portal.id)
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
				button:SetAttribute("type1", "spell")
				button:SetAttribute("spell1", portal.id)
			end
			local icon = C_Spell.GetSpellTexture(portal.id)
			if icon then
				button:SetNormalTexture(icon)
			end
		elseif portal.type == "housing" then
			if isAvailable then
				OneWoW.PortalHubDetection:ApplyHousingTeleportAttributes(button, "1")
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

		button:SetScript("OnMouseUp", function(portalButton, mouseButton)
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
					portalButton.favoriteIcon:Show()
				else
					portalButton.favoriteIcon:Hide()
				end

				local favCount = #OneWoW.db.global.portalHub.escFavorites or 0
				leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))

				if OneWoW.PortalHubEsc then
					OneWoW.PortalHubEsc:Reload()
				end
			end
		end)

		button:SetScript("OnEnter", function(portalButton)
			GameTooltip:SetOwner(portalButton, "ANCHOR_RIGHT")
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

		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		if isAvailable then
			UpdateCooldown(button, portal)
		end

		return button
	end

	local function ShowCategory(categoryID, categoryName)
		if InCombatLockdown() then return end
		selectedCategory = categoryID
		split.detailTitle:SetText(categoryName)

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

		local available = {}
		local unavailable = {}

		for _, portal in ipairs(allPortals) do
			if portal.type == "header" then
				table.insert(available, portal)
			else
				local isAvailable = OneWoW.PortalHubDetection:IsPortalUsable(portal.type, portal.id)
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

				local headerText = OneWoW_GUI:CreateFS(header, 16)
				headerText:SetPoint("LEFT", header, "LEFT", 5, 0)
				headerText:SetText(portal.name)
				headerText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

				local headerLine = header:CreateTexture(nil, "ARTWORK")
				headerLine:SetPoint("LEFT", headerText, "RIGHT", 10, 0)
				headerLine:SetPoint("RIGHT", header, "RIGHT", -5, 0)
				headerLine:SetHeight(1)
				headerLine:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

				table.insert(headerFrames, header)

				row = row + 1
				xOffset = 0
				yOffset = -row * (iconSize + 5) - 5
				col = 0
			else
				local button = CreatePortalButton(portal, iconSize)
				button:SetPoint("TOPLEFT", secureScrollChild, "TOPLEFT", xOffset, yOffset)
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

		local contentHeight = math.max(math.abs(yOffset) + iconSize + 10, portalScrollFrame:GetHeight())
		portalScrollChild:SetHeight(contentHeight)
		secureScrollChild:SetHeight(contentHeight)

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
		local statusMsg = string.format(L["PORTAL_STATUS_AVAILABLE"] or "%s (%d available)", categoryName, availableCount)
		if showAll then
			statusMsg = string.format(L["PORTAL_STATUS_AVAILABLE_UNAVAILABLE"] or "%s (%d available, %d unavailable)", categoryName, availableCount, unavailableCount)
		end
		rightStatusText:SetText(statusMsg)
		leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))
	end

	local categoryItems = {}
	local firstCategoryRow = nil
	local favoritesRow = nil

	local function CategoryHasPortals(category, showAll)
		if showAll then
			return true
		end

		if category.id == "professions" then
			local wormholes = OneWoW.PortalHubDetection:GetWormholes(true)
			local rippers = OneWoW.PortalHubDetection:GetDimensionalRippers(true)
			local transporters = OneWoW.PortalHubDetection:GetUltrasafeTransporters(true)
			for _, w in ipairs(wormholes) do
				if PlayerHasToy(w.id) then
					return true
				end
			end
			for _, r in ipairs(rippers) do
				if PlayerHasToy(r.id) then
					return true
				end
			end
			for _, t in ipairs(transporters) do
				if PlayerHasToy(t.id) then
					return true
				end
			end
			return false
		end

		local portals = OneWoW.PortalHubModule:GetPortalsForCategory(category.id, false)
		for _, portal in ipairs(portals) do
			if portal.type ~= "header" and OneWoW.PortalHubDetection:IsPortalUsable(portal.type, portal.id) then
				return true
			end
		end
		return false
	end

	local function SetSelectedCategoryRow(row)
		if selectedCategoryRow and selectedCategoryRow ~= row then
			selectedCategoryRow:SetActive(false)
		end
		selectedCategoryRow = row
		if row then
			row:SetActive(true)
		end
	end

	local function CreateCategoryRow(category, yOffset, isSubcat)
		local row = OneWoW_GUI:CreateListRowBasic(categoryScrollChild, {
			height = isSubcat and 28 or 30,
			label = category.name,
			onClick = function(row)
				SetSelectedCategoryRow(row)
				ShowCategory(category.id, category.name)
			end,
		})
		row:SetPoint("TOPLEFT", categoryScrollChild, "TOPLEFT", 4, yOffset)
		row:SetPoint("TOPRIGHT", categoryScrollChild, "TOPRIGHT", -4, yOffset)
		row.categoryID = category.id
		row.isSubcat = isSubcat
		if isSubcat and row.label then
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", 22, 0)
			row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		end
		table.insert(categoryItems, row)
		if not firstCategoryRow then
			firstCategoryRow = row
		end
		if category.id == "favorites" then
			favoritesRow = row
		end
		if selectedCategory == category.id then
			SetSelectedCategoryRow(row)
		end
		return yOffset - (isSubcat and 32 or 34)
	end

	local function RefreshCategories(filterText)
		for _, item in ipairs(categoryItems) do
			item:Hide()
			item:SetParent(nil)
		end
		categoryItems = {}
		firstCategoryRow = nil
		favoritesRow = nil
		selectedCategoryRow = nil

		local categories = OneWoW.PortalHubModule:GetCategories()
		local showAll = OneWoW.db.global.portalHub.showAll
		local filter = (filterText or ""):lower()

		local yOffset = -5
		for _, category in ipairs(categories) do
			local hasPortals = CategoryHasPortals(category, showAll)
			local categoryMatches = filter == "" or (category.name or ""):lower():find(filter, 1, true)
			local matchingSubcats = {}

			if category.subcategories then
				for _, subcat in ipairs(category.subcategories) do
					local hasSubPortals = CategoryHasPortals(subcat, showAll)
					local subcatMatches = filter == "" or (subcat.name or ""):lower():find(filter, 1, true)
					if hasSubPortals and subcatMatches then
						table.insert(matchingSubcats, subcat)
					end
				end
			end

			if ((hasPortals or category.id == "favorites") and categoryMatches) or #matchingSubcats > 0 then
				yOffset = CreateCategoryRow(category, yOffset, false)
				for _, subcat in ipairs(matchingSubcats) do
					yOffset = CreateCategoryRow(subcat, yOffset, true)
				end
			end
		end

		categoryScrollChild:SetHeight(math.abs(yOffset) + 50)
		if selectedCategoryRow then
			selectedCategoryRow:Click()
		elseif favoritesRow then
			favoritesRow:Click()
		elseif firstCategoryRow then
			firstCategoryRow:Click()
		else
			split.detailTitle:SetText(L["Select a Category"])
			rightStatusText:SetText("")
			leftStatusText:SetText("")
		end
	end

	showAllCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW.db.global.portalHub.showAll = checkbox:GetChecked()
		local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
		RefreshCategories(filterText)
	end)

	if split.searchBox then
		split.searchBox:SetScript("OnTextChanged", function(searchBox)
			RefreshCategories(searchBox:GetSearchText())
		end)
	end

	parent:HookScript("OnShow", function()
		ShowSecureOverlay()
	end)
	parent:HookScript("OnHide", function()
		HideSecureOverlay()
	end)

	C_Timer.After(0.1, function()
		RefreshCategories("")
		OneWoW_GUI:ApplyFontToFrame(parent)
	end)

	parent.Cleanup = function()
		HideSecureOverlay()
	end

	parent.Activate = function()
		ShowSecureOverlay()
	end

	parent.Deactivate = function()
		HideSecureOverlay()
	end
end
