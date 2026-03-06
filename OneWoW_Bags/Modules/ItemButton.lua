local ADDON_NAME, OneWoW_Bags = ...
OneWoW_Bags.ItemButtonMixin = {}
local Mixin = OneWoW_Bags.ItemButtonMixin

local RARITY_COLORS = {
    [1] = {r = 1.0, g = 1.0, b = 1.0},
    [2] = {r = 0.12, g = 1.0, b = 0.0},
    [3] = {r = 0.0, g = 0.44, b = 0.87},
    [4] = {r = 0.64, g = 0.21, b = 0.93},
    [5] = {r = 1.0, g = 0.5, b = 0.0},
    [6] = {r = 0.9, g = 0.8, b = 0.5},
    [7] = {r = 0.0, g = 0.8, b = 1.0},
    [8] = {r = 0.0, g = 0.8, b = 1.0},
}

function Mixin:OWB_SetSlot(bagID, slotID)
    self.owb_bagID = bagID
    self.owb_slotID = slotID
    self:SetID(slotID)
    self:OWB_MarkDirty()
end

function Mixin:OWB_MarkDirty()
    self.owb_dirty = true
end

function Mixin:OWB_IsDirty()
    return self.owb_dirty
end

function Mixin:OWB_FullUpdate()
    self.owb_dirty = false
    local db = OneWoW_Bags.db

    local info = C_Container.GetContainerItemInfo(self.owb_bagID, self.owb_slotID)
    self.owb_itemInfo = info

    if info and info.hyperlink then
        SetItemButtonTexture(self, info.iconFileID)
        SetItemButtonCount(self, info.stackCount)
        SetItemButtonDesaturated(self, info.isLocked)

        local quality = info.quality
        if quality and quality >= 1 and db and db.global and db.global.rarityColor then
            local color = RARITY_COLORS[quality]
            if color then
                self:OWB_ShowRarity(color.r, color.g, color.b, 0.65)
            else
                self:OWB_HideRarity()
            end
        else
            self:OWB_HideRarity()
        end

        self.owb_hasItem = true
    else
        SetItemButtonTexture(self, nil)
        SetItemButtonCount(self, 0)
        self:OWB_HideRarity()
        self.owb_hasItem = false
    end

    self:OWB_RefreshCooldown()
    OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
end

function Mixin:OWB_RefreshCooldown()
    if not self.owb_bagID or not self.owb_slotID then return end
    local startTime, duration, enable = C_Container.GetContainerItemCooldown(self.owb_bagID, self.owb_slotID)
    if startTime and self.Cooldown then
        CooldownFrame_Set(self.Cooldown, startTime, duration, enable)
    end
end

function Mixin:OWB_RefreshLock()
    if not self.owb_bagID or not self.owb_slotID then return end
    local info = C_Container.GetContainerItemInfo(self.owb_bagID, self.owb_slotID)
    if info then
        SetItemButtonDesaturated(self, info.isLocked)
    end
end

function Mixin:OWB_SetIconSize(size)
    self:SetSize(size, size)
    if self.owb_rarityBorder then
        local borderSize = size + 3
        if size <= 32 then borderSize = size + 3 end
        if size >= 37 then borderSize = size + 2 end
        self.owb_rarityBorder:SetSize(borderSize, borderSize)
    end
    local normalTexture = self:GetNormalTexture()
    if normalTexture then
        local borderSize = math.floor(size * 1.7)
        normalTexture:SetSize(borderSize, borderSize)
    end
end

function Mixin:OWB_ShowRarity(r, g, b, intensity)
    if not self.owb_rarityBorder then return end
    local a = intensity or 0.65
    self.owb_rarityBorder:SetVertexColor(r, g, b, a)
    self.owb_rarityBorder:Show()
end

function Mixin:OWB_HideRarity()
    if not self.owb_rarityBorder then return end
    self.owb_rarityBorder:Hide()
end

function Mixin:OWB_GetLink()
    if not self.owb_bagID or not self.owb_slotID then return nil end
    return C_Container.GetContainerItemLink(self.owb_bagID, self.owb_slotID)
end

function OneWoW_Bags:ApplyItemButtonMixin(button)
    if button._owbMixinApplied then return end
    button._owbMixinApplied = true
    for k, v in pairs(Mixin) do
        button[k] = v
    end
end
