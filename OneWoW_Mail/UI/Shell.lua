local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.Shell = {}
local Shell = ns.Shell

local MT = ns.MailTrace
local function Trace(event, fields)
    if MT.enabled then
        MT:Record("shell", event, fields)
    end
end

local shellFrame
local currentTab = "inbox"
local selected = {}
local blizzardHidden = false
local hideFromMailClosed = false

local TAB_ORDER = { "inbox", "compose", "shipments", "activity" }

local function HideBlizzardMail()
    if not MailFrame or blizzardHidden then
        return
    end
    MailFrame:SetAlpha(0)
    MailFrame:EnableMouse(false)
    if OpenAllMail then
        OpenAllMail:Hide()
        OpenAllMail:SetAlpha(0)
    end
    blizzardHidden = true
end

local function RestoreBlizzardMail()
    if not MailFrame or not blizzardHidden then
        return
    end
    MailFrame:SetAlpha(1)
    MailFrame:EnableMouse(true)
    if OpenAllMail then
        OpenAllMail:SetAlpha(1)
    end
    blizzardHidden = false
end

local function HideSettingsPopover()
    if not shellFrame then
        return
    end
    if shellFrame.settingsDismisser then
        shellFrame.settingsDismisser:Hide()
    end
    if shellFrame.settingsPopover then
        shellFrame.settingsPopover:Hide()
    end
end

local function SelectTab(tab)
    currentTab = tab
    if not shellFrame then
        return
    end
    HideSettingsPopover()
    for _, id in ipairs(TAB_ORDER) do
        local panel = shellFrame.panels[id]
        local btn = shellFrame.tabButtons[id]
        if panel then
            if id == tab then
                panel:Show()
            else
                panel:Hide()
            end
        end
        if btn then
            btn:SetActive(id == tab)
        end
    end

    if tab == "compose" then
        if ns.Compose and ns.Compose.OnShow then
            ns.Compose:OnShow()
        end
    else
        if ns.Compose and ns.Compose.OnHide then
            ns.Compose:OnHide()
        end
    end

    if tab == "inbox" and ns.Inbox and ns.Inbox.Refresh then
        ns.Inbox:Refresh()
    elseif tab == "shipments" and ns.ShipmentsUI and ns.ShipmentsUI.Refresh then
        ns.ShipmentsUI:Refresh()
    elseif tab == "activity" and ns.ActivityUI and ns.ActivityUI.Refresh then
        ns.ActivityUI:Refresh()
    end
end

function Shell:GetSelected()
    return selected
end

function Shell:ClearSelected()
    wipe(selected)
end

function Shell:RefreshInbox()
    if ns.Inbox and ns.Inbox.Refresh then
        ns.Inbox:Refresh()
    end
end

--- Intentional close (X / Escape / Toggle): confirm if Activity has pending review.
function Shell:RequestClose()
    Trace("request_close", { pending = ns.AutoRun and ns.AutoRun:HasPending() or false })
    local function proceed()
        -- Prefer CloseMail so Blizzard tears down the mailbox session (MAIL_CLOSED).
        -- Always hide our shell too: CloseMail can be a no-op while the chrome is
        -- still up (missed interaction end, /1wmail-only, etc.), which made the X
        -- look dead.
        local interacting = C_PlayerInteractionManager.IsInteractingWithNpcOfType(
            Enum.PlayerInteractionType.MailInfo
        )
        Trace("proceed_close", { interacting = interacting and true or false })
        if interacting then
            CloseMail()
        end
        if shellFrame and shellFrame:IsShown() then
            hideFromMailClosed = true
            Shell:Hide()
            hideFromMailClosed = false
            Shell:ClearSelected()
        end
    end
    if ns.AutoRun then
        ns.AutoRun:RequestClose(proceed)
    else
        proceed()
    end
end

