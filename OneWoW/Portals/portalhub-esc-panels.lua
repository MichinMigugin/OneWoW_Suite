local ADDON_NAME, OneWoW = ...
local L = OneWoW.L
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

OneWoW.EscPanels = OneWoW.EscPanels or {}
local EscPanels = OneWoW.EscPanels

local PANEL_WIDTH = 350
EscPanels.PANEL_WIDTH = PANEL_WIDTH
local PANEL_GAP = 6
local PANEL_PADDING = 12
local SCREEN_PAD = 10
local CHARINFO_HEIGHT = 160
local ALERTS_HEIGHT = 100
local function HEADER_COLOR() return {OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")} end
local function TEXT_COLOR() return {OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")} end
local function DIM_COLOR() return {OneWoW_GUI:GetThemeColor("TEXT_MUTED")} end
local function BG_COLOR() return {OneWoW_GUI:GetThemeColor("BG_PRIMARY")} end
local function BORDER_COLOR() return {OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")} end

local function GetNoteTextColor(fontColorKey, pinColorKey)
	local notesAddon = _G.OneWoW_Notes
	local PIN_COLORS = notesAddon and notesAddon.Config and notesAddon.Config.PIN_COLORS
	if not PIN_COLORS then
		local tc = TEXT_COLOR()
		return tc[1], tc[2], tc[3]
	end
	local pinConfig = PIN_COLORS[pinColorKey] or PIN_COLORS["hunter"]
	if fontColorKey == "match" then
		local b = pinConfig.border
		return b[1], b[2], b[3]
	elseif fontColorKey == "white" then
		return 1, 1, 1
	elseif fontColorKey == "black" then
		return 0, 0, 0
	else
		local fontConfig = PIN_COLORS[fontColorKey]
		if fontConfig then
			local b = fontConfig.border
			return b[1], b[2], b[3]
		else
			local b = pinConfig.border
			return b[1], b[2], b[3]
		end
	end
end

local panelFrames = {}
local dimOverlay = nil
local panelsContainer = nil

local BACKDROP_INFO = OneWoW_GUI.Constants.BACKDROP_SOFT

local function GetCharacterInfo()
	local name    = UnitName("player")
	local realm   = GetRealmName()
	local _, class = UnitClass("player")
	local faction = UnitFactionGroup("player")
	local guild, _, guildRank = GetGuildInfo("player")

	local _, itemLevelEquipped = GetAverageItemLevel()
	local itemLevel = math.floor(itemLevelEquipped or 0)

	local mplusRating = 0
	if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
		mplusRating = C_ChallengeMode.GetOverallDungeonScore() or 0
	end

	return {
		name             = name,
		realm            = realm,
		class            = class,
		faction          = faction,
		guild            = guild,
		guildRank        = guildRank,
		itemLevel        = itemLevel,
		mythicPlusRating = mplusRating,
		money            = GetMoney(),
	}
end

local function GetNotesByType(noteType)
	local notes = {}
	local notesAddon = _G.OneWoW_Notes
	if not notesAddon then return notes end
	local notesData = notesAddon.NotesData
	if not notesData or not notesData.GetAllNotes then return notes end

	local allNotes = notesData:GetAllNotes()
	if not allNotes then return notes end

	for noteID, note in pairs(allNotes) do
		if type(note) == "table" and note.noteType == noteType then
			local incompleteTodos = {}
			if note.todos and #note.todos > 0 then
				for _, todo in ipairs(note.todos) do
					if not todo.completed then
						table.insert(incompleteTodos, todo.text)
					end
				end
			end

			local hasTasks = #incompleteTodos > 0

			if hasTasks then
				table.insert(notes, {
					title = note.title,
					id    = note.id,
					tasks = incompleteTodos,
				})
			end
		end
	end
	return notes
end

local function GetZoneNoteData()
	local notesAddon = _G.OneWoW_Notes
	if not notesAddon or not notesAddon.Zones then return nil, nil end

	local zoneName = notesAddon.Zones:GetCurrentZoneName()
	if not zoneName or zoneName == "" then return nil, nil end

	local zoneData = notesAddon.Zones:GetZone(zoneName)
	return zoneName, zoneData
end

local function GetCatalogData(mapID)
	local journalNS = _G.OneWoW_CatalogData_Journal
	if not journalNS or not journalNS.JournalData then return nil end

	local JournalData = journalNS.JournalData
	JournalData:BuildJournalCache()
	if not JournalData.journalCache then return nil end

	local instData
	for _, data in pairs(JournalData.journalCache) do
		if data.mapID == mapID then
			instData = data
			break
		end
	end
	if not instData then return nil end

	local keyMap = {
		TMog    = "tmogs",
		Mount   = "mounts",
		Pet     = "pets",
		Toy     = "toys",
		Recipe  = "recipes",
		Quest   = "quests",
		Housing = "housing",
	}
	local counts = {
		tmogs   = { current = 0, total = 0 },
		mounts  = { current = 0, total = 0 },
		pets    = { current = 0, total = 0 },
		recipes = { current = 0, total = 0 },
		toys    = { current = 0, total = 0 },
		quests  = { current = 0, total = 0 },
		housing = { current = 0, total = 0 },
	}

	for _, enc in ipairs(instData.encounters) do
		for _, item in ipairs(enc.items) do
			local key = keyMap[item.special]
			if key then
				counts[key].total = counts[key].total + 1
				local collected = JournalData:IsItemCollected(item.itemID, item.itemData, item.special)
				if collected then
					counts[key].current = counts[key].current + 1
				end
			end
		end
	end

	return counts
end

local function CreatePanel(parent, name, height)
	local panel = CreateFrame("Frame", name, parent, "BackdropTemplate")
	panel:SetSize(PANEL_WIDTH, height)
	panel:SetBackdrop(BACKDROP_INFO)
	panel:SetBackdropColor(unpack(BG_COLOR()))
	panel:SetBackdropBorderColor(unpack(BORDER_COLOR()))
	return panel
end

local function CreateHeader(panel, textKey)
	local header = OneWoW_GUI:CreateFS(panel, 16)
	header:SetPoint("TOP", panel, "TOP", 0, -PANEL_PADDING)
	header:SetText(L[textKey])
	header:SetTextColor(unpack(HEADER_COLOR()))
	return header
end

local function CalculateLayout(ph, showZone, hasDaily, hasWeekly, hasAlerts)
	local screenHeight = UIParent:GetHeight()
	local fixedHeight = ph.escShowCharacterInfo ~= false and CHARINFO_HEIGHT or 0
	local gapCount = 0
	local flexCount = 0

	if hasAlerts then
		fixedHeight = fixedHeight + ALERTS_HEIGHT
		gapCount = gapCount + 1
	end
	if showZone then
		flexCount = flexCount + 1
		gapCount = gapCount + 1
	end
	if hasDaily then
		flexCount = flexCount + 1
		gapCount = gapCount + 1
	end
	if hasWeekly then
		flexCount = flexCount + 1
		gapCount = gapCount + 1
	end

	local instName, instanceType = GetInstanceInfo()
	local hasInstance = (instanceType == "party" or instanceType == "raid")
	if hasInstance then
		fixedHeight = fixedHeight + 120
		gapCount = gapCount + 1
	end

	local totalGaps = gapCount * PANEL_GAP
	local totalPadding = SCREEN_PAD * 2
	local available = screenHeight - fixedHeight - totalGaps - totalPadding

	local flexHeight = 180
	if flexCount > 0 then
		flexHeight = math.floor(available / flexCount)
		flexHeight = math.max(100, math.min(300, flexHeight))
	end

	local totalUsed = fixedHeight + (flexCount * flexHeight) + totalGaps
	local verticalOffset = math.floor((screenHeight - totalUsed) / 2)
	verticalOffset = math.max(SCREEN_PAD, verticalOffset)

	return flexHeight, verticalOffset
end

local function EnsureDimOverlay()
	if not dimOverlay then
		dimOverlay = CreateFrame("Frame", "OneWoWEscDimOverlay", UIParent)
		dimOverlay:SetAllPoints(UIParent)
		dimOverlay:SetFrameStrata("DIALOG")
		dimOverlay:SetFrameLevel(0)

		local bg = dimOverlay:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.6)
	end
	dimOverlay:Show()
end

local function GetPanelsHorizontalMode(ph)
	if ph and ph.escPanelsSide == "right" then
		return "right"
	end
	return "left"
end

local function EnsurePanelsContainer(ph)
	if not panelsContainer then
		panelsContainer = CreateFrame("Frame", "OneWoWEscPanelsContainer", UIParent)
		panelsContainer:SetFrameStrata("FULLSCREEN_DIALOG")
		panelsContainer:SetFrameLevel(100)
	end

	panelsContainer:ClearAllPoints()
	local gmLeft = GameMenuFrame and GameMenuFrame:GetLeft()
	local gmRight = GameMenuFrame and GameMenuFrame:GetRight()
	local mode = GetPanelsHorizontalMode(ph)
	local yTop = UIParent:GetHeight()

	if mode == "right" then
		if gmRight then
			panelsContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", gmRight + 20, yTop)
		else
			panelsContainer:SetPoint("TOPLEFT", UIParent, "TOP", 200, 0)
		end
	elseif gmLeft then
		panelsContainer:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", gmLeft - 20, yTop)
	else
		panelsContainer:SetPoint("TOPRIGHT", UIParent, "TOP", -200, 0)
	end
	panelsContainer:SetSize(PANEL_WIDTH, UIParent:GetHeight())
	panelsContainer:Show()
end

local function BuildCharacterInfoPanel(container, yOffset, hMode)
	if not panelFrames.charInfo then
		local panel = CreatePanel(container, "OneWoWEscPanelCharInfo", CHARINFO_HEIGHT)
		CreateHeader(panel, "ESCPANEL_CHARACTER_INFO")

		local factionIcon = panel:CreateTexture(nil, "ARTWORK")
		factionIcon:SetSize(48, 48)
		factionIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -38)
		panel.factionIcon = factionIcon

		local nameText = OneWoW_GUI:CreateFS(panel, 16)
		nameText:SetPoint("LEFT", factionIcon, "RIGHT", 12, 8)
		nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.nameText = nameText

		local guildText = OneWoW_GUI:CreateFS(panel, 12)
		guildText:SetPoint("LEFT", factionIcon, "RIGHT", 12, -10)
		guildText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
		panel.guildText = guildText

		local iLevelText = OneWoW_GUI:CreateFS(panel, 12)
		iLevelText:SetPoint("TOPLEFT", factionIcon, "BOTTOMLEFT", 0, -12)
		iLevelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.iLevelText = iLevelText

		local mplusText = OneWoW_GUI:CreateFS(panel, 12)
		mplusText:SetPoint("TOPLEFT", iLevelText, "BOTTOMLEFT", 0, -6)
		mplusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.mplusText = mplusText

		local goldText = OneWoW_GUI:CreateFS(panel, 12)
		goldText:SetPoint("TOPLEFT", mplusText, "BOTTOMLEFT", 0, -6)
		goldText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.goldText = goldText

		panelFrames.charInfo = panel
	end

	local panel = panelFrames.charInfo
	panel:ClearAllPoints()
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
	else
		panel:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOffset)
	end
	panel:SetHeight(CHARINFO_HEIGHT)

	local char = GetCharacterInfo()

	if char.faction == "Horde" then
		panel.factionIcon:SetTexture("Interface\\Timer\\Horde-Logo")
	elseif char.faction == "Alliance" then
		panel.factionIcon:SetTexture("Interface\\Timer\\Alliance-Logo")
	else
		panel.factionIcon:SetTexture("Interface\\Timer\\Panda-Logo")
	end

	local classColor = RAID_CLASS_COLORS[char.class] or {r = 1, g = 1, b = 1}
	panel.nameText:SetFormattedText("%s-%s", char.name, char.realm)
	panel.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)

	if char.guild and char.guildRank then
		panel.guildText:SetFormattedText("<%s> - %s", char.guild, char.guildRank)
	elseif char.guild then
		panel.guildText:SetFormattedText("<%s>", char.guild)
	else
		panel.guildText:SetText(L["ESCPANEL_NO_GUILD"])
	end

	panel.iLevelText:SetFormattedText("iLevel: %d", char.itemLevel)
	panel.mplusText:SetFormattedText("M+ Score: %d", char.mythicPlusRating)

	local gold   = math.floor(char.money / 10000)
	local silver = math.floor((char.money % 10000) / 100)
	local copper = char.money % 100
	panel.goldText:SetFormattedText(
		"Gold: %s|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t %s|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t %s|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t",
		BreakUpLargeNumbers(gold), silver, copper)

	panel:Show()
	return panel, yOffset - CHARINFO_HEIGHT - PANEL_GAP
