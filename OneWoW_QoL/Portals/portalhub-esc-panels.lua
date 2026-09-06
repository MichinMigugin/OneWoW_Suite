local _, ns = ...

-- ============================================================================
-- ESC menu side panels
-- ============================================================================
-- Two cards beside GameMenuFrame: You (character + weekly stats) and Here
-- (this place: collections, source icons, zone notes). Theme / font
-- live through GetThemeColor and RegisterFontRoot.
-- ============================================================================

local OneWoW = OneWoW
local OneWoW_GUI = OneWoW_GUI
local C_Item = C_Item
local C_Map = C_Map
local C_Timer = C_Timer
local C_WeeklyRewards = C_WeeklyRewards
local C_PerksActivities = C_PerksActivities
local C_PerksProgram = C_PerksProgram
local C_NeighborhoodInitiative = C_NeighborhoodInitiative
local CreateFrame = CreateFrame
local ipairs, pairs, type = ipairs, pairs, type
local tinsert = tinsert

local L = ns.L
local CoreL = OneWoW.Locale:GetTable("OneWoW")
local NotesL = OneWoW.Locale:GetTable("OneWoW_Notes")

ns.EscPanels = ns.EscPanels or {}
local EscPanels = ns.EscPanels

local C = OneWoW_GUI.Constants
local GUI = C.GUI
local ICON_TEXTURES = C.ICON_TEXTURES

local PANEL_WIDTH = 350
EscPanels.PANEL_WIDTH = PANEL_WIDTH
local PANEL_GAP = 6
local PANEL_PADDING = GUI.PADDING
local ZONE_NOTES_HEADER_GAP = 8
local SCREEN_PAD = 10
local CHARINFO_MIN_HEIGHT = 240
local PORTRAIT_SIZE = 56
local CHIP_RESERVE = 78
local DURABILITY_ALERT_PCT = 25
local COLLECT_ROW_H = 22
local STAT_BAR_H = C.PROGRESS_BAR.HEIGHT
local VAULT_TRACK_GAP = 6
local LIST_HIT_TOOLTIP_MAX = 8
local ALERT_ICON_SIZE = 16
local ALERT_ICON_GAP = 4
local ALERT_ROW_H = 18
local ALERT_DIM_ALPHA = 0.16

local function HEADER_COLOR() return { OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY") } end
local function TEXT_COLOR() return { OneWoW_GUI:GetThemeColor("TEXT_PRIMARY") } end
local function DIM_COLOR() return { OneWoW_GUI:GetThemeColor("TEXT_MUTED") } end

local panelFrames = {}
local dimOverlay = nil
local panelsContainer = nil
local settingsWired = false

local BACKDROP_INFO = C.BACKDROP_SOFT

local COLLECT_DEFS = {
	{ key = "tmogs",   special = "TMog",    fmt = "ESCPANEL_TMOGS_FORMAT",   icon = "lootroll-icon-transmog", atlas = true },
	{ key = "mounts",  special = "Mount",   fmt = "ESCPANEL_MOUNTS_FORMAT",  icon = "icon-mount" },
	{ key = "pets",    special = "Pet",     fmt = "ESCPANEL_PETS_FORMAT",    icon = "icon-pet" },
	{ key = "toys",    special = "Toy",     fmt = "ESCPANEL_TOYS_FORMAT",    icon = "icon-toy" },
	{ key = "recipes", special = "Recipe",  fmt = "ESCPANEL_RECIPES_FORMAT", icon = "icon-recipe" },
	{ key = "housing", special = "Housing", fmt = "ESCPANEL_HOUSING_FORMAT", icon = "shop-icon-housing-beds-selected", atlas = true },
	{ key = "quests",  special = "Quest",   fmt = "ESCPANEL_QUESTS_FORMAT",  icon = "Quest-Campaign-Available", atlas = true },
}

-- ============================================================================
-- Data
-- ============================================================================

local function GetCharacterInfo()
	local name = UnitName("player")
	local realm = GetRealmName()
	local className, classFile = UnitClass("player")
	local faction = UnitFactionGroup("player")
	local guild, _, guildRank = GetGuildInfo("player")

	local _, itemLevelEquipped = GetAverageItemLevel()
	local specIndex = C_SpecializationInfo.GetSpecialization()
	local specName
	if specIndex then
		specName = select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex))
	end

	return {
		name = name,
		realm = realm,
		className = className,
		classFile = classFile,
		specName = specName,
		level = UnitLevel("player"),
		faction = faction,
		guild = guild,
		guildRank = guildRank,
		itemLevel = math.floor(itemLevelEquipped or 0),
		mythicPlusRating = C_ChallengeMode.GetOverallDungeonScore() or 0,
		money = GetMoney(),
	}
end

local function GetEquippedDurabilityPercent()
	local cur, max = 0, 0
	for slot = 1, 19 do
		local c, m = GetInventoryItemDurability(slot)
		if c and m and m > 0 then
			cur = cur + c
			max = max + m
		end
	end
	if max == 0 then
		return nil
	end
	return math.floor((cur / max) * 100 + 0.5)
end

local function CountVaultTrack(thresholdType)
	local activities = C_WeeklyRewards.GetActivities(thresholdType)
	if type(activities) ~= "table" or #activities == 0 then
		return 0, 0
	end
	local unlocked = 0
	local slots = #activities
	for i = 1, slots do
		local act = activities[i]
		local need = act.threshold or 0
		if need > 0 and (act.progress or 0) >= need then
			unlocked = unlocked + 1
		end
	end
	return unlocked, slots
end

local function GetVaultData()
	local thresholdEnum = Enum.WeeklyRewardChestThresholdType
	local raidU, raidS = CountVaultTrack(thresholdEnum.Raid)
	local dungU, dungS = CountVaultTrack(thresholdEnum.Activities)
	local worldU, worldS = CountVaultTrack(thresholdEnum.World)
	if raidS == 0 and dungS == 0 and worldS == 0 then
		return nil
	end
	return {
		ready = C_WeeklyRewards.HasAvailableRewards() and true or false,
		tracks = {
			{ name = RAID, current = raidU, maximum = raidS > 0 and raidS or 3 },
			{ name = DUNGEONS, current = dungU, maximum = dungS > 0 and dungS or 3 },
			{ name = WORLD, current = worldU, maximum = worldS > 0 and worldS or 3 },
		},
	}
end

local function GetTradingPostData()
	local info = C_PerksActivities.GetPerksActivitiesInfo()
	if not info then
		return nil
	end
	local points = 0
	local thresholdMax = 0
	local activities = info.activities
	if activities then
		for _, activity in pairs(activities) do
			if activity.completed then
				points = points + (activity.thresholdContributionAmount or 0)
			end
		end
	end
	local thresholds = info.thresholds
	if thresholds then
		for _, threshold in pairs(thresholds) do
			local need = threshold.requiredContributionAmount or 0
			if need > thresholdMax then
				thresholdMax = need
			end
		end
	end
	if thresholdMax == 0 then
		return nil
	end
	if points > thresholdMax then
		points = thresholdMax
	end
	local ready = false
	local pending = C_PerksProgram.GetPendingChestRewards()
	if pending then
		for _ in pairs(pending) do
			ready = true
			break
		end
	end
	return { points = points, maximum = thresholdMax, ready = ready }
end

local endeavorEvents
local skipEndeavorRequest = false

local function WireEndeavorEvents()
	if endeavorEvents then
		return
	end
	endeavorEvents = CreateFrame("Frame")
	endeavorEvents:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
	endeavorEvents:SetScript("OnEvent", function()
		if GameMenuFrame and GameMenuFrame:IsShown() then
			skipEndeavorRequest = true
			EscPanels:Build()
			skipEndeavorRequest = false
		end
	end)
end

