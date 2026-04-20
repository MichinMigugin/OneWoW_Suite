local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BagTypes = OneWoW_Bags.BagTypes
local ItemPool = OneWoW_Bags.ItemPool
local PE = OneWoW_GUI.PredicateEngine

local pairs, select = pairs, select

local UnitLevel = UnitLevel
local C_Container = C_Container
local C_Item = C_Item
local PixelUtil = PixelUtil

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

function Mixin:OWB_UpdateNewItemGlow(quality, hasItem)
    local db = OneWoW_Bags:GetDB()
    local bagID, slotID = self.owb_bagID, self.owb_slotID

    if not hasItem or not bagID or not slotID or not BagTypes:IsPlayerBag(bagID) then
        ItemPool:ClearNewItemGlow(self)
        return
    end

    if not db.global.showNewItems then
        ItemPool:ClearNewItemGlow(self)
        return
    end

    local infoForProps = self.owb_itemInfo
    if not infoForProps or not infoForProps.itemID then
        ItemPool:ClearNewItemGlow(self)
        return
    end
    if not PE:BuildProps(infoForProps.itemID, bagID, slotID, infoForProps).isNew then
        ItemPool:ClearNewItemGlow(self)
        return
    end

    local newItemTexture = self.NewItemTexture
    if not newItemTexture then
        return
    end

    local isBattlePay = C_Container.IsBattlePayItem(bagID, slotID)
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

    local atlasByQuality = NEW_ITEM_ATLAS_BY_QUALITY
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

    local info = C_Container.GetContainerItemInfo(self.owb_bagID, self.owb_slotID)
    self.owb_itemInfo = info

    if info and info.hyperlink then
        SetItemButtonTexture(self, info.iconFileID)
        SetItemButtonCount(self, info.stackCount)
        SetItemButtonDesaturated(self, info.isLocked)

        local quality = info.quality
        if OneWoW_Bags:ShouldShowItemQuality(self.owb_isBank, quality) then
            OneWoW_GUI:UpdateIconQuality(self, quality)
        else
            OneWoW_GUI:UpdateIconQuality(self, nil)
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
        OneWoW_GUI:UpdateIconQuality(self, nil)
        if self.SetItemButtonQuality then
            self:SetItemButtonQuality(nil, nil, true)
        end
        self.owb_hasItem = false
    end

    self:OWB_RefreshCooldown()

    local quality = info and info.quality
    local hasItem = info and info.hyperlink
    self:OWB_UpdateNewItemGlow(quality, hasItem)
    self:OWB_UpdateJunkDim(quality, hasItem, info)
    self:OWB_UpdateUnusableOverlay(hasItem, info)

    self._owb_isJunk = hasItem and info and info.itemID
        and PE:BuildProps(info.itemID, self.owb_bagID, self.owb_slotID, info).isJunk
        or false
end

function Mixin:OWB_UpdateJunkDim(quality, hasItem, info)
    if not hasItem then
        self:SetAlpha(1.0)
        return
    end

    local isJunk = info and info.itemID
        and PE:BuildProps(info.itemID, self.owb_bagID, self.owb_slotID, info).isJunk
        or false

    if OneWoW_Bags:ShouldDimJunkItem(isJunk) then
        self:SetAlpha(0.4)
    else
        self:SetAlpha(1.0)
    end

    if OneWoW_Bags:ShouldStripJunkOverlays(isJunk) then
        if self.NewItemTexture then self.NewItemTexture:Hide() end
        if self.BattlepayItemTexture then self.BattlepayItemTexture:Hide() end
        if self.ProfessionQualityOverlay then self.ProfessionQualityOverlay:Hide() end
        if self.flashAnim and self.flashAnim:IsPlaying() then self.flashAnim:Stop() end
        if self.newitemglowAnim and self.newitemglowAnim:IsPlaying() then self.newitemglowAnim:Stop() end
        OneWoW_GUI:UpdateIconQuality(self, nil)
        self._owb_junkStripped = true
    elseif self._owb_junkStripped then
        self._owb_junkStripped = false
    end
end

function Mixin:OWB_UpdateUnusableOverlay(hasItem, info)
    local db = OneWoW_Bags:GetDB()
    if not db.global.showUnusableOverlay then
        if self._owbUnusableOverlay then self._owbUnusableOverlay:Hide() end
        return
    end

    if not hasItem or not info or not info.itemID then
        if self._owbUnusableOverlay then self._owbUnusableOverlay:Hide() end
        return
    end

    local isEquippable = C_Item.IsEquippableItem(info.itemID)
    if not isEquippable then
        if self._owbUnusableOverlay then self._owbUnusableOverlay:Hide() end
        return
    end

    local canEquip = true
    if info.hyperlink then
        local UD = _G.OneWoW and _G.OneWoW.UpgradeDetection
        if UD then
            canEquip = UD:CanPlayerUseItem(info.hyperlink)
        end

        if canEquip then
            local reqLevel = select(5, C_Item.GetItemInfo(info.hyperlink))
            if reqLevel and reqLevel > 0 and UnitLevel("player") < reqLevel then
                canEquip = false
            end
        end
    end

    if not canEquip then
        if not self._owbUnusableOverlay then
            self._owbUnusableOverlay = self:CreateTexture(nil, "OVERLAY", nil, 2)
            self._owbUnusableOverlay:SetAllPoints()
            self._owbUnusableOverlay:SetColorTexture(1, 0, 0, 0.3)
        end
        self._owbUnusableOverlay:Show()
    else
        if self._owbUnusableOverlay then self._owbUnusableOverlay:Hide() end
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
    PixelUtil.SetSize(self, size, size)
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
