local _, ns = ...
local PlayMountsModule, L = ns.ModuleRegistry:Current()
if not PlayMountsModule then return end

local OneWoW_GUI = OneWoW_GUI

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

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
    local modData = ns.ModuleRegistry:GetModuleBucket("playmounts")
    if modData.displayMode then
        return modData.displayMode
    end
    return "all"
end

local function SetDisplayMode(mode)
    ns.ModuleRegistry:GetModuleBucket("playmounts").displayMode = mode
end

function PlayMountsModule:GetMountTypeName(mountTypeID)
    return MOUNT_TYPES[mountTypeID] or "Unknown"
end

function PlayMountsModule:DetectMountOnUnit(unit)
    if not unit or not UnitIsPlayer(unit) then return nil end
    -- 12.1+: index-based UnitAura APIs Lua-error while auras are secret.
    if OneWoW.Restriction.ShouldAurasBeSecret() then return nil end

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

        if spellId and not OneWoW.Restriction.IsSecret(spellId) then
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

local function PlayerMountsTooltipProvider(_, context)
    if not context.isPlayer or not context.unit then return nil end

    local mountInfo = PlayMountsModule:DetectMountOnUnit(context.unit)
    if not mountInfo then return nil end

    local displayMode = GetDisplayMode()
    local lines = {}

    if mountInfo.isMovementForm then
        table.insert(lines, {
            type  = "double",
            left  = MOUNT,
            right = mountInfo.name,
            lr = 0.9, lg = 0.9, lb = 0.9,
            rr = 1.0, rg = 1.0, rb = 1.0,
        })
    else
        local collected = mountInfo.isCollected
            and ("|cFF00FF00" .. (L["PLAYMOUNTS_COLLECTED"]) .. "|r")
            or  ("|cFFFF0000" .. (L["PLAYMOUNTS_NOT_COLLECTED"]) .. "|r")

        table.insert(lines, {
            type  = "double",
            left  = MOUNT,
            right = mountInfo.name .. " " .. collected,
            lr = 0.9, lg = 0.9, lb = 0.9,
            rr = 1.0, rg = 1.0, rb = 1.0,
        })

        if displayMode ~= "name" and mountInfo.mountTypeName then
            table.insert(lines, {
                type = "text",
                text = string.format(L["TYPE_S"], mountInfo.mountTypeName),
                r = 0.7, g = 0.7, b = 0.7,
            })
        end

        if displayMode == "all" and mountInfo.sourceText and mountInfo.sourceText ~= "" then
            table.insert(lines, {
                type = "text",
                text = string.format(L["PLAYMOUNTS_SOURCE"], mountInfo.sourceText),
                r = 0.7, g = 0.7, b = 0.7,
            })
        end
    end

    if #lines == 0 then return nil end
    return lines
end

function PlayMountsModule:OnTargetChanged()
    if not GetToggle("announce_chat") then return end

    local unit = "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local mountInfo = self:DetectMountOnUnit(unit)
    if not mountInfo then return end

    local unitName = UnitName(unit)

    local prefix = "|cFFFFD100[QoL - " .. (MOUNT) .. "]|r "
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
        print(prefix .. string.format(L["PLAYMOUNTS_USING"], playerLink, mountInfo.name))
    else
        local statusText
        if mountInfo.isCollected then
            statusText = " |cFF00FF00" .. (L["PLAYMOUNTS_COLLECTED"]) .. "|r"
        else
            statusText = " |cFFFF0000" .. (L["PLAYMOUNTS_NOT_COLLECTED"]) .. "|r"
        end
        local mountLink = C_Spell.GetSpellLink(mountInfo.spellID) or mountInfo.name
        print(prefix .. string.format(L["PLAYMOUNTS_USING"], playerLink, mountLink .. statusText))
        if displayMode ~= "name" and mountInfo.mountTypeName then
            print(prefix .. string.format(L["TYPE_S"], mountInfo.mountTypeName))
        end
        if displayMode == "all" and mountInfo.sourceText and mountInfo.sourceText ~= "" then
            print(prefix .. string.format(L["PLAYMOUNTS_SOURCE"], mountInfo.sourceText))
        end
    end
end

