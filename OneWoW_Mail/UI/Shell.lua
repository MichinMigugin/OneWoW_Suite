local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.Shell = {}
local Shell = ns.Shell

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

local function SelectTab(tab)
    currentTab = tab
    if not shellFrame then
        return
    end
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
    local function proceed()
        CloseMail()
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
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() shellFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        shellFrame:StopMovingOrSizing()
        OneWoW_GUI:SaveWindowPosition(shellFrame, ns.db.global.mainFramePosition)
    end)

    local icon = titleBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", titleBar._titleText, "LEFT", -4, 0)
    icon:SetAtlas(ns.Constants.ICON_ATLAS)
    titleBar.mailIcon = icon

    local tabBar = CreateFrame("Frame", nil, shellFrame)
    tabBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -4)
    tabBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -8, -4)
    tabBar:SetHeight(30)

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
        local btn = OneWoW_GUI:CreateFitTextButton(tabBar, { text = labels[id], height = 26, toggleable = true })
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

        local panel = CreateFrame("Frame", nil, shellFrame)
        panel:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
        panel:SetPoint("BOTTOMRIGHT", shellFrame, "BOTTOMRIGHT", -8, 8)
        panel:Hide()
        shellFrame.panels[id] = panel
    end

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
    return shellFrame
end

function Shell:Show()
    self:Ensure()
    HideBlizzardMail()
    shellFrame:Show()
    if currentTab == "other" then
        currentTab = "inbox"
    end
    SelectTab(currentTab or "inbox")
    if currentTab == "compose" and ns.NativeSend then
        C_Timer.After(0, function()
            ns.NativeSend:ReassertPark()
        end)
    end
end

function Shell:Hide()
    if ns.Compose and ns.Compose.OnMailboxClosed then
        ns.Compose:OnMailboxClosed()
    elseif ns.Compose and ns.Compose.OnHide then
        ns.Compose:OnHide()
    end
    if shellFrame then
        shellFrame:Hide()
    end
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
