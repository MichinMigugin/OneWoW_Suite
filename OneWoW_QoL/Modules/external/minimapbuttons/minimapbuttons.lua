local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local MinimapButtonsModule = {
    id             = "minimapbuttons",
    title          = "MMBTNS_TITLE",
    category       = "INTERFACE",
    description    = "MMBTNS_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@wow2.xyz",
    link           = "https://www.wow2.xyz",
    toggles        = {},
    preview        = false,
    defaultEnabled = true,
}

-- ─── Raw UIParent methods (bypass noOp overrides when positioning buttons) ──

local RawClearAllPoints = UIParent.ClearAllPoints
local RawSetPoint       = UIParent.SetPoint

-- ─── Constants ──────────────────────────────────────────────────────────────

local CONTAINER_STRATA = "MEDIUM"
local CONTAINER_LEVEL  = 7

-- ─── State ──────────────────────────────────────────────────────────────────

local hubButton        = nil
local containerFrame   = nil
local collectedButtons = {}
local collectedNames   = {}
local collectedMap     = {}
local enhancedRow      = {}
local searchBox        = nil
local searchFilter     = ""
local autoCloseTimer   = nil
local _layouting       = false
local _relayoutTimer   = nil

-- ─── Blizzard frames that must never be collected ───────────────────────────

local BLIZZARD_SKIP = {
    MiniMapMailFrame                    = true,
    MinimapZoomIn                       = true,
    MinimapZoomOut                      = true,
    MiniMapTracking                     = true,
    MinimapBackdrop                     = true,
    GameTimeFrame                       = true,
    TimeManagerClockButton              = true,
    GarrisonLandingPageMinimapButton    = true,
    QueueStatusMinimapButton            = true,
    MinimapZoneTextButton               = true,
    AddonCompartmentFrame               = true,
    ExpansionLandingPageMinimapButton   = true,
    MinimapCluster                      = true,
    MinimapCompassTexture               = true,
}

local OWN_BUTTON_NAME = "OneWoW_QoL_MMBtnCollector"

-- ─── Helpers ────────────────────────────────────────────────────────────────

local noOp = function() end

local function ScheduleRelayout()
    if _relayoutTimer then
        _relayoutTimer:Cancel()
    end
    _relayoutTimer = C_Timer.NewTimer(0.15, function()
        _relayoutTimer = nil
        if containerFrame and containerFrame:IsShown() then
            MinimapButtonsModule:LayoutContainer()
        end
    end)
end

local function GetSettings()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods["minimapbuttons"] then mods["minimapbuttons"] = {} end
    local s = mods["minimapbuttons"]
    if s.closeMode       == nil then s.closeMode       = "autoclose" end
    if s.autoCloseDelay  == nil then s.autoCloseDelay  = 3           end
    if s.enhancedMenu    == nil then s.enhancedMenu    = false       end
    if s.maxColumns      == nil then s.maxColumns      = 6           end
    if s.maxRows         == nil then s.maxRows         = 0           end
    if s.buttonSize      == nil then s.buttonSize      = 34          end
    if s.buttonSpacing   == nil then s.buttonSpacing   = 2           end
    if s.locked          == nil then s.locked          = false       end
    if s.growDirection   == nil then s.growDirection    = "down"      end
    if s.hideCollected   == nil then s.hideCollected   = true        end
    if s.showTooltips    == nil then s.showTooltips    = true        end
    if not s.whitelist       then s.whitelist       = {}          end
    if not s.blacklist       then s.blacklist       = {}          end
    return s
end

MinimapButtonsModule.GetSettings = GetSettings

local function IsBlacklisted(frameName)
    local s = GetSettings()
    for _, name in ipairs(s.blacklist) do
        if name == frameName then return true end
    end
    return false
end

local function GetCurrentIcon()
    if OneWoW_GUI and OneWoW_GUI.GetBrandIcon then
        return OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))
    end
    return "Interface\\AddOns\\OneWoW_GUI\\Media\\neutral-mini.png"
end

-- ─── Hub button position (free-floating on UIParent) ────────────────────────

local function SaveHubPosition()
    if not hubButton then return end
    local s = GetSettings()
    local point, _, relPoint, x, y = hubButton:GetPoint()
    if point then
        s.hubPosition = { point = point, relativePoint = relPoint, x = x, y = y }
    end
end

