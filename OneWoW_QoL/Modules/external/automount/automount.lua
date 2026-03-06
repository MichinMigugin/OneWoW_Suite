-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/automount/automount.lua
local addonName, ns = ...

local AutoMountModule = {
    id          = "automount",
    title       = "AUTOMOUNT_TITLE",
    category    = "AUTOMATION",
    description = "AUTOMOUNT_DESC",
    version     = "1.1",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    _ticker     = nil,
    _eventFrame = nil,
}
local AM = AutoMountModule

local lastCombatTime          = 0
local lastCastingNonMountTime = 0
local lastCastingMountTime    = 0
local lastMountedTime         = 0
local lastMovingTime          = 0
local lastMapUpdate           = 0
local lastDismountTime        = 0
local dismountRemountDelay    = 15
local wasMounted              = false
local mountIdToSpellId        = {}
local isGathering             = false
local druidFlightPending      = nil

local SPEED_ADVFLYING = { advflying = 5, flying = 4, ground = 3, aquatic = 2, other = 1 }
local SPEED_FLYING    = { advflying = 4, flying = 5, ground = 3, aquatic = 2, other = 1 }
local SPEED_WATER     = { advflying = 2, flying = 4, ground = 3, aquatic = 5, other = 1 }
local SPEED_GROUND    = { advflying = 3, flying = 4, ground = 5, aquatic = 2, other = 1 }

local fastestMountIds = {}
local cachedMountIDs  = nil

local GATHERING_SPELL_IDS = {
    1239682,
    2575,   265837, 265839, 265841, 265843, 265845, 265847, 265849, 265851,
    309835, 366260, 423341, 471013,
    2366,   265819, 265821, 265823, 265825, 265827, 265829, 265834, 265835,
    309780, 366252, 441327, 471009,
}
local gatheringSpellSet = {}
for _, id in ipairs(GATHERING_SPELL_IDS) do
    gatheringSpellSet[id] = true
end

-- Preferences

local function GetPreferences()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then
        return {
            ground = "auto", flying = "auto", aquatic = "auto",
            groundEnabled = true, flyingEnabled = true, aquaticEnabled = true, druidEnabled = true, druidCancelTravelForm = false,
        }
    end
    local mods = addon.db.global.modules
    if not mods["automount"] then mods["automount"] = {} end
    if not mods["automount"].preferences then
        mods["automount"].preferences = { ground = "auto", flying = "auto", aquatic = "auto" }
    end
    local prefs = mods["automount"].preferences
    if prefs.ground         == nil then prefs.ground         = "auto" end
    if prefs.flying         == nil then prefs.flying         = "auto" end
    if prefs.aquatic        == nil then prefs.aquatic        = "auto" end
    if prefs.groundEnabled  == nil then prefs.groundEnabled  = true   end
    if prefs.flyingEnabled  == nil then prefs.flyingEnabled  = true   end
    if prefs.aquaticEnabled == nil then prefs.aquaticEnabled = true   end
    if prefs.druidEnabled   == nil then prefs.druidEnabled   = true   end
    if prefs.druidCancelTravelForm == nil then prefs.druidCancelTravelForm = false end
    return prefs
end

local function SavePreference(key, value)
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return end
    local mods = addon.db.global.modules
    if not mods["automount"] then mods["automount"] = {} end
    if not mods["automount"].preferences then
        mods["automount"].preferences = { ground = "auto", flying = "auto", aquatic = "auto" }
    end
    mods["automount"].preferences[key] = value
end

-- Mount helpers

local function InitializeMountData()
    cachedMountIDs = C_MountJournal.GetMountIDs()
    for _, mountId in pairs(cachedMountIDs) do
        local _, spellID = C_MountJournal.GetMountInfoByID(mountId)
        if spellID then
            mountIdToSpellId[spellID] = true
        end
    end
end

local function IsMountSpell(spellID)
    return spellID and mountIdToSpellId[spellID]
end

local function IsCastingNonMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))
    return spellID and not IsMountSpell(spellID)
end

local function IsCastingMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))
    return spellID and IsMountSpell(spellID)
end

local function IsCasting()
    local name = UnitCastingInfo("player")
    return name ~= nil
end

local function IsLootFrameOpened()
    return GetNumLootItems() > 0
end

local function WasCastingNonMount()
    return (GetTime() - lastCastingNonMountTime) <= 1.0
end

local lastBuffCheckTime   = 0
local lastBuffCheckResult = false

local function IsUsingSpecialBuff()
    local now = GetTime()
    if now - lastBuffCheckTime < 2.0 then return lastBuffCheckResult end
    lastBuffCheckTime   = now
    lastBuffCheckResult = false
    for i = 1, 40 do
        local buffData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not buffData then break end
        local icon = buffData.icon
        if icon == 774121 or icon == 134062 or icon == 132293 or
           icon == 132320 or icon == 266311 or icon == 132805 then
            lastBuffCheckResult = true
            return true
        end
    end
    return false