local function GetEndeavorData()
	if not C_NeighborhoodInitiative.IsInitiativeEnabled() then
		return nil
	end
	if not C_NeighborhoodInitiative.PlayerHasInitiativeAccess() then
		return nil
	end
	if not C_NeighborhoodInitiative.PlayerMeetsRequiredLevel() then
		return nil
	end

	WireEndeavorEvents()
	if not skipEndeavorRequest then
		C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
	end

	local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
	if not info or not info.isLoaded or (info.initiativeID or 0) == 0 then
		return nil
	end

	local maximum = 0
	local milestones = info.milestones
	if milestones and #milestones > 0 then
		maximum = milestones[#milestones].requiredContributionAmount or 0
	end
	if maximum <= 0 then
		maximum = info.progressRequired or 0
	end
	if maximum <= 0 then
		return nil
	end

	local current = info.currentProgress or 0
	if current > maximum then
		current = maximum
	end
	return { current = current, maximum = maximum }
end

local function GetZoneNoteData()
	local zoneText = GetZoneText() or ""
	local subZoneText = GetSubZoneText() or ""
	if subZoneText == zoneText then
		subZoneText = ""
	end

	OneWoW:BringUp("OneWoW_Notes")
	local api = OneWoW_Notes_API
	local displayZone = zoneText ~= "" and zoneText or nil
	if not api then
		return nil, nil, displayZone
	end

	if api.GetCurrentZoneName then
		local currentName = api.GetCurrentZoneName()
		if currentName and currentName ~= "" then
			displayZone = currentName
		end
	end

	local matches = api.FindMatchingZoneNotes and api.FindMatchingZoneNotes(zoneText, subZoneText) or {}
	local first = matches[1]
	if first then
		return first.id, first.data, displayZone
	end
	return nil, nil, displayZone
end

local function PlaceTypeLabel(instData)
	local itype = instData and instData.instanceType
	if itype == "party" then
		return MAP_LEGEND_DUNGEON
	elseif itype == "raid" then
		return MAP_LEGEND_RAID
	elseif itype == "delve" then
		return MAP_LEGEND_DELVE
	elseif itype == "zone" then
		if instData.isCity then
			return L["ESCPANEL_CITY"]
		end
		return ZONE
	elseif itype == "world" then
		return WORLD
	end
	return L["ESCPANEL_INSTANCE"]
end

local function ResolveCurrentPlace()
	OneWoW:EnsureCatalogPack("items")
	OneWoW:EnsureCatalogPack("journal")
	local api = OneWoW:GetCatalogPackAPI("journal")
	if not api then
		return nil
	end

	local instName, instanceType, _, diffName, _, _, _, instanceMapID = GetInstanceInfo()
	local uiMapID = C_Map.GetBestMapForUnit("player")
	local instData
	if instanceMapID and instanceType and instanceType ~= "none" and api.GetInstanceByMapID then
		instData = api.GetInstanceByMapID(instanceMapID)
	end
	if not instData and uiMapID and api.GetZoneInstance then
		instData = api.GetZoneInstance(nil, uiMapID)
	end
	if not instData and instanceMapID and api.GetInstanceByMapID then
		instData = api.GetInstanceByMapID(instanceMapID)
	end
	if not instData then
		return nil
	end
	if api.EnsureEncounters then
		api.EnsureEncounters(instData)
	end

	return {
		data = instData,
		api = api,
		liveName = instName,
		instanceType = instanceType,
		diffName = diffName,
		mapID = instData.mapID or instData.uiMapID or uiMapID or instanceMapID,
	}
end

local function CountPlaceCollections(instData, api)
	local counts = {}
	for i = 1, #COLLECT_DEFS do
		counts[COLLECT_DEFS[i].key] = { current = 0, total = 0 }
	end
	local keyMap = {}
	for i = 1, #COLLECT_DEFS do
		keyMap[COLLECT_DEFS[i].special] = COLLECT_DEFS[i].key
	end

	for _, enc in ipairs(instData.encounters or {}) do
		for _, item in ipairs(enc.items or {}) do
			local key = keyMap[item.special]
			if key then
				local row = counts[key]
				row.total = row.total + 1
				if api.IsItemCollected(item.itemID, item.itemData, item.special) then
					row.current = row.current + 1
				end
			end
		end
	end
	return counts
end

local function MapParent(mapID)
	local info = C_Map.GetMapInfo(mapID)
	return info and info.parentMapID or nil
end

local function NpcOnPlaceMaps(npc, seeds)
	if not npc or not npc.locations then
		return false
	end
	local seedSet, seedParentSet = {}, {}
	for i = 1, #seeds do
		local id = seeds[i]
		if id then
			seedSet[id] = true
			local parent = MapParent(id)
			if parent then
				seedParentSet[parent] = true
			end
		end
	end
	for mapID in pairs(npc.locations) do
		if type(mapID) == "number" then
			if seedSet[mapID] or seedParentSet[mapID] then
				return true
			end
			local locParent = MapParent(mapID)
			if locParent and seedSet[locParent] then
				return true
			end
		end
	end
	return false
end

local function ItemDisplayName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if (not name or name == "") and OneWoW_Catalog_API then
		name = OneWoW_Catalog_API.GetCachedItemName(itemID)
	end
	if name and name ~= "" then
		return name
	end
	return "#" .. itemID
end

-- Shopping List items still needed that drop here or sit on an NPC in this map.
local function CollectPlaceListHits(place)
	local hits = {}
	OneWoW:BringUp("OneWoW_ShoppingList")
	local sl = OneWoW_ShoppingList_API
	if not sl then
		return hits
	end

	local seen = {}
	local function AddHit(itemID)
		itemID = tonumber(itemID)
		if not itemID or seen[itemID] or not sl.IsStillNeeded(itemID) then
			return
		end
		seen[itemID] = true
		local lists = {}
		local onList, listNames = sl.IsOnAnyList(itemID)
		if onList then
			lists = listNames
		end
		hits[#hits + 1] = { id = itemID, name = ItemDisplayName(itemID), lists = lists }
	end

	local instData = place and place.data
	if instData then
		for _, enc in ipairs(instData.encounters or {}) do
			for _, item in ipairs(enc.items or {}) do
				AddHit(item.itemID)
			end
		end
	end

	local needed = sl.GetStillNeededItemIDs()
	if #needed == 0 then
		return hits
	end

	if OneWoW:IsCatalogPackAvailable("vendors") then
		OneWoW:EnsureCatalogPack("vendors")
	end
	local npcAPI = OneWoW:GetCatalogPackAPI("vendors")
	if not npcAPI then
		return hits
	end

	local seeds = {}
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if uiMapID then
		seeds[#seeds + 1] = uiMapID
	end
	if place and place.mapID then
		seeds[#seeds + 1] = place.mapID
	end

	for i = 1, #needed do
		local itemID = needed[i]
		if not seen[itemID] then
			local npcs = npcAPI.GetNPCsByItem(itemID)
			for j = 1, #npcs do
				if NpcOnPlaceMaps(npcs[j], seeds) then
					AddHit(itemID)
					break
				end
			end
		end
	end
	return hits
end

local function NoteSnippet(text)
	if not text or text == "" then
		return ""
	end
	text = text:gsub("%s+", " ")
	if #text > 80 then
		return text:sub(1, 77) .. "..."
	end
	return text
end

local function CollectZoneNoteAlerts(matches)
	local hits = {}
	for i = 1, #(matches or {}) do
		local row = matches[i]
		local data = row and row.data
		if data then
			local hasBody = data.content and data.content ~= ""
			local todos = {}
			for _, todo in ipairs(data.todos or {}) do
				if not todo.completed and todo.text and todo.text ~= "" then
					todos[#todos + 1] = todo.text
				end
			end
			if hasBody or #todos > 0 then
				local title = data.zone or ""
				if data.subzone and data.subzone ~= "" then
					title = title .. " - " .. data.subzone
				end
				hits[#hits + 1] = {
					id = row.id,
					title = title,
					snippet = NoteSnippet(data.content),
					todos = todos,
				}
			end
		end
	end
	return hits
end

local function CollectFarmingNoteAlerts(place)
	local names = {}
	local zoneText = GetZoneText()
	if zoneText and zoneText ~= "" then
		names[#names + 1] = zoneText
	end
	local instName = GetInstanceInfo()
	if instName and instName ~= "" then
		names[#names + 1] = instName
	end
	if place and place.liveName and place.liveName ~= "" then
		names[#names + 1] = place.liveName
	end
	local instData = place and place.data
	if instData and instData.name and instData.name ~= "" then
		names[#names + 1] = instData.name
	end
	local api = OneWoW_Notes_API
	if not api or not api.FindFarmingNotesForPlace then
		return {}
	end
	local raw = api.FindFarmingNotesForPlace(names)
	local hits = {}
	for i = 1, #raw do
		local row = raw[i]
		hits[#hits + 1] = {
			id = row.id,
			title = row.title or "",
			itemName = row.itemName or "",
			snippet = NoteSnippet(row.content),
		}
	end
	return hits
end

local function CollectTrackerAlerts(place)
	if not OneWoW:IsAddonEnabled("OneWoW_Trackers") then
		return {}
	end
	OneWoW:BringUp("OneWoW_Trackers")
	local api = OneWoW_Trackers_API
	if not api or not api.GetIncompleteHitsForMap then
		return {}
	end
	local mapIDs = {}
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if uiMapID then
		mapIDs[#mapIDs + 1] = uiMapID
		local parent = MapParent(uiMapID)
		if parent then
			mapIDs[#mapIDs + 1] = parent
		end
	end
	if place and place.mapID then
		mapIDs[#mapIDs + 1] = place.mapID
	end
	return api.GetIncompleteHitsForMap(mapIDs)
end

local function CollectPlaceAlerts(place, zoneMatches)
	return {
		shopping = CollectPlaceListHits(place),
		notes = CollectZoneNoteAlerts(zoneMatches),
		farming = CollectFarmingNoteAlerts(place),
		trackers = CollectTrackerAlerts(place),
	}
end

local function AlertHasHits(hits)
	return hits and #hits > 0
end

-- ============================================================================
-- Chrome
-- ============================================================================

local function PaintPanel(panel, hover)
	if hover then
		panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
		panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
	else
		panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
		panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
	end
	if panel.accent then
		panel.accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
	end
end

local function CloseEscMenu()
	if GameMenuFrame and GameMenuFrame:IsShown() then
		HideUIPanel(GameMenuFrame)
	end
end

local function AttachCardClick(panel, tooltipKey, onClick)
	panel:RegisterForClicks("LeftButtonUp")
	panel:SetScript("OnClick", function()
		onClick(panel)
	end)
	panel:SetScript("OnEnter", function(myself)
		PaintPanel(myself, true)
		if myself.suppressCardTooltip then
			return
		end
		GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
		local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
		GameTooltip:SetText(L[tooltipKey], r, g, b)
		GameTooltip:Show()
	end)
	panel:SetScript("OnLeave", function(myself)
		PaintPanel(myself, false)
		if not myself.suppressCardTooltip then
			GameTooltip:Hide()
		end
	end)
end

local function CreatePanel(parent, name, height, asButton)
	local panel = CreateFrame(asButton and "Button" or "Frame", name, parent, "BackdropTemplate")
	panel:SetSize(PANEL_WIDTH, height)
	panel:SetBackdrop(BACKDROP_INFO)
	PaintPanel(panel, false)

	local accent = panel:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
	accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4)
	accent:SetWidth(3)
	accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
	panel.accent = accent
	return panel
end

local function AnchorBelow(panel, anchorPanel, hMode, gap)
	panel:ClearAllPoints()
	local y = gap or 0
	if hMode == "right" then
		panel:SetPoint("TOPLEFT", anchorPanel, "BOTTOMLEFT", 0, -y)
	else
		panel:SetPoint("TOPRIGHT", anchorPanel, "BOTTOMRIGHT", 0, -y)
	end
end

-- ============================================================================
-- Container
-- ============================================================================

local function EnsureDimOverlay()
	if not dimOverlay then
		dimOverlay = CreateFrame("Frame", "OneWoWEscDimOverlay", UIParent)
		dimOverlay:SetAllPoints(UIParent)
		dimOverlay:SetFrameStrata("DIALOG")
		dimOverlay:SetFrameLevel(0)

		local bg = dimOverlay:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		local r, g, b = unpack(C.OVERLAY_DIM)
		bg:SetColorTexture(r, g, b, 0.6)
	end
	dimOverlay:Show()
end

local function GetPanelsHorizontalMode(ph)
	if ph and ph.escPanelsSide == "right" then
		return "right"
	end
	return "left"
end

local MENU_PANEL_H_GAP = 20

function EscPanels:EnsurePanelsContainer(ph)
	if not panelsContainer then
		panelsContainer = CreateFrame("Frame", "OneWoWEscPanelsContainer", UIParent)
		panelsContainer:SetFrameStrata("FULLSCREEN_DIALOG")
		panelsContainer:SetFrameLevel(500)
		OneWoW_GUI:RegisterFontRoot(panelsContainer, function()
			if GameMenuFrame and GameMenuFrame:IsShown() then
				EscPanels:Build()
			end
		end)
	end

	panelsContainer:SetParent(UIParent)
	local gm = GameMenuFrame
	local mode = GetPanelsHorizontalMode(ph)
	panelsContainer:ClearAllPoints()
	panelsContainer:SetWidth(PANEL_WIDTH)

	if gm and gm:IsShown() then
		if mode == "right" then
			panelsContainer:SetPoint("TOPLEFT", gm, "TOPRIGHT", MENU_PANEL_H_GAP, 0)
			panelsContainer:SetPoint("BOTTOMLEFT", gm, "BOTTOMRIGHT", MENU_PANEL_H_GAP, 0)
		else
			panelsContainer:SetPoint("TOPRIGHT", gm, "TOPLEFT", -MENU_PANEL_H_GAP, 0)
			panelsContainer:SetPoint("BOTTOMRIGHT", gm, "BOTTOMLEFT", -MENU_PANEL_H_GAP, 0)
		end
	else
		local yTop = UIParent:GetHeight()
		local gmLeft = gm and gm.GetLeft and gm:GetLeft()
		local gmRight = gm and gm.GetRight and gm:GetRight()
		if mode == "right" then
			if gmRight then
				panelsContainer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", gmRight + MENU_PANEL_H_GAP, yTop)
			else
				panelsContainer:SetPoint("TOPLEFT", UIParent, "TOP", 200, 0)
			end
		elseif gmLeft then
			panelsContainer:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", gmLeft - MENU_PANEL_H_GAP, yTop)
		else
			panelsContainer:SetPoint("TOPRIGHT", UIParent, "TOP", -200, 0)
		end
		panelsContainer:SetHeight(UIParent:GetHeight())
	end

	panelsContainer:Show()
	return panelsContainer
end

function EscPanels:GetPanelsContainer()
	return panelsContainer
end

local function EnsureStackBase(container)
	if not container.stackBase then
		container.stackBase = CreateFrame("Frame", "OneWoWEscPanelsStackBase", container)
	end
	local f = container.stackBase
	f:ClearAllPoints()
	f:SetSize(PANEL_WIDTH, 1)
	f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
	f:Show()
	return f
end

-- ============================================================================
-- Character
-- ============================================================================

local function HideWeeklyLeftovers(panel)
	if panel.vaultText then
		panel.vaultText:Hide()
	end
	if panel.tradingText then
		panel.tradingText:Hide()
	end
end

local function EnsureWeeklyChrome(panel)
	if panel.vaultTracks then
		return
	end
	HideWeeklyLeftovers(panel)

	if not panel.vaultLabel then
		local vaultLabel = OneWoW_GUI:CreateFS(panel, 10)
		vaultLabel:SetJustifyH("LEFT")
		vaultLabel:SetWordWrap(false)
		vaultLabel:SetText(DELVES_GREAT_VAULT_LABEL)
		panel.vaultLabel = vaultLabel
	end

	local vaultReady = OneWoW_GUI:CreateFS(panel, 10)
	vaultReady:SetJustifyH("RIGHT")
	vaultReady:SetWordWrap(false)
	vaultReady:SetText(CLAIM_REWARD)
	panel.vaultReady = vaultReady

	panel.vaultTracks = {}
	for i = 1, 3 do
		local col = CreateFrame("Frame", nil, panel)
		col:EnableMouse(false)

		local label = OneWoW_GUI:CreateFS(col, 10)
		label:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
		label:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		col.label = label

		local bar = OneWoW_GUI:CreateProgressBar(col, { height = STAT_BAR_H, min = 0, max = 3, value = 0 })
		bar:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
		bar:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -3)
		bar:EnableMouse(false)
		col.bar = bar

		panel.vaultTracks[i] = col
	end

	if not panel.tradingLabel then
		local tradingLabel = OneWoW_GUI:CreateFS(panel, 10)
		tradingLabel:SetJustifyH("LEFT")
		tradingLabel:SetWordWrap(false)
		tradingLabel:SetText(MONTHLY_ACTIVITIES_POINTS)
		panel.tradingLabel = tradingLabel
	end

	local tradingReady = OneWoW_GUI:CreateFS(panel, 10)
	tradingReady:SetJustifyH("RIGHT")
	tradingReady:SetWordWrap(false)
	tradingReady:SetText(L["ESCPANEL_CACHE_AVAILABLE"])
	panel.tradingReady = tradingReady

	local tradingBar = OneWoW_GUI:CreateProgressBar(panel, { height = STAT_BAR_H, min = 0, max = 1, value = 0 })
	tradingBar:EnableMouse(false)
	panel.tradingBar = tradingBar
end

local function EnsureEndeavorChrome(panel)
	if panel.endeavorBar then
		return
	end

	local endeavorLabel = OneWoW_GUI:CreateFS(panel, 10)
	endeavorLabel:SetJustifyH("LEFT")
	endeavorLabel:SetWordWrap(false)
	endeavorLabel:SetText(HOUSING_DASHBOARD_ENDEAVOR)
	panel.endeavorLabel = endeavorLabel

	local endeavorBar = OneWoW_GUI:CreateProgressBar(panel, { height = STAT_BAR_H, min = 0, max = 1, value = 0 })
	endeavorBar:EnableMouse(false)
	panel.endeavorBar = endeavorBar
end

local function HideEndeavorChrome(panel)
	if panel.endeavorLabel then
		panel.endeavorLabel:Hide()
	end
	if panel.endeavorBar then
		panel.endeavorBar:Hide()
	end
end

local function LayoutSectionHeader(panel, label, readyFS, y, ready)
	label:ClearAllPoints()
	label:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
	if ready then
		readyFS:ClearAllPoints()
		readyFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
		readyFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
		readyFS:Show()
		label:SetPoint("TOPRIGHT", readyFS, "TOPLEFT", -6, 0)
	else
		readyFS:Hide()
		label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
	end
	label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
	label:Show()
	return y + (label:GetStringHeight() or 10) + 3
end

local function BuildCharacterInfoPanel(container, anchorPanel, hMode)
	if not panelFrames.charInfo then
		local panel = CreatePanel(container, "OneWoWEscPanelCharInfo", CHARINFO_MIN_HEIGHT, true)

		local chips = CreateFrame("Frame", nil, panel)
		chips:SetSize(CHIP_RESERVE, 36)
		chips:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
		chips:EnableMouse(false)
		panel.chips = chips

		local duraText = OneWoW_GUI:CreateFS(chips, 11)
		duraText:SetPoint("TOPRIGHT", chips, "TOPRIGHT", 0, 0)
		duraText:SetJustifyH("RIGHT")
		duraText:SetWordWrap(false)
		panel.duraText = duraText

		local mailIcon = chips:CreateTexture(nil, "ARTWORK")
		mailIcon:SetSize(16, 16)
		mailIcon:SetPoint("TOPRIGHT", duraText, "TOPLEFT", -6, 1)
		mailIcon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
		mailIcon:Hide()
		panel.mailIcon = mailIcon

		local portraitFrame = OneWoW_GUI:CreateFrame(panel, {
			width = PORTRAIT_SIZE + 8,
			height = PORTRAIT_SIZE + 8,
			backdrop = C.BACKDROP_INNER_NO_INSETS,
			bgColor = "BG_TERTIARY",
			borderColor = "BORDER_ACCENT",
		})
		portraitFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)
		portraitFrame:EnableMouse(false)
		panel.portraitFrame = portraitFrame

		local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
		portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
		panel.portrait = portrait

		local factionIcon = panel:CreateTexture(nil, "OVERLAY")
		factionIcon:SetSize(18, 18)
		factionIcon:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", 4, -4)
		panel.factionIcon = factionIcon

		local nameText = OneWoW_GUI:CreateFS(panel, 15)
		nameText:SetPoint("TOPLEFT", portraitFrame, "TOPRIGHT", 10, -2)
		nameText:SetPoint("TOPRIGHT", chips, "TOPLEFT", -8, -2)
		nameText:SetJustifyH("LEFT")
		nameText:SetWordWrap(false)
		panel.nameText = nameText

		local specText = OneWoW_GUI:CreateFS(panel, 11)
		specText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
		specText:SetPoint("TOPRIGHT", nameText, "BOTTOMRIGHT", 0, -4)
		specText:SetJustifyH("LEFT")
		specText:SetWordWrap(false)
		specText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
		panel.specText = specText

		local guildText = OneWoW_GUI:CreateFS(panel, 11)
		guildText:SetPoint("TOPLEFT", specText, "BOTTOMLEFT", 0, -3)
		guildText:SetPoint("TOPRIGHT", specText, "BOTTOMRIGHT", 0, -3)
		guildText:SetJustifyH("LEFT")
		guildText:SetWordWrap(false)
		guildText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
		panel.guildText = guildText

		local strip = OneWoW_GUI:CreateSummaryStrip(panel, {
			height = GUI.SUMMARY_STRIP_HEIGHT,
			insetX = PANEL_PADDING,
			yOffset = -(PANEL_PADDING + PORTRAIT_SIZE + 20),
			items = {
				{ value = "", label = STAT_AVERAGE_ITEM_LEVEL, valueColor = "TEXT_ACCENT" },
				{ value = "", label = DUNGEON_SCORE, valueColor = "TEXT_ACCENT" },
				{ value = "", label = MONEY, valueColor = "TEXT_ACCENT" },
			},
		})
		strip:EnableMouse(false)
		panel.statStrip = strip

		EnsureWeeklyChrome(panel)

		AttachCardClick(panel, "ESCPANEL_CLICK_CHARACTER", function()
			CloseEscMenu()
			C_Timer.After(0.1, function()
				ToggleCharacter("PaperDollFrame", true)
			end)
		end)

		panelFrames.charInfo = panel
	end

	local panel = panelFrames.charInfo
	AnchorBelow(panel, anchorPanel, hMode, 0)
	PaintPanel(panel, false)

	local char = GetCharacterInfo()
	SetPortraitTexture(panel.portrait, "player")

	local classColor = (char.classFile and RAID_CLASS_COLORS[char.classFile]) or { r = 1, g = 1, b = 1 }
	panel.portraitFrame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

	if char.faction == "Horde" then
		panel.factionIcon:SetTexture(ICON_TEXTURES.horde)
	elseif char.faction == "Alliance" then
		panel.factionIcon:SetTexture(ICON_TEXTURES.alliance)
	else
		panel.factionIcon:SetTexture(ICON_TEXTURES.neutral)
	end

	if HasNewMail() then
		panel.mailIcon:Show()
	else
		panel.mailIcon:Hide()
	end

	local duraPct = GetEquippedDurabilityPercent()
	if duraPct then
		panel.duraText:SetFormattedText("%d%%", duraPct)
		if duraPct <= DURABILITY_ALERT_PCT then
			panel.duraText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
		else
			panel.duraText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
		end
		panel.duraText:Show()
	else
		panel.duraText:Hide()
	end

	panel.nameText:SetFormattedText("%s-%s", char.name, char.realm)
	panel.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)

	local classPart = char.className or ""
	if char.specName and char.specName ~= "" then
		classPart = char.specName .. " " .. classPart
	end
	panel.specText:SetFormattedText(DUNGEON_SCORE_LINK_LEVEL_CLASS_FORMAT_STRING, char.level, classPart)
	panel.specText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

	if char.guild and char.guildRank then
		panel.guildText:SetFormattedText("<%s> - %s", char.guild, char.guildRank)
	elseif char.guild then
		panel.guildText:SetFormattedText("<%s>", char.guild)
	else
		panel.guildText:SetText(L["ESCPANEL_NO_GUILD"])
	end
	panel.guildText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

	panel.statStrip:SetItemValue(1, tostring(char.itemLevel))
	panel.statStrip:SetItemValue(2, tostring(char.mythicPlusRating))
	panel.statStrip:SetItemValue(3, OneWoW.Format.FormatGold(char.money))

	local identityH = math.max(
		PORTRAIT_SIZE + 8,
		(panel.nameText:GetStringHeight() or 16) + 4
			+ (panel.specText:GetStringHeight() or 12) + 3
			+ (panel.guildText:GetStringHeight() or 12)
	)
	local stripTop = PANEL_PADDING + identityH + 10
	panel.statStrip:ClearAllPoints()
	panel.statStrip:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, -stripTop)
	panel.statStrip:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -stripTop)
	if panel.statStrip._relayout then
		panel.statStrip._relayout()
	end
	local stripH = panel.statStrip.GetMeasuredHeight and panel.statStrip:GetMeasuredHeight() or GUI.SUMMARY_STRIP_HEIGHT
	local y = stripTop + stripH + 8

	EnsureWeeklyChrome(panel)
	HideWeeklyLeftovers(panel)

	local vaultData = GetVaultData()
	if vaultData then
		panel.vaultReady:SetText(CLAIM_REWARD)
		y = LayoutSectionHeader(panel, panel.vaultLabel, panel.vaultReady, y, vaultData.ready)
		local innerW = PANEL_WIDTH - 2 * (PANEL_PADDING + 4)
		local colW = (innerW - VAULT_TRACK_GAP * 2) / 3
		local colH = 0
		for i = 1, 3 do
			local col = panel.vaultTracks[i]
			local track = vaultData.tracks[i]
			col:ClearAllPoints()
			col:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4 + (i - 1) * (colW + VAULT_TRACK_GAP), -y)
			col:SetSize(colW, 28)
			col.label:SetText(track.name)
			col.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
			col.bar:UpdateProgress(track.current, track.maximum)
			col:Show()
			local labelH = col.label:GetStringHeight() or 10
			colH = math.max(colH, labelH + 3 + STAT_BAR_H)
		end
		for i = 1, 3 do
			panel.vaultTracks[i]:SetHeight(colH)
		end
		y = y + colH + 8
	else
		panel.vaultLabel:Hide()
		panel.vaultReady:Hide()
		for i = 1, #panel.vaultTracks do
			panel.vaultTracks[i]:Hide()
		end
	end

	local tradingData = GetTradingPostData()
	if tradingData then
		panel.tradingReady:SetText(L["ESCPANEL_CACHE_AVAILABLE"])
		y = LayoutSectionHeader(panel, panel.tradingLabel, panel.tradingReady, y, tradingData.ready)
		panel.tradingBar:ClearAllPoints()
		panel.tradingBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
		panel.tradingBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
		panel.tradingBar:UpdateProgress(tradingData.points, tradingData.maximum)
		panel.tradingBar:Show()
		y = y + STAT_BAR_H
	else
		panel.tradingLabel:Hide()
		panel.tradingReady:Hide()
		panel.tradingBar:Hide()
	end

	local ph = OneWoW:GetPortalHub()
	if ph.escShowEndeavors ~= false then
		EnsureEndeavorChrome(panel)
		local endeavorData = GetEndeavorData()
		if endeavorData then
			if tradingData then
				y = y + 8
			end
			panel.endeavorLabel:ClearAllPoints()
			panel.endeavorLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
			panel.endeavorLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
			panel.endeavorLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			panel.endeavorLabel:Show()
			y = y + (panel.endeavorLabel:GetStringHeight() or 10) + 3
			panel.endeavorBar:ClearAllPoints()
			panel.endeavorBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y)
			panel.endeavorBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y)
			panel.endeavorBar:UpdateProgress(endeavorData.current, endeavorData.maximum)
			panel.endeavorBar:Show()
			y = y + STAT_BAR_H
		else
			HideEndeavorChrome(panel)
		end
	else
		HideEndeavorChrome(panel)
	end

	panel:SetHeight(math.max(CHARINFO_MIN_HEIGHT, y + PANEL_PADDING))
	panel:Show()
	return panel
end

-- ============================================================================
-- Place (collections + lists + notes)
-- ============================================================================

local function AcquireCollectRow(panel, index)
	local row = panel.collectRows[index]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, panel)
	row:SetHeight(COLLECT_ROW_H)
	row:EnableMouse(false)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = icon

	local label = OneWoW_GUI:CreateFS(row, 11)
	label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	row.label = label

	local bar = OneWoW_GUI:CreateProgressBar(row, { height = 8, min = 0, max = 1, value = 0 })
	bar:SetPoint("LEFT", row, "LEFT", 150, 0)
	bar:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	if bar._text then
		bar._text:Hide()
	end
	bar:EnableMouse(false)
	row.bar = bar

	panel.collectRows[index] = row
	return row
end

local function ApplyCollectIcon(texture, def)
	if def.atlas then
		texture:SetTexture(nil)
		texture:SetAtlas(def.icon)
	else
		OneWoW.OverlayIcons:ApplyToTexture(texture, def.icon)
	end
end

local function OpenPlaceInCatalog(panel)
	local spec = panel.openSpec
	if not spec then
		return
	end
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:WithAddon("OneWoW_Catalog", function()
			OneWoW_Catalog_API.OpenToInstance(spec)
		end)
	end)
end

local function OpenShoppingList(listName)
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:BringUp("OneWoW_ShoppingList")
		local api = OneWoW_ShoppingList_API
		if api and api.ShowList then
			api.ShowList(listName)
		elseif api then
			api.Show()
		end
	end)
