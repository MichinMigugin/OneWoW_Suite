local ADDON_NAME, OneWoW = ...

OneWoW.Minimap = {}
local MinimapMod = OneWoW.Minimap

local contextMenu
local minimapBtn
local position

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local function ShowContextMenu(anchorFrame)
    if contextMenu then
        contextMenu:Hide()
        contextMenu:SetParent(nil)
        contextMenu = nil
    end

    local entries = OneWoW._minimapEntries or {}
    local oneWoWEntry
    local otherEntries = {}
    for _, item in ipairs(entries) do
        if item.addon == "OneWoW" then
            oneWoWEntry = item
        elseif _G[item.addon] ~= nil then
            tinsert(otherEntries, item)
        end
    end
    sort(otherEntries, function(a, b) return (a.label or "") < (b.label or "") end)

    local visibleItems = {}
    if oneWoWEntry then
        tinsert(visibleItems, { label = oneWoWEntry.label, global = "OneWoW", always = true, action = oneWoWEntry.callback or (function() if OneWoW.GUI then OneWoW.GUI:Show() end end) })
    end
    for _, item in ipairs(otherEntries) do
        local action = item.callback
        if not action and item.tabKey then
            action = function() if OneWoW.GUI then OneWoW.GUI:Show(item.tabKey) end end
        end
        if action then
            tinsert(visibleItems, { label = item.label, global = item.addon, action = action })
        end
    end

    if #visibleItems == 0 then return end

    contextMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    contextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    contextMenu:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    contextMenu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    contextMenu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local yOff = -4
    local maxWidth = 140
    for _, item in ipairs(visibleItems) do
        local btn = CreateFrame("Button", nil, contextMenu, "BackdropTemplate")
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 4, yOff)
        btn:SetPoint("TOPRIGHT", contextMenu, "TOPRIGHT", -4, yOff)
        btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
        btn:SetBackdropColor(0, 0, 0, 0)

        local textLeftOffset = 8
        local hasErrorAlert = false
        if item.global == "OneWoW_UtilityDevTool" then
            local dt = _G.OneWoW_UtilityDevTool
            if dt and dt.ErrorLogger and dt.ErrorLogger.HasCurrentSessionErrors and dt.ErrorLogger:HasCurrentSessionErrors() then
                hasErrorAlert = true
                textLeftOffset = 24
            end
        end

        btn.text = OneWoW_GUI:CreateFS(btn, 12)
        btn.text:SetPoint("LEFT", textLeftOffset, 0)
        btn.text:SetText(item.label)
        btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        if hasErrorAlert then
            local alertIcon = btn:CreateTexture(nil, "OVERLAY")
            alertIcon:SetSize(16, 16)
            alertIcon:SetPoint("LEFT", 4, 0)
            alertIcon:SetAtlas("Ping_Chat_Warning")
        end

        local textW = btn.text:GetStringWidth() + 20 + (hasErrorAlert and 16 or 0)
        if textW > maxWidth then maxWidth = textW end

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)
        btn:SetScript("OnClick", function()
            contextMenu:Hide()
            item.action()
        end)

        yOff = yOff - 22
    end

    contextMenu:SetSize(maxWidth + 16, math.abs(yOff) + 8)

    local screenW   = UIParent:GetWidth()
    local menuW     = contextMenu:GetWidth()
    local menuH     = contextMenu:GetHeight()
    local ancLeft   = anchorFrame:GetLeft()   or 0
    local ancBottom = anchorFrame:GetBottom() or 0

    local goLeft  = (ancLeft + menuW) > screenW
    local goAbove = (ancBottom - menuH) < 0

    if goAbove and goLeft then
        contextMenu:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 2)
    elseif goAbove then
        contextMenu:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 2)
    elseif goLeft then
        contextMenu:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -2)
    else
        contextMenu:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
    end

    local timeOutside = 0
    contextMenu:SetScript("OnUpdate", function(self, elapsed)
        if not MouseIsOver(contextMenu) and not MouseIsOver(anchorFrame) then
            timeOutside = timeOutside + elapsed
            if timeOutside > 0.5 then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        else
            timeOutside = 0
        end
    end)

    contextMenu:Show()
end

local function GetCurrentIcon()
    return OneWoW_GUI:GetBrandIcon(OneWoW_GUI:GetSetting("minimap.theme"))
end

