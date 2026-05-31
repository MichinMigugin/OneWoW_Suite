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

-- ─── Raw UIParent methods (bypass noop overrides when positioning buttons) ──

local RawClearAllPoints = UIParent.ClearAllPoints
local RawSetPoint       = UIParent.SetPoint
local RawSetScale       = UIParent.SetScale
local RawSetParent      = UIParent.SetParent

local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- ─── Constants ──────────────────────────────────────────────────────────────

local CONTAINER_STRATA = "MEDIUM"
local CONTAINER_LEVEL  = 7

-- ─── State ──────────────────────────────────────────────────────────────────

local hubButton        = nil
local containerFrame   = nil
local hiddenContainer  = nil          -- parent for buttons whose pref is "hide"
local collectedButtons = {}
local collectedNames   = {}
local collectedMap     = {}
local hiddenButtons    = {}           -- [frame] = true for currently-hidden buttons
local enhancedRow      = {}
local searchBox        = nil
local searchFilter     = ""
local autoCloseTimer   = nil
local _layouting       = false
local _relayoutTimer   = nil
local _compartmentHooksRegistered = false

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

local noop = function(...) end

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
    local addon = OneWoW_QoL
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
    if s.buttonScale     == nil then s.buttonScale     = 10          end
    if s.locked          == nil then s.locked          = false       end
    if s.growDirection   == nil then s.growDirection    = "down"      end
    if s.hideCollected   == nil then s.hideCollected   = true        end
    if s.showTooltips    == nil then s.showTooltips    = true        end

    -- The old text-input whitelist / blacklist never worked reliably (see the
    -- bug report that triggered this rewrite). Drop them on first load so
    -- users don't carry around stale entries.
    s.whitelist        = nil
    s.blacklist        = nil
    s.mbbWhitelistSeed = nil

    -- Unified per-button preference model with three states:
    --
    --   "mini" — collected into the OneWoW panel (default for new entries)
    --   "map"  — left on the minimap (button stays where the addon put it)
    --   "hide" — hidden entirely (reparented to an offscreen hidden frame)
    --
    -- The DB remembers the user's choice across sessions so addons being
    -- temporarily disabled don't reset their preference.
    --
    --   s.buttons[frameName] = {
    --       pref        = "mini" | "map" | "hide",
    --       seen        = boolean,
    --       displayName = string,
    --   }
    if not s.buttons then s.buttons = {} end

    -- One-shot schema upgrade. v1 was the binary "show" / "hide" pair shipped
    -- briefly between this and the previous rewrite; map it onto the ternary
    -- "mini" / "map" / "hide" so "hide" doesn't silently change meaning.
    if (s.buttonsSchema or 1) < 2 then
        for _, info in pairs(s.buttons) do
            if info.pref == "show" then
                info.pref = "mini"
            elseif info.pref == "hide" then
                info.pref = "map"
            end
        end
        s.buttonsSchema = 2
    end

    return s
end

MinimapButtonsModule.GetSettings = GetSettings

-- Disabling tears down hooks/parenting; LibDBIcon + square minimap need a full UI reload to behave (same class of issue as Leatrix/minimap shape).
local function ShowDisableReloadDialog()
    local d = StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"]
    if not d then
        StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"] = {
            text = "",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = ReloadUI,
            OnCancel = function()
                print("|cFFFFD100OneWoW QoL:|r " .. (ns.L["MMBTNS_DISABLE_RELOAD_CHAT"] or "Reload later with /reload to fully restore minimap buttons."))
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        d = StaticPopupDialogs["ONEWOW_MMBTNS_RELOAD"]
    end
    d.text = ns.L["MMBTNS_DISABLE_RELOAD_TEXT"]
        or "Disabling this feature requires a UI reload to restore minimap buttons.\n\nReload now?"
    d.button1 = ns.L["MMBTNS_DISABLE_RELOAD_BTN"] or ACCEPT
    StaticPopup_Show("ONEWOW_MMBTNS_RELOAD")
end

-- ─── Per-button preference model ────────────────────────────────────────────

-- Derive a friendly UI label from a raw frame name. LibDBIcon frames follow
-- "LibDBIcon10_<Addon>" so the addon name shows up cleanly in the settings
-- list. Anything else falls back to the raw frame name.
local function MakeDisplayName(frameName, hint)
    if type(hint) == "string" and hint ~= "" and not hint:find("^LibDBIcon10_") then
        return hint
    end
    if type(frameName) ~= "string" then return tostring(frameName or "?") end
    local addonName = frameName:match("^LibDBIcon10_(.+)$")
    if addonName then return addonName end
    return frameName
