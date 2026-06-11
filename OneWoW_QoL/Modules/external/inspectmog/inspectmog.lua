-- Inspect Gear: a side panel on Blizzard's Inspect frame that lists the
-- equipped gear of the inspected player. Gear is read from the live unit via
-- GetInventoryItemLink (the item link already carries the colored name, so no
-- item-cache lookups are needed for display). The list can be saved to a
-- OneWoW Notes player note, and individual items can be pushed to Item Notes.
--
-- NOTE: this intentionally records EQUIPPED items, not resolved transmog
-- appearances. Resolving another player's transmog appearance to an item is
-- unreliable on 12.0 (C_TransmogCollection.GetAppearanceSources only returns
-- data for the inspector's own class proficiency), so it is not attempted.
local _, ns = ...

-- OneWoW Notes category key for items collected here (matches a built-in
-- OneWoW Notes Items category; not a translated string).
local NOTES_CATEGORY = "Transmog"

-- Result codes returned by the Notes helpers; mapped to locale keys by the UI.
local RESULT = {
    SAVED         = "saved",
    UPDATED       = "updated",
    ITEM_ADDED    = "item_added",
    NOTES_MISSING = "notes_missing",
    NO_DATA       = "no_data",
}

local EQUIP_SLOTS = {
    { id = INVSLOT_HEAD,     name = HEADSLOT },
    { id = INVSLOT_SHOULDER, name = SHOULDERSLOT },
    { id = INVSLOT_BACK,     name = BACKSLOT },
    { id = INVSLOT_CHEST,    name = CHESTSLOT },
    { id = INVSLOT_BODY,     name = SHIRTSLOT },
    { id = INVSLOT_TABARD,   name = TABARDSLOT },
    { id = INVSLOT_WRIST,    name = WRISTSLOT },
    { id = INVSLOT_HAND,     name = HANDSSLOT },
    { id = INVSLOT_WAIST,    name = WAISTSLOT },
    { id = INVSLOT_LEGS,     name = LEGSSLOT },
    { id = INVSLOT_FEET,     name = FEETSLOT },
    { id = INVSLOT_MAINHAND, name = MAINHANDSLOT },
    { id = INVSLOT_OFFHAND,  name = SECONDARYHANDSLOT },
}

local InspectMogModule = {
    id          = "inspectmog",
    title       = "INSPECTMOG_TITLE",
    category    = "SOCIAL",
    description = "INSPECTMOG_DESC",
    version     = "1.0",
    author      = "OneWoW",
    contact     = "https://wow2.xyz/",
    link        = "https://wow2.xyz/",
    preview     = true,
}
InspectMogModule.Result = RESULT
ns.InspectMog = InspectMogModule

-- ---- Notes helpers ----

local function EscapePattern(s)
    return (s:gsub("(%W)", "%%%1"))
end

--- Remove a previously-saved gear block (header..footer, inclusive) and trim.
---@param content string
---@param header string
---@param footer string
---@return string stripped
---@return integer removed
local function StripGearBlock(content, header, footer)
    local pattern = EscapePattern(header) .. ".-" .. EscapePattern(footer)
    local stripped, removed = content:gsub(pattern, "")
    stripped = stripped:gsub("^%s+", ""):gsub("%s+$", "")
    return stripped, removed
end

local function RefreshNotesTab(subTab, refreshName)
    -- OneWoW is a RequiredDep, so OneWoW.UI exists; the tab frame is nil until
    -- the Notes UI has been built/opened, hence the value nil check.
    local tab = OneWoW.UI:GetContentFrame("notes", subTab)
    if tab and tab[refreshName] then
        tab[refreshName]()
    end
end

-- ---- Public API ----

--- Build a snapshot of the inspected unit's equipped gear.
---@param unit string|nil
---@return table|nil snapshot
function InspectMogModule:BuildSnapshot(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local rows = {}
    for _, slot in ipairs(EQUIP_SLOTS) do
        local itemLink = GetInventoryItemLink(unit, slot.id)
        if itemLink then
            local itemID = C_Item.GetItemInfoInstant(itemLink)
            rows[#rows + 1] = {
                slotID   = slot.id,
                slotName = slot.name,
                itemLink = itemLink,
                itemID   = itemID,
                texture  = GetInventoryItemTexture(unit, slot.id),
            }
        end
    end

    local name, realm = UnitName(unit)
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    local _, class = UnitClass(unit)
    local _, race  = UnitRace(unit)
    local _, faction = UnitFactionGroup(unit)

    return {
        unit     = unit,
        name     = name,
        realm    = realm,
        fullName = (name or "?") .. "-" .. (realm or "?"),
        class    = class and class:upper() or nil,
        race     = race,
        level    = UnitLevel(unit),
        faction  = faction,
        rows     = rows,
    }
end

--- Save a gear snapshot to the player's OneWoW Notes note. Replaces an existing
--- gear block in place; appends if none exists; preserves the rest of the note.
---@param snapshot table|nil
---@return boolean ok
---@return string result
---@return string|nil playerName
function InspectMogModule:SaveSnapshotToPlayerNote(snapshot)
    if not snapshot or #snapshot.rows == 0 then
        return false, RESULT.NO_DATA
    end

    -- OneWoW Notes is an optional integration, not a hard dependency.
    local notes = OneWoW_Notes
    if not notes or not notes.Players then
        return false, RESULT.NOTES_MISSING
    end

    local L = ns.L
    local header = L["INSPECTMOG_NOTE_HEADER"]
    local footer = L["INSPECTMOG_NOTE_FOOTER"]

    local lines = {}
    lines[#lines + 1] = header
    lines[#lines + 1] = string.format(L["INSPECTMOG_NOTE_UPDATED"], date("%Y-%m-%d %H:%M"))
    for _, row in ipairs(snapshot.rows) do
        lines[#lines + 1] = string.format(L["INSPECTMOG_NOTE_LINE"], row.slotName, row.itemLink)
    end
    lines[#lines + 1] = footer
    local block = table.concat(lines, "\n")

    local fullName = snapshot.fullName
    local existing = notes.Players:GetPlayer(fullName)
    local wasUpdate = false

    if existing then
        local stripped, removed = StripGearBlock(existing.content or "", header, footer)
        wasUpdate = removed > 0
        if stripped ~= "" then
            existing.content = stripped .. "\n\n" .. block
        else
            existing.content = block
        end
        notes.Players:SavePlayer(fullName, existing)
    else
        notes.Players:AddPlayer(fullName, {
            name     = snapshot.name,
            realm    = snapshot.realm,
            fullName = fullName,
            class    = snapshot.class,
            race     = snapshot.race,
            level    = snapshot.level,
            faction  = snapshot.faction,
            category = "General",
            storage  = "account",
            content  = block,
        })
    end

    RefreshNotesTab("players", "RefreshPlayersList")
    return true, wasUpdate and RESULT.UPDATED or RESULT.SAVED, snapshot.name
end

--- Append an "inspected on" stamp to an Item Notes entry (creates it if new).
--- Always appends; never overwrites existing item-note content.
---@param rowData table
---@param playerName string|nil
---@return boolean ok
---@return string result
---@return string|nil itemLink
function InspectMogModule:AddItemToNotes(rowData, playerName)
    local notes = OneWoW_Notes
    if not notes or not notes.Items then
        return false, RESULT.NOTES_MISSING
    end

    local itemID = rowData and rowData.itemID
    if not itemID then
        return false, RESULT.NO_DATA
    end

    local L = ns.L
    local stamp = string.format(L["INSPECTMOG_ITEM_STAMP"], playerName or "?", date("%Y-%m-%d %H:%M"))

    local existing = notes.Items:GetItem(itemID)
    if existing then
        local content = existing.content or ""
        if content ~= "" then
            existing.content = content .. "\n" .. stamp
        else
            existing.content = stamp
        end
        notes.Items:SaveItem(itemID, existing)
    else
        notes.Items:AddItem(itemID, {
            category = NOTES_CATEGORY,
            storage  = "account",
            content  = stamp,
        })
    end

    RefreshNotesTab("items", "RefreshItemsList")
    return true, RESULT.ITEM_ADDED, rowData.itemLink
end

-- ---- Inspect frame integration ----

--- The unit currently shown in Blizzard's Inspect frame, or nil.
---@return string|nil unit
function InspectMogModule:GetUnit()
    -- InspectFrame belongs to the load-on-demand Blizzard_InspectUI; it can be nil.
    return InspectFrame and InspectFrame.unit
end

function InspectMogModule:HookInspectFrame()
    if self._hooked or not InspectFrame then
        return
    end
    self._hooked = true

    -- Blizzard's InspectFrame_Show already calls NotifyInspect; we only observe.
    -- Re-requesting here would fire extra INSPECT_READY cycles and amplify the
    -- Blizzard InspectGuildFrame nil-guild error, so we never call NotifyInspect.
    InspectFrame:HookScript("OnShow", function()
        if not ns.ModuleRegistry:IsEnabled("inspectmog") then
            return
        end
        ns.InspectMogUI:Show()
    end)

    InspectFrame:HookScript("OnHide", function()
        ns.InspectMogUI:Hide()
    end)

    if InspectFrame:IsShown() and ns.ModuleRegistry:IsEnabled("inspectmog") then
        ns.InspectMogUI:Show()
    end
end

function InspectMogModule:OnEnable()
    OneWoW:EnsureLoaded("Blizzard_InspectUI")

    if InspectFrame then
        self:HookInspectFrame()
    elseif not self._inspectWatcherRegistered then
        self._inspectWatcherRegistered = true
        local register = OneWoW_QoL.RegisterAddonLoadedWatcher and OneWoW_QoL.RegisterAddonLoadedWatcher
            or OneWoW.RegisterAddonLoadedWatcher
        register("Blizzard_InspectUI", function()
            InspectMogModule:HookInspectFrame()
        end)
    end

    -- Blizzard hides the InspectFrame when the target changes, so the panel
    -- follows via OnHide; we only need to repaint when fresh data arrives.
    if not self._events then
        local f = CreateFrame("Frame")
        self._events = f
        f:SetScript("OnEvent", function(_, event)
            if event == "INSPECT_READY" and ns.ModuleRegistry:IsEnabled("inspectmog") then
                ns.InspectMogUI:Refresh()
            end
        end)
    end
    self._events:RegisterEvent("INSPECT_READY")
end

function InspectMogModule:OnDisable()
    if self._events then
        self._events:UnregisterAllEvents()
    end
    if ns.InspectMogUI then
        ns.InspectMogUI:Hide()
    end
end
