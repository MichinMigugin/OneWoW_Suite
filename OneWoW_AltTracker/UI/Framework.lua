-- ============================================================================
-- OneWoW_AltTracker/UI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- This file only maps library calls into the local ns.UI namespace.
-- If you need a new UI function, add it to OneWoW_GUI/OneWoW_GUI.lua first,
-- then add a thin wrapper here.
-- ============================================================================
local addonName, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function ns.UI.CreateSearchBox(parent, options)
    return OneWoW_GUI:CreateEditBox(parent, options)
end

function ns.UI.ClearFrame(frame)
    return OneWoW_GUI:ClearFrame(frame)
end

function ns.UI.CreateDialog(config)
    return OneWoW_GUI:CreateDialog(config)
end

function ns.UI.CreateConfirmDialog(config)
    return OneWoW_GUI:CreateConfirmDialog(config)
end

function ns.UI.CreateFilterBar(parent, config)
    return OneWoW_GUI:CreateFilterBar(parent, config)
end

function ns.UI.ApplyFont(fs, size)
    if not fs then return end
    if size then
        fs._owBaseSize = size
    elseif not fs._owBaseSize and fs.GetFont then
        local _, currentSize = fs:GetFont()
        fs._owBaseSize = currentSize or 13
    end
    OneWoW_GUI:SafeSetFont(fs, OneWoW_GUI:GetFont(), fs._owBaseSize or 13)
end

function ns.UI.ApplyFontCapped(fs, size, maxOffset)
    if not fs then return end
    fs._owBaseSize = size
    fs._owMaxOffset = maxOffset
    local fontPath = OneWoW_GUI:GetFont()
    local offset = OneWoW_GUI:GetFontSizeOffset() or 0
    local cappedSize = math.max(6, size + math.min(offset, maxOffset))
    if fontPath then
        local ok = pcall(fs.SetFont, fs, fontPath, cappedSize, "")
        if not ok then fs:SetFontObject(GameFontNormal) end
    else
        fs:SetFontObject(GameFontNormal)
    end
end

function ns.UI.ApplyFontToFrame(frame)
    if not frame then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            if not region._owBaseSize then
                local _, sz = region:GetFont()
                if sz and sz > 0 then
                    region._owBaseSize = sz
                end
            end
            if region._owBaseSize then
                if region._owMaxOffset then
                    ns.UI.ApplyFontCapped(region, region._owBaseSize, region._owMaxOffset)
                else
                    OneWoW_GUI:SafeSetFont(region, OneWoW_GUI:GetFont(), region._owBaseSize)
                end
            end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            if not child._owBaseSize then
                local _, sz = child:GetFont()
                if sz and sz > 0 then
                    child._owBaseSize = sz
                end
            end
            if child._owBaseSize then
                local _, _, flags = child:GetFont()
                OneWoW_GUI:SafeSetFont(child, OneWoW_GUI:GetFont(), child._owBaseSize, flags)
            end
        end
        ns.UI.ApplyFontToFrame(child)
    end
end

function ns.IsFavoriteChar(charKey)
    local db = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global
    return db and db.favorites and db.favorites[charKey] == true
end

function ns.SetFavoriteChar(charKey, value)
    local addon = _G.OneWoW_AltTracker
    if not addon or not addon.db then return end
    if not addon.db.global.favorites then
        addon.db.global.favorites = {}
    end
    addon.db.global.favorites[charKey] = value and true or nil
end