function PlayMountsModule:CreateCustomDetail(parent, yOffset, _, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, parent)
    cardsHost:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if parent.UpdateDetailHeight then
            parent:SetHeight(h)
            parent.UpdateDetailHeight()
        else
            parent:SetHeight(math.abs(yOffset) + h + 20)
            if parent.updateThumb then
                parent.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local modeRefresh

    local modes = {
        { id = "name",     labelKey = "PLAYMOUNTS_MODE_NAME"     },
        { id = "nameType", labelKey = "PLAYMOUNTS_MODE_NAMETYPE" },
        { id = "all",      labelKey = "PLAYMOUNTS_MODE_ALL"      },
    }

    local function ModeLabel(modeId)
        for _, mode in ipairs(modes) do
            if mode.id == modeId then
                return L[mode.labelKey]
            end
        end
        return L["PLAYMOUNTS_MODE_ALL"]
    end

    stack:AddCard("playmounts:display", DISPLAY_MODE, function(content, contentWidth)
        local gap = 8
        local modeDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        modeDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        modeDesc:SetJustifyH("LEFT")
        modeDesc:SetWordWrap(true)
        modeDesc:SetSpacing(2)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            modeDesc:SetWidth(w)
        else
            modeDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        modeDesc:SetText(L["PLAYMOUNTS_DISPLAYMODE_DESC"])
        modeDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local currentMode = GetDisplayMode()
        local modeDropdown, modeDropdownText = OneWoW_GUI:CreateDropdown(content, {
            width = 160,
            height = 26,
            text = ModeLabel(currentMode),
        })
        modeDropdown:SetPoint("TOPLEFT", modeDesc, "BOTTOMLEFT", 0, -gap)
        modeDropdown._activeValue = currentMode

        OneWoW_GUI:AttachFilterMenu(modeDropdown, {
            searchable = false,
            menuHeight = 110,
            buildItems = function()
                local items = {}
                for _, mode in ipairs(modes) do
                    items[#items + 1] = { value = mode.id, text = L[mode.labelKey] }
                end
                return items
            end,
            onSelect = function(value, text)
                SetDisplayMode(value)
                modeDropdown._activeValue = value
                modeDropdownText:SetText(text)
            end,
            getActiveValue = function()
                return GetDisplayMode()
            end,
        })

        modeRefresh = function()
            local isEnabledNow = ns.ModuleRegistry:IsEnabled("playmounts")
            if isEnabledNow then
                modeDropdown:Enable()
                modeDropdownText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            else
                modeDropdown:Disable()
                modeDropdownText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
        modeRefresh()

        local descH = modeDesc:GetStringHeight() or 14
        return math.max(1, descH + gap + 26 + 4)
    end)

    stack:AddCard("playmounts:tooltip", L["PLAYMOUNTS_TOOLTIP_HEADER"], function(content, contentWidth)
        local reqLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        reqLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        reqLabel:SetText(L["PLAYMOUNTS_TOOLTIP_REQUIRES"])
        reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local coreLoaded = (OneWoW ~= nil)
        local detectedLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        detectedLabel:SetPoint("LEFT", reqLabel, "RIGHT", 8, 0)
        if coreLoaded then
            detectedLabel:SetText(L["PLAYMOUNTS_TOOLTIP_DETECTED"])
            detectedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            detectedLabel:SetText(L["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"])
            detectedLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
        end

        local coreNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        coreNote:SetPoint("TOPLEFT", reqLabel, "BOTTOMLEFT", 0, -10)
        local w = tonumber(contentWidth) or 0
        if w >= 1 then
            coreNote:SetWidth(math.max(1, w))
        else
            coreNote:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((reqLabel:GetStringHeight() or 14) + 10))
        end
        coreNote:SetJustifyH("LEFT")
        coreNote:SetWordWrap(true)
        coreNote:SetText(L["PLAYMOUNTS_TOOLTIP_NOTE"])
        coreNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local viewLink = OneWoW_GUI:CreateTextLink(content, {
            text = L["PLAYMOUNTS_TOOLTIP_VIEW_BTN"],
            fontSize = 11,
            nav = true,
            onClick = function()
                ns.UI.SelectTooltipFeature("playermounts")
            end,
        })
        viewLink:SetPoint("TOPLEFT", coreNote, "BOTTOMLEFT", 0, -8)
        viewLink:SetEnabled(coreLoaded)

        local reqH = reqLabel:GetStringHeight() or 14
        local noteH = coreNote:GetStringHeight() or 14
        local linkH = viewLink:GetHeight() or 14
        return math.max(1, reqH + 10 + noteH + 8 + linkH + 4)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            if modeRefresh then
                modeRefresh()
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end

function PlayMountsModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_PlayerMounts")
        self._frame:SetScript("OnEvent", function(_, event)
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

OneWoW.TooltipEngine:RegisterProvider({
    id           = "playermounts",
    order        = 50,
    featureId    = "playermounts",
    tooltipTypes = {"unit"},
    callback     = PlayerMountsTooltipProvider,
})