end

local function OpenAlertSource(sourceKey, payload)
	if sourceKey == "shopping" then
		local listName
		local items = payload or {}
		for i = 1, #items do
			local lists = items[i].lists
			if lists and lists[1] then
				listName = lists[1]
				break
			end
		end
		OpenShoppingList(listName)
		return
	end
	if sourceKey == "notes" then
		local first = payload and payload[1]
		if not first then
			return
		end
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Notes")
			if OneWoW_Notes_API then
				OneWoW_Notes_API.OpenZone(first.id)
			end
		end)
		return
	end
	if sourceKey == "farming" then
		local first = payload and payload[1]
		if not first then
			return
		end
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Notes")
			if OneWoW_Notes_API then
				OneWoW_Notes_API.OpenJournalNote(first.id)
			end
		end)
		return
	end
	if sourceKey == "trackers" then
		local first = payload and payload[1]
		if not first then
			return
		end
		CloseEscMenu()
		C_Timer.After(0.15, function()
			OneWoW:BringUp("OneWoW_Trackers")
			if OneWoW_Trackers_API then
				OneWoW_Trackers_API.ShowList(first.listID)
			end
		end)
	end
end

local function AlertSourceTitle(sourceKey)
	if sourceKey == "shopping" then
		return CoreL["MODULE_SHOPPINGLIST"]
	end
	if sourceKey == "notes" then
		return L["ESCPANEL_NOTES_HERE"]
	end
	if sourceKey == "trackers" then
		return CoreL["MODULE_TRACKERS"]
	end
	return NotesL["NOTE_TYPE_FARMING"]
