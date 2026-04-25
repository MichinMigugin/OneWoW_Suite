-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/automount/automount.lua
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local sort = sort
local tinsert = tinsert

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
    preview     = true,
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
local lastFishingTime         = 0
local wasMounted              = false
local mountIdToSpellId        = {}
local isGathering             = false
local mountFailedReason       = nil

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

local FISHING_SPELL_IDS = {
    131474, 131490, 131476, 7620, 7731, 7732,
    18248, 33095, 51294, 88868, 110410,
    158743, 377895, 1224771,
}
local fishingSpellSet = {}
for _, id in ipairs(FISHING_SPELL_IDS) do
    fishingSpellSet[id] = true
end

local function GetPreferences()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then
        return {
            ground = "auto", flying = "auto", aquatic = "auto",
            groundEnabled = true, flyingEnabled = true, aquaticEnabled = true, druidEnabled = true, druidCancelTravelForm = false,
            dismountDelay = 15, fishingDelay = 15, gatherRemountDelay = 0.5,
            dismountDisabled = false, fishingDisabled = false,
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
    if prefs.dismountDelay      == nil then prefs.dismountDelay      = 15  end
    if prefs.fishingDelay       == nil then prefs.fishingDelay       = 15  end
    if prefs.gatherRemountDelay == nil then prefs.gatherRemountDelay = 0.5 end
    if prefs.dismountDisabled   == nil then prefs.dismountDisabled   = false end
    if prefs.fishingDisabled    == nil then prefs.fishingDisabled    = false end
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

local function updateMountFailedReason(reason, ret)
    if ret then
        if mountFailedReason == nil then
            mountFailedReason = reason
        else
            mountFailedReason = mountFailedReason .. "|" .. reason
        end
    end
    return ret
end

local function IsCastingNonMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))
    return spellID and not IsMountSpell(spellID)
end

local function IsCastingMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))
    return IsMountSpell(spellID)
end

local function IsCasting()
    local name = UnitCastingInfo("player")
    if name == nil then
        name = UnitChannelInfo("player")
    end
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
        if not OneWoW_GUI:IsSecret(icon) then
            if icon == 774121 or icon == 134062 or icon == 132293 or
               icon == 132320 or icon == 266311 or icon == 132805 or
               icon == 136074 then
                lastBuffCheckResult = true
                return true
            end
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
    if (isFlying or isAdvFlying) and not isInWater and not prefs.flyingEnabled then return {} end
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
                tinsert(fastestMountIds, mountId)
                highestSpeed = speed
            end
        end
    end

    return fastestMountIds
end

local function CanMount(opts)
    mountFailedReason = nil
    opts = opts or {}
    local blocked = false
    local now = GetTime()
    local prefs = GetPreferences()

    if updateMountFailedReason("IsFlying", IsFlying()) then blocked = true end
    if updateMountFailedReason("IsIndoors", IsIndoors()) then blocked = true end
    if updateMountFailedReason("IsMounted", IsMounted()) then blocked = true end
    if updateMountFailedReason("IsDead", UnitIsDead("player")) then blocked = true end
    if updateMountFailedReason("IsGhost", UnitIsGhost("player")) then blocked = true end
    if updateMountFailedReason("PetBattle", C_PetBattles.IsInBattle()) then blocked = true end
    if updateMountFailedReason("OnTaxi", UnitOnTaxi("player")) then blocked = true end
    if updateMountFailedReason("IsCasting", IsCasting()) then blocked = true end
    if updateMountFailedReason("InVehicle", UnitInVehicle("player")) then blocked = true end
    if updateMountFailedReason("UsingVehicle", UnitUsingVehicle("player")) then blocked = true end
    if updateMountFailedReason("InCombat", UnitAffectingCombat("player")) then blocked = true end
    if updateMountFailedReason("SpecialBuff", IsUsingSpecialBuff()) then blocked = true end
    if updateMountFailedReason("FeignDeath", IsFeignDeath()) then blocked = true end
    if updateMountFailedReason("IsFalling", IsFalling()) then blocked = true end

    if not opts.isGather then
        if updateMountFailedReason("IsMoving", IsPlayerMoving()) then blocked = true end
        if updateMountFailedReason("ShapeShifted", IsShapeShifted()) then blocked = true end
        if updateMountFailedReason("LootVisible", LootFrame and LootFrame:IsVisible()) then blocked = true end
        if updateMountFailedReason("LootOpen", IsLootFrameOpened()) then blocked = true end
        if updateMountFailedReason("CombatCooldown", (now - lastCombatTime) <= 1) then blocked = true end
        if updateMountFailedReason("CastingNonMount", WasCastingNonMount()) then blocked = true end
        if updateMountFailedReason("MountCastCooldown", (now - lastCastingMountTime) <= 4) then blocked = true end
        if updateMountFailedReason("CastBarVisible", CastingBarFrame and CastingBarFrame:IsVisible()) then blocked = true end
        if updateMountFailedReason("MapUpdate", (now - lastMapUpdate) <= 1) then blocked = true end
        if updateMountFailedReason("MountedCooldown", (now - lastMountedTime) <= 1) then blocked = true end
        if updateMountFailedReason("MovingCooldown", (now - lastMovingTime) <= 0.4) then blocked = true end
        if lastFishingTime > lastDismountTime and not prefs.fishingDisabled then
            if updateMountFailedReason("FishingCooldown", (now - lastFishingTime) <= prefs.fishingDelay) then blocked = true end
        else
            if prefs.dismountDisabled then
                if updateMountFailedReason("DismountDisabled", true) then blocked = true end
            else
                local delayStart = prefs.fishingDisabled and math.max(lastDismountTime, lastFishingTime) or lastDismountTime
                if updateMountFailedReason("DismountDelay", (now - delayStart) <= prefs.dismountDelay) then blocked = true end
            end
        end
    end

    local _, class = UnitClass("player")
    if class == "DRUID" then
        if updateMountFailedReason("DruidEnabled", prefs.druidEnabled) then blocked = true end
        if not opts.isGather then
            if updateMountFailedReason("DruidForm", GetShapeshiftForm() > 0) then blocked = true end
        end
    end

    return not blocked