end

local VALID_PREFS = { mini = true, map = true, hide = true }

local function RegisterDetectedButton(frameName, hint)
    if not frameName or frameName == "" then return end
    if BLIZZARD_SKIP[frameName] or frameName == OWN_BUTTON_NAME then return end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if not info then
        info = { pref = "mini", seen = true, displayName = MakeDisplayName(frameName, hint) }
        s.buttons[frameName] = info
    else
        info.seen = true
        if not VALID_PREFS[info.pref] then info.pref = "mini" end
        -- Refresh displayName if it was previously missing or if the new hint
        -- is more user-friendly than what we had.
        local better = MakeDisplayName(frameName, hint)
        if not info.displayName or info.displayName == "" or info.displayName == frameName then
            info.displayName = better
        end
    end
end

local function GetButtonPref(frameName)
    if not frameName then return "mini" end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if info and VALID_PREFS[info.pref] then return info.pref end
    return "mini"
end

local function SetButtonPref(frameName, pref)
    if not frameName or not VALID_PREFS[pref] then return end
    local s = GetSettings()
    local info = s.buttons[frameName]
    if not info then
        info = { pref = pref, seen = false, displayName = MakeDisplayName(frameName) }
        s.buttons[frameName] = info
    else
        info.pref = pref
    end
end

local function RemoveKnownButton(frameName)
    if not frameName then return end
    local s = GetSettings()
    s.buttons[frameName] = nil
end

local function ResetAllSeenFlags()
    local s = GetSettings()
    for _, info in pairs(s.buttons) do
        info.seen = false
    end
end

MinimapButtonsModule.MakeDisplayName       = MakeDisplayName
MinimapButtonsModule.RegisterDetectedButton = RegisterDetectedButton
MinimapButtonsModule.GetButtonPref          = GetButtonPref
MinimapButtonsModule.SetButtonPref          = SetButtonPref
MinimapButtonsModule.RemoveKnownButton      = RemoveKnownButton

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

-- ─── Button Detection (aligned with MinimapButtonButton Logic/Main.lua) ─────

local function isValidFrame(frame)
    return type(frame) == "table" and frame.IsObjectType and frame:IsObjectType("Frame")
end

local function isTomCatsButton(frameName)
    return frameName:match("^TomCats%-") ~= nil
end

local function nameEndsWithNumber(frameName)
    return frameName:match("%d$") ~= nil
end

local function nameMatchesButtonPattern(frameName)
    local patterns = {
        "^LibDBIcon10_",
        "MinimapButton",
        "MinimapFrame",
        "MinimapIcon",
        "[-_]Minimap[-_]",
        "Minimap$",
    }
    for _, pattern in ipairs(patterns) do
        if frameName:match(pattern) then return true end
    end
    return false
end

local function isMinimapButton(frame)
    local frameName = frame and frame.GetName and frame:GetName()
    if not frameName then return false end

    if issecurevariable and _G[frameName] and issecurevariable(_G, frameName) then
        return false
    end

    if isTomCatsButton(frameName) then return true end
    if nameEndsWithNumber(frameName) then return false end

    return nameMatchesButtonPattern(frameName)
end

local function updateLayoutIfVisibilityChanged(frame)
    if not frame or not frame._OneWoWMBBCollected then return end
    -- During LayoutContainer we Hide() every collected button; hooksecurefunc would
    -- set collectedMap to false and FilteredButtons() would drop all icons (empty panel).
    if _layouting then return end
    local visibility = frame:IsShown()
    if collectedMap[frame] ~= visibility then
        collectedMap[frame] = visibility
        ScheduleRelayout()
    end
end

-- Parent hide (e.g. closing the collector) can fire Hide on children and poison
-- collectedMap; reset when reopening or after addon compartment toggles.
local function ResetCollectedVisibilityMap()
    for _, btn in ipairs(collectedButtons) do
        if btn and btn._OneWoWMBBCollected then
            collectedMap[btn] = true
        end
    end
end

-- Match Leatrix Plus / LibDBIcon: square minimap uses a small radius; round uses full orbit.
local function SyncLibDBIconRadiusToMinimapShape()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.SetButtonRadius then return end
    local shape = "ROUND"
    if GetMinimapShape then
        shape = GetMinimapShape() or "ROUND"
    end
    if type(shape) == "string" and strupper(shape) == "SQUARE" then
        lib:SetButtonRadius(0.165)
    else
        lib:SetButtonRadius(1)
    end
