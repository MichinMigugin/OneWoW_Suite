local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.ItemPool = {}
local Pool = OneWoW_Bags.ItemPool

local available = {}
local active = {}
local totalCreated = 0

function Pool:Preallocate(count)
    for i = 1, count do
        local button = Pool:CreateButton()
        button:Hide()
        tinsert(available, button)
    end
end

function Pool:Acquire()
    local button
    if #available > 0 then
        button = tremove(available)
    else
        button = Pool:CreateButton()
    end
    button.inUse = true
    active[button] = true
    return button
end

function Pool:Release(button)
    if not button then return end
    Pool:ResetButton(button)
    button.inUse = false
    active[button] = nil
    button:Hide()
    tinsert(available, button)
end

function Pool:ReleaseAll()
    for button in pairs(active) do
        Pool:Release(button)
    end
end

function Pool:GetActiveCount()
    local count = 0
    for _ in pairs(active) do count = count + 1 end
    return count
end

function Pool:GetTotalCount()
    return totalCreated
end

function Pool:CreateButton()
    totalCreated = totalCreated + 1
    local name = "OneWoW_BagsItem" .. totalCreated
    local button = CreateFrame("ItemButton", name, UIParent, "ContainerFrameItemButtonTemplate")
    button:SetSize(37, 37)
    button:Hide()
    button.owb_dirty = false
    button.owb_bagID = nil
    button.owb_slotID = nil
    button.owb_itemInfo = nil
    button.owb_categoryName = nil

    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    local highlightTexture = button:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetTexture(nil)
    end

    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pushedTexture = button:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetAllPoints()
    end

    if button.IconBorder then button.IconBorder:Hide() end
    if button.IconOverlay then button.IconOverlay:Hide() end
    if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
    if button.ExtendedSlot then button.ExtendedSlot:Hide() end
    if button.IconQuestTexture then button.IconQuestTexture:Hide() end

    button._skinnedIcon = button.icon
    OneWoW_GUI:SkinIconFrame(button, { preset = "clean" })
    button.icon:SetDrawLayer("ARTWORK")

    button._owb_baseChildCount = select("#", button:GetChildren())

    return button
end

function Pool:ClearNewItemGlow(button)
    if button.NewItemTexture then button.NewItemTexture:Hide() end
    if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
    if button.flashAnim and button.flashAnim:IsPlaying() then button.flashAnim:Stop() end
    if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then button.newitemglowAnim:Stop() end
end

function Pool:ResetButton(button)
    button.owb_dirty = false
    button.owb_bagID = nil
    button.owb_slotID = nil
    button.owb_itemInfo = nil
    button.owb_categoryName = nil
    button.owb_hasItem = false
    button:SetAlpha(1.0)
    if button._owbUnusableOverlay then button._owbUnusableOverlay:Hide() end
    button:ClearAllPoints()
    OneWoW_GUI:UpdateIconQuality(button, nil)
    if button.IconBorder then button.IconBorder:Hide() end
    if button.IconOverlay then button.IconOverlay:Hide() end
    if button.ItemContextOverlay then button.ItemContextOverlay:Hide() end
    if button.ExtendedSlot then button.ExtendedSlot:Hide() end
    if button.IconQuestTexture then button.IconQuestTexture:Hide() end
    if button.SetItemButtonQuality then
        button:SetItemButtonQuality(nil, nil, true)
    end
    local baseCount = button._owb_baseChildCount or 0
    local children = {button:GetChildren()}
    for i = baseCount + 1, #children do
        if children[i] ~= button.ProfessionQualityOverlay then
            children[i]:Hide()
        end
    end
    Pool:ClearNewItemGlow(button)
    SetItemButtonTexture(button, nil)
    SetItemButtonCount(button, 0)
    button:SetID(0)
end