end

local function TryMount(isGather)
    if not ns.ModuleRegistry:IsEnabled(AM.id) then return end
    if not CanMount(isGather and { isGather = true } or nil) then return end
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
    if
        GetPreferences().druidCancelTravelForm and UnitClassBase("player") == "DRUID" and
        GetShapeshiftFormID() == 3 and
        IsFlyableArea() and not IsFlying() and not IsSubmerged() and
        not UnitAffectingCombat("player") and
        not C_ChallengeMode.IsChallengeModeActive() and
        not IsInInstance()
    then
        CancelShapeshiftForm()
    end
end

function AutoMountModule:UpdateDruidFlightWatcher()
    if not self._eventFrame then return end

    if GetPreferences().druidCancelTravelForm and UnitClassBase("player") == "DRUID" then
        self._eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
        self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        EvaluateDruidFlightForm()
    else
        self._eventFrame:UnregisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
        self._eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local TICK_INTERVAL = 0.5

local function ShouldAutoMountPoll()
    local prefs = GetPreferences()
    local anyEnabled = prefs.groundEnabled or prefs.flyingEnabled or prefs.aquaticEnabled
    if not anyEnabled then return false end
    local _, class = UnitClass("player")
    if class == "DRUID" and prefs.druidEnabled then return false end
    return true
end

function AutoMountModule:UpdatePollingState()
    if not ns.ModuleRegistry:IsEnabled(self.id) then
        if self._ticker then
            self._ticker:Cancel()
            self._ticker = nil
        end
        return
    end
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(TICK_INTERVAL, function()
            if not ns.ModuleRegistry:IsEnabled(AM.id) then return end
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
                if ShouldAutoMountPoll() then
                    TryMount(false)
                else
                    CanMount()
                end
            end
        end)
    end
end