end

local function LibDBIconNotifyRestored(frame)
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not frame then return end
    local list = lib.GetButtonList and lib:GetButtonList()
    if not list then return end
    for _, n in ipairs(list) do
        if type(n) == "string" then
            local btn = lib.GetMinimapButton and lib:GetMinimapButton(n)
            if btn == frame then
                if type(lib.Show) == "function" then
                    pcall(lib.Show, lib, n)
                end
                break
            end
        end
    end
end

local function RefreshAllLibDBIcons()
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.GetButtonList or not lib.Show then return end
    SyncLibDBIconRadiusToMinimapShape()
    local list = lib:GetButtonList()
    if not list then return end
    for _, n in ipairs(list) do
        pcall(lib.Show, lib, n)
    end
end

-- ─── Button Collection (MBB-style: reparent, raw scale, hooksecurefunc Show/Hide)

local function ApplyCollectedButtonScale(frame)
    local s = GetSettings()
    local scale = (s.buttonScale or 10) / 10
    if scale > 0 then
        RawSetScale(frame, scale)
    end
end

function MinimapButtonsModule:ApplyButtonScale()
    for _, frame in ipairs(collectedButtons) do
        if frame and frame._OneWoWMBBCollected then
            ApplyCollectedButtonScale(frame)
        end
    end
    self:LayoutContainer()
end

local function CollectButton(frame)
    local name = frame:GetName()
    if not name or collectedNames[name] then return end
    if not GetSettings().hideCollected then return end

    local origEnter = frame:GetScript("OnEnter")
    local origLeave = frame:GetScript("OnLeave")

    collectedNames[name] = true
    frame._OneWoWMBBCollected = true

    frame:SetParent(containerFrame)
    frame:SetFrameStrata(CONTAINER_STRATA)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    if frame.SetIgnoreParentScale then
        frame:SetIgnoreParentScale(false)
    end
    ApplyCollectedButtonScale(frame)

    frame.ClearAllPoints = noop
    frame.SetPoint       = noop
    frame.SetParent      = noop
    frame.SetScale       = noop

    if not frame._OneWoWMBBShowHooked then
        hooksecurefunc(frame, "Show", function()
            updateLayoutIfVisibilityChanged(frame)
        end)
        hooksecurefunc(frame, "Hide", function()
            updateLayoutIfVisibilityChanged(frame)
        end)
        frame._OneWoWMBBShowHooked = true
    end

    frame._OneWoWMBBOrigEnter = origEnter
    frame._OneWoWMBBOrigLeave = origLeave
    frame:SetScript("OnEnter", function(self)
        if frame._OneWoWMBBOrigEnter then frame._OneWoWMBBOrigEnter(self) end
        if not GetSettings().showTooltips then
            GameTooltip:Hide()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if frame._OneWoWMBBOrigLeave then frame._OneWoWMBBOrigLeave(self) end
        if not GetSettings().showTooltips then
            GameTooltip:Hide()
        end
    end)

    table.insert(collectedButtons, frame)
    collectedMap[frame] = frame:IsShown()
end

local function UncollectButton(frame)
    frame._OneWoWMBBCollected = false
    local n = frame:GetName()
    if n then
        collectedNames[n] = nil
    end
    collectedMap[frame] = nil

    frame.ClearAllPoints = nil
    frame.SetPoint       = nil
    frame.SetParent      = nil
    frame.SetScale       = nil
    RawSetScale(frame, 1)

    frame:SetScript("OnEnter", frame._OneWoWMBBOrigEnter)
    frame:SetScript("OnLeave", frame._OneWoWMBBOrigLeave)
    frame._OneWoWMBBOrigEnter = nil
    frame._OneWoWMBBOrigLeave = nil

    -- Drop layout anchors from the collector grid; otherwise icons stay where the panel was.
    RawClearAllPoints(frame)
    frame:SetParent(Minimap)
    if frame.Show then frame:Show() end
    LibDBIconNotifyRestored(frame)
end

