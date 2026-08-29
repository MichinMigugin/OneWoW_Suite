local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI
local Restriction = OneWoW.Restriction

-- ============================================================================
-- Magic button: click-mirror Start / Create / Complete on OrderView.
-- Never calls ClaimOrder / craft / fulfill from Lua (those have restrictions).
-- The visible button stays on OrderInfo (left) for Start, Craft, and Complete
-- so the mouse does not move. Concentration is an icon beside Craft only.
-- ============================================================================

local INNER_NAME = "OneWoWQoLCOInner"
local MAGIC_NAME = "OneWoWQoLCOMagic"
local CONC_NAME = "OneWoWQoLCOConc"
local MAGIC_W = 160
local MAGIC_H = 24
local MAGIC_Y = 50
local CONC_SIZE = 24
local CONC_GAP = OneWoW_GUI.Constants.SPACING.SM
local CONC_ICON = "Interface\\ICONS\\UI_Concentration"

local clickQueue = {}

local function ModuleOn()
    return ns.ModuleRegistry:IsEnabled("craftingorders")
end

local function GetOrderView()
    local pf = ProfessionsFrame
    local page = pf and pf.OrdersPage
    return page and page.OrderView
end

local function GetConcentrateButton(view)
    local details = view and view.OrderDetails
    local form = details and details.SchematicForm
    local detailsPanel = form and form.Details
    local choices = detailsPanel and detailsPanel.CraftingChoicesContainer
    local detailsConc = choices and choices.ConcentrateContainer
    local detailsBtn = detailsConc and detailsConc.ConcentrateToggleButton
    if detailsBtn and detailsConc:IsShown() then
        return detailsBtn
    end
    local formConc = form and form.Concentrate
    return formConc and formConc.ConcentrateToggleButton
end

local function GetConfirmButton()
    local visible = StaticPopup_Visible("GENERIC_CONFIRMATION")
    if not visible then return nil end
    return _G[visible .. "Button1"]
end

local function CurrentActionButton(view)
    if not view then return nil, nil end
    if view.CompleteOrderButton and view.CompleteOrderButton:IsShown() then
        return view.CompleteOrderButton, "complete"
    end
    if view.CreateButton and view.CreateButton:IsShown() then
        return view.CreateButton, "create"
    end
    if view.OrderInfo and view.OrderInfo.StartOrderButton and view.OrderInfo.StartOrderButton:IsShown() then
        return view.OrderInfo.StartOrderButton, "start"
    end
    return nil, nil
end

local function SetHiddenChrome(btn, hidden)
    if not btn then return end
    if hidden then
        btn:SetAlpha(0)
        btn:EnableMouse(false)
    else
        btn:SetAlpha(1)
        btn:EnableMouse(true)
    end
end

local function RestoreBlizzardButtons(view)
    if not view then return end
    SetHiddenChrome(view.CreateButton, false)
    SetHiddenChrome(view.CompleteOrderButton, false)
    if view.OrderInfo then
        SetHiddenChrome(view.OrderInfo.StartOrderButton, false)
    end
end

local function HideBlizzardButtons(view)
    if not view then return end
    SetHiddenChrome(view.CreateButton, true)
    SetHiddenChrome(view.CompleteOrderButton, true)
    if view.OrderInfo then
        SetHiddenChrome(view.OrderInfo.StartOrderButton, true)
    end
end

-- Standard suite button chrome (matches CreateFitTextButton): backdrop fill,
-- themed border, hover/pressed states, muted label when disabled. The magic
-- button cannot be a CreateFitTextButton (it must stay an
-- InsecureActionButtonTemplate for the secure click mirror), so it carries
-- the same chrome by hand.
local function ApplyMagicChrome(magic, hover)
    if not magic:IsEnabled() then
        magic:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        magic:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        magic.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        return
    end
    if hover then
        magic:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        magic:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
        magic.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        magic:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        magic:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
        magic.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local function PlaceMagic(magic, view)
    local info = view and view.OrderInfo
    if not info then return end
    magic:SetParent(info)
    magic:ClearAllPoints()
    magic:SetPoint("BOTTOM", info, "BOTTOM", 0, MAGIC_Y)
    magic:SetSize(MAGIC_W, MAGIC_H)
    magic:SetFrameLevel(info:GetFrameLevel() + 20)
end

local function ApplySecureAttributes(fn)
    Restriction.RunWhenUnrestricted("protected", "QoL_craftingorders_magic", fn)
end

local function NoopCastBar()
end

