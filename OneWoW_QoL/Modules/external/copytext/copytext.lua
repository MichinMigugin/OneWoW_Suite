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
}

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("copytext", id)
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
    local fastCopy = GetToggle("fast_copy")
    OneWoW.CopyPaste:Copy(title or "Copy", text, { autoHide = fastCopy, readOnly = fastCopy })
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