end

local function IsFeignDeath()
    if UnitIsFeignDeath("player") then return true end
    local mirrorTimer = GetMirrorTimerInfo(3)
    return mirrorTimer == "FEIGNDEATH"
end

local function IsShapeShifted()
    local shapeshiftForm = GetShapeshiftForm()
    if shapeshiftForm and tonumber(shapeshiftForm) > 0 then
        local _, class = UnitClass("player")
        return class == "SHAMAN"
    end
    return false
end

local function GetMountTypeInfo(mountTypeId)
    if mountTypeId == 230 or mountTypeId == 269 or mountTypeId == 284 then
        return "ground"
    elseif mountTypeId == 248 or mountTypeId == 247 then
        return "flying"
    elseif mountTypeId == 398 or mountTypeId == 402 or mountTypeId == 424 then
        return "advflying"
    elseif mountTypeId == 231 or mountTypeId == 232 or mountTypeId == 254 or
           mountTypeId == 407 or mountTypeId == 408 or mountTypeId == 412 or
           mountTypeId == 436 then
        return "aquatic"
    elseif mountTypeId == 241 then
        return "ground"
    else
        return "other"
    end
end

local function GetMountCategory(mountId)
    local _, _, _, _, mountTypeId = C_MountJournal.GetMountInfoExtraByID(mountId)
    if mountTypeId == 230 or mountTypeId == 269 or mountTypeId == 284 or mountTypeId == 241 then
        return "ground"
    elseif mountTypeId == 248 or mountTypeId == 247 then
        return "flying"
    elseif mountTypeId == 398 or mountTypeId == 402 or mountTypeId == 424 then
        return "flying"
    elseif mountTypeId == 231 or mountTypeId == 232 or mountTypeId == 254 or
           mountTypeId == 407 or mountTypeId == 408 or mountTypeId == 412 or
           mountTypeId == 436 then
        return "aquatic"
    else
        return "other"
    end
end

local function GetMountSpeed(mountId, isFlying, isAdvFlying, isInWater, prefs)
    local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(mountId)
    local _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)
    if not isUsable or not isCollected then return nil end

    local namedMountType = GetMountTypeInfo(mountType)
    local speed
    local preferredMount = nil

    if isInWater and prefs.aquatic and prefs.aquatic ~= "auto" then
        preferredMount = prefs.aquatic
    elseif (isFlying or isAdvFlying) and prefs.flying and prefs.flying ~= "auto" then
        preferredMount = prefs.flying
    elseif not isFlying and not isAdvFlying and not isInWater and prefs.ground and prefs.ground ~= "auto" then
        preferredMount = prefs.ground
    end

    if preferredMount and preferredMount == mountId then
        speed = 6
    elseif isAdvFlying then
        speed = SPEED_ADVFLYING[namedMountType]
    elseif isFlying then
        speed = SPEED_FLYING[namedMountType]
    elseif isInWater then
        speed = SPEED_WATER[namedMountType]
    else
        speed = SPEED_GROUND[namedMountType]
    end

    if preferredMount and preferredMount ~= "auto" and preferredMount ~= mountId then
        speed = nil
    end

    if isFavorite and speed ~= nil then
        speed = speed + 0.1
    end

    return speed
end

local function GetFastestMount()
    local isFlying    = IsFlyableArea()
    local isAdvFlying = (IsAdvancedFlyableArea and IsAdvancedFlyableArea()) or false
    local isInWater   = IsSwimming()
    local prefs       = GetPreferences()

    if isInWater and not prefs.aquaticEnabled then return {} end
    if (isFlying or isAdvFlying) and not prefs.flyingEnabled then return {} end
    if not isFlying and not isAdvFlying and not isInWater and not prefs.groundEnabled then return {} end

    wipe(fastestMountIds)
    local highestSpeed = nil

    local mountIDs = cachedMountIDs or C_MountJournal.GetMountIDs()
    for _, mountId in pairs(mountIDs) do
        local speed = GetMountSpeed(mountId, isFlying, isAdvFlying, isInWater, prefs)
        if speed then
            if highestSpeed == nil or speed >= highestSpeed then
                if highestSpeed and speed > highestSpeed then
                    wipe(fastestMountIds)
                end
                table.insert(fastestMountIds, mountId)
                highestSpeed = speed
            end
        end
    end

    return fastestMountIds
end

