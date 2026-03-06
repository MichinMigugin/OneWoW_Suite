local ADDON_NAME, OneWoW_Bags = ...
OneWoW_Bags.ItemPool = {}
local Pool = OneWoW_Bags.ItemPool

local available = {}
local active = {}
local totalCreated = 0

function Pool:Preallocate(count)
    for i = 1, count do
        local button = Pool:CreateButton()
        button:Hide()
        table.insert(available, button)
    end
end

function Pool:Acquire()
    local button
    if #available > 0 then
        button = table.remove(available)
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
    table.insert(available, button)
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
        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTexture:SetSize(64, 64)
        normalTexture:ClearAllPoints()
        normalTexture:SetPoint("CENTER", 0, -1)
    end

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local highlightTexture = button:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetAllPoints()
        highlightTexture:SetBlendMode("ADD")
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

    button.owb_rarityBorder = button:CreateTexture(nil, "OVERLAY")
    button.owb_rarityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.owb_rarityBorder:SetTexCoord(0.218, 0.718, 0.234, 0.781)
    button.owb_rarityBorder:SetBlendMode("ADD")
    button.owb_rarityBorder:SetSize(41, 41)
    button.owb_rarityBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.owb_rarityBorder:Hide()

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
    button:ClearAllPoints()
    button.owb_rarityBorder:Hide()
    if button.IconBorder then button.IconBorder:Hide() end
    Pool:ClearNewItemGlow(button)
    SetItemButtonTexture(button, nil)
    SetItemButtonCount(button, 0)
    button:SetID(0)
end