function AutoMountModule:OnEnable()
    InitializeMountData()

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AutoMount")
        self._eventFrame:SetScript("OnEvent", function(frame, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                lastMapUpdate = GetTime()
                AM:UpdatePollingState()
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                local unit, _, spellID = ...
                if unit == "player" and gatheringSpellSet[spellID] then
                    isGathering = true
                end
            elseif event == "LOOT_CLOSED" then
                if isGathering then
                    isGathering = false
                    C_Timer.After(GetPreferences().gatherRemountDelay, function() TryMount(true) end)
                end
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                local unit, _, spellID = ...
                if unit == "player" and fishingSpellSet[spellID] then
                    lastFishingTime = GetTime()
                end
            elseif event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
                EvaluateDruidFlightForm()
            elseif event == "PLAYER_REGEN_ENABLED" then
                C_Timer.After(0.2, EvaluateDruidFlightForm)
            end
        end)
    end

    self._eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self._eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self._eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self._eventFrame:RegisterEvent("LOOT_CLOSED")

    if self._mountStatusLabel then
        self._mountStatusLabel:Show()
    end

    self:UpdateDruidFlightWatcher()
    self:UpdatePollingState()
end

function AutoMountModule:OnDisable()
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    if self._mountStatusLabel then
        self._mountStatusLabel:Hide()
    end
end

function AutoMountModule:OnToggle(toggleId, value)
end

function AutoMountModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh, rightStatusBar)
    local L = ns.L

    if rightStatusBar then
        if not AM._mountStatusLabel then
            local statusBtn = CreateFrame("Button", nil, rightStatusBar)
            statusBtn:SetHeight(25)
            statusBtn:SetPoint("RIGHT", rightStatusBar, "RIGHT", -10, 0)

            local statusText = statusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusText:SetPoint("RIGHT", statusBtn, "RIGHT", 0, 0)
            statusText:SetText(L["AUTOMOUNT_STATUS_LABEL"])
            statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            statusBtn:SetWidth(statusText:GetStringWidth() + 4)

            statusBtn:SetScript("OnEnter", function(self)
                statusText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["AUTOMOUNT_STATUS_LABEL"], 1, 1, 1)
                if not ns.ModuleRegistry:IsEnabled(AM.id) then
                    GameTooltip:AddLine(L["AUTOMOUNT_STATUS_DISABLED"], 0.6, 0.6, 0.6, true)
                elseif mountFailedReason then
                    local reasons = { strsplit("|", mountFailedReason) }
                    for _, reason in ipairs(reasons) do
                        GameTooltip:AddLine(reason, 1, 0.5, 0.5)
                    end
                elseif IsMounted() then
                    GameTooltip:AddLine(L["AUTOMOUNT_STATUS_MOUNTED"], 0.5, 1, 0.5)
                else
                    GameTooltip:AddLine(L["AUTOMOUNT_STATUS_READY"], 0.5, 1, 0.5)
                end
                GameTooltip:Show()
            end)
            statusBtn:SetScript("OnLeave", function()
                statusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                GameTooltip:Hide()
            end)

            AM._mountStatusLabel = statusBtn
        end
        AM._mountStatusLabel:SetParent(rightStatusBar)
        AM._mountStatusLabel:ClearAllPoints()
        AM._mountStatusLabel:SetPoint("RIGHT", rightStatusBar, "RIGHT", -10, 0)
        AM._mountStatusLabel:Show()
    end

    local prefsHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prefsHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    prefsHeader:SetText(L["AUTOMOUNT_MOUNT_PREFS"])
    prefsHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - prefsHeader:GetStringHeight() - 8

    local prefsDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    prefsDivider:SetHeight(1)
    prefsDivider:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    prefsDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    prefsDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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
        local UpdateRow
        local mountBtnRef   = {}
        local rowRefresh

        local prefs = GetPreferences()
        yOffset, rowRefresh, _ = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
            yOffset = yOffset,
            label = mountInfo.label,
            createContent = function(container)
                local mountBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
                mountBtn:SetSize(220, 30)
                mountBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                mountBtn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                mountBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                mountBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

                mountBtn.mountIcon = mountBtn:CreateTexture(nil, "ARTWORK")
                mountBtn.mountIcon:SetSize(22, 22)
                mountBtn.mountIcon:SetPoint("LEFT", mountBtn, "LEFT", 4, 0)

                mountBtn.mountText = mountBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                mountBtn.mountText:SetPoint("LEFT", mountBtn.mountIcon, "RIGHT", 6, 0)
                mountBtn.mountText:SetPoint("RIGHT", mountBtn, "RIGHT", -6, 0)
                mountBtn.mountText:SetJustifyH("LEFT")

                mountBtn:SetScript("OnEnter", function(btn)
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L["AUTOMOUNT_SELECT_TOOLTIP"])
                    GameTooltip:AddLine(L["AUTOMOUNT_SELECT_TOOLTIP_DESC"], 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                mountBtn:SetScript("OnLeave", function(btn)
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    GameTooltip:Hide()
                end)
                mountBtn:SetScript("OnClick", function()
                    AM:ShowMountPicker(capturedKey, function()
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
                    end)
                end)

                mountBtnRef[1] = mountBtn
                return mountBtn, 30
            end,
            value = prefs[catEnabledKey],
            isEnabled = isEnabled,
            onValueChange = function(val)
                SavePreference(catEnabledKey, val)
                UpdateRow()
                AM:UpdatePollingState()
            end,
            onLabel = L["AUTOMOUNT_CAT_ON"],
            offLabel = L["AUTOMOUNT_CAT_OFF"],
        })

        UpdateRow = function()
            local isEnabledNow = ns.ModuleRegistry:IsEnabled(AM.id)
            local prefs2       = GetPreferences()
            local catEnabled   = prefs2[catEnabledKey]
            local active       = isEnabledNow and catEnabled

            rowRefresh(isEnabledNow, catEnabled)

            local mountBtn = mountBtnRef[1]
            if mountBtn then
                local sel = prefs2[capturedKey]
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
                    mountBtn.mountText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                else
                    mountBtn:EnableMouse(false)
                    mountBtn.mountText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
            end
        end

        if registerRefresh then registerRefresh(UpdateRow) end
        UpdateRow()
    end

    yOffset = yOffset - 4

    local timingDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    timingDivider:SetHeight(1)
    timingDivider:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    timingDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    timingDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local timingHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timingHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    timingHeader:SetText(L["AUTOMOUNT_TIMING_SECTION"])
    timingHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - timingHeader:GetStringHeight() - 8

    local timingSectionDiv = detailScrollChild:CreateTexture(nil, "ARTWORK")
    timingSectionDiv:SetHeight(1)
    timingSectionDiv:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    timingSectionDiv:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    timingSectionDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local timingPrefs = GetPreferences()
    local timingSliders = {}
    local UpdateTimingSliders

    local sliderDefs = {
        { key = "dismountDelay",      disableKey = "dismountDisabled", label = L["AUTOMOUNT_DISMOUNT_DELAY"],  desc = L["AUTOMOUNT_DISMOUNT_DELAY_DESC"],  minVal = 0,   maxVal = 30, step = 0.5 },
        { key = "fishingDelay",       disableKey = "fishingDisabled",  label = L["AUTOMOUNT_FISHING_DELAY"],   desc = L["AUTOMOUNT_FISHING_DELAY_DESC"],   minVal = 0,   maxVal = 30, step = 0.5 },
        { key = "gatherRemountDelay", label = L["AUTOMOUNT_GATHER_DELAY"],    desc = L["AUTOMOUNT_GATHER_DELAY_DESC"],    minVal = 0,   maxVal = 5,  step = 0.5 },
    }

    for _, def in ipairs(sliderDefs) do
        local sliderLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sliderLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        sliderLabel:SetText(def.label)
        sliderLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        yOffset = yOffset - sliderLabel:GetStringHeight() - 2

        local sliderDesc = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sliderDesc:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        sliderDesc:SetText(def.desc)
        sliderDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        yOffset = yOffset - sliderDesc:GetStringHeight() - 6

        local sliderContainer = OneWoW_GUI:CreateSlider(detailScrollChild, {
            minVal = def.minVal,
            maxVal = def.maxVal,
            step = def.step,
            currentVal = timingPrefs[def.key],
            onChange = function(val) SavePreference(def.key, val) end,
            width = 200,
            fmt = "%.1fs",
        })
        sliderContainer:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)

        local disableCheck = nil
        if def.disableKey then
            disableCheck = CreateFrame("CheckButton", nil, detailScrollChild, "UICheckButtonTemplate")
            disableCheck:SetSize(26, 26)
            disableCheck:SetPoint("LEFT", sliderContainer, "RIGHT", 8, 10)
            disableCheck:SetChecked(timingPrefs[def.disableKey])

            local disableLabel = disableCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            disableLabel:SetPoint("LEFT", disableCheck, "RIGHT", 2, 0)
            disableLabel:SetText(L["AUTOMOUNT_DISABLE"])
            disableLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local capturedDisableKey = def.disableKey
            disableCheck:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                SavePreference(capturedDisableKey, checked)
                UpdateTimingSliders()
            end)
        end

        yOffset = yOffset - 36 - 8

        tinsert(timingSliders, { container = sliderContainer, label = sliderLabel, desc = sliderDesc, disableCheck = disableCheck, disableKey = def.disableKey })
    end

    UpdateTimingSliders = function()
        local active = ns.ModuleRegistry:IsEnabled(AM.id)
        local currentPrefs = GetPreferences()
        for _, s in ipairs(timingSliders) do
            local sliderChild = select(1, s.container:GetChildren())
            local disabled = s.disableKey and currentPrefs[s.disableKey]
            local sliderActive = active and not disabled
            if sliderChild then sliderChild:EnableMouse(sliderActive) end
            if s.disableCheck then s.disableCheck:EnableMouse(active) end
            if active then
                if disabled then
                    s.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    s.desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    s.container:SetAlpha(0.5)
                else
                    s.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    s.desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    s.container:SetAlpha(1.0)
                end
            else
                s.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                s.desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                s.container:SetAlpha(0.5)
            end
        end
    end

    if registerRefresh then registerRefresh(UpdateTimingSliders) end
    UpdateTimingSliders()

    yOffset = yOffset - 4

    local druidDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    druidDivider:SetHeight(1)
    druidDivider:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    druidDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local druidHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    druidHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    druidHeader:SetText(L["AUTOMOUNT_DRUID_SECTION"])
    druidHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - druidHeader:GetStringHeight() - 8

    local druidSectionDiv = detailScrollChild:CreateTexture(nil, "ARTWORK")
    druidSectionDiv:SetHeight(1)
    druidSectionDiv:SetPoint("TOPLEFT",  detailScrollChild, "TOPLEFT",  12, yOffset)
    druidSectionDiv:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    druidSectionDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local druidPrefs = GetPreferences()
    local druidRowRefresh
    local UpdateDruidRow
    yOffset, druidRowRefresh, _ = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
        yOffset = yOffset,
        label = L["AUTOMOUNT_DRUID_MODE_LABEL"],
        description = L["AUTOMOUNT_DRUID_MODE_DESC"],
        value = druidPrefs.druidEnabled,
        isEnabled = isEnabled,
        onValueChange = function(val)
            SavePreference("druidEnabled", val)
            UpdateDruidRow()
            AM:UpdatePollingState()
        end,
        onLabel = L["AUTOMOUNT_CAT_ON"],
        offLabel = L["AUTOMOUNT_CAT_OFF"],
    })

    UpdateDruidRow = function()
        local isEnabledNow = ns.ModuleRegistry:IsEnabled(AM.id)
        local prefs        = GetPreferences()
        local druidEnabled = prefs.druidEnabled
        druidRowRefresh(isEnabledNow, druidEnabled)
    end

    if registerRefresh then registerRefresh(UpdateDruidRow) end
    UpdateDruidRow()

    yOffset = yOffset - 4

    local cancelPrefs = GetPreferences()
    local cancelRowRefresh
    local UpdateCancelRow
    yOffset, cancelRowRefresh, _ = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
        yOffset = yOffset,
        label = L["AUTOMOUNT_DRUID_CANCEL_LABEL"],
        description = L["AUTOMOUNT_DRUID_CANCEL_DESC"],
        value = cancelPrefs.druidCancelTravelForm,
        isEnabled = isEnabled,
        onValueChange = function(val)
            SavePreference("druidCancelTravelForm", val)
            UpdateCancelRow()
            AM:UpdateDruidFlightWatcher()
        end,
        onLabel = L["AUTOMOUNT_CAT_ON"],
        offLabel = L["AUTOMOUNT_CAT_OFF"],
    })

    UpdateCancelRow = function()
        local isEnabledNow = ns.ModuleRegistry:IsEnabled(AM.id)
        local prefs        = GetPreferences()
        local cancelEnabled = prefs.druidCancelTravelForm
        cancelRowRefresh(isEnabledNow, cancelEnabled)
    end

    if registerRefresh then registerRefresh(UpdateCancelRow) end
    UpdateCancelRow()

    return yOffset
