local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local LibStub = LibStub
local pairs = pairs

OneWoW_Bags.Integrations = OneWoW_Bags.Integrations or {}
OneWoW_Bags.Masque = {}
local M = OneWoW_Bags.Masque
OneWoW_Bags.Integrations.Masque = M

local Masque = LibStub("Masque", true)

M.available = Masque ~= nil
M.groups = nil
M.bagBarGroups = nil
M._initialized = false

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

--- True if Masque is loaded AND the user has not opted out via settings.
--- Database is queried lazily because Masque.lua loads before InitializeDatabase.
function M:IsActive()
    if not M.available then return false end
    local db = OneWoW_Bags.db
    if not db or not db.global then return true end
    return db.global.useMasque ~= false
end

function M:OnLoad()
    if not M.available or M._initialized then return end
    M._initialized = true

    M.groups = {
        bags    = Masque:Group("OneWoW_Bags", "Backpack"),
        bank    = Masque:Group("OneWoW_Bags", "Bank"),
        warband = Masque:Group("OneWoW_Bags", "Warband Bank"),
        guild   = Masque:Group("OneWoW_Bags", "Guild Bank"),
    }
    M.bagBarGroups = {
        bags    = M.groups.bags,
        bank    = M.groups.bank,
        warband = M.groups.warband,
        guild   = M.groups.guild,
    }

    for _, g in pairs(M.groups) do
        g:RegisterCallback(M.OnSkinChange, M)
    end
end

-- ---------------------------------------------------------------------------
-- Kind detection
-- ---------------------------------------------------------------------------

--- Determine the Masque group kind for an item button based on its bag flags
--- and the current bank mode.
---@param button table
---@return string kind  one of "bags" | "bank" | "warband" | "guild"
function M:KindFor(button)
    if button.owb_isGuildBank then
        return "guild"
    end
    if button.owb_isBank then
        local bc = OneWoW_Bags.BankController
        if bc and bc.IsWarbandMode and bc:IsWarbandMode() then
            return "warband"
        end
        return "bank"
    end
    return "bags"
end

-- ---------------------------------------------------------------------------
-- OneWoW_GUI chrome visibility
-- ---------------------------------------------------------------------------
-- When Masque skins a button, the OneWoW_GUI border/background/highlight
-- decorations (added by OneWoW_GUI:SkinIconFrame) would render behind the
-- Masque skin and bleed through transparent regions. Hide them while skinned,
-- restore them when unskinned. This lets the integration toggle at runtime
-- without recreating pool buttons.

local function HideOneWoWChrome(button)
    if button._skinBg then button._skinBg:Hide() end
    if button._skinBorder then button._skinBorder:Hide() end
    if button._skinHighlight then button._skinHighlight:Hide() end
end

local function ShowOneWoWChrome(button)
    if button._skinBg then button._skinBg:Show() end
    if button._skinBorder then button._skinBorder:Show() end
    if button._skinHighlight then button._skinHighlight:Show() end
end

-- ---------------------------------------------------------------------------
-- Item button skinning
-- ---------------------------------------------------------------------------

--- Add an item button to the appropriate Masque group. If the button was
--- previously in a different group (pool reuse across bag/bank/guild), it is
--- removed from that group first. OneWoW_GUI chrome regions are hidden so
--- Masque's skin is the only visual border.
---@param button table
---@param kind   string?  optional override of M:KindFor
function M:SkinItemButton(button, kind)
    if not M:IsActive() then return end
    kind = kind or M:KindFor(button)

    local prev = button._owbMasqueGroup
    if prev and prev ~= kind and M.groups[prev] then
        M.groups[prev]:RemoveButton(button)
    end

    local group = M.groups[kind]
    if not group then return end

    HideOneWoWChrome(button)
    group:AddButton(button)
    button._owbMasqueGroup = kind
    M:ReapplyBorderBlend(button)
end

--- Remove an item button from its Masque group and restore OneWoW_GUI chrome.
--- Safe to call when Masque is inactive — uses the per-button tag, not the
--- live IsActive() state.
---@param button table
function M:UnskinItemButton(button)
    local prev = button._owbMasqueGroup
    if not prev then
        return
    end
    button._owbMasqueGroup = nil
    if M.groups and M.groups[prev] then
        M.groups[prev]:RemoveButton(button)
    end
    ShowOneWoWChrome(button)
