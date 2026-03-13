-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/playmounts/playmounts.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local PlayMountsModule = {
    id          = "playmounts",
    title       = "PLAYMOUNTS_TITLE",
    category    = "INTERFACE",
    description = "PLAYMOUNTS_DESC",
    version     = "1.1",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "announce_chat",    label = "PLAYMOUNTS_TOGGLE_CHAT",       description = "PLAYMOUNTS_TOGGLE_CHAT_DESC",       default = false },
        { id = "enableMatchMount", label = "PLAYMOUNTS_TOGGLE_MATCHMOUNT", description = "PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC", default = true  },
    },
    defaultEnabled = true,
    _frame = nil,
}

local MAXIMUM_BUFF_COUNT = 40

local MOUNT_TYPES = {
    [230] = "Ground", [231] = "Aquatic", [232] = "Aquatic", [241] = "Ground",
    [247] = "Water Strider", [248] = "Flying", [254] = "Aquatic",
    [269] = "Water Strider", [284] = "Dynamic Flying", [398] = "Ground",
    [402] = "Dragonriding", [407] = "Aquatic", [412] = "Ground",
    [424] = "Dragonriding", [436] = "Aquatic",
}

local NON_MOUNT_MOVEMENT_FORMS = {
    [783]    = {name = "Travel Form",  icon = "Interface\\Icons\\Ability_Druid_TravelForm"},
    [768]    = {name = "Cat Form",     icon = "Interface\\Icons\\Ability_Druid_CatForm"},
    [5487]   = {name = "Bear Form",    icon = "Interface\\Icons\\Ability_Racial_BearForm"},
    [24858]  = {name = "Moonkin Form", icon = "Interface\\Icons\\Spell_Nature_ForceOfNature"},
    [210053] = {name = "Mount Form",   icon = "Interface\\Icons\\Ability_Druid_TravelForm"},
    [2645]   = {name = "Ghost Wolf",   icon = "Interface\\Icons\\Spell_Nature_SpiritWolf"},
    [192077] = {name = "Wind Rush",    icon = "Interface\\Icons\\Ability_Shaman_WindWalkTotem"},
    [1850]   = {name = "Dash",         icon = "Interface\\Icons\\Ability_Druid_Dash"},
    [1784]   = {name = "Stealth",      icon = "Interface\\Icons\\Ability_Stealth"},
    [113858] = {name = "Dark Flight",  icon = "Interface\\Icons\\Ability_Racial_DarkFlight"},
    [118922] = {name = "Posthaste",    icon = "Interface\\Icons\\Ability_Hunter_Posthaste"},
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("playmounts", id)
end

local function GetDisplayMode()
    local addon = _G.OneWoW_QoL
    if addon and addon.db and addon.db.global.modules then
        local modData = addon.db.global.modules["playmounts"]
        if modData and modData.displayMode then
            return modData.displayMode
        end
    end
    return "all"
end

local function SetDisplayMode(mode)
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global.modules then return end
    if not addon.db.global.modules["playmounts"] then
        addon.db.global.modules["playmounts"] = {}
    end
    addon.db.global.modules["playmounts"].displayMode = mode
end

function PlayMountsModule:GetMountTypeName(mountTypeID)
    return MOUNT_TYPES[mountTypeID] or "Unknown"
end

function PlayMountsModule:DetectMountOnUnit(unit)
    if not unit or not UnitIsPlayer(unit) then return nil end

    local buffCount = 0
    while true do
        local spellInfo = C_UnitAuras.GetBuffDataByIndex(unit, buffCount + 1)
        if not spellInfo then break end
        buffCount = buffCount + 1
        if buffCount > MAXIMUM_BUFF_COUNT then return nil end
    end

    local spellIterator = 1
    while true do
        local spellInfo = C_UnitAuras.GetBuffDataByIndex(unit, spellIterator)
        if not spellInfo then break end

        local spellId = spellInfo.spellId
        spellIterator = spellIterator + 1

        if spellId and not issecretvalue(spellId) then
            local formInfo = NON_MOUNT_MOVEMENT_FORMS[spellId]
            if formInfo then
                return { isMount = false, isMovementForm = true, name = formInfo.name, icon = formInfo.icon, spellId = spellId }
            end

            local mountID = C_MountJournal.GetMountFromSpell(spellId)
            if mountID then
                local name, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                if name then
                    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
                    local _, _, source = C_MountJournal.GetMountInfoExtraByID(mountID)
                    local sourceText
                    if source then
                        sourceText = strtrim(source:gsub("|n", " "):gsub("  ", " "))
                    end
                    return {
                        isMount        = true,
                        isMovementForm = false,
                        mountID        = mountID,
                        name           = name,
                        spellID        = spellID,
                        icon           = icon,
                        isCollected    = isCollected,
                        sourceText     = sourceText,
                        mountTypeID    = mountTypeID,
                        mountTypeName  = self:GetMountTypeName(mountTypeID),
                    }
                end
            end
        end
    end

    return nil
end

function PlayMountsModule:OnTargetChanged()
    if not GetToggle("announce_chat") then return end

    local unit = "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local mountInfo = self:DetectMountOnUnit(unit)
    if not mountInfo then return end

    local unitName = UnitName(unit)
    local L = ns.L

    local prefix = "|cFFFFD100[QoL - " .. (L["PLAYMOUNTS_MOUNT"] or "Mount") .. "]|r "
    local playerLink = "|Hplayer:" .. unitName .. "|h|cFFFFFFFF[" .. unitName .. "]|r|h"

    local _, classFilename = UnitClass(unit)
    if classFilename then
        local classColorObj = C_ClassColor.GetClassColor(classFilename)
        if classColorObj then
            playerLink = "|Hplayer:" .. unitName .. "|h|c" .. classColorObj:GenerateHexColor() .. "[" .. unitName .. "]|r|h"
        end
    end

    local displayMode = GetDisplayMode()

    if mountInfo.isMovementForm then
        print(prefix .. string.format(L["PLAYMOUNTS_USING"] or "%s is using %s", playerLink, mountInfo.name))
    else
        local statusText
        if mountInfo.isCollected then
            statusText = " |cFF00FF00" .. (L["PLAYMOUNTS_COLLECTED"] or "(Collected)") .. "|r"
        else
            statusText = " |cFFFF0000" .. (L["PLAYMOUNTS_NOT_COLLECTED"] or "(Not Collected)") .. "|r"
        end
        local mountLink = C_Spell.GetSpellLink(mountInfo.spellID) or mountInfo.name
        print(prefix .. string.format(L["PLAYMOUNTS_USING"] or "%s is using %s", playerLink, mountLink .. statusText))
        if displayMode ~= "name" and mountInfo.mountTypeName then
            print(prefix .. string.format(L["PLAYMOUNTS_TYPE"] or "Type: %s", mountInfo.mountTypeName))
        end
        if displayMode == "all" and mountInfo.sourceText and mountInfo.sourceText ~= "" then
            print(prefix .. string.format(L["PLAYMOUNTS_SOURCE"] or "Source: %s", mountInfo.sourceText))
        end
    end
end

function PlayMountsModule:CreateCustomDetail(parent, yOffset, isEnabled, registerRefresh)
    local L = ns.L

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local modeHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    modeHeader:SetText(L["PLAYMOUNTS_DISPLAYMODE_HEADER"])
    modeHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - modeHeader:GetStringHeight() - 8

    local modeDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeDesc:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    modeDesc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    modeDesc:SetJustifyH("LEFT")
    modeDesc:SetWordWrap(true)
    modeDesc:SetText(L["PLAYMOUNTS_DISPLAYMODE_DESC"])
    modeDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - modeDesc:GetStringHeight() - 8

    local modes = {
        { id = "name",     labelKey = "PLAYMOUNTS_MODE_NAME"     },
        { id = "nameType", labelKey = "PLAYMOUNTS_MODE_NAMETYPE" },
        { id = "all",      labelKey = "PLAYMOUNTS_MODE_ALL"      },
    }

    local currentMode = GetDisplayMode()
    local modeBtns = {}

    local function UpdateModeButtons()
        local isEnabledNow = ns.ModuleRegistry:IsEnabled("playmounts")
        for _, btn in ipairs(modeBtns) do
            if not isEnabledNow then
                btn:EnableMouse(false)
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            else
                btn:EnableMouse(true)
                if btn.isActive then
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                else
                    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                    btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
            end
        end
    end

    local prevModeBtn = nil
    for _, mode in ipairs(modes) do
        local capturedMode = mode
        local isActive = (currentMode == mode.id)
        local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = L[mode.labelKey] or mode.id, height = 22 })
        if prevModeBtn then
            btn:SetPoint("TOPLEFT", prevModeBtn, "TOPRIGHT", 6, 0)
        else
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
        end
        prevModeBtn = btn
        btn.isActive = isActive

        btn:HookScript("OnLeave", function(self)
            UpdateModeButtons()
        end)

        btn:SetScript("OnClick", function(self)
            SetDisplayMode(capturedMode.id)
            for _, b in ipairs(modeBtns) do
                b.isActive = (b == self)
            end
            UpdateModeButtons()
        end)

        table.insert(modeBtns, btn)
    end

    if registerRefresh then registerRefresh(UpdateModeButtons) end
    UpdateModeButtons()

    yOffset = yOffset - 22 - 6

    local modeDivider = parent:CreateTexture(nil, "ARTWORK")
    modeDivider:SetHeight(1)
    modeDivider:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    modeDivider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    modeDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 12

    local coreHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    coreHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    coreHeader:SetText(L["PLAYMOUNTS_TOOLTIP_HEADER"])
    coreHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - coreHeader:GetStringHeight() - 8

    local reqLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    reqLabel:SetText(L["PLAYMOUNTS_TOOLTIP_REQUIRES"])
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local coreLoaded = (_G.OneWoW ~= nil)
    local detectedLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detectedLabel:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
    if coreLoaded then
        detectedLabel:SetText(L["PLAYMOUNTS_TOOLTIP_DETECTED"])
        detectedLabel:SetTextColor(0.2, 1.0, 0.2)
    else
        detectedLabel:SetText(L["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"])
        detectedLabel:SetTextColor(1.0, 0.2, 0.2)
    end
    yOffset = yOffset - 24

    local viewBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["PLAYMOUNTS_TOOLTIP_VIEW_BTN"], height = 22 })
    viewBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    if coreLoaded then
        viewBtn:SetScript("OnClick", function()
            _G.OneWoW.GUI:Show("settings")
            _G.OneWoW.GUI:SelectSubTab("settings", "tooltips")
        end)
    else
        viewBtn:EnableMouse(false)
        viewBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        viewBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        viewBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local coreNote = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coreNote:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset - 3)
    coreNote:SetPoint("RIGHT", viewBtn, "LEFT", -8, 0)
    coreNote:SetJustifyH("LEFT")
    coreNote:SetWordWrap(true)
    coreNote:SetText(L["PLAYMOUNTS_TOOLTIP_NOTE"])
    coreNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    yOffset = yOffset - math.max(coreNote:GetStringHeight(), 22) - 10

    return yOffset