local function RestoreHubPosition()
    if not hubButton then return end
    local s = GetSettings()
    if s.hubPosition then
        hubButton:ClearAllPoints()
        hubButton:SetPoint(s.hubPosition.point, UIParent, s.hubPosition.relativePoint,
            s.hubPosition.x, s.hubPosition.y)
    else
        hubButton:ClearAllPoints()
        hubButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    end
end

-- ─── Button Detection ───────────────────────────────────────────────────────

local NAME_PATTERNS = {
    "^LibDBIcon10_",
    "MinimapButton",
    "MinimapFrame",
    "MinimapIcon",
    "[-_]Minimap[-_]",
    "Minimap$",
}

local function FrameNameMatchesPatterns(name)
    for _, pat in ipairs(NAME_PATTERNS) do
        if name:find(pat) then return true end
    end
    return false
end

local function HasIconTexture(frame)
    for _, child in ipairs({ frame:GetRegions() }) do
        if child:IsObjectType("Texture") then
            local drawLayer = child:GetDrawLayer()
            if drawLayer == "ARTWORK" or drawLayer == "BACKGROUND" then
                local tex = child:GetTexture()
                if tex and tex ~= "" then return true end
            end
        end
    end
    return false
end

local function ShouldCollectChild(child)
    if not child.GetName then return false end
    local name = child:GetName()
    if not name or name == "" then return false end
    if name == OWN_BUTTON_NAME then return false end
    if BLIZZARD_SKIP[name] then return false end
    if collectedNames[name] then return false end
    if IsBlacklisted(name) then return false end

    if issecurevariable and _G[name] and issecurevariable(_G, name) then
        return false
    end

    if FrameNameMatchesPatterns(name) then return true end
    if HasIconTexture(child) then return true end

    return false
end

-- ─── Button Collection (MBB-style: simple reparent, no texture manipulation) ─

local function CollectButton(frame)
    local name = frame:GetName()
    if not name or collectedNames[name] then return end
    collectedNames[name] = true

    frame:SetParent(containerFrame)
    frame:SetFrameStrata(CONTAINER_STRATA)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)

    frame.ClearAllPoints = noOp
    frame.SetPoint       = noOp
    frame.SetParent      = noOp
    frame.SetScale       = noOp

    table.insert(collectedButtons, frame)
    collectedMap[frame] = frame:IsShown()

    frame:HookScript("OnShow", function()
        if not _layouting then
            collectedMap[frame] = true
            ScheduleRelayout()
        end
    end)
    frame:HookScript("OnHide", function()
        if not _layouting then
            collectedMap[frame] = false
            ScheduleRelayout()
        end
    end)
end

local function UncollectButton(frame)
    local origCP  = UIParent.ClearAllPoints
    local origSP  = UIParent.SetPoint
    local origPar = UIParent.SetParent
    local origSc  = UIParent.SetScale

    frame.ClearAllPoints = nil
    frame.SetPoint       = nil
    frame.SetParent      = nil
    frame.SetScale       = nil
    frame:SetParent(_G.Minimap)
end

local function ScanMinimapChildren()
    if not containerFrame then return end
    for _, child in ipairs({ _G.Minimap:GetChildren() }) do
        if child:IsObjectType("Button") or child:IsObjectType("Frame") then
            if ShouldCollectChild(child) then
                CollectButton(child)
            end
            for _, grandchild in ipairs({ child:GetChildren() }) do
                if (grandchild:IsObjectType("Button") or grandchild:IsObjectType("Frame"))
                   and ShouldCollectChild(grandchild) then
                    CollectButton(grandchild)
                end
            end
        end
    end
end

local function ScanLibDBIcon()
    if not containerFrame then return end
    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not libDBIcon then return end

    local list = libDBIcon:GetButtonList()
    if not list then return end
    for _, name in ipairs(list) do
        local btn = libDBIcon:GetMinimapButton(name)
        if btn and btn.GetName then
            local frameName = btn:GetName()
            if frameName and not collectedNames[frameName]
               and not BLIZZARD_SKIP[frameName]
               and not IsBlacklisted(frameName)
               and frameName ~= OWN_BUTTON_NAME then
                CollectButton(btn)
            end
        end
    end
end

local function ScanWhitelist()
    if not containerFrame then return end
    local s = GetSettings()
    for _, name in ipairs(s.whitelist) do
        if not collectedNames[name] then
            local frame = _G[name]
            if frame and type(frame) == "table" and frame.GetName and frame:GetName() then
                CollectButton(frame)
            end
        end
    end