end

local function BuildAlertsPanel(container, yOffset, anchorPanel, hMode)
	if not panelFrames.alerts then
		local panel = CreatePanel(container, "OneWoWEscPanelAlerts", ALERTS_HEIGHT)
		CreateHeader(panel, "ESCPANEL_ALERTS")

		local noAlertsText = OneWoW_GUI:CreateFS(panel, 12)
		noAlertsText:SetPoint("CENTER", panel, "CENTER", 0, -5)
		noAlertsText:SetText(L["ESCPANEL_NO_ALERTS"])
		noAlertsText:SetTextColor(unpack(DIM_COLOR()))
		panel.noAlertsText = noAlertsText

		panel.alertTexts = {}
		panel.alertIcons = {}
		for i = 1, 3 do
			local icon = panel:CreateTexture(nil, "ARTWORK")
			icon:SetSize(28, 28)
			icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -35 - (i-1) * 30)
			icon:Hide()
			panel.alertIcons[i] = icon

			local text = OneWoW_GUI:CreateFS(panel, 12)
			text:SetPoint("LEFT", icon, "RIGHT", 12, 0)
			text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
			text:Hide()
			panel.alertTexts[i] = text
		end

		panelFrames.alerts = panel
	end

	local panel = panelFrames.alerts
	panel:ClearAllPoints()
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -PANEL_GAP)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -PANEL_GAP)
	end
	panel:SetHeight(ALERTS_HEIGHT)

	local alertIndex = 1

	if HasNewMail and HasNewMail() then
		panel.alertIcons[alertIndex]:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
		panel.alertTexts[alertIndex]:SetText(string.format(L["ESCPANEL_MAIL_FORMAT"], 1))
		panel.alertIcons[alertIndex]:Show()
		panel.alertTexts[alertIndex]:Show()
		alertIndex = alertIndex + 1
	end

	for i = alertIndex, 3 do
		panel.alertIcons[i]:Hide()
		panel.alertTexts[i]:Hide()
	end

	if alertIndex == 1 then
		panel.noAlertsText:Show()
	else
		panel.noAlertsText:Hide()
	end

	panel:Show()
	return panel, yOffset - ALERTS_HEIGHT - PANEL_GAP
