local _, ns = ...

-- ============================================================================
-- BlizzardBankHost
-- ============================================================================
-- Owns the "hosted Blizzard bank" contract while OneWoW's custom bank UI is
-- enabled. Blizzard still drives bank open via BankFrame_Open → ShowUIPanel,
-- and OneWoW still needs BankFrame/BankPanel Shown for:
--   - SetBankType / active bank-type state
--   - hitchhiking the secure PurchaseButton (overrideBankType)
--   - tab-settings menu data plumbing
--
-- Hosting must therefore keep those frames alive, but MUST also guarantee they
-- never appear on-screen or intercept mouse over OneWoW's bank/bags windows.
--
-- Failure mode this replaces: SuppressBankFrame parked BankFrame once, then
-- early-returned on later opens. BankFrame_Open/ShowUIPanel put it back at the
-- normal left UIPanel position (alpha 0), BankPanel regenerated its item grid +
-- AutoSortButton, and those invisible widgets stole hover ("Clean Up Bank",
-- wrong item tooltips, no OneWoW button highlight).
--
-- Contract:
--   Begin()     — one-time install (scripts, UIPanel, hooks, container sink)
--   Apply()     — idempotent re-park + input neutralize (every open / panel prep)
--   PreparePanel(bankType) — Show + SetBankType + Apply
--   ReleasePanel() — Hide BankPanel while keeping the host installed
--   End()       — tear down when custom bank UI is disabled
-- ============================================================================

ns.BlizzardBankHost = {}
local Host = ns.BlizzardBankHost

local OFFSCREEN_POINT = { "TOPLEFT", UIParent, "BOTTOMLEFT", 0, -10000 }

local active = false
local applying = false
local hooksInstalled = false
local hiddenParent
local origOnShow
local origOnHide
local origOnEvent
local origUIPanelEnabled

---@param frame Frame
---@param enabled boolean
local function SetMouseEnabledRecursive(frame, enabled)
    if not frame then return end
    if frame.EnableMouse then
        frame:EnableMouse(enabled)
    end
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(enabled)
    end
    local i = 1
    local child = select(i, frame:GetChildren())
    while child do
        SetMouseEnabledRecursive(child, enabled)
        i = i + 1
        child = select(i, frame:GetChildren())
    end
end

local function SetUIPanelEnabled(frame, enabled)
    SetUIPanelAttribute(frame, "enabled", enabled)
end

local function GetUIPanelEnabled(frame)
    local value = frame:GetAttribute("UIPanelLayout-enabled")
    if value == nil then
        return true
    end
    return value and true or false
end

--- Park BankFrame off-screen and invisible. Safe to call repeatedly.
local function ParkBankFrame()
    if not BankFrame then return end
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint(OFFSCREEN_POINT[1], OFFSCREEN_POINT[2], OFFSCREEN_POINT[3], OFFSCREEN_POINT[4], OFFSCREEN_POINT[5])
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
    BankFrame:EnableMouseWheel(false)
end

--- Drop Blizzard's hosted item grid / sort chrome so it cannot steal hover.
--- PurchasePrompt (and its secure PurchaseButton) stay available for hitchhiking.
---@param panel Frame
local function NeutralizeBankPanel(panel)
    if not panel then return end

    -- Release any generated BankPanel item buttons. BAG_UPDATE may recreate
    -- them via Clean(); GenerateItemSlots hook below releases those too.
    panel:SetItemDisplayEnabled(false)

    if panel.AutoSortButton then
        panel.AutoSortButton:Hide()
        panel.AutoSortButton:EnableMouse(false)
    end

    SetMouseEnabledRecursive(panel, false)
end

local function ReparentLegacyBankContainers(toHidden)
    if not hiddenParent then return end
    for i = 7, 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf then
            if toHidden then
                cf:SetParent(hiddenParent)
            elseif cf:GetParent() == hiddenParent then
                cf:SetParent(UIParent)
            end
        end
    end
end

function Host:IsActive()
    return active
end

--- Idempotent visual + input enforcement. Call after any Blizzard path that may
--- have shown, resized, or regenerated BankFrame/BankPanel.
function Host:Apply()
    if not active or not BankFrame or applying then return end
    applying = true

    ParkBankFrame()
    if not BankFrame:IsShown() then
        BankFrame:Show()
    end

    -- Parent EnableMouse(false) does not disable children. Kill the whole tree,
    -- then strip BankPanel's generated item grid / AutoSort if the panel is live.
    SetMouseEnabledRecursive(BankFrame, false)

    local panel = BankFrame.BankPanel
    if panel and panel:IsShown() then
        NeutralizeBankPanel(panel)
    end

    applying = false