function M:InstallCastBarNoop()
    if not M._origSetOverrideCastBarActive and ProfessionsCrafterOrderViewMixin then
        M._origSetOverrideCastBarActive = ProfessionsCrafterOrderViewMixin.SetOverrideCastBarActive
        ProfessionsCrafterOrderViewMixin.SetOverrideCastBarActive = NoopCastBar
    end
    local view = GetOrderView()
    if view and not M._viewCastBarNoop then
        M._viewCastBarNoop = true
        M._castBarView = view
        M._origViewSetOverrideCastBarActive = view.SetOverrideCastBarActive
        view.SetOverrideCastBarActive = NoopCastBar
    end
end

function M:RestoreCastBar()
    if M._origSetOverrideCastBarActive and ProfessionsCrafterOrderViewMixin then
        ProfessionsCrafterOrderViewMixin.SetOverrideCastBarActive = M._origSetOverrideCastBarActive
    end
    M._origSetOverrideCastBarActive = nil
    local view = M._castBarView or GetOrderView()
    if view and M._origViewSetOverrideCastBarActive then
        view.SetOverrideCastBarActive = M._origViewSetOverrideCastBarActive
        view.isOverrideCastBarActive = false
    end
    M._castBarView = nil
    M._viewCastBarNoop = nil
    M._origViewSetOverrideCastBarActive = nil
end

local function UpdateCastBar(bar, view)
    if not bar then return end
    local name, _, _, startMS, endMS, _, _, _, spellID = UnitCastingInfo("player")
    if Restriction.IsSecretValue(spellID) or Restriction.IsSecretValue(name) then
        bar:Hide()
        return
    end
    local order = view and view.order
    if not name or not startMS or not endMS then
        bar:Hide()
        return
    end
    if order and order.spellID and spellID and spellID ~= order.spellID then
        bar:Hide()
        return
    end
    bar:SetMinMaxValues(startMS, endMS)
    bar:SetValue(GetTime() * 1000)
    bar:Show()
end

