-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/copytext/copytext.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local CopyTextModule = {
    id          = "copytext",
    title       = "COPYTEXT_TITLE",
    category    = "UTILITY",
    description = "COPYTEXT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "mode_tooltips", label = "COPYTEXT_TOGGLE_TOOLTIPS", description = "COPYTEXT_TOGGLE_TOOLTIPS_DESC", default = true  },
        { id = "mode_anything", label = "COPYTEXT_TOGGLE_ANYTHING", description = "COPYTEXT_TOGGLE_ANYTHING_DESC", default = false },
        { id = "fast_copy",     label = "COPYTEXT_TOGGLE_FAST",     description = "COPYTEXT_TOGGLE_FAST_DESC",     default = false },
    },
    preview        = true,
    defaultEnabled = true,
    _libCopyPaste = nil,
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("copytext", id)
end

function CopyTextModule:GetLib()
    if not self._libCopyPaste then
        self._libCopyPaste = LibStub and LibStub("LibCopyPaste-1.0", true)
    end
    return self._libCopyPaste
end

function CopyTextModule:Capture()
    local text, title

    if GetToggle("mode_tooltips") then
        text = self:ExtractTooltipText()
        title = ns.L["COPYTEXT_TOOLTIP_CONTENT"] or "Tooltip Content"
    end

    if (not text or #text == 0) and GetToggle("mode_anything") then
        text = self:ExtractAnything()
        title = ns.L["COPYTEXT_UI_CONTENT"] or "UI Text"
    end

    if text and #text > 0 then
        self:ShowCopyDialog(title, text)
    else
        print("|cFFFFD100OneWoW QoL:|r " .. (ns.L["COPYTEXT_NO_TEXT"] or "No text found under cursor."))
    end
end

function CopyTextModule:ExtractTooltipText()
    local tooltips = {GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}
    local tooltipTexts = {}

    for _, tooltip in ipairs(tooltips) do
        if tooltip and tooltip:IsVisible() then
            local lines = {}
            for i = 1, tooltip:NumLines() do
                local leftText  = _G[tooltip:GetName() .. "TextLeft"  .. i]
                local rightText = _G[tooltip:GetName() .. "TextRight" .. i]
                local line = ""
                if leftText then
                    local left = leftText:GetText()
                    if left then line = left end
                end
                if rightText then
                    local right = rightText:GetText()
                    if right and right ~= "" then
                        line = (#line > 0) and (line .. " - " .. right) or right
                    end
                end
                if #line > 0 then table.insert(lines, line) end
            end
            if #lines > 0 then
                table.insert(tooltipTexts, table.concat(lines, "\n"))
            end
        end
    end

    return #tooltipTexts > 0 and table.concat(tooltipTexts, "\n\n") or nil
end

function CopyTextModule:ExtractAnything()
    local fontStrings = {}
    local frame = EnumerateFrames()
    while frame do
        local ok, regions = pcall(function() return {frame:GetRegions()} end)
        if ok and regions then
            for _, region in ipairs(regions) do
                pcall(function()
                    if region:GetObjectType() == "FontString" and region:IsVisible() then
                        local ok2, over = pcall(MouseIsOver, region)
                        if ok2 and over then
                            table.insert(fontStrings, region)
                        end
                    end
                end)
            end
        end
        frame = EnumerateFrames(frame)
    end

    local texts = {}
    for _, fs in ipairs(fontStrings) do
        local t = fs:GetText()
        if t and #t > 0 then table.insert(texts, t) end
    end
    return #texts > 0 and table.concat(texts, "\n") or nil
end

function CopyTextModule:ShowCopyDialog(title, text)
    local lib = self:GetLib()
    if lib then
        local fastCopy = GetToggle("fast_copy")
        lib:Copy(title or "Copy", text, { autoHide = fastCopy, readOnly = fastCopy })
        return
    end

    local dialog = CreateFrame("Frame", "OneWoW_QoL_CopyTextDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(400, 150)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    dialog:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    dialog:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)

    local editBox = CreateFrame("EditBox", nil, dialog)
    editBox:SetMultiLine(false)
    editBox:SetSize(380, 24)
    editBox:SetPoint("CENTER", dialog, "CENTER", 0, 10)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(true)
    editBox:SetText(text or "")
    editBox:HighlightText()
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    editBox:SetScript("OnEnterPressed", function() dialog:Hide() end)

    local closeBtn = CreateFrame("Button", nil, dialog)
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 8)
    closeBtn:SetNormalFontObject(GameFontNormal)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)

    dialog:Show()
end

function CopyTextModule:OnEnable()
    _G["SLASH_OWCOPYTEXT1"] = "/copytext"
    _G["SLASH_OWCOPYTEXT2"] = "/ct"
    SlashCmdList["OWCOPYTEXT"] = function()
        self:Capture()
    end
end

function CopyTextModule:OnDisable()
    SlashCmdList["OWCOPYTEXT"] = nil
    _G["SLASH_OWCOPYTEXT1"] = nil
    _G["SLASH_OWCOPYTEXT2"] = nil
end

ns.CopyTextModule = CopyTextModule
