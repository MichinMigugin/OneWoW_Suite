local ADDON_NAME, OneWoW_Bags = ...
OneWoW_Bags.ItemButtonMixin = {}
local Mixin = OneWoW_Bags.ItemButtonMixin

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
    local GUILib = OneWoW_Bags.GUILib

    local info = C_Container.GetContainerItemInfo(self.owb_bagID, self.owb_slotID)
    self.owb_itemInfo = info

    if info and info.hyperlink then
        SetItemButtonTexture(self, info.iconFileID)
        SetItemButtonCount(self, info.stackCount)
        SetItemButtonDesaturated(self, info.isLocked)

        local quality = info.quality
        if quality and quality >= 1 and db and db.global and db.global.rarityColor then
            GUILib:UpdateIconQuality(self, quality)
        else
            GUILib:UpdateIconQuality(self, nil)
        end

        self.owb_hasItem = true
    else
        SetItemButtonTexture(self, nil)
        SetItemButtonCount(self, 0)
        GUILib:UpdateIconQuality(self, nil)
        self.owb_hasItem = false
    end

    self:OWB_RefreshCooldown()

    local isBank = OneWoW_Bags.BagTypes and (OneWoW_Bags.BagTypes:IsBankBag(self.owb_bagID) or OneWoW_Bags.BagTypes:IsWarbandBag(self.owb_bagID))
    local isGuild = self.owb_isGuildBank

    if not isBank and not isGuild then
        local isNew = false
        if db and db.global and db.global.showNewItems and info and info.hyperlink then
            isNew = C_NewItems.IsNewItem(self.owb_bagID, self.owb_slotID)
        end
        if not isNew then
            OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
        end
    else
        OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
    end
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