function M:EnsureMagicButton()
    if M._magic then return M._magic end
    local view = GetOrderView()
    if not view then return nil end

    -- /click ignores hidden frames. Keep a 1px shown inner on UIParent.
    local inner = CreateFrame("Button", INNER_NAME, UIParent, "InsecureActionButtonTemplate")
    inner:SetSize(1, 1)
    inner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    inner:SetAlpha(0)
    inner:EnableMouse(false)
    inner:RegisterForClicks("LeftButtonUp")
    inner:Show()
    inner:SetScript("PreClick", function(myself)
        if Restriction.IsProtectedActionBlocked() then
            return
        end
        local target = tremove(clickQueue, 1)
        if not target or not target:IsShown() then
            target = GetConfirmButton()
        end
        if target and target:IsShown() then
            myself:SetAttribute("type", "click")
            myself:SetAttribute("clickbutton", target)
        else
            myself:SetAttribute("type", nil)
            myself:SetAttribute("clickbutton", nil)
        end
    end)

    local magic = CreateFrame("Button", MAGIC_NAME, view.OrderInfo,
        "InsecureActionButtonTemplate, BackdropTemplate")
    PlaceMagic(magic, view)
    magic:RegisterForClicks("LeftButtonUp")
    magic:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    -- Blocked-in-combat tooltip must still show while the button is disabled.
    magic:SetMotionScriptsWhileDisabled(true)
    local label = OneWoW_GUI:CreateFS(magic, 12)
    label:SetPoint("LEFT", magic, "LEFT", 8, 0)
    label:SetPoint("RIGHT", magic, "RIGHT", -8, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    magic.label = label
    OneWoW_GUI:RegisterFontRoot(magic, function()
        if M._magic and M._magic:IsShown() then
            M:ValidateMagicButton()
        end
    end)

    local stop = SLASH_STOPCASTING1
    local click = SLASH_CLICK1
    local clickLine = click .. " " .. INNER_NAME
    local macro = stop .. "\n" .. clickLine .. "\n" .. clickLine .. "\n" .. clickLine
    ApplySecureAttributes(function()
        inner:SetAttribute("useOnKeyDown", false)
        magic:SetAttribute("useOnKeyDown", false)
        magic:SetAttribute("type", "macro")
        magic:SetAttribute("macrotext", macro)
    end)

    magic:SetScript("PreClick", function()
        wipe(clickQueue)
        local ov = GetOrderView()
        local conc = GetConcentrateButton(ov)
        if M._conc and M._conc:IsShown() and conc and conc.GetChecked then
            local want = M._conc._wanted == true
            if want ~= conc:GetChecked() then
                clickQueue[#clickQueue + 1] = conc
            end
        end
        local action = CurrentActionButton(ov)
        if action then
            clickQueue[#clickQueue + 1] = action
        end
    end)

    magic:SetScript("OnEnter", function(myself)
        ApplyMagicChrome(myself, true)
        if Restriction.IsProtectedActionBlocked() then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(SPELL_FAILED_AFFECTING_COMBAT)
            GameTooltip:Show()
            return
        end
        local ov = GetOrderView()
        local action = CurrentActionButton(ov)
        if action and action:GetScript("OnEnter") then
            action:GetScript("OnEnter")(action)
        end
    end)
    magic:SetScript("OnLeave", function(myself)
        ApplyMagicChrome(myself, false)
        GameTooltip_Hide()
    end)
    magic:SetScript("OnMouseDown", function(myself)
        if not myself:IsEnabled() then return end
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
    end)
    magic:SetScript("OnMouseUp", function(myself)
        if not myself:IsEnabled() then return end
        ApplyMagicChrome(myself, myself:IsMouseOver())
    end)

    local concBtn = CreateFrame("Button", CONC_NAME, magic)
    concBtn:SetSize(CONC_SIZE, CONC_SIZE)
    concBtn:SetPoint("RIGHT", magic, "LEFT", -CONC_GAP, 0)
    local concIcon = concBtn:CreateTexture(nil, "ARTWORK")
    concIcon:SetAllPoints()
    concIcon:SetTexture(CONC_ICON)
    concBtn.icon = concIcon
    concBtn:RegisterForClicks("LeftButtonUp")
    concBtn:SetScript("OnClick", function(myself)
        myself._wanted = not myself._wanted
        myself.icon:SetAlpha(myself._wanted and 1 or 0.35)
        myself.icon:SetDesaturated(not myself._wanted)
    end)
    concBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(PROFESSIONS_CRAFTING_STAT_CONCENTRATION)
        GameTooltip:Show()
    end)
    concBtn:SetScript("OnLeave", GameTooltip_Hide)
    magic.conc = concBtn
    M._conc = concBtn

    local bar = CreateFrame("StatusBar", nil, magic)
    bar:SetHeight(4)
    bar:SetPoint("TOPLEFT", magic, "BOTTOMLEFT", 0, -2)
    bar:SetPoint("TOPRIGHT", magic, "BOTTOMRIGHT", 0, -2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    bar:Hide()
    bar:SetScript("OnUpdate", function(myself)
        local ov = GetOrderView()
        UpdateCastBar(myself, ov)
    end)
    magic.castBar = bar

    M._magicInner = inner
    M._magic = magic
    return magic
end

function M:ValidateMagicButton()
    local magic = M._magic
    local view = GetOrderView()
    if not magic or not view then return end
    if not ModuleOn() or not view:IsShown() then
        magic:Hide()
        if M._conc then M._conc:Hide() end
        RestoreBlizzardButtons(view)
        return
    end

    local action, kind = CurrentActionButton(view)
    if not action then
        magic:Hide()
        RestoreBlizzardButtons(view)
        return
    end

    magic:Show()
    HideBlizzardButtons(view)
    PlaceMagic(magic, view)

    local blocked = Restriction.IsProtectedActionBlocked()
    magic:SetEnabled(not blocked and action:IsEnabled())
    if kind == "start" then
        magic.label:SetText(PROFESSIONS_START_ORDER)
    elseif kind == "complete" then
        magic.label:SetText(PROFESSIONS_COMPLETE_ORDER)
    else
        magic.label:SetText(action:GetText() or CREATE_PROFESSION)
    end
    ApplyMagicChrome(magic, magic:IsMouseOver())

    local conc = GetConcentrateButton(view)
    local needConc = kind == "create" and conc and conc:IsShown()
    if M._conc then
        M._conc:SetShown(needConc == true)
        if needConc then
            local orderID = view.order and view.order.orderID
            if M._concOrderID ~= orderID then
                M._concOrderID = orderID
                M._conc._wanted = conc:GetChecked()
            end
            M._conc.icon:SetAlpha(M._conc._wanted and 1 or 0.35)
            M._conc.icon:SetDesaturated(not M._conc._wanted)
        end
    end
end

function M:OnOrderViewUpdated()
    if not ModuleOn() then return end
    M:EnsureMagicButton()
    M:ValidateMagicButton()
end

function M:HideMagicButton()
    local view = GetOrderView()
    RestoreBlizzardButtons(view)
    if M._magic then M._magic:Hide() end
    if M._conc then M._conc:Hide() end
end