-- Locate frame for `frameName` regardless of whether we're already holding
-- it. Walks our own collected/hidden tables first (fastest), then falls back
-- to LibDBIcon, LibMapButton, Minimap children, and finally _G.
local function FindButtonFrame(frameName)
    if not frameName then return nil end

    for _, btn in ipairs(collectedButtons) do
        if btn and btn.GetName and btn:GetName() == frameName then
            return btn
        end
    end
    for btn in pairs(hiddenButtons) do
        if btn and btn.GetName and btn:GetName() == frameName then
            return btn
        end
    end

    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList then
        local list = lib:GetButtonList()
        if list then
            for _, n in ipairs(list) do
                if type(n) == "string" then
                    local btn = lib.GetMinimapButton and lib:GetMinimapButton(n)
                    if btn and btn.GetName and btn:GetName() == frameName then
                        return btn
                    end
                end
            end
        end
    end

    local libMap = LibStub and LibStub("LibMapButton-1.1", true)
    if libMap and libMap.buttons then
        for _, btn in pairs(libMap.buttons) do
            if btn and btn.GetName and btn:GetName() == frameName then
                return btn
            end
        end
    end

    local parents = { Minimap, MinimapBackdrop, MinimapCluster }
    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if child and child.GetName and child:GetName() == frameName then
                    return child
                end
            end
        end
    end

    local g = _G[frameName]
    if type(g) == "table" and g.GetObjectType then
        return g
    end
    return nil
end

local function UncollectByName(frameName)
    for i = #collectedButtons, 1, -1 do
        local btn = collectedButtons[i]
        if btn and btn.GetName and btn:GetName() == frameName then
            tremove(collectedButtons, i)
            UncollectButton(btn)
            return btn
        end
    end
    return nil
end

-- Hidden buttons live as children of an offscreen, permanently :Hide()-ed
-- frame. Children of a hidden parent never render even if their own :Show()
-- has been called, so we don't need to fight the owning addon every frame.
local function EnsureHiddenContainer()
    if hiddenContainer then return hiddenContainer end
    hiddenContainer = CreateFrame("Frame", "OneWoW_QoL_MMBtnHidden", UIParent)
    hiddenContainer:SetSize(1, 1)
    hiddenContainer:Hide()
    return hiddenContainer
end

local function HideButton(frame)
    if not frame or hiddenButtons[frame] then return end
    EnsureHiddenContainer()

    -- Stash originals so we can put them back when the user switches pref.
    -- _OneWoWMBBOrigShow is unused right now (the hidden parent is enough)
    -- but kept as a marker for future swap-back logic.
    frame._OneWoWMBBHidden = true

    -- The addon may still call SetParent on its own button; noop it so we
    -- don't lose the hidden parent. Restored in UnhideButton.
    frame.SetParent = noop
    frame.ClearAllPoints = noop
    frame.SetPoint = noop

    RawClearAllPoints(frame)
    RawSetParent(frame, hiddenContainer)
    if frame.Hide then frame:Hide() end

    hiddenButtons[frame] = true
end

local function UnhideButton(frame)
    if not frame or not hiddenButtons[frame] then return end

    frame.SetParent = nil
    frame.ClearAllPoints = nil
    frame.SetPoint = nil
    frame._OneWoWMBBHidden = nil

    RawClearAllPoints(frame)
    frame:SetParent(Minimap)
    if frame.Show then frame:Show() end

    hiddenButtons[frame] = nil
    LibDBIconNotifyRestored(frame)
end

-- Move a single button to the state implied by `pref`. Idempotent — calling
-- twice with the same pref is a no-op. Caller is responsible for triggering
-- LayoutContainer / UpdateBadge afterwards if it's batching multiple updates.
local function ApplyPrefImmediate(frameName, pref)
    if not VALID_PREFS[pref] then return end
    local frame = FindButtonFrame(frameName)
    if not frame then return end

    local isCollected = collectedNames[frameName] == true
    local isHidden    = hiddenButtons[frame] == true

    if pref == "mini" then
        if isHidden then UnhideButton(frame) end
        if not isCollected and containerFrame and GetSettings().hideCollected then
            CollectButton(frame)
        end
    elseif pref == "map" then
        if isCollected then UncollectByName(frameName) end
        if isHidden then UnhideButton(frame) end
    elseif pref == "hide" then
        if isCollected then UncollectByName(frameName) end
        if not isHidden then HideButton(frame) end
    end
end

-- Discovery + collection are decoupled: ConsiderButton always registers the
-- button (so the settings UI can list it even when the collector is off),
-- then delegates the "where should this live?" decision to ApplyPrefImmediate
-- so the same logic is shared between scans and direct UI clicks.
local function ConsiderButton(frame, hint)
    if not frame or not frame.GetName then return end
    local frameName = frame:GetName()
    if not frameName
        or BLIZZARD_SKIP[frameName]
        or frameName == OWN_BUTTON_NAME then
        return
    end
    RegisterDetectedButton(frameName, hint)

    if not containerFrame or not GetSettings().hideCollected then return end
    ApplyPrefImmediate(frameName, GetButtonPref(frameName))