end

local function BuildZoneNotesPanel(container, yOffset, anchorPanel, flexHeight, hMode)
	local zoneName, zoneData = GetZoneNoteData()
	local displayZone = zoneName or (GetZoneText() or "")

	if not panelFrames.zoneNotes then
		local panel = CreatePanel(container, "OneWoWEscPanelZoneNotes", flexHeight)

		local header = OneWoW_GUI:CreateFS(panel, 16)
		header:SetPoint("TOP", panel, "TOP", 0, -PANEL_PADDING)
		header:SetTextColor(unpack(HEADER_COLOR()))
		panel.header = header

		panel.contentTexts = {}

		local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(panel, {})
		scrollFrame:ClearAllPoints()
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -35)
		scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 35)
		scrollChild:SetWidth(PANEL_WIDTH - 40)
		panel.scrollFrame = scrollFrame
		panel.scrollChild = scrollChild

		local actionBtn = OneWoW_GUI:CreateFitTextButton(panel, { text = L["ESCPANEL_MANAGE_ZONE"], height = 22, minWidth = 100 })
		actionBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
		actionBtn:SetScript("OnClick", function()
			local targetZone = panel.currentZoneName
			if GameMenuFrame and GameMenuFrame:IsShown() then
				HideUIPanel(GameMenuFrame)
			end
			C_Timer.After(0.15, function()
				if not targetZone or targetZone == "" then return end
				local notesAddon = _G.OneWoW_Notes
				if notesAddon and notesAddon.Zones then
					local existing = notesAddon.Zones:GetZone(targetZone)
					if not existing then
						local mapInfo = notesAddon.Zones.GetCurrentMapInfo and notesAddon.Zones:GetCurrentMapInfo() or nil
						local zoneData = { content = "", category = "General", storage = "account", pinColor = "sync", fontColor = "match" }
						if mapInfo then
							zoneData.mapID = mapInfo.mapID
							zoneData.mapType = mapInfo.mapType
							zoneData.parentMapID = mapInfo.parentMapID
						end
						notesAddon.Zones:AddZone(targetZone, zoneData)
					end
				end
				if OneWoW.GUI then
					OneWoW.GUI:Show("notes")
					C_Timer.After(0.1, function()
						OneWoW.GUI:SelectSubTab("notes", "zones")
						C_Timer.After(0.15, function()
							local zonesFrame = OneWoW.GUI:GetContentFrame("notes", "zones")
							if zonesFrame and zonesFrame.SelectZone then
								zonesFrame.SelectZone(targetZone)
							end
						end)
					end)
				end
			end)
		end)
		panel.actionBtn = actionBtn

		panelFrames.zoneNotes = panel
	end

	local panel = panelFrames.zoneNotes
	panel:ClearAllPoints()
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -PANEL_GAP)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -PANEL_GAP)
	end
	panel:SetHeight(flexHeight)
	panel.currentZoneName = zoneName

	if displayZone ~= "" then
		panel.header:SetText(L["ESCPANEL_ZONE_NOTES"] .. " - " .. displayZone)
	else
		panel.header:SetText(L["ESCPANEL_ZONE_NOTES"])
	end

	for _, fs in pairs(panel.contentTexts) do
		fs:Hide()
	end

	local contentY = -5
	local fsIndex = 1

	if zoneData then
		panel.actionBtn:SetFitText(L["ESCPANEL_MANAGE_ZONE"])

		if zoneData.content and zoneData.content ~= "" then
			if not panel.contentTexts[fsIndex] then
				local fs = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
				panel.contentTexts[fsIndex] = fs
			end
			local fs = panel.contentTexts[fsIndex]
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
			fs:SetWidth(PANEL_WIDTH - 50)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(true)
			fs:SetText(zoneData.content)
			fs:SetTextColor(unpack(TEXT_COLOR()))
			fs:Show()
			contentY = contentY - fs:GetStringHeight() - 8
			fsIndex = fsIndex + 1
		end

		if zoneData.todos and #zoneData.todos > 0 then
			local hasIncompleteTodos = false
			for _, todo in ipairs(zoneData.todos) do
				if not todo.completed then
					hasIncompleteTodos = true
					break
				end
			end

			if hasIncompleteTodos then
				if not panel.contentTexts[fsIndex] then
					local fs = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
					panel.contentTexts[fsIndex] = fs
				end
				local todosHeader = panel.contentTexts[fsIndex]
				todosHeader:ClearAllPoints()
				todosHeader:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
				todosHeader:SetText(L["ESCPANEL_ZONE_TODOS"])
				todosHeader:SetTextColor(unpack(HEADER_COLOR()))
				todosHeader:Show()
				contentY = contentY - 18
				fsIndex = fsIndex + 1

				for _, todo in ipairs(zoneData.todos) do
					if not todo.completed then
						if not panel.contentTexts[fsIndex] then
							local fs = OneWoW_GUI:CreateFS(panel.scrollChild, 10)
							panel.contentTexts[fsIndex] = fs
						end
						local fs = panel.contentTexts[fsIndex]
						fs:ClearAllPoints()
						fs:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, contentY)
						fs:SetWidth(PANEL_WIDTH - 60)
						fs:SetJustifyH("LEFT")
						fs:SetText("  - " .. todo.text)
						fs:SetTextColor(unpack(TEXT_COLOR()))
						fs:Show()
						contentY = contentY - 16
						fsIndex = fsIndex + 1
					end
				end
			end
		end
	else
		panel.actionBtn:SetFitText(L["ESCPANEL_ADD_ZONE_NOTE"])

		if not panel.contentTexts[1] then
			local fs = OneWoW_GUI:CreateFS(panel.scrollChild, 10)
			panel.contentTexts[1] = fs
		end
		local emptyText = panel.contentTexts[1]
		emptyText:ClearAllPoints()
		emptyText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, -5)
		emptyText:SetWidth(PANEL_WIDTH - 50)
		emptyText:SetJustifyH("LEFT")
		emptyText:SetText(L["ESCPANEL_NO_ZONE_NOTES"])
		emptyText:SetTextColor(unpack(DIM_COLOR()))
		emptyText:Show()
	end

	panel.scrollChild:SetHeight(math.abs(contentY) + 10)
	panel:Show()
	return panel, yOffset - flexHeight - PANEL_GAP