local MinimapShapes = {
    ["ROUND"]                 = {true,  true,  true,  true },
    ["SQUARE"]                = {false, false, false, false},
    ["CORNER-TOPLEFT"]        = {false, false, false, true },
    ["CORNER-TOPRIGHT"]       = {false, false, true,  false},
    ["CORNER-BOTTOMLEFT"]     = {false, true,  false, false},
    ["CORNER-BOTTOMRIGHT"]    = {true,  false, false, false},
    ["SIDE-LEFT"]             = {false, true,  false, true },
    ["SIDE-RIGHT"]            = {true,  false, true,  false},
    ["SIDE-TOP"]              = {false, false, true,  true },
    ["SIDE-BOTTOM"]           = {true,  true,  false, false},
    ["TRICORNER-TOPLEFT"]     = {false, true,  true,  true },
    ["TRICORNER-TOPRIGHT"]    = {true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = {true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = {true,  true,  true,  false},
}

local function UpdatePosition(self)
    local angle = math.rad(position)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local width   = _G.Minimap:GetWidth()  * 0.5
    local height  = _G.Minimap:GetHeight() * 0.5
    local rounding = 10
    if MinimapShapes[GetMinimapShape and GetMinimapShape() or "ROUND"][q] then
        x, y = x * width, y * height
    else
        x = math.max(-width,  math.min(x * (math.sqrt(2 * width^2)  - rounding), width))
        y = math.max(-height, math.min(y * (math.sqrt(2 * height^2) - rounding), height))
    end
    self:SetPoint("CENTER", _G.Minimap, "CENTER", math.floor(x), math.floor(y))
end

local function CreateMinimapButton()
    if minimapBtn then return end
    position = (OneWoW.db and OneWoW.db.global and OneWoW.db.global.minimap and OneWoW.db.global.minimap.minimapPos) or 220

    minimapBtn = CreateFrame("Button", "OneWoW_MinimapButton", _G.Minimap)
    minimapBtn:SetSize(35, 35)
    minimapBtn:SetFrameStrata("MEDIUM")
    minimapBtn:SetMovable(true)
    minimapBtn:EnableMouse(true)
    minimapBtn:RegisterForDrag("LeftButton", "RightButton")
    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = minimapBtn:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(GetCurrentIcon())
    tex:SetAllPoints()
    tex:Show()
    minimapBtn.tex = tex

    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFD1001WoW|r", 1, 0.82, 0, 1)
        local L = OneWoW.L
        if L and L["MINIMAP_TOOLTIP_HINT"] then
            GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
        end
        if L and L["MINIMAP_RIGHT_CLICK"] then
            GameTooltip:AddLine(L["MINIMAP_RIGHT_CLICK"], 0.5, 0.5, 0.6, 1)
        end
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    minimapBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and OneWoW.GUI then
            OneWoW.GUI:Toggle()
        elseif button == "RightButton" then
            ShowContextMenu(self)
        end
    end)
    minimapBtn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = _G.Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = _G.Minimap:GetEffectiveScale()
            position = math.deg(math.atan2((py / scale) - my, (px / scale) - mx)) % 360
            if OneWoW.db and OneWoW.db.global and OneWoW.db.global.minimap then
                OneWoW.db.global.minimap.minimapPos = position
            end
            self:Raise()
            UpdatePosition(self)
        end)
    end)
    minimapBtn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    minimapBtn:SetScript("OnEvent", function(self)
        UpdatePosition(self)
    end)
    minimapBtn:RegisterEvent("LOADING_SCREEN_DISABLED")

    UpdatePosition(minimapBtn)
    minimapBtn:Show()
end

function MinimapMod:UpdateIcon()
    if minimapBtn and minimapBtn.tex then
        minimapBtn.tex:SetTexture(GetCurrentIcon())
    end
    if MinimapMod._ldbPlugin then
        MinimapMod._ldbPlugin.icon = GetCurrentIcon()
    end
end

function MinimapMod:Initialize()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if ldb then
        local plugin = ldb:NewDataObject("OneWoW", {
            type = "launcher",
            icon = GetCurrentIcon(),
            OnClick = function(self, button)
                if button == "LeftButton" and OneWoW.GUI then
                    OneWoW.GUI:Toggle()
                elseif button == "RightButton" then
                    ShowContextMenu(self)
                end
            end,
            OnEnter = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine("|cFFFFD1001WoW|r", 1, 0.82, 0, 1)
                local L = OneWoW.L
                if L and L["MINIMAP_TOOLTIP_HINT"] then
                    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                end
                if L and L["MINIMAP_RIGHT_CLICK"] then
                    GameTooltip:AddLine(L["MINIMAP_RIGHT_CLICK"], 0.5, 0.5, 0.6, 1)
                end
                GameTooltip:Show()
            end,
            OnLeave = function()
                GameTooltip:Hide()
            end,
        })
        MinimapMod._ldbPlugin = plugin
    end

    if OneWoW_GUI:GetSetting("minimap.hide") then return end

    CreateMinimapButton()
end

function MinimapMod:Show()
    if not minimapBtn then
        CreateMinimapButton()
    else
        minimapBtn:Show()
    end
end

function MinimapMod:Hide()
    if minimapBtn then minimapBtn:Hide() end
end

function MinimapMod:Toggle()
    OneWoW_GUI:SetSetting("minimap.hide", not OneWoW_GUI:GetSetting("minimap.hide"))
end

function MinimapMod:IsShown()
    return minimapBtn and minimapBtn:IsShown()
end