end

local function ShowAlertTooltip(btn)
	GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
	local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
	local sr, sg, sb = OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
	local title = AlertSourceTitle(btn.sourceKey)
	GameTooltip:SetText(title, r, g, b)
	local hits = btn.hits
	if not hits or #hits == 0 then
		GameTooltip:AddLine(L["ESCPANEL_SOURCE_EMPTY"], sr, sg, sb, true)
		GameTooltip:Show()
		return
	end

	local shown = 0
	if btn.sourceKey == "shopping" then
		local listsSeen = {}
		for i = 1, #hits do
			for _, listName in ipairs(hits[i].lists or {}) do
				if listName ~= "" and not listsSeen[listName] then
					listsSeen[listName] = true
					GameTooltip:AddLine(listName, r, g, b)
				end
			end
		end
		for i = 1, #hits do
			if shown >= LIST_HIT_TOOLTIP_MAX then
				GameTooltip:AddLine(string.format(L["ESCPANEL_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
				break
			end
			GameTooltip:AddLine(hits[i].name, sr, sg, sb)
			shown = shown + 1
		end
	elseif btn.sourceKey == "notes" then
		for i = 1, #hits do
			if shown >= LIST_HIT_TOOLTIP_MAX then
				GameTooltip:AddLine(string.format(L["ESCPANEL_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
				break
			end
			local row = hits[i]
			GameTooltip:AddLine(row.title, r, g, b)
			if row.snippet ~= "" then
				GameTooltip:AddLine(row.snippet, sr, sg, sb, true)
			end
			for t = 1, #row.todos do
				GameTooltip:AddLine("  - " .. row.todos[t], sr, sg, sb)
			end
			shown = shown + 1
		end
	elseif btn.sourceKey == "farming" then
		for i = 1, #hits do
			if shown >= LIST_HIT_TOOLTIP_MAX then
				GameTooltip:AddLine(string.format(L["ESCPANEL_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
				break
			end
			local row = hits[i]
			GameTooltip:AddLine(row.title, r, g, b)
			if row.itemName ~= "" then
				GameTooltip:AddLine(row.itemName, sr, sg, sb)
			end
			if row.snippet ~= "" then
				GameTooltip:AddLine(row.snippet, sr, sg, sb, true)
			end
			shown = shown + 1
		end
	else
		for i = 1, #hits do
			if shown >= LIST_HIT_TOOLTIP_MAX then
				GameTooltip:AddLine(string.format(L["ESCPANEL_LISTS_MORE_FORMAT"], #hits - shown), sr, sg, sb)
				break
			end
			local row = hits[i]
			GameTooltip:AddLine(row.title, r, g, b)
			for s = 1, #row.steps do
				GameTooltip:AddLine(row.steps[s], sr, sg, sb)
			end
			shown = shown + 1
		end
	end
	GameTooltip:AddLine(string.format(L["ESCPANEL_CLICK_OPEN_FORMAT"], title), sr, sg, sb, true)
	GameTooltip:Show()
end

local ALERT_SOURCE_DEFS = {
	{ key = "shopping", icon = "Perks-ShoppingCart" },
	{ key = "notes", icon = "icon-pin" },
	{ key = "trackers", icon = "icon-flag" },
	{ key = "farming", icon = "bags-icon-reagents" },
}

local function EnsureAlertRow(panel)
	if panel.alertRow then
		return panel.alertRow
	end

	local row = CreateFrame("Frame", nil, panel)
	row:SetHeight(ALERT_ROW_H)
	row:EnableMouse(false)
	panel.alertRow = row

	local label = OneWoW_GUI:CreateFS(row, 11)
	label:SetPoint("LEFT", row, "LEFT", 0, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetText(L["ESCPANEL_ITEM_ALERT"] .. ":")
	row.label = label

	row.icons = {}
	for i = 1, #ALERT_SOURCE_DEFS do
		local def = ALERT_SOURCE_DEFS[i]
		local btn = CreateFrame("Button", nil, row)
		btn:SetSize(ALERT_ICON_SIZE, ALERT_ICON_SIZE)
		btn.sourceKey = def.key
		local tex = btn:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		OneWoW.OverlayIcons:ApplyToTexture(tex, def.icon)
		btn.icon = tex
		btn:SetScript("OnClick", function(myself)
			if not AlertHasHits(myself.hits) then
				return
			end
			OpenAlertSource(myself.sourceKey, myself.hits)
		end)
		btn:SetScript("OnEnter", function(myself)
			panel.suppressCardTooltip = true
			GameTooltip:Hide()
			ShowAlertTooltip(myself)
		end)
		btn:SetScript("OnLeave", function()
			panel.suppressCardTooltip = false
			GameTooltip:Hide()
		end)
		row.icons[def.key] = btn
	end
	return row
end

local function LayoutAlertRow(panel, alerts)
	local row = EnsureAlertRow(panel)
	row.label:SetText(L["ESCPANEL_ITEM_ALERT"] .. ":")
	row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
	local labelW = math.ceil(row.label:GetStringWidth() or 70)
	row.label:SetWidth(labelW)

	local x = labelW + 8
	for i = 1, #ALERT_SOURCE_DEFS do
		local def = ALERT_SOURCE_DEFS[i]
		local btn = row.icons[def.key]
		local hits = alerts[def.key]
		btn.hits = hits
		btn:ClearAllPoints()
		btn:SetPoint("LEFT", row, "LEFT", x, 0)
		if AlertHasHits(hits) then
			btn.icon:SetAlpha(1)
			btn.icon:SetVertexColor(1, 1, 1)
			btn:EnableMouse(true)
		else
			btn.icon:SetAlpha(ALERT_DIM_ALPHA)
			btn.icon:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			btn:EnableMouse(true)
		end
		btn:Show()
		x = x + ALERT_ICON_SIZE + ALERT_ICON_GAP
	end
	row:Show()
	return ALERT_ROW_H
end

local function OpenZoneNotesFromPanel(panel)
	local targetId = panel.currentNoteId
	CloseEscMenu()
	C_Timer.After(0.15, function()
		OneWoW:BringUp("OneWoW_Notes")
		local api = OneWoW_Notes_API
		if not api then return end
		if not targetId then
			local zone, subzone, mapInfo
			if api.GetCurrentZoneParts then
				zone, subzone, mapInfo = api.GetCurrentZoneParts()
			else
				zone = GetZoneText() or ""
				subzone = ""
				mapInfo = api.GetCurrentMapInfo and api.GetCurrentMapInfo() or nil
			end
			if not zone or zone == "" then return end
			targetId = api.AddZone({
				zone = zone,
				subzone = subzone or "",
				content = "",
				category = "General",
				storage = "account",
				mapID = mapInfo and mapInfo.mapID,
				parentMapID = mapInfo and mapInfo.parentMapID,
			})
		end
		if targetId then
			api.OpenZone(targetId)
		end
	end)
end

local function AcquireEscWaypinButton(panel, index)
	local btn = panel.waypinBtns[index]
	if btn then
		return btn
	end
	btn = CreateFrame("Button", nil, panel.scrollChild)
	btn:SetHeight(18)
	local fs = OneWoW_GUI:CreateFS(btn, 11)
	fs:SetAllPoints()
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	btn.label = fs
	btn:SetScript("OnClick", function(myself)
		if myself.pinID and OneWoW_Notes_API and OneWoW_Notes_API.TrackWayPin then
			OneWoW_Notes_API.TrackWayPin(myself.pinID)
		end
	end)
	btn:SetScript("OnEnter", function(myself)
		myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
	end)
	btn:SetScript("OnLeave", function(myself)
		myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
	end)
	panel.waypinBtns[index] = btn
	return btn
end

local function FillPlaceNotes(panel, zoneData, pins)
	for _, fs in pairs(panel.contentTexts) do
		fs:Hide()
	end
	for _, btn in ipairs(panel.waypinBtns) do
		btn:Hide()
	end

	local contentY = -5
	local fsIndex = 1

	if zoneData then
		panel.actionBtn:SetFitText(L["ESCPANEL_MANAGE_ZONE"])

		if zoneData.content and zoneData.content ~= "" then
			if not panel.contentTexts[fsIndex] then
				panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
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
					panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
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
							panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 10)
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

		if #pins == 0 then
			if not panel.contentTexts[1] then
				panel.contentTexts[1] = OneWoW_GUI:CreateFS(panel.scrollChild, 10)
			end
			local emptyText = panel.contentTexts[1]
			emptyText:ClearAllPoints()
			emptyText:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, -5)
			emptyText:SetWidth(PANEL_WIDTH - 50)
			emptyText:SetJustifyH("LEFT")
			emptyText:SetText(L["ESCPANEL_NO_ZONE_NOTES"])
			emptyText:SetTextColor(unpack(DIM_COLOR()))
			emptyText:Show()
			contentY = contentY - 24
			fsIndex = 2
		end
	end

	if #pins > 0 then
		if not panel.contentTexts[fsIndex] then
			panel.contentTexts[fsIndex] = OneWoW_GUI:CreateFS(panel.scrollChild, 12)
		end
		local pinsHeader = panel.contentTexts[fsIndex]
		pinsHeader:ClearAllPoints()
		pinsHeader:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 5, contentY)
		pinsHeader:SetText(L["ESCPANEL_WAYPINS"])
		pinsHeader:SetTextColor(unpack(HEADER_COLOR()))
		pinsHeader:Show()
		contentY = contentY - 18
		fsIndex = fsIndex + 1

		for i, pin in ipairs(pins) do
			local btn = AcquireEscWaypinButton(panel, i)
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 15, contentY)
			btn:SetPoint("TOPRIGHT", panel.scrollChild, "TOPRIGHT", -5, contentY)
			btn.pinID = pin.id
			btn.label:SetText(pin.title or "")
			btn.label:SetTextColor(unpack(TEXT_COLOR()))
			btn:Show()
			contentY = contentY - 18
		end
	end

	panel.scrollChild:SetHeight(math.abs(contentY) + 10)
end

local function BuildPlacePanel(container, anchorPanel, hMode, flexHeight, showNotes)
	local place = ResolveCurrentPlace()
	local noteId, zoneData, displayZone = GetZoneNoteData()
	displayZone = displayZone or (GetZoneText() or "")
	local mapID = C_Map.GetBestMapForUnit("player")
	local pins = (OneWoW_Notes_API and OneWoW_Notes_API.GetWayPinsForMap and mapID)
		and OneWoW_Notes_API.GetWayPinsForMap(mapID) or {}
	local zoneMatches = {}
	if OneWoW_Notes_API and OneWoW_Notes_API.FindMatchingZoneNotes then
		local zoneText = GetZoneText() or ""
		local subZoneText = GetSubZoneText() or ""
		if subZoneText == zoneText then
			subZoneText = ""
		end
		zoneMatches = OneWoW_Notes_API.FindMatchingZoneNotes(zoneText, subZoneText)
	end
	local alerts = CollectPlaceAlerts(place, zoneMatches)

	if not place and not showNotes and not AlertHasHits(alerts.shopping)
		and not AlertHasHits(alerts.notes) and not AlertHasHits(alerts.farming)
		and not AlertHasHits(alerts.trackers) then
		if panelFrames.place then
			panelFrames.place:Hide()
		end
		return nil
	end

	if not panelFrames.place then
		local panel = CreatePanel(container, "OneWoWEscPanelPlace", 140, true)

		local header = OneWoW_GUI:CreateFS(panel, 16)
		header:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -PANEL_PADDING)
		header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -PANEL_PADDING)
		header:SetJustifyH("LEFT")
		header:SetWordWrap(false)
		header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
		panel.headerText = header

		local meta = OneWoW_GUI:CreateFS(panel, 11)
		meta:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
		meta:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
		meta:SetJustifyH("LEFT")
		meta:SetWordWrap(false)
		meta:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
		panel.metaText = meta

		local counts = OneWoW_GUI:CreateFS(panel, 11)
		counts:SetJustifyH("LEFT")
		counts:SetWordWrap(true)
		counts:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.countsText = counts

		EnsureAlertRow(panel)

		local overall = OneWoW_GUI:CreateProgressBar(panel, { height = 10, min = 0, max = 1, value = 0 })
		overall:EnableMouse(false)
		panel.overallBar = overall

		local emptyText = OneWoW_GUI:CreateFS(panel, 11)
		emptyText:SetJustifyH("LEFT")
		emptyText:SetWordWrap(true)
		emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
		emptyText:Hide()
		panel.emptyText = emptyText

		panel.collectRows = {}

		local notesHeader = OneWoW_GUI:CreateFS(panel, 12)
		notesHeader:SetJustifyH("LEFT")
		notesHeader:SetWordWrap(false)
		notesHeader:SetText(L["ESCPANEL_ZONE_NOTES"])
		panel.notesHeader = notesHeader

		panel.contentTexts = {}
		panel.waypinBtns = {}

		local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(panel, {})
		scrollChild:SetWidth(PANEL_WIDTH - 40)
		panel.scrollFrame = scrollFrame
		panel.scrollChild = scrollChild

		local actionBtn = OneWoW_GUI:CreateFitTextButton(panel, { text = L["ESCPANEL_MANAGE_ZONE"], height = 22, minWidth = 100 })
		actionBtn:SetScript("OnClick", function()
			OpenZoneNotesFromPanel(panel)
		end)
		panel.actionBtn = actionBtn

		AttachCardClick(panel, "ESCPANEL_CLICK_CATALOG", OpenPlaceInCatalog)

		panelFrames.place = panel
	end

	local panel = panelFrames.place
	local attachGap = (anchorPanel and anchorPanel.GetHeight and anchorPanel:GetHeight() > 1) and PANEL_GAP or 0
	AnchorBelow(panel, anchorPanel, hMode, attachGap)
	PaintPanel(panel, false)
	panel.currentNoteId = noteId

	local instData = place and place.data
	local title
	if instData then
		title = instData.name
		if (not title or title == "") and place.liveName and place.liveName ~= "" then
			title = place.liveName
		end
	end
	if not title or title == "" then
		title = displayZone ~= "" and displayZone or L["ESCPANEL_INSTANCE"]
	end
	panel.headerText:SetText(title)
	panel.headerText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

	if instData then
		local metaParts = {}
		if instData.expansionName and instData.expansionName ~= "" then
			tinsert(metaParts, instData.expansionName)
		end
		tinsert(metaParts, PlaceTypeLabel(instData))
		if place.diffName and place.diffName ~= "" and place.instanceType ~= "none" then
			tinsert(metaParts, place.diffName)
		end
		panel.metaText:SetText(table.concat(metaParts, " | "))
		panel.metaText:Show()
	else
		panel.metaText:SetText("")
		panel.metaText:Hide()
	end
	panel.metaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

	if place then
		panel.openSpec = {
			mapID = place.mapID,
			instanceID = instData.instanceID,
			placeKey = instData.placeKey,
		}
	else
		panel.openSpec = nil
	end

	local y = PANEL_PADDING + (panel.headerText:GetStringHeight() or 16)
	if panel.metaText:IsShown() then
		y = y + 4 + (panel.metaText:GetStringHeight() or 12)
	end

	local collected, total = 0, 0
	local visible = {}
	if place and instData then
		local catalogData = CountPlaceCollections(instData, place.api)
		for i = 1, #COLLECT_DEFS do
			local def = COLLECT_DEFS[i]
			local row = catalogData[def.key]
			if row and row.total > 0 then
				collected = collected + row.current
				total = total + row.total
				tinsert(visible, { def = def, current = row.current, total = row.total })
			end
		end
	end

	local countParts = {}
	if instData then
		local bossCount = instData.bossCount or 0
		local rareCount = instData.rareCount or 0
		if bossCount > 0 then
			tinsert(countParts, string.format("%s %d", BOSSES, bossCount))
		end
		if rareCount > 0 then
			tinsert(countParts, string.format(L["ESCPANEL_RARES_FORMAT"], rareCount))
		end
		if total > 0 then
			tinsert(countParts, string.format(L["ESCPANEL_COLLECTED_FORMAT"], collected, total))
			local missing = total - collected
			if missing > 0 then
				tinsert(countParts, string.format(L["ESCPANEL_MISSING_FORMAT"], missing))
			end
		end
	end
	if #countParts > 0 then
		panel.countsText:ClearAllPoints()
		panel.countsText:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -y - 3)
		panel.countsText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -y - 3)
		panel.countsText:SetText(table.concat(countParts, " | "))
		panel.countsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
		panel.countsText:Show()
		y = y + 3 + (panel.countsText:GetStringHeight() or 12)
	else
		panel.countsText:Hide()
	end

	if panel.listsBtn then
		panel.listsBtn:Hide()
	end
	local alertRow = EnsureAlertRow(panel)
	alertRow:ClearAllPoints()
	alertRow:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 4))
	alertRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 4))
	y = y + 4 + LayoutAlertRow(panel, alerts)

	if total > 0 then
		panel.emptyText:Hide()
		panel.overallBar:Show()
		panel.overallBar:ClearAllPoints()
		panel.overallBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
		panel.overallBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
		panel.overallBar:UpdateProgress(collected, total)
		if panel.overallBar._text then
			panel.overallBar._text:SetText(string.format("%d/%d", collected, total))
			panel.overallBar._text:Show()
		end
		y = y + 8 + 10

		for i, entry in ipairs(visible) do
			local row = AcquireCollectRow(panel, i)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
			row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
			ApplyCollectIcon(row.icon, entry.def)
			row.label:SetFormattedText(L[entry.def.fmt], entry.current, entry.total)
			if entry.current >= entry.total then
				row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
			else
				row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
			end
			row.bar:UpdateProgress(entry.current, entry.total)
			row:Show()
			y = y + 8 + COLLECT_ROW_H
		end
		for i = #visible + 1, #panel.collectRows do
			panel.collectRows[i]:Hide()
		end
	else
		panel.overallBar:Hide()
		for i = 1, #panel.collectRows do
			panel.collectRows[i]:Hide()
		end
		if place then
			panel.emptyText:Show()
			panel.emptyText:ClearAllPoints()
			panel.emptyText:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -(y + 8))
			panel.emptyText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -(y + 8))
			panel.emptyText:SetText(L["ESCPANEL_NO_COLLECTIONS"])
			panel.emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
			y = y + 8 + (panel.emptyText:GetStringHeight() or 12)
		else
			panel.emptyText:Hide()
		end
	end

	local collectionsH = y + PANEL_PADDING
	if showNotes then
		local notesTop = collectionsH
		panel.notesHeader:ClearAllPoints()
		panel.notesHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING + 4, -notesTop)
		panel.notesHeader:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PANEL_PADDING, -notesTop)
		panel.notesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
		panel.notesHeader:Show()
		local notesHeaderH = panel.notesHeader:GetStringHeight() or 12
		local scrollTop = notesTop + notesHeaderH + ZONE_NOTES_HEADER_GAP
		panel.actionBtn:ClearAllPoints()
		panel.actionBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
		panel.actionBtn:Show()
		panel.scrollFrame:ClearAllPoints()
		panel.scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -scrollTop)
		panel.scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 35)
		panel.scrollFrame:Show()
		FillPlaceNotes(panel, zoneData, pins)

		local notesBlock = math.max(80, flexHeight or 80)
		panel:SetHeight(collectionsH + notesBlock)
	else
		panel.notesHeader:Hide()
		panel.scrollFrame:Hide()
		panel.actionBtn:Hide()
		panel:SetHeight(math.max(110, collectionsH))
	end

	panel:Show()
	return panel