end

local function GetOrCreateFontString(panel, index, fontSize)
	if panel.contentTexts[index] then
		local fs = panel.contentTexts[index]
		fs:ClearAllPoints()
		fs:Show()
		return fs
	end
	local fs = OneWoW_GUI:CreateFS(panel.scrollChild, fontSize)
	panel.contentTexts[index] = fs
	return fs
end

local function UpdateNotesContent(panel, notesData, emptyKey)
	for _, text in pairs(panel.contentTexts) do
		text:Hide()
	end

	local yOff = -5
	local fsIndex = 1

	if not notesData or #notesData == 0 then
		local emptyText = GetOrCreateFontString(panel, fsIndex, 10)
		emptyText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 10, yOff)
		emptyText:SetText(L[emptyKey])
		emptyText:SetTextColor(unpack(DIM_COLOR()))
		emptyText:SetJustifyH("LEFT")
		emptyText:SetWidth(PANEL_WIDTH - 50)
		panel.scrollChild:SetHeight(30)
		return
	end

	for _, noteData in ipairs(notesData) do
		local tr, tg, tb
		local cr, cg, cb
		if noteData.pinColor then
			tr, tg, tb = GetNoteTextColor("match", noteData.pinColor)
			cr, cg, cb = GetNoteTextColor(noteData.fontColor or "match", noteData.pinColor)
		else
			local hc = HEADER_COLOR()
			tr, tg, tb = hc[1], hc[2], hc[3]
			local txc = TEXT_COLOR()
			cr, cg, cb = txc[1], txc[2], txc[3]
		end

		local titleText = GetOrCreateFontString(panel, fsIndex, 12)
		fsIndex = fsIndex + 1
		titleText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 10, yOff)
		titleText:SetText(noteData.title)
		titleText:SetTextColor(tr, tg, tb, 1)
		titleText:SetJustifyH("LEFT")
		titleText:SetWidth(PANEL_WIDTH - 50)
		yOff = yOff - 20

		if noteData.content then
			local contentText = GetOrCreateFontString(panel, fsIndex, 10)
			fsIndex = fsIndex + 1
			contentText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, yOff)
			contentText:SetText(noteData.content)
			contentText:SetTextColor(cr, cg, cb, 1)
			if noteData.fontSize then
				OneWoW_GUI:SafeSetFont(contentText, OneWoW_GUI:GetFont(), noteData.fontSize)
			end
			contentText:SetJustifyH("LEFT")
			contentText:SetWordWrap(true)
			contentText:SetWidth(PANEL_WIDTH - 55)
			yOff = yOff - contentText:GetStringHeight() - 6
		end

		if noteData.tasks then
			for _, task in ipairs(noteData.tasks) do
				local taskText = GetOrCreateFontString(panel, fsIndex, 10)
				fsIndex = fsIndex + 1
				taskText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 25, yOff)
				taskText:SetText("  - " .. task)
				taskText:SetTextColor(cr, cg, cb, 1)
				if noteData.fontSize then
					OneWoW_GUI:SafeSetFont(taskText, OneWoW_GUI:GetFont(), noteData.fontSize)
				end
				taskText:SetJustifyH("LEFT")
				taskText:SetWidth(PANEL_WIDTH - 65)
				yOff = yOff - 18
			end
		end

		yOff = yOff - 10
	end

	panel.scrollChild:SetHeight(math.abs(yOff) + 10)
