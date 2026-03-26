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

--- New-item glow for player inventory bags only (not bank / guild bank). Uses Blizzard
--- C_NewItems plus ContainerFrameItemButtonTemplate overlays (see default ContainerFrame).
function Mixin:OWB_UpdateNewItemGlow(quality, hasItem)
    local BagTypes = OneWoW_Bags.BagTypes
    local bagID, slotID = self.owb_bagID, self.owb_slotID

    if not hasItem or not bagID or not slotID or not BagTypes:IsPlayerBag(bagID) then
        OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
        return
    end

    local db = OneWoW_Bags.db
    if not db or not db.global or not db.global.showNewItems then
        OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
        return
    end

    if not C_NewItems or not C_NewItems.IsNewItem or not C_NewItems.IsNewItem(bagID, slotID) then
        OneWoW_Bags.ItemPool:ClearNewItemGlow(self)
        return
    end

    local newItemTexture = self.NewItemTexture
    if not newItemTexture then
        return
    end

    local isBattlePay = C_Container.IsBattlePayItem and C_Container.IsBattlePayItem(bagID, slotID)
    if isBattlePay and self.BattlepayItemTexture then
        if self.flashAnim and self.flashAnim:IsPlaying() then self.flashAnim:Stop() end
        if self.newitemglowAnim and self.newitemglowAnim:IsPlaying() then self.newitemglowAnim:Stop() end
        newItemTexture:Hide()
        self.BattlepayItemTexture:Show()
        return
    end

    if self.BattlepayItemTexture then
        self.BattlepayItemTexture:Hide()
    end

    local atlasByQuality = _G.NEW_ITEM_ATLAS_BY_QUALITY
    local atlas = "bags-glow-white"
    if atlasByQuality and quality ~= nil and atlasByQuality[quality] then
        atlas = atlasByQuality[quality]
    end
    newItemTexture:SetAtlas(atlas)
    newItemTexture:Show()

    if self.flashAnim and self.newitemglowAnim then
        if not self.flashAnim:IsPlaying() and not self.newitemglowAnim:IsPlaying() then
            self.flashAnim:Play()
            self.newitemglowAnim:Play()
        end
    end
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
        local useRarity = db and db.global and (self.owb_isBank and db.global.bankRarityColor or db.global.rarityColor)
        if quality and quality >= 1 and useRarity then
            GUILib:UpdateIconQuality(self, quality)
        else
            GUILib:UpdateIconQuality(self, nil)
        end

        if self.SetItemButtonQuality then
            self:SetItemButtonQuality(quality, info.hyperlink, false)
            if self.IconBorder then self.IconBorder:Hide() end
            if self.ProfessionQualityOverlay then
                self.ProfessionQualityOverlay:SetDrawLayer("OVERLAY", 7)
            end
        end

        self.owb_hasItem = true
    else
        SetItemButtonTexture(self, nil)
        SetItemButtonCount(self, 0)
        GUILib:UpdateIconQuality(self, nil)
        if self.SetItemButtonQuality then
            self:SetItemButtonQuality(nil, nil, true)
        end
        self.owb_hasItem = false
    end

    self:OWB_RefreshCooldown()

    local quality = info and info.quality
    local hasItem = info and info.hyperlink
    self:OWB_UpdateNewItemGlow(quality, hasItem)
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
