local ADDON_NAME, OneWoW = ...

OneWoW.Toasts = OneWoW.Toasts or {}
local Toasts = OneWoW.Toasts

local MAX_ACTIVE   = 3
local TOAST_WIDTH  = 360
local TOAST_H_SM   = 56
local TOAST_H_LG   = 74
local INST_WIDTH    = 375
local INST_HEIGHT   = 130
local STAT_COLS     = 3
local STAT_COL_W    = 120
local STAT_ROW_H    = 18
local STAT_TOP_Y    = -52
local STAT_COL_X    = { 8, 128, 248 }
local STACK_GAP     = 8
local ANCHOR_HEIGHT = 88

local DELAY_LOOT     = 5
local DELAY_NOTES    = 6
local DELAY_INSTANCE = 8
local ANIM_IN_DUR    = 0.2
local ANIM_SLIDE_PX  = 20
local ANIM_OUT_DUR   = 0.8

Toasts.activeToasts  = {}
Toasts.pendingQueue  = {}
Toasts.smallPool     = {}
Toasts.largePool     = {}
Toasts.anchorFrame   = nil
Toasts.anchorVisible = false

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.toasts
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled ~= false
end

local function IndexOf(t, val)
    for i, v in ipairs(t) do
        if v == val then return i end
    end
    return nil
end

local function RepositionToasts()
    if not Toasts.anchorFrame then return end
    local anchor  = Toasts.anchorFrame
    local screenH = GetScreenHeight()
    local anchorY = select(5, anchor:GetPoint()) or 0
    local stackUp = (anchor:GetBottom() or 0) < screenH * 0.25

    for i, toast in ipairs(Toasts.activeToasts) do
        toast:ClearAllPoints()
        if i == 1 then
            if stackUp then
                toast:SetPoint("BOTTOM", anchor, "TOP", 0, STACK_GAP)
            else
                toast:SetPoint("TOP", anchor, "BOTTOM", 0, -STACK_GAP)
            end
        else
            local prev = Toasts.activeToasts[i - 1]
            if stackUp then
                toast:SetPoint("BOTTOM", prev, "TOP", 0, STACK_GAP)
            else
                toast:SetPoint("TOP", prev, "BOTTOM", 0, -STACK_GAP)
            end
        end
    end
end

local function ReleaseToast(toast)
    local idx = IndexOf(Toasts.activeToasts, toast)
    if idx then
        table.remove(Toasts.activeToasts, idx)
    end
    toast:Hide()
    toast:SetAlpha(1)
    if toast._isLarge then
        table.insert(Toasts.largePool, toast)
    else
        table.insert(Toasts.smallPool, toast)
    end
    RepositionToasts()
    C_Timer.After(0, function()
        Toasts.ProcessQueue()
    end)
end

local function BuildAnimations(toast, delay)
    if toast._animIn then
        toast._animIn:Stop()
    end
    if toast._animOut then
        toast._animOut:Stop()
    end

    local animIn = toast:CreateAnimationGroup()
    toast._animIn = animIn

    local slide = animIn:CreateAnimation("Translation")
    slide:SetOffset(ANIM_SLIDE_PX, 0)
    slide:SetDuration(ANIM_IN_DUR)
    slide:SetOrder(1)
    slide:SetSmoothing("OUT")

    local fadeIn = animIn:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(ANIM_IN_DUR)
    fadeIn:SetOrder(1)

    local animOut = toast:CreateAnimationGroup()
    toast._animOut = animOut
    animOut:SetScript("OnFinished", function()
        ReleaseToast(toast)
    end)

    local fadeOut = animOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(delay)
    fadeOut:SetDuration(ANIM_OUT_DUR)
    fadeOut:SetOrder(1)
    toast._fadeOut = fadeOut

    animIn:SetScript("OnFinished", function()
        toast:SetAlpha(1)
        toast._animOut:Play()
    end)

    toast:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if self._animIn  then self._animIn:Stop()  end
            if self._animOut then self._animOut:Stop() end
            ReleaseToast(self)
        end
    end)

    toast:SetScript("OnEnter", function(self)
        if self._animOut then
            self._animOut:Stop()
        end
        self:SetAlpha(1)
    end)
    toast:SetScript("OnLeave", function(self)
        if self._fadeOut then
            self._fadeOut:SetStartDelay(2)
        end
        if self._animOut then
            self._animOut:Stop()
            self._animOut:Play()
        end
    end)