end

-- ============================================================================
-- Build / hide
-- ============================================================================

local function WireSettings()
	if settingsWired then
		return
	end
	settingsWired = true
	OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", EscPanels, function()
		if GameMenuFrame and GameMenuFrame:IsShown() then
			EscPanels:Build()
		end
	end)
end

function EscPanels:Build()
	local ph = OneWoW:GetPortalHub()
	if not ph or not ph.escEnabled then
		self:HideAll()
		return
	end

	WireSettings()
	EnsureDimOverlay()
	local container = self:EnsurePanelsContainer(ph)
	local hMode = GetPanelsHorizontalMode(ph)

	local _, zoneData = GetZoneNoteData()
	local zoneHasContent = zoneData and ((zoneData.content and zoneData.content ~= "") or (zoneData.todos and #zoneData.todos > 0))
	local mapID = C_Map.GetBestMapForUnit("player")
	local pins = (OneWoW_Notes_API and OneWoW_Notes_API.GetWayPinsForMap and mapID)
		and OneWoW_Notes_API.GetWayPinsForMap(mapID) or {}
	local hasWayPins = #pins > 0
	local showNotes = ph.escShowZoneNotes and (not ph.escHideZoneNotesWhenEmpty or zoneHasContent or hasWayPins)

	local availH = container:GetHeight()
	if (not availH) or availH < 80 then
		availH = GameMenuFrame and GameMenuFrame.GetHeight and GameMenuFrame:GetHeight() or UIParent:GetHeight()
	end

	local lastPanel = EnsureStackBase(container)
	local usedHeight = 0
	local gapUsed = 0

	local function Consume(panel, gap)
		if not panel then
			return
		end
		if gap then
			gapUsed = gapUsed + PANEL_GAP
		end
		usedHeight = usedHeight + panel:GetHeight()
		lastPanel = panel
	end

	if ph.escShowCharacterInfo ~= false then
		Consume(BuildCharacterInfoPanel(container, lastPanel, hMode), false)
	elseif panelFrames.charInfo then
		panelFrames.charInfo:Hide()
	end

	local remain = availH - usedHeight - gapUsed - PANEL_GAP - SCREEN_PAD
	local flexHeight = math.max(80, math.min(300, math.floor(remain)))
	local placePanel = BuildPlacePanel(container, lastPanel, hMode, flexHeight, showNotes)
	if placePanel then
		local hadPrior = lastPanel and lastPanel.GetHeight and lastPanel:GetHeight() > 1
		Consume(placePanel, hadPrior)
	end

	if panelFrames.alerts then panelFrames.alerts:Hide() end
	if panelFrames.instanceToast then panelFrames.instanceToast:Hide() end
	if panelFrames.zoneNotes then panelFrames.zoneNotes:Hide() end
	if panelFrames.daily then panelFrames.daily:Hide() end
	if panelFrames.weekly then panelFrames.weekly:Hide() end

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
	self:EnsurePanelsContainer(ph)
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