local function RemountAfterGather()
    if IsFlying() or IsMounted() or UnitIsDead("player")
       or UnitIsGhost("player") or C_PetBattles.IsInBattle()
       or UnitOnTaxi("player") or UnitAffectingCombat("player")
       or UnitInVehicle("player") or UnitUsingVehicle("player")
       or IsFalling() then
        return
    end

    local prefs = GetPreferences()
    local _, class = UnitClass("player")

    if class == "DRUID" and prefs.druidEnabled then
        return
    end

    local mounts = GetFastestMount()
    if #mounts > 0 then
        C_MountJournal.SummonByID(mounts[math.random(1, #mounts)])
    end
end

local function MountTheFastestMount()
    if IsFlying() or IsPlayerMoving() or IsIndoors()
       or IsMounted()
       or UnitIsDead("player") or UnitIsGhost("player")
       or C_PetBattles.IsInBattle() or UnitOnTaxi("player")
       or IsShapeShifted()
       or (LootFrame and LootFrame:IsVisible())
       or IsCasting() or IsLootFrameOpened()
       or (GetTime() - lastCombatTime) <= 1
       or UnitInVehicle("player") or UnitUsingVehicle("player")
       or WasCastingNonMount()
       or (GetTime() - lastCastingMountTime) <= 4
       or (CastingBarFrame and CastingBarFrame:IsVisible())
       or (GetTime() - lastMapUpdate) <= 1
       or UnitAffectingCombat("player")
       or (GetTime() - lastMountedTime) <= 1
       or (GetTime() - lastMovingTime) <= 0.4
       or IsUsingSpecialBuff()
       or IsFeignDeath()
       or IsFalling()
       or (GetTime() - lastDismountTime) <= dismountRemountDelay then
        return
    end

    local prefs = GetPreferences()
    local _, class = UnitClass("player")

    if class == "DRUID" then
        if GetShapeshiftForm() > 0 then return end
        if prefs.druidEnabled then return end
    end

    local mounts = GetFastestMount()
    if #mounts > 0 then
        C_MountJournal.SummonByID(mounts[math.random(1, #mounts)])
    end
end

local function CancelAutoMountingIfNeeded()
    if IsLootFrameOpened() and not IsFlying() and not IsMounted() then
        C_MountJournal.Dismiss()
    end
end

local function EvaluateDruidFlightForm()
    local prefs = GetPreferences()
    if not prefs.druidCancelTravelForm then
        druidFlightPending = nil
        return
    end
    local _, class = UnitClass("player")
    if class ~= "DRUID" then
        druidFlightPending = nil
        return
    end
    if not GetShapeshiftFormID or not IsFlyableArea or not CancelShapeshiftForm then return end
    local formID = GetShapeshiftFormID()
    if formID == 3 and IsFlyableArea() then
        if InCombatLockdown and InCombatLockdown() then
            druidFlightPending = true
            return
        end
        druidFlightPending = nil
        CancelShapeshiftForm()
    else
        druidFlightPending = nil
    end
end

function AutoMountModule:UpdateDruidFlightWatcher()
    if not self._eventFrame then return end
    self._eventFrame:UnregisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    self._eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    druidFlightPending = nil
    local prefs = GetPreferences()
    local _, class = UnitClass("player")
    if prefs.druidCancelTravelForm and class == "DRUID" then
        self._eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        EvaluateDruidFlightForm()
    end
end

function AutoMountModule:OnEnable()
    InitializeMountData()

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AutoMount")
        self._eventFrame:SetScript("OnEvent", function(frame, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                lastMapUpdate = GetTime()
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                local unit, _, spellID = ...
                if unit == "player" and gatheringSpellSet[spellID] then
                    isGathering = true
                end
            elseif event == "LOOT_CLOSED" then
                if isGathering then
                    isGathering = false
                    C_Timer.After(0.5, RemountAfterGather)
                end
            elseif event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
                EvaluateDruidFlightForm()
            elseif event == "PLAYER_REGEN_ENABLED" then
                if druidFlightPending then EvaluateDruidFlightForm() end
            end
        end)
    end

    self._eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self._eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self._eventFrame:RegisterEvent("LOOT_CLOSED")

    self:UpdateDruidFlightWatcher()

    if not self._ticker then
        self._ticker = C_Timer.NewTicker(0.5, function()
            local mountedNow = IsMounted()
            if wasMounted and not mountedNow then
                lastDismountTime = GetTime()
            end
            wasMounted = mountedNow

            if IsCastingNonMountSpell() then lastCastingNonMountTime = GetTime() end
            if IsMounted()              then lastMountedTime         = GetTime() end
            if IsPlayerMoving()         then lastMovingTime          = GetTime() end
            if IsCastingMountSpell()    then lastCastingMountTime    = GetTime() end
            if UnitAffectingCombat("player") then lastCombatTime     = GetTime() end

            CancelAutoMountingIfNeeded()
            if not mountedNow then
                MountTheFastestMount()
            end
        end)
    end
end

function AutoMountModule:OnDisable()
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    druidFlightPending = nil
end

function AutoMountModule:OnToggle(toggleId, value)
end

function AutoMountModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    local L = ns.L
    local T = ns.T

    local function ApplyToggleHover(btn)
        if btn.isActive then
            btn:SetBackdropBorderColor(T("BORDER_FOCUS"))
        else
            btn:SetBackdropColor(T("BTN_HOVER"))
            btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
            btn.text:SetTextColor(T("TEXT_SECONDARY"))
        end
    end

    local function ApplyToggleNormal(btn)
        if btn.isActive then
            btn:SetBackdropColor(T("BG_ACTIVE"))
            btn:SetBackdropBorderColor(T("BORDER_ACCENT"))
            btn.text:SetTextColor(T("TEXT_ACCENT"))
        else
            btn:SetBackdropColor(T("BTN_NORMAL"))
            btn:SetBackdropBorderColor(T("BTN_BORDER"))
            btn.text:SetTextColor(T("TEXT_MUTED"))
        end
    end

    -- Mount Preferences section header

    local prefsHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefsHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    prefsHeader:SetText(L["AUTOMOUNT_MOUNT_PREFS"])
    prefsHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - prefsHeader:GetStringHeight() - 8

    local prefsDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    prefsDivider:SetHeight(1)
    prefsDivider:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    prefsDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    prefsDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    -- Ground / Flying / Aquatic rows

    local mountTypes = {
        { key = "ground",  label = L["AUTOMOUNT_GROUND_LABEL"]  },
        { key = "flying",  label = L["AUTOMOUNT_FLYING_LABEL"]  },
        { key = "aquatic", label = L["AUTOMOUNT_AQUATIC_LABEL"] },
    }

    for _, mountInfo in ipairs(mountTypes) do
        local capturedKey   = mountInfo.key
        local catEnabledKey = capturedKey .. "Enabled"

        -- Label + On/Off on same row
        local label = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        label:SetText(mountInfo.label)

        local offBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_OFF"], 36, 20)
        offBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
        offBtn.isActive = false

        local onBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_ON"], 36, 20)
        onBtn:SetPoint("RIGHT", offBtn, "LEFT", -4, 0)
        onBtn.isActive = false

        onBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
        onBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
        onBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)
        offBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
        offBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
        offBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)

        yOffset = yOffset - 24

        -- Mount picker button
        local mountBtn = CreateFrame("Button", nil, detailScrollChild, "BackdropTemplate")
        mountBtn:SetSize(220, 30)
        mountBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        mountBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        mountBtn:SetBackdropColor(T("BG_SECONDARY"))
        mountBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        mountBtn.mountIcon = mountBtn:CreateTexture(nil, "ARTWORK")
        mountBtn.mountIcon:SetSize(22, 22)
        mountBtn.mountIcon:SetPoint("LEFT", mountBtn, "LEFT", 4, 0)

        mountBtn.mountText = mountBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mountBtn.mountText:SetPoint("LEFT", mountBtn.mountIcon, "RIGHT", 6, 0)
        mountBtn.mountText:SetPoint("RIGHT", mountBtn, "RIGHT", -6, 0)
        mountBtn.mountText:SetJustifyH("LEFT")

        mountBtn:SetScript("OnEnter", function(btn)
            btn:SetBackdropColor(T("BTN_HOVER"))
            btn:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["AUTOMOUNT_SELECT_TOOLTIP"])
            GameTooltip:AddLine(L["AUTOMOUNT_SELECT_TOOLTIP_DESC"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        mountBtn:SetScript("OnLeave", function(btn)
            btn:SetBackdropColor(T("BG_SECONDARY"))
            btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            GameTooltip:Hide()
        end)
        mountBtn:SetScript("OnClick", function()
            AM:ShowMountPicker(capturedKey, function()
                local prefs = GetPreferences()
                local sel   = prefs[capturedKey]
                if sel == "auto" or not sel then
                    mountBtn.mountIcon:SetTexture("Interface\\Icons\\achievement_guildperk_mountup")
                    mountBtn.mountText:SetText(L["AUTOMOUNT_RANDOM_FAVORITE"])
                else
                    local name, _, icon = C_MountJournal.GetMountInfoByID(sel)
                    if name then
                        mountBtn.mountIcon:SetTexture(icon)
                        mountBtn.mountText:SetText(name)
                    else
                        mountBtn.mountIcon:SetTexture("Interface\\Icons\\achievement_guildperk_mountup")
                        mountBtn.mountText:SetText(L["AUTOMOUNT_RANDOM_FAVORITE"])
                        SavePreference(capturedKey, "auto")
                    end
                end
            end)
        end)

        local function UpdateRow()
            local prefs      = GetPreferences()
            local catEnabled = prefs[catEnabledKey]
            local active     = isEnabled and catEnabled

            -- Toggle visual state
            if not isEnabled then
                onBtn.isActive  = false
                offBtn.isActive = false
                onBtn:EnableMouse(false)
                offBtn:EnableMouse(false)
                label:SetTextColor(T("TEXT_MUTED"))
            else
                onBtn:EnableMouse(true)
                offBtn:EnableMouse(true)
                label:SetTextColor(T("TEXT_PRIMARY"))
                if catEnabled then
                    onBtn.isActive  = true
                    offBtn.isActive = false
                else
                    onBtn.isActive  = false
                    offBtn.isActive = true
                end
            end
            ApplyToggleNormal(onBtn)
            ApplyToggleNormal(offBtn)

            -- Mount picker state
            local prefs2 = GetPreferences()
            local sel    = prefs2[capturedKey]
            if sel == "auto" or not sel then
                mountBtn.mountIcon:SetTexture("Interface\\Icons\\achievement_guildperk_mountup")
                mountBtn.mountText:SetText(L["AUTOMOUNT_RANDOM_FAVORITE"])
            else
                local name, _, icon = C_MountJournal.GetMountInfoByID(sel)
                if name then
                    mountBtn.mountIcon:SetTexture(icon)
                    mountBtn.mountText:SetText(name)
                else
                    mountBtn.mountIcon:SetTexture("Interface\\Icons\\achievement_guildperk_mountup")
                    mountBtn.mountText:SetText(L["AUTOMOUNT_RANDOM_FAVORITE"])
                    SavePreference(capturedKey, "auto")
                end
            end
            if active then
                mountBtn:EnableMouse(true)
                mountBtn.mountText:SetTextColor(T("TEXT_PRIMARY"))
            else
                mountBtn:EnableMouse(false)
                mountBtn.mountText:SetTextColor(T("TEXT_MUTED"))
            end
        end

        onBtn:SetScript("OnClick", function()
            SavePreference(catEnabledKey, true)
            UpdateRow()
        end)
        offBtn:SetScript("OnClick", function()
            SavePreference(catEnabledKey, false)
            UpdateRow()
        end)

        UpdateRow()
        yOffset = yOffset - 34 - 10
    end

    -- Druid section: only shown when player is a druid

    local _, playerClass = UnitClass("player")
    if playerClass ~= "DRUID" then
        return yOffset
    end

    yOffset = yOffset - 4

    local druidDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    druidDivider:SetHeight(1)
    druidDivider:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    druidDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local druidHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    druidHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    druidHeader:SetText(L["AUTOMOUNT_DRUID_SECTION"])
    druidHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - druidHeader:GetStringHeight() - 8

    local druidSectionDiv = detailScrollChild:CreateTexture(nil, "ARTWORK")
    druidSectionDiv:SetHeight(1)
    druidSectionDiv:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    druidSectionDiv:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidSectionDiv:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local druidLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    druidLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    druidLabel:SetText(L["AUTOMOUNT_DRUID_MODE_LABEL"])

    local druidOffBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_OFF"], 36, 20)
    druidOffBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidOffBtn.isActive = false

    local druidOnBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_ON"], 36, 20)
    druidOnBtn:SetPoint("RIGHT", druidOffBtn, "LEFT", -4, 0)
    druidOnBtn.isActive = false

    druidOnBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
    druidOnBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
    druidOnBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)
    druidOffBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
    druidOffBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
    druidOffBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)

    yOffset = yOffset - 24

    local druidDesc = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    druidDesc:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    druidDesc:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidDesc:SetJustifyH("LEFT")
    druidDesc:SetWordWrap(true)
    druidDesc:SetText(L["AUTOMOUNT_DRUID_MODE_DESC"])

    local function UpdateDruidRow()
        local prefs        = GetPreferences()
        local druidEnabled = prefs.druidEnabled

        if not isEnabled then
            druidOnBtn.isActive  = false
            druidOffBtn.isActive = false
            druidOnBtn:EnableMouse(false)
            druidOffBtn:EnableMouse(false)
            druidLabel:SetTextColor(T("TEXT_MUTED"))
            druidDesc:SetTextColor(T("TEXT_MUTED"))
        else
            druidOnBtn:EnableMouse(true)
            druidOffBtn:EnableMouse(true)
            druidLabel:SetTextColor(T("TEXT_PRIMARY"))
            druidDesc:SetTextColor(T("TEXT_MUTED"))
            if druidEnabled then
                druidOnBtn.isActive  = true
                druidOffBtn.isActive = false
            else
                druidOnBtn.isActive  = false
                druidOffBtn.isActive = true
            end
        end
        ApplyToggleNormal(druidOnBtn)
        ApplyToggleNormal(druidOffBtn)
    end

    druidOnBtn:SetScript("OnClick", function()
        SavePreference("druidEnabled", true)
        UpdateDruidRow()
    end)
    druidOffBtn:SetScript("OnClick", function()
        SavePreference("druidEnabled", false)
        UpdateDruidRow()
    end)

    UpdateDruidRow()
    yOffset = yOffset - druidDesc:GetStringHeight() - 10

    yOffset = yOffset - 4

    local cancelLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cancelLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    cancelLabel:SetText(L["AUTOMOUNT_DRUID_CANCEL_LABEL"])

    local cancelOffBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_OFF"], 36, 20)
    cancelOffBtn:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    cancelOffBtn.isActive = false

    local cancelOnBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOMOUNT_CAT_ON"], 36, 20)
    cancelOnBtn:SetPoint("RIGHT", cancelOffBtn, "LEFT", -4, 0)
    cancelOnBtn.isActive = false

    cancelOnBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
    cancelOnBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
    cancelOnBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)
    cancelOffBtn:HookScript("OnEnter",   function(self) ApplyToggleHover(self)  end)
    cancelOffBtn:HookScript("OnLeave",   function(self) ApplyToggleNormal(self) end)
    cancelOffBtn:HookScript("OnMouseUp", function(self) ApplyToggleNormal(self) end)

    yOffset = yOffset - 24

    local cancelDesc = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cancelDesc:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    cancelDesc:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    cancelDesc:SetJustifyH("LEFT")
    cancelDesc:SetWordWrap(true)
    cancelDesc:SetText(L["AUTOMOUNT_DRUID_CANCEL_DESC"])

    local function UpdateCancelRow()
        local prefs = GetPreferences()
        local cancelEnabled = prefs.druidCancelTravelForm

        if not isEnabled then
            cancelOnBtn.isActive  = false
            cancelOffBtn.isActive = false
            cancelOnBtn:EnableMouse(false)
            cancelOffBtn:EnableMouse(false)
            cancelLabel:SetTextColor(T("TEXT_MUTED"))
            cancelDesc:SetTextColor(T("TEXT_MUTED"))
        else
            cancelOnBtn:EnableMouse(true)
            cancelOffBtn:EnableMouse(true)
            cancelLabel:SetTextColor(T("TEXT_PRIMARY"))
            cancelDesc:SetTextColor(T("TEXT_MUTED"))
            if cancelEnabled then
                cancelOnBtn.isActive  = true
                cancelOffBtn.isActive = false
            else
                cancelOnBtn.isActive  = false
                cancelOffBtn.isActive = true
            end
        end
        ApplyToggleNormal(cancelOnBtn)
        ApplyToggleNormal(cancelOffBtn)
    end

    cancelOnBtn:SetScript("OnClick", function()
        SavePreference("druidCancelTravelForm", true)
        UpdateCancelRow()
        AM:UpdateDruidFlightWatcher()
    end)
    cancelOffBtn:SetScript("OnClick", function()
        SavePreference("druidCancelTravelForm", false)
        UpdateCancelRow()
        AM:UpdateDruidFlightWatcher()
    end)

    UpdateCancelRow()
    yOffset = yOffset - cancelDesc:GetStringHeight() - 10

    return yOffset
end

function AutoMountModule:ShowMountPicker(mountType, onSelect)
    local L = ns.L
    local T = ns.T

    local matchingMounts = {}
    local otherMounts    = {}

    for _, mountId in pairs(C_MountJournal.GetMountIDs()) do
        local name, _, icon, _, isUsable, _, isFavorite, isFactionSpecific, faction, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountId)
        if isCollected then
            local rightFaction = true
            if isFactionSpecific then
                local englishFaction = UnitFactionGroup("player")
                rightFaction = (englishFaction == "Alliance" and faction == 1)
                           or  (englishFaction == "Horde"    and faction == 0)
            end
            if rightFaction then
                local mountCategory = GetMountCategory(mountId)
                local mountData = { name = name, icon = icon, mountId = mountId, category = mountCategory }
                if mountCategory == mountType then
                    table.insert(matchingMounts, mountData)
                else
                    table.insert(otherMounts, mountData)
                end
            end
        end
    end

    table.sort(matchingMounts, function(a, b) return a.name < b.name end)
    table.sort(otherMounts,    function(a, b) return a.name < b.name end)

    local popup = AM._mountPickerFrame
    local isNew = not popup

    if isNew then
        popup = CreateFrame("Frame", "OneWoW_QoL_MountPickerPopup", UIParent, "BackdropTemplate")
        popup:SetSize(350, 450)
        popup:SetPoint("CENTER")
        popup:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        popup:SetBackdropColor(T("BG_PRIMARY"))
        popup:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        popup:SetFrameStrata("DIALOG")
        popup:SetToplevel(true)
        popup:SetMovable(true)
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", function(f) f:StartMoving() end)
        popup:SetScript("OnDragStop",  function(f) f:StopMovingOrSizing() end)
        tinsert(UISpecialFrames, "OneWoW_QoL_MountPickerPopup")

        local titleBar = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        titleBar:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -1)
        titleBar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -1)
        titleBar:SetHeight(28)
        titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        titleBar:SetBackdropColor(T("TITLEBAR_BG"))

        popup._titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        popup._titleFS:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
        popup._titleFS:SetTextColor(T("ACCENT_PRIMARY"))

        local headerDiv = popup:CreateTexture(nil, "ARTWORK")
        headerDiv:SetHeight(1)
        headerDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -29)
        headerDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -29)
        headerDiv:SetColorTexture(T("BORDER_SUBTLE"))

        local searchLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 15, -38)
        searchLabel:SetText(L["AUTOMOUNT_SEARCH"])
        searchLabel:SetTextColor(T("TEXT_SECONDARY"))

        popup._searchBox = CreateFrame("EditBox", nil, popup, "BackdropTemplate")
        popup._searchBox:SetPoint("TOPLEFT",  popup, "TOPLEFT",  15, -52)
        popup._searchBox:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -15, -52)
        popup._searchBox:SetHeight(24)
        popup._searchBox:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        popup._searchBox:SetBackdropColor(T("BG_SECONDARY"))
        popup._searchBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        popup._searchBox:SetFontObject(GameFontHighlight)
        popup._searchBox:SetTextInsets(6, 6, 0, 0)
        popup._searchBox:SetAutoFocus(false)
        popup._searchBox:SetMaxLetters(50)
        popup._searchBox:SetTextColor(T("TEXT_PRIMARY"))
        popup._searchBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
        popup._searchBox:SetScript("OnEditFocusGained", function(eb)
            eb:SetBackdropBorderColor(T("BORDER_ACCENT"))
        end)
        popup._searchBox:SetScript("OnEditFocusLost", function(eb)
            eb:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end)

        local scrollBarWidth = 10
        local contentWidth   = 350 - 24 - scrollBarWidth
        popup._contentWidth  = contentWidth

        local listContainer = CreateFrame("Frame", nil, popup)
        listContainer:SetPoint("TOPLEFT",     popup, "TOPLEFT",     12, -82)
        listContainer:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 48)

        popup._scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
        popup._scrollFrame:SetPoint("TOPLEFT",     listContainer, "TOPLEFT",     0, 0)
        popup._scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
        popup._scrollFrame:EnableMouseWheel(true)

        local scrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
        scrollTrack:SetPoint("TOPRIGHT",    listContainer, "TOPRIGHT",    -2, 0)
        scrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
        scrollTrack:SetWidth(8)
        scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

        local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
        scrollThumb:SetWidth(6)
        scrollThumb:SetHeight(30)
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
        scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

        popup._scrollChild = CreateFrame("Frame", nil, popup._scrollFrame)
        popup._scrollChild:SetWidth(contentWidth)
        popup._scrollChild:SetHeight(1)
        popup._scrollFrame:SetScrollChild(popup._scrollChild)

        local function UpdateScrollThumb()
            local scrollRange = popup._scrollFrame:GetVerticalScrollRange()
            local scroll      = popup._scrollFrame:GetVerticalScroll()
            local frameH      = popup._scrollFrame:GetHeight()
            local contentH    = popup._scrollChild:GetHeight()
            if scrollRange <= 0 or contentH <= 0 then
                scrollThumb:SetHeight(scrollTrack:GetHeight())
                scrollThumb:ClearAllPoints()
                scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
                return
            end
            local trackH    = scrollTrack:GetHeight()
            local thumbH    = math.max(20, (frameH / contentH) * trackH)
            scrollThumb:SetHeight(thumbH)
            local maxOffset = trackH - thumbH
            local pct       = scroll / scrollRange
            scrollThumb:ClearAllPoints()
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(pct * maxOffset))
        end
        popup._updateScrollThumb = UpdateScrollThumb

        popup._scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
            local current   = sf:GetVerticalScroll()
            local maxScroll = sf:GetVerticalScrollRange()
            if delta > 0 then
                sf:SetVerticalScroll(math.max(0, current - 40))
            else
                sf:SetVerticalScroll(math.min(maxScroll, current + 40))
            end
            UpdateScrollThumb()
        end)
        popup._scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
        popup._scrollFrame:HookScript("OnSizeChanged",   function() UpdateScrollThumb() end)

        scrollThumb:EnableMouse(true)
        scrollThumb:RegisterForDrag("LeftButton")
        scrollThumb:SetScript("OnDragStart", function(thumb)
            thumb.dragging        = true
            thumb.dragStartY      = select(2, GetCursorPosition()) / thumb:GetEffectiveScale()
            thumb.dragStartScroll = popup._scrollFrame:GetVerticalScroll()
        end)
        scrollThumb:SetScript("OnDragStop", function(thumb)
            thumb.dragging = false
        end)
        scrollThumb:SetScript("OnUpdate", function(thumb)
            if not thumb.dragging then return end
            local curY      = select(2, GetCursorPosition()) / thumb:GetEffectiveScale()
            local delta     = thumb.dragStartY - curY
            local trackH    = scrollTrack:GetHeight()
            local thumbH    = thumb:GetHeight()
            local maxOffset = trackH - thumbH
            if maxOffset <= 0 then return end
            local scrollRange = popup._scrollFrame:GetVerticalScrollRange()
            local newScroll   = thumb.dragStartScroll + (delta / maxOffset) * scrollRange
            popup._scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
            UpdateScrollThumb()
        end)

        local btnDiv = popup:CreateTexture(nil, "ARTWORK")
        btnDiv:SetHeight(1)
        btnDiv:SetPoint("BOTTOMLEFT",  popup, "BOTTOMLEFT",  1, 42)
        btnDiv:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -1, 42)
        btnDiv:SetColorTexture(T("BORDER_SUBTLE"))

        local closeBtn = ns.UI.CreateButton(nil, popup, L["AUTOMOUNT_CLOSE"], 120, 32)
        closeBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 6)
        closeBtn:SetScript("OnClick", function() popup:Hide() end)

        popup._mountButtons = {}
        AM._mountPickerFrame = popup
    end

    local displayType = mountType:gsub("^%l", string.upper)
    popup._titleFS:SetText(string.format(L["AUTOMOUNT_SELECT_TITLE"], displayType))
    popup._scrollFrame:SetVerticalScroll(0)

    local mountButtons = popup._mountButtons
    local scrollChild  = popup._scrollChild
    local contentWidth = popup._contentWidth
    local rowWidth     = contentWidth - 10

    local function CreateMountRow(mountData, isAuto)
        local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        btn:SetSize(rowWidth, 30)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(T("BG_SECONDARY"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local rowIcon = btn:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(22, 22)
        rowIcon:SetPoint("LEFT", btn, "LEFT", 4, 0)
        rowIcon:SetTexture(mountData.icon)

        local rowText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowText:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
        rowText:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        rowText:SetJustifyH("LEFT")
        rowText:SetText(mountData.name)
        rowText:SetTextColor(T("TEXT_PRIMARY"))

        btn:SetScript("OnEnter", function(b)
            b:SetBackdropColor(T("BTN_HOVER"))
            b:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        end)
        btn:SetScript("OnLeave", function(b)
            b:SetBackdropColor(T("BG_SECONDARY"))
            b:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end)
        btn:SetScript("OnClick", function()
            if isAuto then
                SavePreference(mountType, "auto")
            else
                SavePreference(mountType, mountData.mountId)
            end
            if onSelect then onSelect() end
            popup:Hide()
        end)

        return btn
    end

    local function UpdateMountList(searchText)
        for _, btn in ipairs(mountButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        wipe(mountButtons)

        local listY  = -5
        searchText   = searchText and searchText:lower() or ""

        local autoBtn = CreateMountRow({
            name = L["AUTOMOUNT_RANDOM_FAVORITE"],
            icon = "Interface\\Icons\\achievement_guildperk_mountup",
        }, true)
        autoBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, listY)
        autoBtn:Show()
        table.insert(mountButtons, autoBtn)
        listY = listY - 34

        local function AddIfMatches(mountData)
            if searchText == "" or mountData.name:lower():find(searchText, 1, true) then
                local btn = CreateMountRow(mountData, false)
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, listY)
                btn:Show()
                table.insert(mountButtons, btn)
                listY = listY - 34
            end
        end

        for _, mountData in ipairs(matchingMounts) do AddIfMatches(mountData) end
        for _, mountData in ipairs(otherMounts)    do AddIfMatches(mountData) end

        scrollChild:SetHeight(math.abs(listY) + 10)
        C_Timer.After(0.05, popup._updateScrollThumb)
    end

    popup._searchBox:SetScript("OnTextChanged", function(eb)
        UpdateMountList(eb:GetText())
    end)

    popup._searchBox:SetText("")
    UpdateMountList("")
    popup:Show()
    popup:Raise()
end

ns.AutoMountModule = AutoMountModule