end

local function CreateSmallToast()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(TOAST_WIDTH, TOAST_H_SM)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local stripe = f:CreateTexture(nil, "ARTWORK")
    stripe:SetSize(4, TOAST_H_SM)
    stripe:SetPoint("LEFT", f, "LEFT", 0, 0)
    stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    f._stripe = stripe

    local iconBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    iconBg:SetSize(44, 44)
    iconBg:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    iconBg:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER)
    iconBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    iconBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    f._iconBg = iconBg

    local icon = iconBg:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconBg)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f._icon = icon

    local title = OneWoW_GUI:CreateFS(f, 16)
    title:SetPoint("LEFT", f, "LEFT", 14, 0)
    title:SetPoint("RIGHT", iconBg, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(false)
    f._title = title

    local subtitle = OneWoW_GUI:CreateFS(f, 12)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:Hide()
    f._subtitle = subtitle

    f._isLarge = false
    return f
end

local function CreateLargeToast()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(INST_WIDTH, INST_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetAtlas("GarrMissionLocation-Maw-bg-01", true)
    f._bg = bg

    local title = OneWoW_GUI:CreateFS(f, 18)
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetWidth(INST_WIDTH - 16)
    title:SetJustifyH("CENTER")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(2, -2)
    f._title = title

    local subtitle = OneWoW_GUI:CreateFS(f, 12)
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetWidth(INST_WIDTH - 16)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    subtitle:SetShadowColor(0, 0, 0, 1)
    subtitle:SetShadowOffset(1, -1)
    f._subtitle = subtitle

    local statCells = {}
    for i = 1, 7 do
        local col  = ((i - 1) % STAT_COLS) + 1
        local row  = math.floor((i - 1) / STAT_COLS)
        local cell = OneWoW_GUI:CreateFS(f, 10)
        cell:SetPoint("TOPLEFT", f, "TOPLEFT", STAT_COL_X[col], STAT_TOP_Y - (row * STAT_ROW_H))
        cell:SetWidth(STAT_COL_W - 2)
        cell:SetJustifyH("LEFT")
        cell:SetWordWrap(false)
        cell:SetShadowColor(0, 0, 0, 1)
        cell:SetShadowOffset(1, -1)
        statCells[i] = cell
    end
    f._statCells = statCells

    f._isLarge = true
    return f
end

local function GetToast(large)
    local pool = large and Toasts.largePool or Toasts.smallPool
    if #pool > 0 then
        return table.remove(pool)
    end
    return large and CreateLargeToast() or CreateSmallToast()
end

local function ShowSmallToast(data)
    local toast = GetToast(false)

    local delay = DELAY_LOOT
    if data.toastType == "notes" then delay = DELAY_NOTES end

    toast._stripe:SetVertexColor(unpack(data.color or {0.5, 0.5, 0.5, 1.0}))
    toast._icon:SetTexture(data.icon)

    toast._title:SetText(data.title or "")
    toast._title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if data.subtitle and data.subtitle ~= "" then
        toast:SetHeight(TOAST_H_LG)
        toast._stripe:SetHeight(TOAST_H_LG)
        toast._title:ClearAllPoints()
        toast._title:SetPoint("TOPLEFT", toast, "TOPLEFT", 14, -10)
        toast._title:SetPoint("RIGHT",   toast._iconBg, "LEFT", -8, 0)
        toast._title:SetJustifyV("TOP")
        toast._subtitle:ClearAllPoints()
        toast._subtitle:SetPoint("TOPLEFT", toast._title, "BOTTOMLEFT", 0, -4)
        toast._subtitle:SetPoint("RIGHT",   toast._iconBg, "LEFT", -8, 0)
        toast._subtitle:SetText(data.subtitle)
        toast._subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        toast._subtitle:Show()
    else
        toast:SetHeight(TOAST_H_SM)
        toast._stripe:SetHeight(TOAST_H_SM)
        toast._title:ClearAllPoints()
        toast._title:SetPoint("LEFT",  toast, "LEFT", 14, 0)
        toast._title:SetPoint("RIGHT", toast._iconBg, "LEFT", -8, 0)
        toast._title:SetJustifyV("MIDDLE")
        toast._subtitle:Hide()
    end

    toast:SetAlpha(0)
    toast:Show()

    table.insert(Toasts.activeToasts, toast)
    RepositionToasts()

    BuildAnimations(toast, delay)
    toast._animIn:Play()
end

local function BuildLargeToastAnimations(toast)
    if toast._animIn  then toast._animIn:Stop()  end
    if toast._animOut then toast._animOut:Stop() end

    local animIn = toast:CreateAnimationGroup()
    toast._animIn = animIn

    local fadeIn1 = animIn:CreateAnimation("Alpha")
    fadeIn1:SetFromAlpha(1)
    fadeIn1:SetToAlpha(0)
    fadeIn1:SetDuration(0)
    fadeIn1:SetOrder(1)

    local fadeIn2 = animIn:CreateAnimation("Alpha")
    fadeIn2:SetFromAlpha(0)
    fadeIn2:SetToAlpha(1)
    fadeIn2:SetDuration(0.5)
    fadeIn2:SetOrder(2)

    local animOut = toast:CreateAnimationGroup()
    toast._animOut = animOut
    animOut:SetScript("OnFinished", function()
        ReleaseToast(toast)
    end)

    local fadeOut = animOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(DELAY_INSTANCE)
    fadeOut:SetDuration(2.0)
    fadeOut:SetOrder(1)
    toast._fadeOut = fadeOut

    animIn:SetScript("OnFinished", function()
        toast:SetAlpha(1)
        toast._animOut:Play()
    end)

    toast:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._instanceMapID then
            if self._animIn  then self._animIn:Stop()  end
            if self._animOut then self._animOut:Stop() end
            local mapID = self._instanceMapID
            ReleaseToast(self)
            local cat = _G.OneWoW_Catalog
            if cat and cat.UI and cat.UI.OpenToInstance then
                cat.UI.OpenToInstance(mapID)
            end
        elseif button == "RightButton" then
            if self._animIn  then self._animIn:Stop()  end
            if self._animOut then self._animOut:Stop() end
            ReleaseToast(self)
        end
    end)

    toast:SetScript("OnEnter", function(self)
        if self._animOut then self._animOut:Stop() end
        self:SetAlpha(1)
        if self._instanceMapID then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            local L = OneWoW.L
            GameTooltip:SetText(L and L["TOAST_INSTANCE_CLICK"] or "Click to view in Journal", 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    toast:SetScript("OnLeave", function(self)
        if self._fadeOut then self._fadeOut:SetStartDelay(2) end
        if self._animOut then
            self._animOut:Stop()
            self._animOut:Play()
        end
        GameTooltip:Hide()
    end)
end

local function ShowLargeToast(data)
    local toast = GetToast(true)

    toast._instanceMapID = data.instanceMapID
    toast._title:SetText(data.title or "")
    toast._subtitle:SetText(data.subtitle or "")

    local grid = data.grid
    for i, cell in ipairs(toast._statCells) do
        local entry = grid and grid[i]
        if entry then
            local current = entry.current or 0
            local total   = entry.total   or 0
            local text, r, g, b
            if entry.totalOnly then
                text = entry.label .. ": " .. total
                r, g, b = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
            else
                text = entry.label .. " " .. current .. "/" .. total
                if total > 0 and current >= total then
                    r, g, b = OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
                elseif current > 0 then
                    r, g, b = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
                else
                    r, g, b = OneWoW_GUI:GetThemeColor("TEXT_MUTED")
                end
            end
            cell:SetText(text)
            cell:SetTextColor(r, g, b, 1.0)
            cell:Show()
        else
            cell:SetText("")
            cell:Hide()
        end
    end

    toast:SetAlpha(0)
    toast:Show()

    table.insert(Toasts.activeToasts, toast)
    RepositionToasts()

    BuildLargeToastAnimations(toast)
    toast._animIn:Play()
end

function Toasts.ProcessQueue()
    if not IsEnabled() then return end
    while #Toasts.activeToasts < MAX_ACTIVE and #Toasts.pendingQueue > 0 do
        local data = table.remove(Toasts.pendingQueue, 1)
        if data._isLarge then
            ShowLargeToast(data)
        else
            ShowSmallToast(data)
        end
        Toasts.PlayToastSound(data.toastType or "loot")
    end
end

function Toasts.FireToast(data)
    if not IsEnabled() then return end
    data._isLarge = (data.toastType == "instance")
    table.insert(Toasts.pendingQueue, data)
    Toasts.ProcessQueue()
end

function Toasts.PlayToastSound(category)
    local db = GetDB()
    if not db then return end
    local section = db[category]
    if section and section.sound and section.sound > 0 then
        PlaySound(section.sound, "Master")
    end
end

local function UpdateAnchorDisplay(anchor)
    local db = GetDB()
    local locked = db and db.anchor and db.anchor.locked
    if locked then
        anchor._titleText:SetText("Toast Anchor  [LOCKED]")
        anchor._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        anchor:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        anchor._titleText:SetText("Toast Anchor")
        anchor._titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        anchor:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end
end

local function BuildAnchor()
    if Toasts.anchorFrame then return end

    local anchor = CreateFrame("Frame", "OneWoW_ToastAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(TOAST_WIDTH, ANCHOR_HEIGHT)
    anchor:SetFrameStrata("HIGH")
    anchor:EnableMouse(true)
    anchor:SetMovable(true)
    anchor:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    anchor:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    anchor:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local titleText = OneWoW_GUI:CreateFS(anchor, 12)
    titleText:SetPoint("TOPLEFT",  anchor, "TOPLEFT",  10, -10)
    titleText:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -10, -10)
    titleText:SetJustifyH("CENTER")
    titleText:SetText("Toast Anchor")
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    anchor._titleText = titleText

    local divider = anchor:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  anchor, "TOPLEFT",  6, -30)
    divider:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -6, -30)
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.85, 0.70, 0.20, 0.4)

    local controlsText = OneWoW_GUI:CreateFS(anchor, 10)
    controlsText:SetPoint("TOPLEFT",  anchor, "TOPLEFT",  10, -38)
    controlsText:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -10, -38)
    controlsText:SetJustifyH("CENTER")
    controlsText:SetWordWrap(true)
    controlsText:SetText("Alt+Drag: Move  |  Shift+Click: Lock  |  Ctrl+Alt+Click: Hide")
    controlsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)

    anchor:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown() then
            local db = GetDB()
            if db and db.anchor and db.anchor.locked then return end
            self:StartMoving()
            self._wasDragged = true
        end
    end)

    anchor:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if self._wasDragged then
                self:StopMovingOrSizing()
                self._wasDragged = false
                local db = GetDB()
                if db and db.anchor then
                    db.anchor.x = self:GetLeft()
                    db.anchor.y = self:GetTop()
                end
            else
                if IsShiftKeyDown() then
                    local db = GetDB()
                    if db and db.anchor then
                        db.anchor.locked = not db.anchor.locked
                        UpdateAnchorDisplay(self)
                    end
                elseif IsControlKeyDown() and IsAltKeyDown() then
                    Toasts.HideAnchor()
                end
            end
        end
    end)

    anchor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local L = OneWoW.L
        GameTooltip:SetText(L and L["TOAST_ANCHOR_TOOLTIP"] or "Toast Anchor")
        GameTooltip:AddLine("Alt+Drag: Move", 0.80, 0.80, 0.80)
        GameTooltip:AddLine("Shift+Click: Lock / Unlock", 0.80, 0.80, 0.80)
        GameTooltip:AddLine("Ctrl+Alt+Click: Hide", 0.80, 0.80, 0.80)
        GameTooltip:Show()
    end)
    anchor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    anchor:Hide()
    Toasts.anchorFrame = anchor

    C_Timer.After(0.1, function()
        local db = GetDB()
        if db and db.anchor then
            if db.anchor.x and db.anchor.y then
                anchor:ClearAllPoints()
                anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.anchor.x, db.anchor.y)
            end
            UpdateAnchorDisplay(anchor)
            if db.anchor.visible then
                Toasts.ShowAnchor()
            end
        end
    end)
end

function Toasts.ShowAnchor()
    BuildAnchor()
    Toasts.anchorFrame:Show()
    Toasts.anchorVisible = true
    local db = GetDB()
    if db and db.anchor then
        db.anchor.visible = true
    end
end

function Toasts.HideAnchor()
    if Toasts.anchorFrame then
        Toasts.anchorFrame:Hide()
        Toasts.anchorVisible = false
        local db = GetDB()
        if db and db.anchor then
            db.anchor.visible = false
        end
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    BuildAnchor()
end)