end

-- Some addons parent their button to MinimapBackdrop or MinimapCluster instead
-- of Minimap directly; walk all three so they're picked up.
local function ScanMinimapChildren()
    local parents = { Minimap, MinimapBackdrop, MinimapCluster }
    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if (child:IsObjectType("Button") or child:IsObjectType("Frame"))
                    and isValidFrame(child) and isMinimapButton(child) then
                    ConsiderButton(child)
                end
            end
        end
    end
end

local function ScanLibDBIcon()
    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not libDBIcon then return end

    local list = libDBIcon:GetButtonList()
    if not list then return end
    for _, name in ipairs(list) do
        if type(name) == "string" then
            local btn = libDBIcon:GetMinimapButton(name)
            ConsiderButton(btn, name)
        end
    end
end

local function ScanLibMapButton()
    local libMap = LibStub and LibStub("LibMapButton-1.1", true)
    if not libMap or not libMap.buttons then return end
    for _, btn in pairs(libMap.buttons) do
        ConsiderButton(btn)
    end
end

-- Lightweight discovery-only pass: refreshes seen flags and the s.buttons
-- map without touching collection state. Used by the settings UI before
-- listing rows so "Enabled/Disabled" status is always current.
function MinimapButtonsModule:DiscoverButtons()
    ResetAllSeenFlags()
    ScanLibDBIcon()
    ScanLibMapButton()
    ScanMinimapChildren()

    -- Buttons we're already holding (collected into the panel or stashed in
    -- the hidden container) are no longer children of Minimap, so the scans
    -- above can't see them. Mark them seen explicitly — by definition the
    -- owning addon is loaded if we still have the frame reference.
    for _, btn in ipairs(collectedButtons) do
        local n = btn and btn.GetName and btn:GetName()
        if n then RegisterDetectedButton(n) end
    end
    for btn in pairs(hiddenButtons) do
        local n = btn and btn.GetName and btn:GetName()
        if n then RegisterDetectedButton(n) end
    end
end

local function SortCollected()
    table.sort(collectedButtons, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)
end

-- Returns a sorted array of { name, displayName, pref, seen } for the UI.
function MinimapButtonsModule:GetKnownButtons()
    local s = GetSettings()
    local out = {}
    for name, info in pairs(s.buttons) do
        out[#out + 1] = {
            name        = name,
            displayName = info.displayName or MakeDisplayName(name),
            pref        = info.pref or "show",
            seen        = info.seen == true,
        }
    end
    table.sort(out, function(a, b)
        local ad = (a.displayName or ""):lower()
        local bd = (b.displayName or ""):lower()
        if ad == bd then return (a.name or "") < (b.name or "") end
        return ad < bd
    end)
    return out
end

-- Called by the UI when the user picks Mini / Map / Hide on a row. Applies
-- the change immediately via the shared ApplyPrefImmediate helper so the
-- click-driven path goes through exactly the same state machine as scans.
function MinimapButtonsModule:ApplyButtonPref(frameName, pref)
    if not frameName or not VALID_PREFS[pref] then return end
    SetButtonPref(frameName, pref)
    ApplyPrefImmediate(frameName, pref)
    self:LayoutContainer()
    self:UpdateBadge()
end