end

local function BuildNotesPanel(container, yOffset, anchorPanel, panelKey, headerKey, emptyKey, noteType, flexHeight, prefetchedData, hMode)
	if not panelFrames[panelKey] then
		local panel = CreatePanel(container, "OneWoWEscPanel_" .. panelKey, flexHeight)
		CreateHeader(panel, headerKey)

		local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(panel, {})
		scrollFrame:ClearAllPoints()
		scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -35)
		scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 10)
		scrollChild:SetWidth(PANEL_WIDTH - 40)
		panel.scrollFrame = scrollFrame
		panel.scrollChild = scrollChild

		panel.contentTexts = {}

		panelFrames[panelKey] = panel
	end

	local panel = panelFrames[panelKey]
	panel:ClearAllPoints()
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -PANEL_GAP)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -PANEL_GAP)
	end
	panel:SetHeight(flexHeight)

	local notesData = prefetchedData or GetNotesByType(noteType)
	UpdateNotesContent(panel, notesData, emptyKey)

	panel:Show()
	return panel, yOffset - flexHeight - PANEL_GAP
end

local function BuildInstanceToastPanel(container, yOffset, anchorPanel, hMode)
	local instName, instanceType, diffID, diffName, _, _, _, instanceMapID = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then
		if panelFrames.instanceToast then
			panelFrames.instanceToast:Hide()
		end
		return anchorPanel, yOffset
	end

	if not panelFrames.instanceToast then
		local panel = CreatePanel(container, "OneWoWEscPanelInstance", 120)
		local header = CreateHeader(panel, "ESCPANEL_INSTANCE")
		panel.headerText = header

		local subtitle = OneWoW_GUI:CreateFS(panel, 12)
		subtitle:SetPoint("TOP", panel, "TOP", 0, -32)
		subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
		panel.subtitle = subtitle

		local statsText = OneWoW_GUI:CreateFS(panel, 12)
		statsText:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
		statsText:SetWidth(PANEL_WIDTH - 30)
		statsText:SetJustifyH("CENTER")
		statsText:SetWordWrap(true)
		statsText:SetSpacing(3)
		statsText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
		panel.statsText = statsText

		panelFrames.instanceToast = panel
	end

	local panel = panelFrames.instanceToast
	panel:ClearAllPoints()
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -PANEL_GAP)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -PANEL_GAP)
	end

	if instName and instName ~= "" then
		panel.headerText:SetText(instName)
	else
		panel.headerText:SetText(L["ESCPANEL_INSTANCE"])
	end

	local subtitleStr = ""
	if diffName and diffName ~= "" then
		subtitleStr = diffName
	end
	panel.subtitle:SetText(subtitleStr)

	local catalogData = GetCatalogData(instanceMapID)
	if catalogData then
		local statLines = {}
		local formatMap = {
			{key = "mounts",  fmt = "ESCPANEL_MOUNTS_FORMAT"},
			{key = "pets",    fmt = "ESCPANEL_PETS_FORMAT"},
			{key = "recipes", fmt = "ESCPANEL_RECIPES_FORMAT"},
			{key = "tmogs",   fmt = "ESCPANEL_TMOGS_FORMAT"},
			{key = "housing", fmt = "ESCPANEL_HOUSING_FORMAT"},
			{key = "toys",    fmt = "ESCPANEL_TOYS_FORMAT"},
		}
		for _, entry in ipairs(formatMap) do
			local data = catalogData[entry.key]
			if data and data.total > 0 then
				table.insert(statLines, string.format(L[entry.fmt], data.current, data.total))
			end
		end
		if #statLines > 0 then
			panel.statsText:SetText(table.concat(statLines, "\n"))
		else
			panel.statsText:SetText("")
		end
	else
		panel.statsText:SetText("")
	end

	local contentHeight = 50
	if panel.statsText:GetText() and panel.statsText:GetText() ~= "" then
		contentHeight = contentHeight + panel.statsText:GetStringHeight() + 15
	end
	local totalHeight = math.max(80, contentHeight)
	panel:SetHeight(totalHeight)

	panel:Show()
	return panel, yOffset - totalHeight - PANEL_GAP