end

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    -- BankFrame_Open → ShowUIPanel places BankFrame in the left UIPanel slot
    -- before BANKFRAME_OPENED reaches us. Re-apply immediately after.
    hooksecurefunc("BankFrame_Open", function()
        if active then
            Host:Apply()
        end
    end)

    hooksecurefunc("ShowUIPanel", function(frame)
        if active and frame == BankFrame then
            Host:Apply()
        end
    end)

    hooksecurefunc("UpdateUIPanelPositions", function(frame)
        if not active then return end
        if frame == nil or frame == BankFrame then
            Host:Apply()
        end
    end)

    -- BankPanel regenerates its item grid on show / bag updates. Release those
    -- slots whenever we are hosting so they never become invisible hit targets.
    hooksecurefunc(BankPanelMixin, "GenerateItemSlotsForSelectedTab", function(panel)
        if not active then return end
        panel.itemButtonPool:ReleaseAll()
        if panel.AutoSortButton then
            panel.AutoSortButton:Hide()
            panel.AutoSortButton:EnableMouse(false)
        end
        SetMouseEnabledRecursive(panel, false)
    end)

    hooksecurefunc(BankPanelMixin, "RefreshBankPanel", function(panel)
        if not active then return end
        NeutralizeBankPanel(panel)
    end)
end

--- One-time host install. Subsequent opens call Apply()/PreparePanel() only.
function Host:Begin()
    if not BankFrame then return end

    if not active then
        active = true
        hiddenParent = CreateFrame("Frame")
        hiddenParent:Hide()

        origOnShow = BankFrame:GetScript("OnShow")
        origOnHide = BankFrame:GetScript("OnHide")
        origOnEvent = BankFrame:GetScript("OnEvent")
        origUIPanelEnabled = GetUIPanelEnabled(BankFrame)

        -- Stop Blizzard open/close scripts from fighting the custom bank UI,
        -- and pull BankFrame out of UIPanel layout so ShowUIPanel cannot park
        -- it on-screen again.
        BankFrame:SetScript("OnShow", nil)
        BankFrame:SetScript("OnHide", nil)
        BankFrame:SetScript("OnEvent", nil)
        SetUIPanelEnabled(BankFrame, false)

        ReparentLegacyBankContainers(true)
        InstallHooks()
    end

    self:Apply()
end

--- Show BankPanel at the requested bank type, then re-assert host visuals.
--- Prefer this over raw BankPanel:Show()/SetBankType at call sites.
---@param bankType Enum.BankType
function Host:PreparePanel(bankType)
    self:Begin()
    if not (BankFrame and BankFrame.BankPanel) then return end

    local panel = BankFrame.BankPanel
    -- SetBankType only Reset()s when already shown; when hidden, OnShow→Reset
    -- uses the type set here. Preserve that Blizzard ordering.
    if bankType ~= nil then
        panel:SetBankType(bankType)
    end
    panel:Show()
    self:Apply()
end

function Host:ReleasePanel()
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Hide()
    end
end

--- Tear down hosting when the custom bank UI is turned off.
function Host:End()
    if not active then return end
    active = false

    if BankFrame then
        if origOnShow then
            BankFrame:SetScript("OnShow", origOnShow)
        end
        if origOnHide then
            BankFrame:SetScript("OnHide", origOnHide)
        end
        if origOnEvent then
            BankFrame:SetScript("OnEvent", origOnEvent)
        end

        if origUIPanelEnabled ~= nil then
            SetUIPanelEnabled(BankFrame, origUIPanelEnabled)
        else
            SetUIPanelEnabled(BankFrame, true)
        end

        self:ReleasePanel()
        SetMouseEnabledRecursive(BankFrame, true)
        BankFrame:SetAlpha(1)
        -- Leave points alone; the next ShowUIPanel will place it normally.
    end

    ReparentLegacyBankContainers(false)

    origOnShow = nil
    origOnHide = nil
    origOnEvent = nil
    origUIPanelEnabled = nil
    hiddenParent = nil
end

-- ---------------------------------------------------------------------------
-- ns-facing wrappers (preserve existing Suppress/Restore call names)
-- ---------------------------------------------------------------------------

function ns:SuppressBankFrame()
    Host:Begin()
end

function ns:RestoreBankFrame()
    Host:End()
end

--- @param bankType Enum.BankType|nil
function ns:PrepareBlizzardBankPanel(bankType)
    Host:PreparePanel(bankType)
end

function ns:ReleaseBlizzardBankPanel()
    Host:ReleasePanel()
end
