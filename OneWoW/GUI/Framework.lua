-- ============================================================================
-- OneWoW/GUI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- Font functions (ApplyFont, ApplyFontToFrame, SafeSetFont, CreateFS) are
-- called directly from OneWoW_GUI. No per-addon bridges.
-- ============================================================================
local ADDON_NAME, OneWoW = ...

OneWoW.GUI = OneWoW.GUI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function OneWoW.GUI.SerializeVal(val, depth)
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        local inner = string.rep("  ", depth + 1)
        local outer = string.rep("  ", depth)
        for k, v in pairs(val) do
            local vStr = OneWoW.GUI.SerializeVal(v, depth + 1)
            if vStr ~= nil then
                local keyStr
                if type(k) == "string" and k:match("^[%a_][%a%d_]*$") then
                    keyStr = k
                elseif type(k) == "number" then
                    keyStr = "[" .. tostring(k) .. "]"
                else
                    keyStr = "[" .. string.format("%q", tostring(k)) .. "]"
                end
                table.insert(parts, inner .. keyStr .. " = " .. vStr)
            end
        end
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "}"
    end
    return nil
end

function OneWoW.GUI.CreateScrollableEditBox(parent, onEscape)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     4,  -4)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 4)
    sf:EnableMouseWheel(true)
    OneWoW_GUI:StyleScrollBar(sf, { container = parent, offset = -4 })

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(0)
    local fontPath = OneWoW_GUI and OneWoW_GUI.GetFont and OneWoW_GUI:GetFont() or "Fonts\\FRIZQT__.TTF"
    OneWoW_GUI:SafeSetFont(eb, fontPath, 12)
    eb:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    eb:SetScript("OnEscapePressed", onEscape or function() end)
    eb:SetScript("OnTextChanged", function() sf:UpdateScrollChildRect() end)

    sf:SetScrollChild(eb)
    sf:HookScript("OnSizeChanged", function(self, w) eb:SetWidth(w) end)

    return eb, sf
end
