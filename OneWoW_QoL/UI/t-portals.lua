local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local portalButtons = {}
local headerFrames = {}
local portalButtonPool = {}

function ns.UI.CreatePortalsTab(parent)
	local L = ns.L or {}

	local split = OneWoW_GUI:CreateSplitPanel(parent, {
		showSearch = true,
		searchPlaceholder = L["SEARCH_HINT"],
	})
	split.listTitle:SetText(L["PORTALS_LIST_TITLE"])
	split.detailTitle:SetText(L["PORTALS_DETAIL_TITLE"])

	local categoryScrollChild = split.listScrollChild
	local portalPanel = split.detailPanel
	local portalScrollFrame = split.detailScrollFrame
	local portalScrollChild = split.detailScrollChild
	local leftStatusText = split.leftStatusText
	local rightStatusText = split.rightStatusText
	local selectedCategoryRow = nil
	local selectedCategory = nil
	local selectedCategoryName = nil
	local layoutRefreshTimer = nil
	local ShowCategory
	local RefreshCategories

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

	local ph = OneWoW:GetPortalHub()

	local optionsTitle = OneWoW_GUI:CreateFS(controlPanel, 12)
	optionsTitle:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -10)
	optionsTitle:SetText(L["PORTAL_DISPLAY_OPTIONS"])
	optionsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

	local escCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["Show Portals on ESC"] })
	escCheckbox:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -34)
	escCheckbox:SetChecked(OneWoW:GetPortalHub().escPortalsEnabled)
	escCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().escPortalsEnabled = checkbox:GetChecked()
		if ns.PortalHubEsc and GameMenuFrame and GameMenuFrame:IsShown() then
			ns.PortalHubEsc:ShowPortalFrames()
		end
	end)

	local escLabel = escCheckbox.label

	local randomHearthCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_RANDOM_HEARTHSTONE"] })
	randomHearthCheckbox:SetPoint("LEFT", escLabel, "RIGHT", 20, 0)
	randomHearthCheckbox:SetChecked(OneWoW:GetPortalHub().randomHearthstone)
	randomHearthCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().randomHearthstone = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
		end
	end)

	local randomHearthLabel = randomHearthCheckbox.label

	local showAllCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["Show Unavailable"] })
	showAllCheckbox:SetPoint("LEFT", randomHearthLabel, "RIGHT", 20, 0)
	showAllCheckbox:SetChecked(OneWoW:GetPortalHub().showAll)

	local showAllEscCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_SHOW_ALL_ESC"] })
	showAllEscCheckbox:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 12, -62)
	showAllEscCheckbox:SetChecked(OneWoW:GetPortalHub().showAllOnEsc or false)
	showAllEscCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().showAllOnEsc = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
		end
	end)

	local showAllEscLabel = showAllEscCheckbox.label

	local showSeasonalCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_SHOW_SEASONAL"] })
	showSeasonalCheckbox:SetPoint("LEFT", showAllEscLabel, "RIGHT", 20, 0)
	showSeasonalCheckbox:SetChecked(OneWoW:GetPortalHub().showSeasonal)
	showSeasonalCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().showSeasonal = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
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
		OneWoW:GetPortalHub().showDalaranHearth = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
		end
	end)

	local showDalaranLabel = showDalaranCheckbox.label

	local showGarrisonCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_GARRISON_HEARTH"] })
	showGarrisonCheckbox:SetPoint("LEFT", showDalaranLabel, "RIGHT", 15, 0)
	showGarrisonCheckbox:SetChecked(ph.showGarrisonHearth ~= false)
	showGarrisonCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().showGarrisonHearth = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
		end
	end)

	local showGarrisonLabel = showGarrisonCheckbox.label

	local showWhistleCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_FLIGHT_WHISTLE"] })
	showWhistleCheckbox:SetPoint("LEFT", showGarrisonLabel, "RIGHT", 15, 0)
	showWhistleCheckbox:SetChecked(ph.showFlightWhistle ~= false)
	showWhistleCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().showFlightWhistle = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
		end
	end)

	local showWhistleLabel = showWhistleCheckbox.label

	local showHousingCheckbox = OneWoW_GUI:CreateCheckbox(controlPanel, { label = L["PORTAL_HOUSING_PORTAL"] })
	showHousingCheckbox:SetPoint("LEFT", showWhistleLabel, "RIGHT", 15, 0)
	showHousingCheckbox:SetChecked(ph.showHousingPortal ~= false)
	showHousingCheckbox:SetScript("OnClick", function(checkbox)
		OneWoW:GetPortalHub().showHousingPortal = checkbox:GetChecked()
		if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
			ns.PortalHubEsc:Reload()
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
	local function GetPortalScrollWidth()
		local w = portalScrollChild:GetWidth()
		if w and w > 0 then
			return w
		end
		w = portalScrollFrame:GetWidth()
		if w and w > 0 then
			return w
		end
		return 400
	end

	local function SchedulePortalLayoutRefresh()
		if layoutRefreshTimer then
			layoutRefreshTimer:Cancel()
		end
		layoutRefreshTimer = C_Timer.NewTimer(0, function()
			layoutRefreshTimer = nil
			if not parent:IsShown() then
				return
			end
			if selectedCategory and selectedCategoryName then
				ShowCategory(selectedCategory, selectedCategoryName)
			else
				local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
				RefreshCategories(filterText)
			end
		end)
	end

	portalScrollFrame:HookScript("OnSizeChanged", function(_, width)
		secureScrollChild:SetWidth(width)
		if width and width > 0 and selectedCategory then
			SchedulePortalLayoutRefresh()
		end
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
		secureScrollChild:SetWidth(GetPortalScrollWidth())
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
			local cdInfo = C_Housing.GetVisitCooldownInfo()
			start = cdInfo.startTime
			duration = cdInfo.duration
			enabled = cdInfo.isEnabled
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
			button.dimOverlay:SetColorTexture(unpack(OneWoW_GUI.Constants.OVERLAY_DIM))
			button.dimOverlay:Hide()
		end

		button:SetParent(secureScrollChild)
		button:SetSize(size, size)
		button:Show()
		button._onewowHousingRequestToken = (button._onewowHousingRequestToken or 0) + 1

		if not button.dimOverlay then
			button.dimOverlay = button:CreateTexture(nil, "ARTWORK")
			button.dimOverlay:SetAllPoints()
			button.dimOverlay:SetColorTexture(unpack(OneWoW_GUI.Constants.OVERLAY_DIM))
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
				ns.PortalHubDetection:ApplyHousingTeleportAttributes(button, "1")
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

		local isFavorite = ns.PortalHubModule:IsFavorite(portal.type, portal.id)
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

				local added = ns.PortalHubModule:ToggleFavorite(portal.type, portal.id, spellName or "Unknown")
				if added then
					portalButton.favoriteIcon:Show()
				else
					portalButton.favoriteIcon:Hide()
				end

				local favCount = #OneWoW:GetPortalHub().escFavorites or 0
				leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))

				if ns.PortalHubEsc then
					ns.PortalHubEsc:Reload()
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
				local info = C_Housing.GetCurrentHouseInfo()
				if info and info.houseGUID then
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine(string.format(L["UI_PORTAL_HOUSE_ID"], info.houseGUID), 0.5, 0.5, 0.5)
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

	ShowCategory = function(categoryID, categoryName)
		if OneWoW.Restriction.IsAddonRestricted() then return end
		selectedCategory = categoryID
		selectedCategoryName = categoryName
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

		local showAll = OneWoW:GetPortalHub().showAll
		local allPortals = ns.PortalHubModule:GetPortalsForCategory(categoryID, showAll)

		local available = {}
		local unavailable = {}

		for _, portal in ipairs(allPortals) do
			if portal.type == "header" then
				table.insert(available, portal)
			else
				local isAvailable = ns.PortalHubDetection:IsPortalUsable(portal.type, portal.id)
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

		local iconSize = OneWoW:GetPortalHub().iconSize or 40
		local columns = OneWoW:GetPortalHub().gridColumns or 12
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
				header:SetSize(GetPortalScrollWidth(), 30)

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

		local favCount = #OneWoW:GetPortalHub().escFavorites or 0
		local statusMsg = string.format(L["PORTAL_STATUS_AVAILABLE"], categoryName, availableCount)
		if showAll then
			statusMsg = string.format(L["PORTAL_STATUS_AVAILABLE_UNAVAILABLE"], categoryName, availableCount, unavailableCount)
		end
		rightStatusText:SetText(statusMsg)
		leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))
		ShowSecureOverlay()
	end

	local categoryItems = {}
	local firstCategoryRow = nil
	local favoritesRow = nil

	local function CategoryHasPortals(category, showAll)
		if showAll then
			return true
		end

		if category.id == "professions" then
			local wormholes = ns.PortalHubDetection:GetWormholes(true)
			local rippers = ns.PortalHubDetection:GetDimensionalRippers(true)
			local transporters = ns.PortalHubDetection:GetUltrasafeTransporters(true)
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

		local portals = ns.PortalHubModule:GetPortalsForCategory(category.id, false)
		for _, portal in ipairs(portals) do
			if portal.type ~= "header" and ns.PortalHubDetection:IsPortalUsable(portal.type, portal.id) then
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

	RefreshCategories = function(filterText)
		for _, item in ipairs(categoryItems) do
			item:Hide()
			item:SetParent(nil)
		end
		categoryItems = {}
		firstCategoryRow = nil
		favoritesRow = nil
		selectedCategoryRow = nil

		local categories = ns.PortalHubModule:GetCategories()
		local showAll = OneWoW:GetPortalHub().showAll
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
		OneWoW:GetPortalHub().showAll = checkbox:GetChecked()
		local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
		RefreshCategories(filterText)
	end)

	if split.searchBox then
		split.searchBox:SetScript("OnTextChanged", function(searchBox)
			RefreshCategories(searchBox:GetSearchText())
		end)
	end

	-- ---- Custom (user-added) items: Add/Manage dialog ----
	local customDialog
	local customRows = {}
	local previewIcon, previewName, previewType, idBox, listEmptyFS, listContent

	local function RefreshAfterCustomChange()
		local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
		RefreshCategories(filterText)
	end

	local function ResolvePreview(text)
		local id = tonumber(text)
		if not id or id <= 0 then
			previewIcon:SetTexture(nil)
			previewName:SetText("")
			previewType:SetText("")
			return
		end

		local itemType = ns.PortalHubModule:DetectItemType(id)
		if not itemType then
			previewIcon:SetTexture(nil)
			previewName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			previewName:SetText(L["PORTAL_CUSTOM_NOT_FOUND_PREVIEW"])
			previewType:SetText("")
			return
		end

		previewName:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		if itemType == "toy" then
			local _, toyName, toyIcon = C_ToyBox.GetToyInfo(id)
			previewIcon:SetTexture(toyIcon)
			previewName:SetText(toyName or tostring(id))
			previewType:SetText(L["PORTAL_CUSTOM_TYPE_TOY"])
		else
			previewIcon:SetTexture((select(5, C_Item.GetItemInfoInstant(id))))
			previewName:SetText(C_Item.GetItemNameByID(id) or tostring(id))
			previewType:SetText(L["PORTAL_CUSTOM_TYPE_ITEM"])
			local item = Item:CreateFromItemID(id)
			item:ContinueOnItemLoad(function()
				previewIcon:SetTexture(item:GetItemIcon())
				previewName:SetText(item:GetItemName())
			end)
		end
	end

	local function RefreshCustomList()
		for _, r in ipairs(customRows) do
			r:Hide()
			r:SetParent(nil)
		end
		wipe(customRows)

		local items = ns.PortalHubModule:GetCustomItems()
		if #items == 0 then
			listEmptyFS:Show()
		else
			listEmptyFS:Hide()
		end

		local y = -4
		for _, entry in ipairs(items) do
			local row = OneWoW_GUI:CreateListRowBasic(listContent, {
				height = 30,
				label = entry.name or tostring(entry.id),
			})
			row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 4, y)
			row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", -4, y)
			if row.label then
				row.label:ClearAllPoints()
				row.label:SetPoint("LEFT", row, "LEFT", 34, 0)
				row.label:SetPoint("RIGHT", row, "RIGHT", -64, 0)
			end

			local icon = row:CreateTexture(nil, "ARTWORK")
			icon:SetSize(24, 24)
			icon:SetPoint("LEFT", row, "LEFT", 5, 0)
			if entry.type == "toy" then
				icon:SetTexture((select(3, C_ToyBox.GetToyInfo(entry.id))))
			else
				icon:SetTexture((select(5, C_Item.GetItemInfoInstant(entry.id))))
			end

			local removeBtn = OneWoW_GUI:CreateFitTextButton(row, {
				text = REMOVE,
				height = 20,
				minWidth = 50,
			})
			removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			local thisId = entry.id
			removeBtn:SetScript("OnClick", function()
				ns.PortalHubModule:RemoveCustomItem(thisId)
				RefreshCustomList()
				RefreshAfterCustomChange()
			end)

			tinsert(customRows, row)
			y = y - 34
		end

		listContent:SetHeight(math.max(1, math.abs(y) + 10))
	end

	local function ShowCustomItemsDialog()
		if not customDialog then
			customDialog = OneWoW_GUI:CreateDialog({
				name = "OneWoW_PortalCustomItemsDialog",
				title = L["PORTAL_CUSTOM_TITLE"],
				width = 460,
				height = 500,
				showBrand = true,
				buttons = {
					{ text = CLOSE, onClick = function(frame) frame:Hide() end },
				},
			})
			local content = customDialog.contentFrame

			local intro = OneWoW_GUI:CreateFS(content, 12)
			intro:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -12)
			intro:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, -12)
			intro:SetJustifyH("LEFT")
			intro:SetText(L["PORTAL_CUSTOM_INTRO"])
			intro:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

			local idLabel = OneWoW_GUI:CreateFS(content, 12)
			idLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -52)
			idLabel:SetText(L["ITEM_ID"])
			idLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

			idBox = OneWoW_GUI:CreateEditBox(content, {
				width = 120,
				height = 26,
				placeholderText = L["PORTAL_CUSTOM_ID_HINT"],
				maxLetters = 12,
			})
			idBox:SetPoint("LEFT", idLabel, "RIGHT", 10, 0)

			local addBtn = OneWoW_GUI:CreateFitTextButton(content, {
				text = ADD,
				height = 26,
				minWidth = 70,
			})
			addBtn:SetPoint("LEFT", idBox, "RIGHT", 10, 0)

			previewIcon = content:CreateTexture(nil, "ARTWORK")
			previewIcon:SetSize(28, 28)
			previewIcon:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -86)

			previewName = OneWoW_GUI:CreateFS(content, 13)
			previewName:SetPoint("LEFT", previewIcon, "RIGHT", 8, 6)
			previewName:SetJustifyH("LEFT")

			previewType = OneWoW_GUI:CreateFS(content, 10)
			previewType:SetPoint("TOPLEFT", previewName, "BOTTOMLEFT", 0, -2)
			previewType:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

			local statusFS = OneWoW_GUI:CreateFS(content, 11)
			statusFS:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -122)
			statusFS:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, -122)
			statusFS:SetJustifyH("LEFT")
			customDialog.statusFS = statusFS

			idBox:SetScript("OnTextChanged", function(box)
				statusFS:SetText("")
				ResolvePreview(box:GetSearchText())
			end)

			addBtn:SetScript("OnClick", function()
				local ok, result = ns.PortalHubModule:AddCustomItem(idBox:GetSearchText())
				if ok then
					idBox:SetText("")
					idBox:RestorePlaceholder()
					ResolvePreview("")
					statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
					statusFS:SetText(L["PORTAL_CUSTOM_ADDED"])
					RefreshCustomList()
					RefreshAfterCustomChange()
				else
					statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
					statusFS:SetText(result)
				end
			end)

			local divider = content:CreateTexture(nil, "ARTWORK")
			divider:SetHeight(1)
			divider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -144)
			divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -144)
			divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

			local listHeader = OneWoW_GUI:CreateFS(content, 12)
			listHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -154)
			listHeader:SetText(L["PORTAL_CUSTOM_LIST_HEADER"])
			listHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

			local listScroll
			listScroll, listContent = OneWoW_GUI:CreateScrollFrame(content, {})
			listScroll:ClearAllPoints()
			listScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -178)
			listScroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)

			listEmptyFS = OneWoW_GUI:CreateFS(content, 12)
			listEmptyFS:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -188)
			listEmptyFS:SetText(L["PORTAL_CUSTOM_EMPTY"])
			listEmptyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
		end

		RefreshCustomList()
		customDialog.statusFS:SetText("")
		customDialog.frame:Show()
	end

	local manageCustomBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, {
		text = L["ADD_ITEM"],
		height = 24,
		minWidth = 90,
	})
	manageCustomBtn:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -12, -8)
	manageCustomBtn:SetScript("OnClick", ShowCustomItemsDialog)

	local function RefreshPortalView()
		ShowSecureOverlay()
		SchedulePortalLayoutRefresh()
	end

	parent:HookScript("OnShow", RefreshPortalView)
	parent:HookScript("OnHide", function()
		HideSecureOverlay()
	end)

	OneWoW_GUI:ApplyFontToFrame(parent)

	parent.Cleanup = function()
		HideSecureOverlay()
	end

	parent.Activate = RefreshPortalView

	parent.Deactivate = function()
		HideSecureOverlay()
	end
end