function MinimapButtonsModule:CollectAll()
    local s = GetSettings()
    if not s.hideCollected then
        SyncLibDBIconRadiusToMinimapShape()
        local copy = {}
        for _, b in ipairs(collectedButtons) do
            copy[#copy + 1] = b
        end
        for _, btn in ipairs(copy) do
            UncollectButton(btn)
        end
        wipe(collectedButtons)
        wipe(collectedNames)
        wipe(collectedMap)
        -- "Don't hide anything" also implies "stop hiding any buttons you
        -- were holding offscreen" — restore them to the minimap.
        local hiddenCopy = {}
        for btn in pairs(hiddenButtons) do
            hiddenCopy[#hiddenCopy + 1] = btn
        end
        for _, btn in ipairs(hiddenCopy) do
            UnhideButton(btn)
        end
        RefreshAllLibDBIcons()
        C_Timer.After(0, function()
            SyncLibDBIconRadiusToMinimapShape()
            RefreshAllLibDBIcons()
        end)
        self:LayoutContainer()
        self:UpdateBadge()
        return
    end

    -- First refresh discovery so seen flags are current. ConsiderButton calls
    -- ApplyPrefImmediate for every discovered button, so this single pass
    -- collects / leaves-on-map / hides each button per its stored pref.
    self:DiscoverButtons()

    -- Reconcile any buttons we're still holding that no longer have a
    -- matching pref (e.g. user toggled MAP or HIDE on a collected button
    -- when the settings panel was closed and the discovery scan can't undo
    -- that on its own).
    for i = #collectedButtons, 1, -1 do
        local btn = collectedButtons[i]
        local n = btn and btn.GetName and btn:GetName()
        if n then
            local pref = GetButtonPref(n)
            if pref ~= "mini" then
                tremove(collectedButtons, i)
                UncollectButton(btn)
                if pref == "hide" then HideButton(btn) end
            end
        end
    end

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
    if not OneWoW then return nil end
    local companions = OneWoW._loadedComponents
    if not companions then return nil end
    for _, comp in ipairs(companions) do
        if comp.name == compName then
            -- Core and GUI both ultimately just toggle the main OneWoW window.
            -- Skip the slash dispatch (pairs(SlashCmdList) iteration order can
            -- mis-resolve "/1w" on some clients, leaving the Core tile dead).
            if comp.name == "Core" or comp.name == "GUI" then
                return function()
                    if OneWoW and OneWoW.GUI then
                        OneWoW.GUI:Toggle()
                    end
                end
            end
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

    if not OneWoW or not OneWoW._loadedComponents then return end

    for _, comp in ipairs(OneWoW._loadedComponents) do
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
            GameTooltip:AddLine(comp.name, 1, 0.82, 0, true)
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
        elseif OneWoW and OneWoW.GUI then
            btn:SetScript("OnClick", function()
                OneWoW.GUI:Toggle()
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
    ResetCollectedVisibilityMap()
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

    SyncLibDBIconRadiusToMinimapShape()
    for _, btn in ipairs(collectedButtons) do
        UncollectButton(btn)
    end
    wipe(collectedButtons)
    wipe(collectedNames)
    wipe(collectedMap)

    -- Disabling the feature must release every button we were hiding —
    -- otherwise icons stay invisible until the user notices and re-enables.
    local hiddenCopy = {}
    for btn in pairs(hiddenButtons) do
        hiddenCopy[#hiddenCopy + 1] = btn
    end
    for _, btn in ipairs(hiddenCopy) do
        UnhideButton(btn)
    end

    RefreshAllLibDBIcons()
    C_Timer.After(0, function()
        SyncLibDBIconRadiusToMinimapShape()
        RefreshAllLibDBIcons()
    end)

    if containerFrame then
        containerFrame:Hide()
    end
    if hubButton then
        hubButton:Hide()
    end

    C_Timer.After(0, ShowDisableReloadDialog)
end

function MinimapButtonsModule:OnToggle(toggleId, value)
end

function MinimapButtonsModule:RegisterAddonCompartmentHooks()
    if _compartmentHooksRegistered then return end
    local f = AddonCompartmentFrame
    if not f or not f.HookScript then return end
    _compartmentHooksRegistered = true
    local function onCompartmentVisibility()
        if not containerFrame or not containerFrame:IsShown() then return end
        ResetCollectedVisibilityMap()
        ScheduleRelayout()
    end
    f:HookScript("OnShow", onCompartmentVisibility)
    f:HookScript("OnHide", onCompartmentVisibility)
end

function MinimapButtonsModule:RegisterEvents()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_MMBtnEvents")
    end
    self._eventFrame:UnregisterAllEvents()
    if IS_RETAIL then
        self._eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
        self._eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
    end

    self._eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PET_BATTLE_OPENING_START" then
            if hubButton then hubButton:Hide() end
        elseif event == "PET_BATTLE_CLOSE" then
            if hubButton then hubButton:Show() end
        end
    end)

    self:RegisterAddonCompartmentHooks()
end

function MinimapButtonsModule:Refresh()
    if GetSettings().enhancedMenu then
        BuildEnhancedRow()
    end
    self:CollectAll()
end

function MinimapButtonsModule:ApplyMinimapShapeToLibDBIcons()
    SyncLibDBIconRadiusToMinimapShape()
    RefreshAllLibDBIcons()
    C_Timer.After(0, function()
        SyncLibDBIconRadiusToMinimapShape()
        RefreshAllLibDBIcons()
    end)
end

ns.MinimapButtonsModule = MinimapButtonsModule