end

local function SortCollected()
    table.sort(collectedButtons, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)
end

function MinimapButtonsModule:CollectAll()
    if InCombatLockdown() then
        self._needsCollect = true
        return
    end
    ScanLibDBIcon()
    ScanMinimapChildren()
    ScanWhitelist()
    SortCollected()
    self:LayoutContainer()
    self:UpdateBadge()
end

-- ─── Enhanced OneWoW Row ────────────────────────────────────────────────────

local OW_COMPANION_ICONS = {
    Core          = "Interface\\ICONS\\INV_Misc_Map_01",
    QoL           = "Interface\\ICONS\\INV_Misc_Gear_01",
    DevTools      = "Interface\\ICONS\\Trade_Engineering",
    AltTracker    = "Interface\\ICONS\\INV_Misc_GroupNeedMore",
    ShoppingList  = "Interface\\ICONS\\INV_Misc_Note_01",
    DirectDeposit = "Interface\\ICONS\\INV_Misc_Coin_01",
    Notes         = "Interface\\ICONS\\INV_Scroll_03",
    Trackers      = "Interface\\ICONS\\INV_Misc_Spyglass_03",
    Catalog       = "Interface\\ICONS\\INV_Misc_Book_09",
    Bags          = "Interface\\ICONS\\INV_Misc_Bag_07_Green",
    GUI           = "Interface\\ICONS\\Spell_Holy_MagicalSentry",
}

local function GetCompanionAction(compName)
    if not _G.OneWoW then return nil end
    local companions = _G.OneWoW._loadedComponents
    if not companions then return nil end
    for _, comp in ipairs(companions) do
        if comp.name == compName then
            if comp.cmd then
                return function()
                    local cmd = comp.cmd:gsub("^/", "")
                    local slashKey
                    for k, v in pairs(SlashCmdList) do
                        for i = 1, 10 do
                            local s = _G["SLASH_" .. k .. i]
                            if s and s:lower() == ("/" .. cmd):lower() then
                                slashKey = k
                                break
                            end
                        end
                        if slashKey then break end
                    end
                    if slashKey then
                        SlashCmdList[slashKey]("")
                    end
                end
            end
            return nil
        end
    end
    return nil
end

local function BuildEnhancedRow()
    if not containerFrame then return end
    for _, btn in ipairs(enhancedRow) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(enhancedRow)

    if not _G.OneWoW or not _G.OneWoW._loadedComponents then return end

    for _, comp in ipairs(_G.OneWoW._loadedComponents) do
        local icon = OW_COMPANION_ICONS[comp.name] or "Interface\\ICONS\\INV_Misc_QuestionMark"
        local action = GetCompanionAction(comp.name)

        local btn = CreateFrame("Button", nil, containerFrame)
        btn:SetSize(28, 28)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(icon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        if OneWoW_GUI then
            OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })
        end

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(comp.name, 1, 0.82, 0, 1)
            if comp.ver and comp.ver ~= "" then
                GameTooltip:AddLine("v" .. comp.ver, 0.7, 0.7, 0.7)
            end
            if comp.cmd then
                GameTooltip:AddLine(comp.cmd, 0.5, 0.5, 0.6)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        if action then
            btn:SetScript("OnClick", function() action() end)
        elseif _G.OneWoW and _G.OneWoW.GUI then
            btn:SetScript("OnClick", function()
                _G.OneWoW.GUI:Toggle()
            end)
        end

        table.insert(enhancedRow, btn)
    end
end

-- ─── Container Layout ───────────────────────────────────────────────────────

local function FilteredButtons()
    local filtered = {}
    local lower = searchFilter ~= "" and searchFilter:lower() or nil
    for _, btn in ipairs(collectedButtons) do
        if collectedMap[btn] ~= false then
            if not lower then
                table.insert(filtered, btn)
            else
                local name = btn:GetName() or ""
                if name:lower():find(lower, 1, true) then
                    table.insert(filtered, btn)
                end
            end
        end
    end
    return filtered
end

