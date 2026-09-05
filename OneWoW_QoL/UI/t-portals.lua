local _, ns = ...

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI

local tinsert, tremove, wipe = tinsert, tremove, wipe
local ipairs = ipairs
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local portalButtons = {}
local portalButtonPool = {}
local slotAnchors = {}
local collapsedCards = {}
local SETTINGS_ID = "__settings__"

function ns.UI.CreatePortalsTab(parent)
	local L = ns.L or {}

	local split = OneWoW_GUI:CreateSplitPanel(parent, {
		showSearch = true,
		searchPlaceholder = L["SEARCH_HINT"],
		hideTitles = true,
	})

	local categoryScrollChild = split.listScrollChild
	local portalScrollFrame = split.detailScrollFrame
	local portalScrollChild = split.detailScrollChild
	local leftStatusText = split.leftStatusText
	local rightStatusText = split.rightStatusText
	local selectedCategoryRow = nil
	local selectedCategory = nil
	local selectedCategoryName = nil
	local layoutRefreshTimer = nil
	local activeStack = nil
	local ShowCategory
	local ShowSettings
	local RefreshCategories

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

	local function ClearPortalButtons()
		for _, button in ipairs(portalButtons) do
			button:Hide()
			button:SetParent(nil)
			button:ClearAllPoints()
			tinsert(portalButtonPool, button)
		end
		wipe(portalButtons)
	end

	local CreatePortalButton

	local function SyncSecureButtons()
		if OneWoW.Restriction.IsProtectedActionBlocked() then
			return
		end

		ClearPortalButtons()

		local scrollLeft = portalScrollChild:GetLeft()
		local scrollTop = portalScrollChild:GetTop()
		if not scrollLeft or not scrollTop then
			HideSecureOverlay()
			return
		end

		local any = false
		for _, anchor in ipairs(slotAnchors) do
			local slot = anchor.slot
			local card = anchor.card
			-- Cards clip content when collapsed but leave children Shown; skip those
			-- so overlay icons do not float over the restacked headers.
			if card and card.IsCollapsed and card:IsCollapsed() then
				-- skip
			elseif slot and slot:IsShown() and slot:GetLeft() then
				any = true
				local button = CreatePortalButton(anchor.portal, anchor.size)
				local x = slot:GetLeft() - scrollLeft
				local y = slot:GetTop() - scrollTop
				button:SetPoint("TOPLEFT", secureScrollChild, "TOPLEFT", x, y)
				tinsert(portalButtons, button)
			end
		end

		secureScrollChild:SetWidth(GetPortalScrollWidth())
		secureScrollChild:SetHeight(portalScrollChild:GetHeight() or 1)
		if any then
			ShowSecureOverlay()
		else
			HideSecureOverlay()
		end
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
			if selectedCategory == SETTINGS_ID then
				ShowSettings()
			elseif selectedCategory and selectedCategoryName then
				ShowCategory(selectedCategory, selectedCategoryName)
			else
				local filterText = split.searchBox and split.searchBox:GetSearchText() or ""
				RefreshCategories(filterText)
			end
		end)
	end

	portalScrollFrame:HookScript("OnSizeChanged", function(_, width)
		secureScrollChild:SetWidth(width)
		if width and width > 0 and selectedCategory and selectedCategory ~= SETTINGS_ID then
			if activeStack and activeStack.SyncContentWidth and activeStack:SyncContentWidth() then
				wipe(slotAnchors)
				activeStack:ReflowContents()
			else
				C_Timer.After(0, SyncSecureButtons)
			end
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
			enabled = cdInfo.isEnabled and not button._onewowHousingIsReturn
		end

		if enabled and duration and duration > 0 then
			button.cooldownFrame:SetCooldown(start, duration)
		else
			button.cooldownFrame:Clear()
		end
	end

	CreatePortalButton = function(portal, size)
		local button
		if #portalButtonPool > 0 then
			button = tremove(portalButtonPool)
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
			else
				button:SetAttribute("type1", nil)
				button:SetAttribute("toy1", nil)
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
			else
				button:SetAttribute("type1", nil)
				button:SetAttribute("item1", nil)
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
			else
				button:SetAttribute("type1", nil)
				button:SetAttribute("spell1", nil)
			end
			local icon = C_Spell.GetSpellTexture(portal.id)
			if icon then
				button:SetNormalTexture(icon)
			end
		elseif portal.type == "housing" then
			if isAvailable then
				ns.PortalHubDetection:ApplyHousingTeleportAttributes(button, "1")
			else
				button:SetAttribute("type1", nil)
				button:SetNormalAtlas("dashboard-panel-homestone-teleport-button")
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
			if mouseButton ~= "RightButton" then
				return
			end

			if not isAvailable then
				return
			end

			local spellName
			if portal.type == "toy" then
				spellName = C_ToyBox.GetToyInfo(portal.id)
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

			local favCount = #(OneWoW:GetPortalHub().escFavorites or {})
			leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))

			if ns.PortalHubEsc then
				ns.PortalHubEsc:Reload()
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
				if portalButton._onewowHousingIsReturn then
					GameTooltip:SetText(HOUSING_DASHBOARD_RETURN, 1, 1, 1)
				else
					GameTooltip:SetText(HOUSING_DASHBOARD_TELEPORT_TO_PLOT, 1, 1, 1)
				end
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

	local function CountCategoryPortals(categoryID)
		local portals = ns.PortalHubModule:GetPortalsForCategory(categoryID, true)
		local usable, total = 0, 0
		for _, portal in ipairs(portals) do
			if portal.type ~= "header" then
				total = total + 1
				local available = portal.available
				if available == nil then
					available = ns.PortalHubDetection:IsPortalUsable(portal.type, portal.id)
				end
				if available then
					usable = usable + 1
				end
			end
		end
		return usable, total
	end

	local function SplitKnownUnknown(portals)
		local known, unknown = {}, {}
		for _, portal in ipairs(portals) do
			if portal.type ~= "header" then
				local available = portal.available
				if available == nil then
					available = ns.PortalHubDetection:IsPortalUsable(portal.type, portal.id)
				end
				portal.available = available
				if available then
					tinsert(known, portal)
				else
					tinsert(unknown, portal)
				end
			end
		end
		return known, unknown
	end

	local function GroupPortalsByHeader(portals)
		local groups = {}
		local current = { name = nil, portals = {} }
		for _, portal in ipairs(portals) do
			if portal.type == "header" then
				if #current.portals > 0 or current.name then
					tinsert(groups, current)
				end
				current = { name = portal.name, portals = {} }
			else
				tinsert(current.portals, portal)
			end
		end
		if #current.portals > 0 or current.name then
			tinsert(groups, current)
		end
		return groups
	end

	local function LayoutPortalGrid(content, contentWidth, portals, dimmed)
		local iconSize = OneWoW:GetPortalHub().iconSize or 40
		local gap = 5
		local removeSize = OneWoW_GUI.Constants.GUI.ENTRY_LIST_ICON_SIZE or 16
		local removeGap = 4
		local card = content:GetParent()
		local hasCustom = false
		for _, portal in ipairs(portals) do
			if portal.isCustom then
				hasCustom = true
				break
			end
		end
		local cellW = iconSize + (hasCustom and (removeGap + removeSize) or 0)
		local columns = math.max(1, math.floor((contentWidth + gap) / (cellW + gap)))
		local col, row = 0, 0

		for _, portal in ipairs(portals) do
			if dimmed then
				portal.available = false
			elseif portal.available == nil then
				portal.available = ns.PortalHubDetection:IsPortalUsable(portal.type, portal.id)
			end

			local x = col * (cellW + gap)
			local y = -row * (iconSize + gap)

			local slot = CreateFrame("Frame", nil, content)
			slot:SetSize(iconSize, iconSize)
			slot:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
			tinsert(slotAnchors, { slot = slot, portal = portal, size = iconSize, card = card })

			if portal.isCustom then
				local removeBtn = CreateFrame("Button", nil, content)
				removeBtn:SetSize(removeSize, removeSize)
				removeBtn:SetPoint("LEFT", slot, "RIGHT", removeGap, 0)
				removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
				removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
				local itemID = portal.id
				removeBtn:SetScript("OnClick", function()
					ns.PortalHubModule:RemoveCustomItem(itemID)
					ShowCategory("custom", CUSTOM)
					RefreshCategories(split.searchBox and split.searchBox:GetSearchText() or "")
				end)
			end

			col = col + 1
			if col >= columns then
				col = 0
				row = row + 1
			end
		end

		local rows = row + (col > 0 and 1 or 0)
		if rows < 1 then
			rows = 0
		end
		return math.max(1, rows * (iconSize + gap) - (rows > 0 and gap or 0))
	end

	local function MakeStack(host)
		local stack = OneWoW_GUI:CreateCardStack(host, {
			getCollapsed = function(key)
				return collapsedCards[key] == true
			end,
			setCollapsed = function(key, collapsed)
				collapsedCards[key] = collapsed
			end,
		})

		local rawReflow = stack.ReflowContents
		function stack:ReflowContents(...)
			wipe(slotAnchors)
			ClearPortalButtons()
			rawReflow(self, ...)
		end

		stack.OnRelayout = function()
			-- Drop overlay icons immediately so collapse does not leave them
			-- floating until the deferred SyncSecureButtons runs.
			ClearPortalButtons()
			HideSecureOverlay()
			local h = host:GetHeight() or 0
			portalScrollChild:SetHeight(math.max(h + 8, portalScrollFrame:GetHeight() or 1))
			secureScrollChild:SetHeight(portalScrollChild:GetHeight())
			C_Timer.After(0, SyncSecureButtons)
		end

		activeStack = stack
		return stack
	end

	local function AddKnownUnknownCards(stack, keyPrefix, portals)
		local known, unknown = SplitKnownUnknown(portals)
		if #known > 0 then
			stack:AddCard(keyPrefix .. ":known", L["PORTAL_KNOWN"], function(content, contentWidth)
				return LayoutPortalGrid(content, contentWidth, known, false)
			end)
		end
		if #unknown > 0 then
			stack:AddCard(keyPrefix .. ":unknown", UNKNOWN, function(content, contentWidth)
				return LayoutPortalGrid(content, contentWidth, unknown, true)
			end)
		end
		return #known, #unknown
	end

	local function ClearDetail()
		activeStack = nil
		ClearPortalButtons()
		wipe(slotAnchors)
		HideSecureOverlay()
		OneWoW_GUI:ClearFrame(portalScrollChild)
	end

	ShowSettings = function()
		if OneWoW.Restriction.IsProtectedActionBlocked() then return end
		selectedCategory = SETTINGS_ID
		selectedCategoryName = SETTINGS
		ClearDetail()

		local host = CreateFrame("Frame", nil, portalScrollChild)
		host:SetPoint("TOPLEFT", portalScrollChild, "TOPLEFT", 0, 0)
		host:SetPoint("TOPRIGHT", portalScrollChild, "TOPRIGHT", 0, 0)

		local stack = MakeStack(host)
		local ph = OneWoW:GetPortalHub()

		stack:AddCard("settings:esc", SETTINGS, function(content, contentWidth)
			local rowY = 0

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["Show Portals on ESC"],
				description = L["PORTAL_SETTINGS_ESC_DESC"],
				value = ph.escPortalsEnabled and true or false,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().escPortalsEnabled = newVal
					if ns.PortalHubEsc and GameMenuFrame and GameMenuFrame:IsShown() then
						ns.PortalHubEsc:ShowPortalFrames()
					elseif ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			OneWoW_GUI:SetFontBaseSize(sizeLabel, 12)
			OneWoW_GUI:SafeSetFont(sizeLabel, OneWoW_GUI:GetFont(), 12)
			sizeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
			sizeLabel:SetJustifyH("LEFT")
			sizeLabel:SetText(L["PORTAL_ESC_ICON_SIZE"])
			sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

			local sizeDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			OneWoW_GUI:SetFontBaseSize(sizeDesc, 10)
			OneWoW_GUI:SafeSetFont(sizeDesc, OneWoW_GUI:GetFont(), 10)
			sizeDesc:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -3)
			sizeDesc:SetWidth(math.max(50, contentWidth - 24))
			sizeDesc:SetJustifyH("LEFT")
			sizeDesc:SetWordWrap(true)
			sizeDesc:SetText(L["PORTAL_ESC_ICON_SIZE_DESC"])
			sizeDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

			local sliderY = rowY - sizeLabel:GetStringHeight() - 3 - sizeDesc:GetStringHeight() - 6
			local sizeSlider = OneWoW_GUI:CreateSlider(content, {
				width = math.min(220, math.max(120, contentWidth - 24)),
				minVal = 20,
				maxVal = 64,
				step = 2,
				currentVal = ph.escIconSize or 40,
				fmt = "%dpx",
				onChange = function(val)
					OneWoW:GetPortalHub().escIconSize = val
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
			})
			sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, sliderY)
			rowY = sliderY - 36 - 10

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_ESC_SHOW_ICON_TEXT"],
				description = L["PORTAL_ESC_SHOW_ICON_TEXT_DESC"],
				value = ph.escShowIconText,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().escShowIconText = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			local fontLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			OneWoW_GUI:SetFontBaseSize(fontLabel, 12)
			OneWoW_GUI:SafeSetFont(fontLabel, OneWoW_GUI:GetFont(), 12)
			fontLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
			fontLabel:SetJustifyH("LEFT")
			fontLabel:SetText(L["PORTAL_ESC_ICON_FONT_SIZE"])
			fontLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

			local fontDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			OneWoW_GUI:SetFontBaseSize(fontDesc, 10)
			OneWoW_GUI:SafeSetFont(fontDesc, OneWoW_GUI:GetFont(), 10)
			fontDesc:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -3)
			fontDesc:SetWidth(math.max(50, contentWidth - 24))
			fontDesc:SetJustifyH("LEFT")
			fontDesc:SetWordWrap(true)
			fontDesc:SetText(L["PORTAL_ESC_ICON_FONT_SIZE_DESC"])
			fontDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

			local fontSliderY = rowY - fontLabel:GetStringHeight() - 3 - fontDesc:GetStringHeight() - 6
			local fontSlider = OneWoW_GUI:CreateSlider(content, {
				width = math.min(220, math.max(120, contentWidth - 24)),
				minVal = 8,
				maxVal = 18,
				step = 1,
				currentVal = ph.escIconFontSize,
				fmt = "%d",
				onChange = function(val)
					OneWoW:GetPortalHub().escIconFontSize = val
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
			})
			fontSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 12, fontSliderY)
			rowY = fontSliderY - 36 - 10

			local hsLabel = OneWoW_GUI:CreateFS(content, 12)
			hsLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, rowY)
			hsLabel:SetJustifyH("LEFT")
			hsLabel:SetText(L["PORTAL_HEARTHSTONE_CHOICE"])
			hsLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

			local function HearthChoiceLabel(choice)
				if choice == "none" then
					return NONE
				end
				if choice == "disabled" then
					return L["FEATURE_DISABLED"]
				end
				if choice == "default" then
					return DEFAULT
				end
				local id = tonumber(choice)
				if id then
					local _, name = C_ToyBox.GetToyInfo(id)
					return name or tostring(id)
				end
				return L["PORTAL_RANDOM_HEARTHSTONE"]
			end

			local hsDrop, hsDropText = OneWoW_GUI:CreateDropdown(content, {
				width = math.min(260, math.max(160, contentWidth - 24)),
				height = 26,
				text = HearthChoiceLabel(ns.PortalHubDetection:GetHearthstoneChoice()),
			})
			hsDrop:SetPoint("TOPLEFT", hsLabel, "BOTTOMLEFT", 0, -4)
			OneWoW_GUI:AttachFilterMenu(hsDrop, {
				searchable = true,
				menuHeight = 280,
				buildItems = function()
					local items = {
						{value = "random", text = L["PORTAL_RANDOM_HEARTHSTONE"]},
						{value = "default", text = DEFAULT},
						{value = "none", text = NONE},
						{value = "disabled", text = L["FEATURE_DISABLED"]},
					}
					local toys = ns.PortalData_Hearthstones:GetOwnedToys()
					for _, toy in ipairs(toys) do
						tinsert(items, {value = toy.id, text = toy.name})
					end
					return items
				end,
				onSelect = function(value, text)
					OneWoW:GetPortalHub().hearthstoneChoice = value
					OneWoW:GetPortalHub().randomHearthstone = (value == "random")
					hsDropText:SetText(text)
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				getActiveValue = function()
					return OneWoW:GetPortalHub().hearthstoneChoice
				end,
			})

			local hsDesc = OneWoW_GUI:CreateFS(content, 10)
			hsDesc:SetPoint("TOPLEFT", hsDrop, "BOTTOMLEFT", 0, -4)
			hsDesc:SetWidth(math.max(50, contentWidth - 24))
			hsDesc:SetJustifyH("LEFT")
			hsDesc:SetWordWrap(true)
			hsDesc:SetText(L["PORTAL_HEARTHSTONE_CHOICE_DESC"])
			hsDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			rowY = rowY - hsLabel:GetStringHeight() - 4 - 26 - 4 - hsDesc:GetStringHeight() - 10

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SEASONAL_ONLY"],
				description = L["PORTAL_SEASONAL_ONLY_DESC"],
				value = ph.seasonalOnly == true,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().seasonalOnly = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_LIVE_PATH_FLYOUTS"],
				description = L["PORTAL_LIVE_PATH_FLYOUTS_DESC"],
				value = ph.useLivePathFlyouts ~= false,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().useLivePathFlyouts = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_LFG_PROMPT"],
				description = L["PORTAL_LFG_PROMPT_DESC"],
				value = ph.lfgTeleportPrompt == true,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().lfgTeleportPrompt = newVal
					if ns.PortalHubLFG then
						ns.PortalHubLFG:SetEnabled(newVal)
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SHOW_SEASON1"],
				description = L["PORTAL_SHOW_SEASON1_DESC"],
				value = ph.showSeason1 ~= false,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().showSeason1 = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SHOW_SEASON2"],
				description = L["PORTAL_SHOW_SEASON2_DESC"],
				value = ph.showSeason2 ~= false,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().showSeason2 = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SHOW_MAGE_TELEPORTS"],
				description = L["PORTAL_SHOW_MAGE_TELEPORTS_DESC"],
				value = ph.showMageTeleports,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().showMageTeleports = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SHOW_MAGE_PORTALS"],
				description = L["PORTAL_SHOW_MAGE_PORTALS_DESC"],
				value = ph.showMagePortals,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().showMagePortals = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_ESC_SHOW_UNKNOWN"],
				description = L["PORTAL_ESC_SHOW_UNKNOWN_DESC"],
				value = ph.escShowUnknown ~= false,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().escShowUnknown = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_FAVORITES_ALWAYS_EXPANDED"],
				description = L["PORTAL_FAVORITES_ALWAYS_EXPANDED_DESC"],
				value = ph.escFavoritesAlwaysExpanded == true,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().escFavoritesAlwaysExpanded = newVal
					if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
						ns.PortalHubEsc:Reload()
					end
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			return math.max(1, math.abs(rowY))
		end)

		stack:AddCard("settings:toprow", L["PORTAL_ESC_TOP_ROW"], function(content, contentWidth)
			local rowY = 0
			local topRowOn = ph.showEscTopRow ~= false
			local pinRefreshes = {}

			local function ReloadEsc()
				if ns.PortalHubEsc and ns.PortalHubEsc.Reload then
					ns.PortalHubEsc:Reload()
				end
			end

			rowY = OneWoW_GUI:CreateToggleRow(content, {
				yOffset = rowY,
				contentWidth = contentWidth,
				label = L["PORTAL_SHOW_ESC_TOP_ROW"],
				description = L["PORTAL_SHOW_ESC_TOP_ROW_DESC"],
				value = topRowOn,
				isEnabled = true,
				onValueChange = function(newVal)
					OneWoW:GetPortalHub().showEscTopRow = newVal
					for _, refreshPin in ipairs(pinRefreshes) do
						refreshPin(newVal)
					end
					ReloadEsc()
				end,
				onLabel = L["FEATURES_ON"],
				offLabel = L["FEATURES_OFF"],
				buttonWidth = 50,
			})

			local function AddPinToggle(label, desc, getValue, setValue)
				local refresh
				rowY, refresh = OneWoW_GUI:CreateToggleRow(content, {
					yOffset = rowY,
					contentWidth = contentWidth,
					label = label,
					description = desc,
					value = getValue(),
					isEnabled = OneWoW:GetPortalHub().showEscTopRow ~= false,
					onValueChange = function(newVal)
						setValue(newVal)
						ReloadEsc()
					end,
					onLabel = L["FEATURES_ON"],
					offLabel = L["FEATURES_OFF"],
					buttonWidth = 50,
				})
				tinsert(pinRefreshes, function(enabled)
					refresh(enabled, getValue())
				end)
			end

			AddPinToggle(L["PORTAL_DALARAN_HEARTH"], L["PORTAL_DALARAN_HEARTH_DESC"],
				function() return OneWoW:GetPortalHub().showDalaranHearth ~= false end,
				function(v) OneWoW:GetPortalHub().showDalaranHearth = v end)
			AddPinToggle(L["PORTAL_GARRISON_HEARTH"], L["PORTAL_GARRISON_HEARTH_DESC"],
				function() return OneWoW:GetPortalHub().showGarrisonHearth ~= false end,
				function(v) OneWoW:GetPortalHub().showGarrisonHearth = v end)
			AddPinToggle(L["PORTAL_FLIGHT_WHISTLE"], L["PORTAL_FLIGHT_WHISTLE_DESC"],
				function() return OneWoW:GetPortalHub().showFlightWhistle ~= false end,
				function(v) OneWoW:GetPortalHub().showFlightWhistle = v end)
			AddPinToggle(L["PORTAL_HOUSING_PORTAL"], L["PORTAL_HOUSING_PORTAL_DESC"],
				function() return OneWoW:GetPortalHub().showHousingPortal ~= false end,
				function(v) OneWoW:GetPortalHub().showHousingPortal = v end)

			return math.max(1, math.abs(rowY))
		end)

		stack:Finish()

		local favCount = #(OneWoW:GetPortalHub().escFavorites or {})
		leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))
		rightStatusText:SetText(SETTINGS)
		HideSecureOverlay()
	end

	ShowCategory = function(categoryID, categoryName)
		if OneWoW.Restriction.IsProtectedActionBlocked() then return end
		if categoryID == SETTINGS_ID then
			ShowSettings()
			return
		end

		selectedCategory = categoryID
		selectedCategoryName = categoryName
		ClearDetail()

		local host = CreateFrame("Frame", nil, portalScrollChild)
		host:SetPoint("TOPLEFT", portalScrollChild, "TOPLEFT", 0, 0)
		host:SetPoint("TOPRIGHT", portalScrollChild, "TOPRIGHT", 0, 0)

		local yTop = 0
		if categoryID == "custom" then
			local addHost = CreateFrame("Frame", nil, host)
			addHost:SetPoint("TOPLEFT", host, "TOPLEFT", 4, yTop)
			addHost:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, yTop)
			addHost:SetHeight(36)

			local addRow = OneWoW_GUI:CreateValueAddRow(addHost, {
				x = 0,
				rightInset = 0,
				yOffset = -4,
				label = L["ITEM_ID"],
				addText = ADD,
				input = { kind = "itemId" },
				drop = { mode = "chip", text = L["DRAG_ITEM_HERE"] },
				onAdd = function(itemID)
					local ok, err = ns.PortalHubModule:AddCustomItem(itemID)
					if not ok then
						print("|cFF00FF00OneWoW:|r", err)
						return false
					end
					C_Timer.After(0, function()
						ShowCategory("custom", CUSTOM)
						RefreshCategories(split.searchBox and split.searchBox:GetSearchText() or "")
					end)
				end,
			})
			addRow.frame:SetPoint("TOPLEFT", addHost, "TOPLEFT", 0, -4)
			addRow.frame:SetPoint("TOPRIGHT", addHost, "TOPRIGHT", 0, -4)
			yTop = yTop - 44
		end

		local cardsHost = CreateFrame("Frame", nil, host)
		cardsHost:SetPoint("TOPLEFT", host, "TOPLEFT", 0, yTop)
		cardsHost:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, yTop)

		local stack = MakeStack(cardsHost)
		local allPortals = ns.PortalHubModule:GetPortalsForCategory(categoryID, true)
		local knownTotal, unknownTotal = 0, 0

		local hasHeaders = false
		for _, portal in ipairs(allPortals) do
			if portal.type == "header" then
				hasHeaders = true
				break
			end
		end

		if hasHeaders then
			local groups = GroupPortalsByHeader(allPortals)
			for i, group in ipairs(groups) do
				if #group.portals > 0 then
					if group.name then
						local titleFrame = CreateFrame("Frame", nil, cardsHost)
						titleFrame:SetHeight(22)
						local title = OneWoW_GUI:CreateFS(titleFrame, 13)
						title:SetPoint("LEFT", titleFrame, "LEFT", 8, 0)
						title:SetText(group.name)
						title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
						stack:AddFrame(titleFrame)
					end
					local k, u = AddKnownUnknownCards(stack, categoryID .. ":" .. (group.name or i), group.portals)
					knownTotal = knownTotal + k
					unknownTotal = unknownTotal + u
				end
			end
		else
			knownTotal, unknownTotal = AddKnownUnknownCards(stack, categoryID, allPortals)
		end

		-- Outer host includes the Custom add row above the card stack.
		stack.OnRelayout = function()
			ClearPortalButtons()
			HideSecureOverlay()
			local cardsH = cardsHost:GetHeight() or 0
			local total = math.abs(yTop) + cardsH + 8
			host:SetHeight(total)
			portalScrollChild:SetHeight(math.max(total + 8, portalScrollFrame:GetHeight() or 1))
			secureScrollChild:SetHeight(portalScrollChild:GetHeight())
			C_Timer.After(0, SyncSecureButtons)
		end

		stack:Finish()

		local favCount = #(OneWoW:GetPortalHub().escFavorites or {})
		rightStatusText:SetText(string.format(
			L["PORTAL_STATUS_KNOWN_UNKNOWN"],
			categoryName,
			knownTotal,
			knownTotal + unknownTotal
		))
		leftStatusText:SetText(string.format(L["Favorites: %d/%d"], favCount, 15))
	end

	local categoryItems = {}
	local settingsRow = nil
	local firstCategoryRow = nil
	local favoritesRow = nil

	local function SetSelectedCategoryRow(row)
		if selectedCategoryRow and selectedCategoryRow ~= row then
			selectedCategoryRow:SetActive(false)
			if selectedCategoryRow._dimmed and selectedCategoryRow.label then
				selectedCategoryRow.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			end
		end
		selectedCategoryRow = row
		if row then
			row:SetActive(true)
		end
	end

	local function CreateCategoryRow(category, yOffset, isSubcat, usable, total)
		local valueText
		local dimmed = false
		if category.id ~= SETTINGS_ID then
			valueText = string.format("%d/%d", usable or 0, total or 0)
			dimmed = (usable or 0) == 0 and (total or 0) > 0
			if (total or 0) == 0 then
				dimmed = true
			end
		end

		local row = OneWoW_GUI:CreateListRowBasic(categoryScrollChild, {
			height = isSubcat and 28 or 30,
			label = category.name,
			showValueText = valueText ~= nil,
			valueText = valueText or "",
			showDot = category.id ~= SETTINGS_ID,
			dotEnabled = not dimmed and (usable or 0) > 0,
			onClick = function(clicked)
				SetSelectedCategoryRow(clicked)
				if category.id == SETTINGS_ID then
					ShowSettings()
				else
					ShowCategory(category.id, category.name)
				end
			end,
		})
		row:SetPoint("TOPLEFT", categoryScrollChild, "TOPLEFT", 4, yOffset)
		row:SetPoint("TOPRIGHT", categoryScrollChild, "TOPRIGHT", -4, yOffset)
		row.categoryID = category.id
		row.isSubcat = isSubcat
		row._dimmed = dimmed

		if isSubcat and row.label then
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", 22, 0)
			if row.valueText then
				row.label:SetPoint("RIGHT", row.valueText, "LEFT", -4, 0)
			else
				row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
			end
		end

		if dimmed and row.label then
			row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			if row.valueText then
				row.valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			end
			local origSetActive = row.SetActive
			function row:SetActive(active)
				origSetActive(self, active)
				if not active then
					self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
				end
			end
			row:HookScript("OnLeave", function(myself)
				if not myself.isActive and myself._dimmed then
					myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
				end
			end)
		end

		tinsert(categoryItems, row)
		if not firstCategoryRow then
			firstCategoryRow = row
		end
		if category.id == SETTINGS_ID then
			settingsRow = row
		elseif category.id == "favorites" then
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
		wipe(categoryItems)
		firstCategoryRow = nil
		favoritesRow = nil
		settingsRow = nil
		selectedCategoryRow = nil

		local categories = ns.PortalHubModule:GetCategories()
		local filter = (filterText or ""):lower()
		local yOffset = -5

		local settingsName = SETTINGS
		local settingsMatches = filter == "" or settingsName:lower():find(filter, 1, true)
		if settingsMatches then
			yOffset = CreateCategoryRow({ id = SETTINGS_ID, name = settingsName }, yOffset, false)
		end

		local customCat, favoritesCat
		local rest = {}
		for _, category in ipairs(categories) do
			if category.id == "custom" then
				customCat = category
			elseif category.id == "favorites" then
				favoritesCat = category
			else
				tinsert(rest, category)
			end
		end

		local function AppendCategory(category)
			local categoryMatches = filter == "" or (category.name or ""):lower():find(filter, 1, true)
			local matchingSubcats = {}
			if category.subcategories then
				for _, subcat in ipairs(category.subcategories) do
					local subcatMatches = filter == "" or (subcat.name or ""):lower():find(filter, 1, true)
					if subcatMatches then
						tinsert(matchingSubcats, subcat)
					end
				end
			end

			if categoryMatches or #matchingSubcats > 0 then
				local usable, total = CountCategoryPortals(category.id)
				yOffset = CreateCategoryRow(category, yOffset, false, usable, total)
				for _, subcat in ipairs(matchingSubcats) do
					local su, st = CountCategoryPortals(subcat.id)
					yOffset = CreateCategoryRow(subcat, yOffset, true, su, st)
				end
			end
		end

		if customCat then
			AppendCategory(customCat)
		end
		if favoritesCat then
			AppendCategory(favoritesCat)
		end
		for _, category in ipairs(rest) do
			AppendCategory(category)
		end

		categoryScrollChild:SetHeight(math.abs(yOffset) + 50)
		if selectedCategoryRow then
			selectedCategoryRow:Click()
		elseif settingsRow then
			settingsRow:Click()
		elseif favoritesRow then
			favoritesRow:Click()
		elseif firstCategoryRow then
			firstCategoryRow:Click()
		else
			rightStatusText:SetText("")
			leftStatusText:SetText("")
		end
	end

	if split.searchBox then
		split.searchBox:SetScript("OnTextChanged", function(searchBox)
			RefreshCategories(searchBox:GetSearchText())
		end)
	end

	local function RefreshPortalView()
		if selectedCategory == SETTINGS_ID then
			HideSecureOverlay()
		else
			ShowSecureOverlay()
		end
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