end

function PlayMountsModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_PlayerMounts")
        self._frame:SetScript("OnEvent", function(frame, event, ...)
            if event == "PLAYER_TARGET_CHANGED" then
                self:OnTargetChanged()
            end
        end)
    end
    self._frame:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function PlayMountsModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

ns.PlayMountsModule = PlayMountsModule

if _G.OneWoW and _G.OneWoW.TooltipEngine then
    local function PlayerMountsTooltipProvider(tooltip, context)
        if not ns.ModuleRegistry:IsEnabled("playmounts") then return nil end
        if not context.isPlayer or not context.unit then return nil end

        local mountInfo = PlayMountsModule:DetectMountOnUnit(context.unit)
        if not mountInfo then return nil end

        local L = ns.L
        local displayMode = GetDisplayMode()
        local lines = {}

        if mountInfo.isMovementForm then
            table.insert(lines, {
                type  = "double",
                left  = L["PLAYMOUNTS_MOUNT"] or "Mount",
                right = mountInfo.name,
                lr = 0.9, lg = 0.9, lb = 0.9,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        else
            local collected = mountInfo.isCollected
                and ("|cFF00FF00" .. (L["PLAYMOUNTS_COLLECTED"] or "(Collected)") .. "|r")
                or  ("|cFFFF0000" .. (L["PLAYMOUNTS_NOT_COLLECTED"] or "(Not Collected)") .. "|r")

            table.insert(lines, {
                type  = "double",
                left  = L["PLAYMOUNTS_MOUNT"] or "Mount",
                right = mountInfo.name .. " " .. collected,
                lr = 0.9, lg = 0.9, lb = 0.9,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })

            if displayMode ~= "name" and mountInfo.mountTypeName then
                table.insert(lines, {
                    type = "text",
                    text = string.format(L["PLAYMOUNTS_TYPE"] or "Type: %s", mountInfo.mountTypeName),
                    r = 0.7, g = 0.7, b = 0.7,
                })
            end

            if displayMode == "all" and mountInfo.sourceText and mountInfo.sourceText ~= "" then
                table.insert(lines, {
                    type = "text",
                    text = string.format(L["PLAYMOUNTS_SOURCE"] or "Source: %s", mountInfo.sourceText),
                    r = 0.7, g = 0.7, b = 0.7,
                })
            end
        end

        if #lines == 0 then return nil end
        return lines
    end

    _G.OneWoW.TooltipEngine:RegisterProvider({
        id           = "playermounts",
        order        = 50,
        featureId    = "playermounts",
        tooltipTypes = {"unit"},
        callback     = PlayerMountsTooltipProvider,
    })
end