function MinimapButtonsModule:LayoutContainer()
    if not containerFrame then return end
    _layouting = true
    local s = GetSettings()
    local btnSize = s.buttonSize
    local spacing = s.buttonSpacing
    local maxCols = s.maxColumns
    local maxRows = s.maxRows

    for _, btn in ipairs(collectedButtons) do
        btn:Hide()
    end

    local visibleButtons = FilteredButtons()
    local totalCount = #visibleButtons + (s.enhancedMenu and #enhancedRow or 0)

    if maxRows == 1 and maxCols == 1 and totalCount > 1 then
        s.maxRows = 0
        maxRows = 0
        print("|cFFFFD100OneWoW QoL:|r " .. (ns.L["MMBTNS_1X1_WARNING"] or "1x1 guard triggered."))
    end

    local yOff = 0
    local maxW = 0

    if s.enhancedMenu and #enhancedRow > 0 then
        local owSize = 28
        local owSpacing = 2
        local owCols = math.min(#enhancedRow, maxCols)
        local owRows = math.ceil(#enhancedRow / owCols)

        for i, btn in ipairs(enhancedRow) do
            local row = math.floor((i - 1) / owCols)
            local col = (i - 1) % owCols
            btn:ClearAllPoints()
            btn:SetSize(owSize, owSize)
            btn:SetPoint("TOPLEFT", containerFrame, "TOPLEFT",
                4 + col * (owSize + owSpacing),
                -(4 + yOff + row * (owSize + owSpacing)))
            btn:Show()
        end

        local owWidth = owCols * (owSize + owSpacing) - owSpacing + 8
        if owWidth > maxW then maxW = owWidth end
        yOff = yOff + owRows * (owSize + owSpacing) + 2

        if not containerFrame._divider then
            containerFrame._divider = containerFrame:CreateTexture(nil, "ARTWORK")
            containerFrame._divider:SetHeight(1)
        end
        local div = containerFrame._divider
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 4, -(4 + yOff))
        div:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -4, -(4 + yOff))
        if OneWoW_GUI then
            div:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        else
            div:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        end
        div:Show()
        yOff = yOff + 4
    else
        for _, btn in ipairs(enhancedRow) do btn:Hide() end
        if containerFrame._divider then containerFrame._divider:Hide() end
    end

    local showSearch = #collectedButtons > 12 or searchFilter ~= ""
    if showSearch then
        if not searchBox then
            searchBox = CreateFrame("EditBox", nil, containerFrame, "BackdropTemplate")
            searchBox:SetSize(120, 20)
            searchBox:SetBackdrop(OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS or {
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            if OneWoW_GUI then
                searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            else
                searchBox:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
                searchBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
            searchBox:SetFontObject(GameFontHighlightSmall)
            searchBox:SetTextInsets(4, 4, 0, 0)
            searchBox:SetAutoFocus(false)
            searchBox:SetMaxLetters(30)
            if OneWoW_GUI then
                searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            searchBox._placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            searchBox._placeholder:SetPoint("LEFT", 6, 0)
            searchBox._placeholder:SetText(ns.L["MMBTNS_SEARCH_PLACEHOLDER"] or "Search...")

            searchBox:SetScript("OnTextChanged", function(self)
                local text = self:GetText() or ""
                searchFilter = text
                if self._placeholder then
                    self._placeholder:SetShown(text == "")
                end
                MinimapButtonsModule:LayoutContainer()
            end)
            searchBox:SetScript("OnEscapePressed", function(self)
                self:SetText("")
                self:ClearFocus()
            end)
        end

        searchBox:ClearAllPoints()
        searchBox:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 4, -(4 + yOff))
        searchBox:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -4, -(4 + yOff))
        searchBox:Show()
        yOff = yOff + 24
    else
        if searchBox then
            searchBox:Hide()
            searchFilter = ""
        end
    end

    local cols = math.min(#visibleButtons, maxCols)
    if cols < 1 then cols = 1 end
    local rows = math.ceil(#visibleButtons / cols)
    if maxRows > 0 and rows > maxRows then rows = maxRows end
    local maxVisible = cols * rows

    for i, btn in ipairs(visibleButtons) do
        if i <= maxVisible then
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols

            RawClearAllPoints(btn)

            local bSize = btnSize
            btn:SetSize(bSize, bSize)

            RawSetPoint(btn, "TOPLEFT", containerFrame, "TOPLEFT",
                4 + col * (bSize + spacing),
                -(4 + yOff + row * (bSize + spacing)))

            btn:Show()
        end
    end

    local gridW = cols * (btnSize + spacing) - spacing + 8
    if gridW > maxW then maxW = gridW end
    local gridH = rows * (btnSize + spacing) - spacing

    local totalH = yOff + gridH + 8
    if totalH < 20 then totalH = 20 end
    if maxW < 40 then maxW = 40 end

    containerFrame:SetSize(maxW, totalH)
    _layouting = false
end

-- ─── Container Frame ────────────────────────────────────────────────────────

local function CreateContainer()
    if containerFrame then return end

    containerFrame = CreateFrame("Frame", "OneWoW_QoL_MMBtnContainer", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    containerFrame:SetFrameStrata(CONTAINER_STRATA)
    containerFrame:SetFrameLevel(CONTAINER_LEVEL)
    containerFrame:SetClampedToScreen(true)
    containerFrame:SetBackdrop(OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_SOFT or {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileEdge = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if OneWoW_GUI then
        containerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        containerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    else
        containerFrame:SetBackdropColor(0, 0, 0, 1)
        containerFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
    containerFrame:SetSize(100, 100)
    containerFrame:Hide()
end

local function PositionContainer()
    if not containerFrame or not hubButton then return end
    local s = GetSettings()
    containerFrame:ClearAllPoints()
    local dir = s.growDirection or "down"
    if dir == "up" then
        containerFrame:SetPoint("BOTTOMLEFT", hubButton, "TOPLEFT", 0, 4)
    elseif dir == "left" then
        containerFrame:SetPoint("TOPRIGHT", hubButton, "TOPLEFT", -4, 0)
    elseif dir == "right" then
        containerFrame:SetPoint("TOPLEFT", hubButton, "TOPRIGHT", 4, 0)
    else
        containerFrame:SetPoint("TOPLEFT", hubButton, "BOTTOMLEFT", 0, -4)
    end
end

local function ShowContainer()
    if not containerFrame then return end
    MinimapButtonsModule:CollectAll()
    PositionContainer()
    containerFrame:Show()
    MinimapButtonsModule:StartAutoCloseTimer()
end

local function HideContainer()
    if not containerFrame then return end
    MinimapButtonsModule:CancelAutoCloseTimer()
    containerFrame:Hide()
end

local function ToggleContainer()
    if not containerFrame then return end
    if containerFrame:IsShown() then
        HideContainer()
    else
        ShowContainer()
    end
end

-- ─── Auto-close ─────────────────────────────────────────────────────────────

function MinimapButtonsModule:StartAutoCloseTimer()
    self:CancelAutoCloseTimer()
    local s = GetSettings()
    if s.closeMode ~= "autoclose" then return end

    local delay = s.autoCloseDelay or 3
    autoCloseTimer = C_Timer.NewTimer(delay, function()
        if containerFrame and containerFrame:IsShown() then
            if not MouseIsOver(containerFrame) and not (hubButton and MouseIsOver(hubButton)) then
                HideContainer()
            else
                MinimapButtonsModule:StartAutoCloseTimer()
            end
        end
    end)
end

function MinimapButtonsModule:CancelAutoCloseTimer()
    if autoCloseTimer then
        autoCloseTimer:Cancel()
        autoCloseTimer = nil
    end
end

-- ─── Hub Button ─────────────────────────────────────────────────────────────

local function CreateHubButton()
    if hubButton then return end

    hubButton = CreateFrame("Button", OWN_BUTTON_NAME, UIParent)
    hubButton:SetSize(36, 36)
    hubButton:SetFrameStrata(CONTAINER_STRATA)
    hubButton:SetFrameLevel(CONTAINER_LEVEL)
    hubButton:SetMovable(true)
    hubButton:SetClampedToScreen(true)
    hubButton:EnableMouse(true)
    hubButton:RegisterForDrag("LeftButton")
    hubButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = hubButton:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(GetCurrentIcon())
    tex:SetAllPoints()
    hubButton.icon = tex

    local badge = hubButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge:SetPoint("BOTTOMRIGHT", 2, -2)
    badge:SetText("")
    hubButton.badge = badge

    hubButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.L["MMBTNS_TOOLTIP_LINE1"] or "OneWoW Button Collector", 1, 0.82, 0)
        local count = #collectedButtons
        GameTooltip:AddLine(string.format(ns.L["MMBTNS_TOOLTIP_BUTTONS"] or "%d buttons", count), 0.7, 0.7, 0.8)
        GameTooltip:AddLine(ns.L["MMBTNS_TOOLTIP_HINT"] or "Left-click to toggle", 0.5, 0.5, 0.6)
        GameTooltip:AddLine(ns.L["MMBTNS_TOOLTIP_HINT_RIGHT"] or "Right-click for menu", 0.5, 0.5, 0.6)
        if not GetSettings().locked then
            GameTooltip:AddLine(ns.L["MMBTNS_TOOLTIP_DRAG"] or "Drag to move", 0.5, 0.5, 0.6)
        end
        GameTooltip:Show()
    end)
    hubButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    hubButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleContainer()
        elseif button == "RightButton" then
            MinimapButtonsModule:ShowContextMenu(self)
        end
    end)

    hubButton:SetScript("OnDragStart", function(self)
        if GetSettings().locked then return end
        self:StartMoving()
    end)
    hubButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveHubPosition()
    end)

    RestoreHubPosition()
    hubButton:Show()
end

function MinimapButtonsModule:UpdateIcon()
    if hubButton and hubButton.icon then
        hubButton.icon:SetTexture(GetCurrentIcon())
    end
end

function MinimapButtonsModule:UpdateBadge()
    if not hubButton or not hubButton.badge then return end
    local count = #collectedButtons
    if count > 0 then
        hubButton.badge:SetText(tostring(count))
    else
        hubButton.badge:SetText("")
    end
end

-- ─── Context Menu ───────────────────────────────────────────────────────────

function MinimapButtonsModule:ShowContextMenu(anchor)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
            local s = GetSettings()
            rootDescription:CreateTitle(ns.L["MMBTNS_TITLE"] or "Button Collector")
            local lockLabel = s.locked
                and (ns.L["MMBTNS_CONTEXT_UNLOCK"] or "Unlock")
                or  (ns.L["MMBTNS_CONTEXT_LOCK"]   or "Lock")
            rootDescription:CreateButton(lockLabel, function()
                s.locked = not s.locked
            end)
            rootDescription:CreateButton(ns.L["MMBTNS_CONTEXT_REFRESH"] or "Refresh", function()
                MinimapButtonsModule:CollectAll()
            end)
            rootDescription:CreateButton(ns.L["MMBTNS_CONTEXT_SETTINGS"] or "Settings", function()
                MinimapButtonsModule:OpenSettings()
            end)
        end)
    end
