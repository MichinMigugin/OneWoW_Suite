local _, ns = ...
local L = ns.L

-- ============================================================================
-- Collectibles merchant capture
-- ============================================================================
-- Subscribes Notes to the core OneWoW.Merchant scan funnel and turns vendor
-- items that grant an uncollected collectible into "want" records with a vendor
-- offer snapshot. Capture is a *subscription decision*, not a handler-side gate:
--   off    -> not subscribed (manual add only)
--   prompt -> subscribed; a per-vendor confirm before capturing new offers
--   auto   -> subscribed; silently upserts uncollected vendor collectibles
-- The scan fans out to all subscribers and can be re-delivered (catch-up/retry),
-- so every path here is idempotent (MergeVendorOffer dedupes by npc+item).
--
-- No BringUp: Notes must already be loaded for passive capture. If Notes is
-- opted out, the merchant scan still runs for any other subscriber (or not at
-- all). Core (OneWoW.Merchant / OneWoW.Collectibles) is always resident.
-- ============================================================================

local CollectiblesMerchant = {}
ns.CollectiblesMerchant = CollectiblesMerchant

local OWNER_ID = "OneWoW_Notes_Collectibles"
local POPUP = "ONEWOW_NOTES_CAPTURE_COLLECTIBLES"

local pairs, ipairs = pairs, ipairs

local function CaptureMode()
    return ns.db.global.collectibleCaptureMode
end

-- Slim vendor-offer junction from a scan + one of its item entries.
local function BuildOffer(scan, itemID, item)
    return {
        npcID         = scan.npcID,
        npcName       = scan.name,
        itemID        = itemID,
        cost          = item.cost,
        currencies    = item.currencies,
        isPurchasable = item.isPurchasable,
        blockReason   = item.blockReason,
        location      = scan.location,
        lastSeen      = item.lastSeen or scan.scannedAt,
    }
end

-- Items on the scan that grant a not-yet-collected collectible.
-- Returns an array of { key, itemID, item }.
local function GatherCandidates(scan)
    local Collectibles = OneWoW.Collectibles
    local out = {}
    if not (scan and scan.items) then return out end

    for itemID, item in pairs(scan.items) do
        local key = Collectibles.ResolveKeyFromItem(itemID)
        if key then
            local state = Collectibles.GetCollectionState(key)
            if not (state and state.collected) then
                out[#out + 1] = { key = key, itemID = itemID, item = item }
            end
        end
    end
    return out
end

local function CaptureCandidate(scan, cand)
    local offer = BuildOffer(scan, cand.itemID, cand.item)
    local ok, isNew = ns.Collectibles:MergeVendorOffer(cand.key, offer)

    -- An ensemble resolves to a `set` record: the set has no icon/link of its
    -- own, so remember the teaching item that was on sale — the detail view shows
    -- that item's icon/link and falls back to a member appearance when absent.
    if ok then
        local descriptor = OneWoW.Collectibles.ParseKey(cand.key)
        if descriptor and descriptor.type == "set" then
            ns.Collectibles:UpsertCollectible(cand.key, { sourceItemID = cand.itemID })
        end
    end

    return ok, isNew
end

-- Refresh the Collectibles tab if it is built, so a live capture shows up.
local function RefreshTab()
    if ns.UI and ns.UI.RefreshCollectiblesList then
        ns.UI.RefreshCollectiblesList()
    end
    if ns.UI and ns.UI.RefreshCollectiblesDetail then
        ns.UI.RefreshCollectiblesDetail()
    end
end

-- Confirm dialog for prompt mode. Captures every candidate on accept. Guarded so
-- repeated scans while the dialog is open don't re-stack it.
function CollectiblesMerchant:PromptCapture(scan, candidates)
    if StaticPopup_Visible and StaticPopup_Visible(POPUP) then return end

    StaticPopupDialogs[POPUP] = {
        text = string.format(L["POPUP_CAPTURE_COLLECTIBLES"], #candidates),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            local added = 0
            for _, cand in ipairs(candidates) do
                local ok, isNew = CaptureCandidate(scan, cand)
                if ok and isNew then added = added + 1 end
            end
            if added > 0 then
                print("|cFFFFD100OneWoW - Notes:|r " ..
                    string.format(L["COLLECTIBLE_CAPTURE_ADDED"], added))
                RefreshTab()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show(POPUP)
end

local function OnMerchantScan(scan)
    local mode = CaptureMode()
    if mode == "off" then return end

    local candidates = GatherCandidates(scan)
    if #candidates == 0 then return end

    if mode == "auto" then
        local added = 0
        for _, cand in ipairs(candidates) do
            local ok, isNew = CaptureCandidate(scan, cand)
            if ok and isNew then added = added + 1 end
        end
        if added > 0 then RefreshTab() end
        return
    end

    -- prompt: only surface a dialog when there is at least one offer we have not
    -- already recorded (otherwise repeated scans of a known vendor would nag).
    local newOnes = {}
    for _, cand in ipairs(candidates) do
        if not ns.Collectibles:HasVendorOffer(cand.key, scan.npcID, cand.itemID) then
            newOnes[#newOnes + 1] = cand
        end
    end
    if #newOnes == 0 then return end

    CollectiblesMerchant:PromptCapture(scan, newOnes)
end

--- Reconcile the merchant subscription with the current capture mode. The single
--- point a mode change (or login) calls to subscribe/unsubscribe.
function CollectiblesMerchant:ApplySubscription()
    if CaptureMode() == "off" then
        OneWoW.Merchant.UnregisterCallback(OWNER_ID)
    else
        OneWoW.Merchant.RegisterScanCallback(OWNER_ID, OnMerchantScan)
    end
end

--- Current capture mode ("off" | "prompt" | "auto").
---@return string
function CollectiblesMerchant:GetCaptureMode()
    return CaptureMode()
end

--- Set the capture mode and reconcile the subscription.
---@param mode string "off" | "prompt" | "auto"
function CollectiblesMerchant:SetCaptureMode(mode)
    if mode ~= "prompt" and mode ~= "auto" then mode = "off" end
    ns.db.global.collectibleCaptureMode = mode
    self:ApplySubscription()
end

function CollectiblesMerchant:Initialize()
    self:ApplySubscription()
end