function Shell:Ensure()
    if shellFrame then
        return shellFrame
    end

    local C = ns.Constants.GUI
    shellFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_MailShell",
        width = C.WINDOW_WIDTH,
        height = C.WINDOW_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    do
        local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
        shellFrame:SetBackdropColor(r, g, b, 1)
    end
    shellFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if not OneWoW_GUI:RestoreWindowPosition(shellFrame, ns.db.global.mainFramePosition) then
        shellFrame:SetPoint("CENTER")
    end
    -- Grow with the default if a saved size is shorter (e.g. Shipments form grew).
    if (shellFrame:GetHeight() or 0) < C.WINDOW_HEIGHT then
        shellFrame:SetHeight(C.WINDOW_HEIGHT)
        OneWoW_GUI:SaveWindowPosition(shellFrame, ns.db.global.mainFramePosition)
    end
    shellFrame:SetMovable(true)
    shellFrame:EnableMouse(true)
    shellFrame:RegisterForDrag("LeftButton")
    shellFrame:SetScript("OnDragStart", shellFrame.StartMoving)
    shellFrame:SetScript("OnDragStop", function(myself)
        myself:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(myself, ns.db.global.mainFramePosition)
    end)
    shellFrame:SetClampedToScreen(true)
    shellFrame:SetFrameStrata("HIGH")
    shellFrame:SetToplevel(true)
    shellFrame:Hide()

    -- Escape (UISpecialFrames) hides the shell without CloseMail, which used to
    -- leave AutoRun.mailOpen stuck. Route through RequestClose / CloseMail.
    shellFrame:HookScript("OnHide", function(myself)
        if hideFromMailClosed then
            return
        end
        if ns.AutoRun and ns.AutoRun:HasPending() then
            C_Timer.After(0, function()
                if myself then
                    myself:Show()
                end
                Shell:RequestClose()
            end)
            return
        end
        CloseMail()
    end)

    local titleBar = OneWoW_GUI:CreateTitleBar(shellFrame, {
        title = L["ADDON_TITLE"],
        showBrand = true,
        onClose = function()
            Shell:RequestClose()
        end,
    })
    do
        local tr, tg, tb = OneWoW_GUI:GetThemeColor("TITLEBAR_BG")
        titleBar:SetBackdropColor(tr, tg, tb, 1)
    end
    shellFrame.titleBar = titleBar
    -- Keep the X above title-bar drag chrome so clicks always reach it.
    if titleBar._closeBtn then
        titleBar._closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 10)
    end
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() shellFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        shellFrame:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(shellFrame, ns.db.global.mainFramePosition)
    end)

    local tabBar = CreateFrame("Frame", nil, shellFrame)
    local pad = OneWoW_GUI.Constants.GUI.PADDING
    local tabH = OneWoW_GUI.Constants.GUI.TAB_BUTTON_HEIGHT
    tabBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", pad - 4, -4)
    tabBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -(pad - 4), -4)
    tabBar:SetHeight(tabH)

    shellFrame.tabButtons = {}
    shellFrame.panels = {}

    local labels = {
        inbox = INBOX,
        compose = L["TAB_COMPOSE"],
        shipments = L["TAB_SHIPMENTS"],
        activity = L["TAB_ACTIVITY"],
    }

    local prev
    for _, id in ipairs(TAB_ORDER) do
        local btn = OneWoW_GUI:CreateFitTextButton(tabBar, {
            text = labels[id],
            height = math.max(22, tabH - 4),
            toggleable = true,
        })
        if not prev then
            btn:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        end
        btn:SetScript("OnClick", function()
            SelectTab(id)
        end)
        shellFrame.tabButtons[id] = btn
        prev = btn

        if id == "activity" then
            local badge = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            badge:SetHeight(14)
            badge:SetFrameLevel(btn:GetFrameLevel() + 5)
            badge:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            badge:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            badge:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 6, 6)
            badge.text = OneWoW_GUI:CreateFS(badge, 9)
            badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
            badge.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            badge:Hide()
            btn.pendingBadge = badge
            btn._baseWidth = btn:GetWidth()
        end

        local panel = CreateFrame("Frame", nil, shellFrame)
        panel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
        panel:SetPoint("BOTTOMRIGHT", shellFrame, "BOTTOMRIGHT", -(pad - 4), pad - 4)
        panel:Hide()
        shellFrame.panels[id] = panel
    end

    local settingsBtn = OneWoW_GUI:CreateAtlasIconButton(tabBar, {
        atlas = "mechagon-projects",
        width = 22,
        height = 22,
    })
    settingsBtn:SetPoint("RIGHT", tabBar, "RIGHT", 0, 0)
    settingsBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(SETTINGS, 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsBtn:HookScript("OnLeave", GameTooltip_Hide)
    shellFrame.settingsBtn = settingsBtn

    local settingsDismisser = CreateFrame("Button", nil, shellFrame)
    settingsDismisser:SetAllPoints(shellFrame)
    settingsDismisser:SetFrameLevel(tabBar:GetFrameLevel() + 20)
    settingsDismisser:Hide()
    settingsDismisser:SetScript("OnClick", HideSettingsPopover)
    shellFrame.settingsDismisser = settingsDismisser

    local popover = CreateFrame("Frame", nil, shellFrame, "BackdropTemplate")
    popover:SetSize(300, 150)
    popover:SetPoint("TOPRIGHT", settingsBtn, "BOTTOMRIGHT", 0, -4)
    popover:SetFrameLevel(settingsDismisser:GetFrameLevel() + 1)
    popover:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    popover:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    popover:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    popover:EnableMouse(true)
    popover:Hide()
    shellFrame.settingsPopover = popover

    local popTitle = OneWoW_GUI:CreateFS(popover, 12)
    popTitle:SetPoint("TOPLEFT", popover, "TOPLEFT", 12, -10)
    popTitle:SetPoint("TOPRIGHT", popover, "TOPRIGHT", -12, -10)
    popTitle:SetJustifyH("LEFT")
    popTitle:SetText(SETTINGS)
    popTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    shellFrame.settingsPopoverTitle = popTitle

    local ackLabel = OneWoW_GUI:CreateFS(popover, 11)
    ackLabel:SetPoint("TOPLEFT", popTitle, "BOTTOMLEFT", 0, -10)
    ackLabel:SetPoint("RIGHT", popover, "RIGHT", -12, 0)
    ackLabel:SetJustifyH("LEFT")
    ackLabel:SetText(L["SETTINGS_SEND_ACK_TIMEOUT"])
    ackLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    shellFrame.settingsAckLabel = ackLabel

    local Const = ns.Constants
    local ackSlider = OneWoW_GUI:CreateSlider(popover, {
        minVal = Const.SEND_ACK_TIMEOUT_MIN,
        maxVal = Const.SEND_ACK_TIMEOUT_MAX,
        step = 1,
        currentVal = ns.SendResult:GetAckTimeout(),
        width = 276,
        getLabel = function(pos)
            return string.format("%ds", pos)
        end,
        onChange = function(seconds)
            ns.db.global.mail.sendAckTimeout = seconds
        end,
    })
    ackSlider:SetPoint("TOPLEFT", ackLabel, "BOTTOMLEFT", 0, -6)
    shellFrame.settingsAckSlider = ackSlider

    local ackTip = OneWoW_GUI:CreateFS(popover, 10)
    ackTip:SetPoint("TOPLEFT", ackSlider, "BOTTOMLEFT", 0, -8)
    ackTip:SetPoint("RIGHT", popover, "RIGHT", -12, 0)
    ackTip:SetJustifyH("LEFT")
    ackTip:SetWordWrap(true)
    ackTip:SetText(L["TT_SETTINGS_SEND_ACK_TIMEOUT"])
    ackTip:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    shellFrame.settingsAckTip = ackTip

    -- Keep the gear above the dismisser so toggle still works while open.
    settingsBtn:SetFrameLevel(settingsDismisser:GetFrameLevel() + 2)
    settingsBtn:SetScript("OnClick", function()
        if popover:IsShown() then
            HideSettingsPopover()
            return
        end
        ackSlider.slider:SetValue(ns.SendResult:GetAckTimeout())
        settingsDismisser:Show()
        popover:Show()
    end)

    if ns.Inbox and ns.Inbox.Create then
        ns.Inbox:Create(shellFrame.panels.inbox)
    end
    if ns.Compose and ns.Compose.Create then
        ns.Compose:Create(shellFrame.panels.compose)
    end
    if ns.ShipmentsUI and ns.ShipmentsUI.Create then
        ns.ShipmentsUI:Create(shellFrame.panels.shipments)
    end
    if ns.ActivityUI and ns.ActivityUI.Create then
        ns.ActivityUI:Create(shellFrame.panels.activity)
    end

    tinsert(UISpecialFrames, "OneWoW_MailShell")
    -- Standalone mailbox window is outside the hub rebuild; opt in to live font changes.
    OneWoW_GUI:RegisterFontRoot(shellFrame)
    return shellFrame
end

function Shell:Show()
    self:Ensure()
    HideBlizzardMail()
    Trace("show", { tab = currentTab })
    shellFrame:Show()
    if currentTab == "other" then
        currentTab = "inbox"
    end
    SelectTab(currentTab or "inbox")
    self:UpdateActivityBadge()
    if currentTab == "compose" and ns.NativeSend then
        C_Timer.After(0, function()
            ns.NativeSend:ReassertPark()
        end)
    end
end

--- Count badge on the Activity tab for pending review groups.
function Shell:UpdateActivityBadge()
    if not shellFrame or not shellFrame.tabButtons then
        return
    end
    local btn = shellFrame.tabButtons.activity
    if not btn or not btn.pendingBadge then
        return
    end
    local count = 0
    if ns.AutoRun and ns.AutoRun.GetPendingGroupCount then
        count = ns.AutoRun:GetPendingGroupCount()
    end
    local badge = btn.pendingBadge
    if count <= 0 then
        badge:Hide()
        if btn._baseWidth then
            btn:SetWidth(btn._baseWidth)
        end
        return
    end
    local text = tostring(count)
    badge.text:SetText(text)
    local w = math.max(14, (badge.text:GetStringWidth() or 8) + 10)
    badge:SetWidth(w)
    badge:Show()
    if btn._baseWidth then
        btn:SetWidth(btn._baseWidth + math.floor(w / 2))
    end
end

function Shell:Hide()
    if not shellFrame or not shellFrame:IsShown() then
        return
    end
    Trace("hide", {})
    HideSettingsPopover()
    if ns.Compose and ns.Compose.OnMailboxClosed then
        ns.Compose:OnMailboxClosed()
    elseif ns.Compose and ns.Compose.OnHide then
        ns.Compose:OnHide()
    end
    shellFrame:Hide()
    RestoreBlizzardMail()
end

function Shell:Toggle()
    if shellFrame and shellFrame:IsShown() then
        self:RequestClose()
    else
        self:Show()
    end
end

function Shell:IsShown()
    return shellFrame and shellFrame:IsShown()
end

function Shell:FullReset()
    if ns.Compose and ns.Compose.OnHide then
        ns.Compose:OnHide()
    end
    if shellFrame then
        OneWoW_GUI:UnregisterFontRoot(shellFrame)
        hideFromMailClosed = true
        shellFrame:Hide()
        hideFromMailClosed = false
        shellFrame:SetParent(nil)
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "OneWoW_MailShell" then
                tremove(UISpecialFrames, i)
            end
        end
        if OneWoW_MailShell == shellFrame then
            OneWoW_MailShell = nil
        end
        shellFrame = nil
    end
    if ns.Inbox and ns.Inbox.Reset then
        ns.Inbox:Reset()
    end
    if ns.Compose and ns.Compose.Reset then
        ns.Compose:Reset()
    end
    if ns.ShipmentsUI and ns.ShipmentsUI.Reset then
        ns.ShipmentsUI:Reset()
    end
    if ns.ActivityUI and ns.ActivityUI.Reset then
        ns.ActivityUI:Reset()
    end
end

function Shell:ApplyTheme()
    if not shellFrame then
        return
    end
    local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
    shellFrame:SetBackdropColor(r, g, b, 1)
    shellFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    if shellFrame.titleBar then
        local tr, tg, tb = OneWoW_GUI:GetThemeColor("TITLEBAR_BG")
        shellFrame.titleBar:SetBackdropColor(tr, tg, tb, 1)
    end
    if shellFrame.settingsPopover then
        shellFrame.settingsPopover:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        shellFrame.settingsPopover:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    end
    if shellFrame.settingsPopoverTitle then
        shellFrame.settingsPopoverTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
    if shellFrame.settingsAckLabel then
        shellFrame.settingsAckLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    if shellFrame.settingsAckTip then
        shellFrame.settingsAckTip:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
    OneWoW_GUI:ApplyFontToFrame(shellFrame)
end

function Shell:Initialize()
    if self._wired then
        return
    end
    self._wired = true

    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:RegisterEvent("MAIL_CLOSED")
    f:RegisterEvent("MAIL_INBOX_UPDATE")
    f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "MAIL_SHOW" then
            Shell:Show()
        elseif event == "MAIL_CLOSED" then
            hideFromMailClosed = true
            Shell:Hide()
            hideFromMailClosed = false
            Shell:ClearSelected()
        elseif event == "MAIL_INBOX_UPDATE" then
            if Shell:IsShown() then
                Shell:RefreshInbox()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local itype = ...
            if itype == Enum.PlayerInteractionType.MailInfo then
                hideFromMailClosed = true
                Shell:Hide()
                hideFromMailClosed = false
            end
        end
    end)
end