end

function MinimapButtonsModule:OpenSettings()
    if ns.UI and ns.UI.SelectFeature then
        ns.UI.SelectFeature("minimapbuttons")
    end
end

-- ─── Theme Update ───────────────────────────────────────────────────────────

function MinimapButtonsModule:ApplyTheme()
    if containerFrame and OneWoW_GUI then
        containerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        containerFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end
    if containerFrame and containerFrame._divider and OneWoW_GUI then
        containerFrame._divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
    if searchBox and OneWoW_GUI then
        searchBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        searchBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

function MinimapButtonsModule:OnEnable()
    CreateContainer()
    CreateHubButton()

    if GetSettings().enhancedMenu then
        BuildEnhancedRow()
    end

    self:RegisterEvents()

    C_Timer.After(0, function() self:CollectAll() end)
    C_Timer.After(1, function() self:CollectAll() end)
    C_Timer.After(3, function() self:CollectAll() end)

    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if libDBIcon and libDBIcon.RegisterCallback then
        libDBIcon.RegisterCallback(self, "LibDBIcon_IconCreated", function()
            C_Timer.After(0.2, function() self:CollectAll() end)
        end)
    end

    if OneWoW_GUI and OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
            MinimapButtonsModule:ApplyTheme()
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function()
            MinimapButtonsModule:UpdateIcon()
        end)
    end
end

function MinimapButtonsModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end

    for _, btn in ipairs(collectedButtons) do
        UncollectButton(btn)
    end
    wipe(collectedButtons)
    wipe(collectedNames)
    wipe(collectedMap)

    if containerFrame then
        containerFrame:Hide()
    end
    if hubButton then
        hubButton:Hide()
    end
end

function MinimapButtonsModule:OnToggle(toggleId, value)
end

function MinimapButtonsModule:RegisterEvents()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_MMBtnEvents")
    end
    self._eventFrame:UnregisterAllEvents()
    self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self._eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if MinimapButtonsModule._needsCollect then
                MinimapButtonsModule._needsCollect = false
                MinimapButtonsModule:CollectAll()
            end
        end
    end)
end

function MinimapButtonsModule:Refresh()
    if GetSettings().enhancedMenu then
        BuildEnhancedRow()
    end
    self:CollectAll()
end

ns.MinimapButtonsModule = MinimapButtonsModule