end

function EscPanels:Build(parent)
	local ph = OneWoW.db and OneWoW.db.global and OneWoW.db.global.portalHub
	if not ph or not ph.escEnabled then
		self:HideAll()
		return
	end

	EnsureDimOverlay()
	EnsurePanelsContainer(ph)

	local hMode = GetPanelsHorizontalMode(ph)
	local showTasks = ph.escShowTasks ~= false
	local dailyNotes, weeklyNotes
	if showTasks then
		dailyNotes = GetNotesByType("daily")
		weeklyNotes = GetNotesByType("weekly")
	end
	local hasDaily = dailyNotes and #dailyNotes > 0
	local hasWeekly = weeklyNotes and #weeklyNotes > 0

	local hasAlerts = ph.escShowAlerts and (HasNewMail and HasNewMail())

	local _, zoneData = GetZoneNoteData()
	local zoneHasContent = zoneData and ((zoneData.content and zoneData.content ~= "") or (zoneData.todos and #zoneData.todos > 0))
	local showZone = ph.escShowZoneNotes and (not ph.escHideZoneNotesWhenEmpty or zoneHasContent)

	local flexHeight, verticalOffset = CalculateLayout(ph, showZone, hasDaily, hasWeekly, hasAlerts)
	local yOffset = -verticalOffset
	local lastPanel = panelsContainer

	local charPanel
	if ph.escShowCharacterInfo ~= false then
		charPanel, yOffset = BuildCharacterInfoPanel(panelsContainer, yOffset, hMode)
		lastPanel = charPanel
	elseif panelFrames.charInfo then
		panelFrames.charInfo:Hide()
	end

	local instPanel
	instPanel, yOffset = BuildInstanceToastPanel(panelsContainer, yOffset, lastPanel, hMode)
	lastPanel = instPanel

	if hasAlerts then
		local alertPanel
		alertPanel, yOffset = BuildAlertsPanel(panelsContainer, yOffset, lastPanel, hMode)
		lastPanel = alertPanel
	elseif panelFrames.alerts then
		panelFrames.alerts:Hide()
	end

	if showZone then
		local zonePanel
		zonePanel, yOffset = BuildZoneNotesPanel(panelsContainer, yOffset, lastPanel, flexHeight, hMode)
		lastPanel = zonePanel
	elseif panelFrames.zoneNotes then
		panelFrames.zoneNotes:Hide()
	end

	if showTasks then
		if hasDaily then
			local dailyPanel
			dailyPanel, yOffset = BuildNotesPanel(panelsContainer, yOffset, lastPanel, "daily", "ESCPANEL_DAILY_NOTES", "ESCPANEL_NO_DAILY", "daily", flexHeight, dailyNotes, hMode)
			lastPanel = dailyPanel
		elseif panelFrames.daily then
			panelFrames.daily:Hide()
		end

		if hasWeekly then
			local weeklyPanel
			weeklyPanel, yOffset = BuildNotesPanel(panelsContainer, yOffset, lastPanel, "weekly", "ESCPANEL_WEEKLY_NOTES", "ESCPANEL_NO_WEEKLY", "weekly", flexHeight, weeklyNotes, hMode)
			lastPanel = weeklyPanel
		elseif panelFrames.weekly then
			panelFrames.weekly:Hide()
		end
	else
		if panelFrames.daily then panelFrames.daily:Hide() end
		if panelFrames.weekly then panelFrames.weekly:Hide() end
	end

	if not self:HasVisiblePanelStack() then
		if panelsContainer then
			panelsContainer:Hide()
		end
	end
end

function EscPanels:HasVisiblePanelStack()
	for _, p in pairs(panelFrames) do
		if p and p.IsShown and p:IsShown() then
			return true
		end
	end
	return false
end

function EscPanels:SyncPanelsContainerPosition(ph)
	if not ph or not ph.escEnabled then return end
	if not panelsContainer or not panelsContainer:IsShown() then return end
	EnsurePanelsContainer(ph)
end

function EscPanels:HideAll()
	for _, panel in pairs(panelFrames) do
		if panel and panel.Hide then
			panel:Hide()
		end
	end
	if dimOverlay then dimOverlay:Hide() end
	if panelsContainer then panelsContainer:Hide() end
end