end

function AutoMountModule:ShowMountPicker(mountType, onSelect)
    local L = ns.L

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
                    tinsert(matchingMounts, mountData)
                else
                    tinsert(otherMounts, mountData)
                end
            end
        end
    end

    sort(matchingMounts, function(a, b) return a.name < b.name end)
    sort(otherMounts,    function(a, b) return a.name < b.name end)

    local popup = AM._mountPickerFrame
    local isNew = not popup

    if isNew then
        local result = OneWoW_GUI:CreateDialog({
            name = "OneWoW_QoL_MountPickerPopup",
            title = "",
            width = 350,
            height = 450,
            onClose = function(frame) frame:Hide() end,
        })
        popup = result.frame
        popup._titleBar = result.titleBar
        local popupContent = result.contentFrame

        popup._searchBox = OneWoW_GUI:CreateEditBox(popupContent, { width = 220, height = 24, placeholderText = L["AUTOMOUNT_SEARCH"], maxLetters = 50 })
        popup._searchBox:SetPoint("TOPLEFT",  popupContent, "TOPLEFT",  15, -10)
        popup._searchBox:SetPoint("TOPRIGHT", popupContent, "TOPRIGHT", -15, -10)

        local scrollBarWidth = 10
        local contentWidth   = 350 - 24 - scrollBarWidth
        popup._contentWidth  = contentWidth

        local listContainer = CreateFrame("Frame", nil, popupContent)
        listContainer:SetPoint("TOPLEFT",     popupContent, "TOPLEFT",     12, -40)
        listContainer:SetPoint("BOTTOMRIGHT", popupContent, "BOTTOMRIGHT", -12, 48)

        popup._scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
        popup._scrollFrame:SetPoint("TOPLEFT",     listContainer, "TOPLEFT",     0, 0)
        popup._scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
        popup._scrollFrame:EnableMouseWheel(true)

        local scrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
        scrollTrack:SetPoint("TOPRIGHT",    listContainer, "TOPRIGHT",    -2, 0)
        scrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
        scrollTrack:SetWidth(8)
        scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
        scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

        local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
        scrollThumb:SetWidth(6)
        scrollThumb:SetHeight(30)
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
        scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
        scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

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

        local btnDiv = popupContent:CreateTexture(nil, "ARTWORK")
        btnDiv:SetHeight(1)
        btnDiv:SetPoint("BOTTOMLEFT",  popupContent, "BOTTOMLEFT",  1, 42)
        btnDiv:SetPoint("BOTTOMRIGHT", popupContent, "BOTTOMRIGHT", -1, 42)
        btnDiv:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local closeBtn = OneWoW_GUI:CreateFitTextButton(popupContent, { text = L["AUTOMOUNT_CLOSE"], height = 32 })
        closeBtn:SetPoint("BOTTOM", popupContent, "BOTTOM", 0, 6)
        closeBtn:SetScript("OnClick", function() popup:Hide() end)

        popup._mountButtons = {}
        AM._mountPickerFrame = popup
    end

    popup._titleBar._titleText:SetText(string.format(L["AUTOMOUNT_SELECT_TITLE"], mountType:gsub("^%l", string.upper)))
    popup._scrollFrame:SetVerticalScroll(0)

    local mountButtons = popup._mountButtons
    local scrollChild  = popup._scrollChild
    local contentWidth = popup._contentWidth
    local rowWidth     = contentWidth - 10

    local function CreateMountRow(mountData, isAuto)
        local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        btn:SetSize(rowWidth, 30)
        btn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local rowIcon = btn:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(22, 22)
        rowIcon:SetPoint("LEFT", btn, "LEFT", 4, 0)
        rowIcon:SetTexture(mountData.icon)

        local rowText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowText:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
        rowText:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        rowText:SetJustifyH("LEFT")
        rowText:SetText(mountData.name)
        rowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        btn:SetScript("OnEnter", function(b)
            b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
            b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        end)
        btn:SetScript("OnLeave", function(b)
            b:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
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
        tinsert(mountButtons, autoBtn)
        listY = listY - 34

        local function AddIfMatches(mountData)
            if searchText == "" or mountData.name:lower():find(searchText, 1, true) then
                local btn = CreateMountRow(mountData, false)
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, listY)
                btn:Show()
                tinsert(mountButtons, btn)
                listY = listY - 34
            end
        end

        for _, mountData in ipairs(matchingMounts) do AddIfMatches(mountData) end
        for _, mountData in ipairs(otherMounts)    do AddIfMatches(mountData) end

        scrollChild:SetHeight(math.abs(listY) + 10)
        C_Timer.After(0.05, popup._updateScrollThumb)
    end

    popup._searchBox:SetScript("OnTextChanged", function(eb)
        local text = eb:GetText()
        if text == popup._searchBox.placeholderText then text = "" end
        UpdateMountList(text)
    end)

    UpdateMountList("")
    popup:Show()
    popup:Raise()
end

ns.AutoMountModule = AutoMountModule