end

-- ---------------------------------------------------------------------------
-- Bag-bar button skinning
-- ---------------------------------------------------------------------------
-- Bag-bar slot buttons are plain CreateFrame("Button", ...) frames with only
-- a .icon texture. Masque expects named regions (Icon, Normal, Pushed,
-- Highlight). PrepareBagBarButton attaches the minimum surface area Masque
-- needs to skin them; SkinBagBarButton then adds them to the matching group.

local function PrepareBagBarButton(button)
    if button._owbBagBarPrepared then return end
    button._owbBagBarPrepared = true

    if not button.Icon and button.icon then
        button.Icon = button.icon
    end

    if not button:GetNormalTexture() then
        button:SetNormalTexture(0)
        local nt = button:GetNormalTexture()
        if nt then nt:SetAlpha(0) end
    end
    if not button:GetPushedTexture() then
        button:SetPushedTexture(0)
        local pt = button:GetPushedTexture()
        if pt then pt:SetAlpha(0) end
    end
    if not button:GetHighlightTexture() then
        button:SetHighlightTexture(0)
        local ht = button:GetHighlightTexture()
        if ht then ht:SetAlpha(0.3) end
    end
end

--- Skin a bag-bar slot button. Bag-bar buttons are not pooled, so this is
--- expected to be called once per button at creation time.
---@param button table
---@param kind   string  "bags" | "bank" | "warband" | "guild"
function M:SkinBagBarButton(button, kind)
    if not M:IsActive() then return end
    local group = M.bagBarGroups and M.bagBarGroups[kind]
    if not group then return end

    PrepareBagBarButton(button)
    HideOneWoWChrome(button)
    group:AddButton(button)
    button._owbMasqueGroup = kind
end

--- Remove a bag-bar slot button from its Masque group and restore OneWoW_GUI
--- chrome. Called when the integration is toggled off and the bar is rebuilt.
---@param button table
function M:UnskinBagBarButton(button)
    M:UnskinItemButton(button)
end

-- ---------------------------------------------------------------------------
-- Bag-bar selection overlay
-- ---------------------------------------------------------------------------
-- Bag/bank/guild bar tab selection is normally indicated by recoloring the
-- OneWoW_GUI _skinBorder. With Masque active that border is hidden, so we
-- need a separate overlay texture rendered on top of Masque's skin.

local function GetOrCreateSelectionOverlay(button)
    local overlay = button._owbMasqueSelection
    if overlay then return overlay end

    overlay = button:CreateTexture(nil, "OVERLAY", nil, 1)
    overlay:SetAllPoints(button)
    overlay:SetColorTexture(
        OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    )
    overlay:SetAlpha(0.35)
    overlay:Hide()
    button._owbMasqueSelection = overlay
    return overlay
end

--- Toggle the bag-bar selection indicator for a Masque-skinned button.
--- No-op when Masque is inactive (callers should use _skinBorder instead).
---@param button table
---@param selected boolean
function M:UpdateBagBarSelection(button, selected)
    if not M:IsActive() then return end
    local overlay = GetOrCreateSelectionOverlay(button)
    overlay:SetShown(selected and true or false)
end

-- ---------------------------------------------------------------------------
-- Border blend fixup
-- ---------------------------------------------------------------------------

--- Mirror BetterBags' ReapplyBlend: some Masque skins set IconBorder's blend
--- mode to "DISABLE", which suppresses the rarity tint. Force BLEND so the
--- quality color from SetItemButtonQuality renders correctly.
---@param button table
function M:ReapplyBorderBlend(button)
    local border = button.IconBorder
    if not border then return end
    if border:GetBlendMode() == "DISABLE" then
        border:SetBlendMode("BLEND")
    end
end

--- Masque fires this when the user changes skin/options. Refresh border blend
--- on every button in the affected group.
---@param group table
function M:OnSkinChange(group)
    if not group or not group.Buttons then return end
    for _, button in pairs(group.Buttons) do
        M:ReapplyBorderBlend(button)
    end
end
