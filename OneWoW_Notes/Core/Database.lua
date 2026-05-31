local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

local pairs, ipairs, type, next = pairs, ipairs, type, next

local defaults = {
    global = {
        language               = nil,
        theme                  = "green",
        lastTab                = "notes",
        mainFrameSize          = nil,
        mainFramePosition      = nil,
        minimap                = { hide = false, minimapPos = 220, theme = "horde" },
        notes                  = {},
        items                  = {},
        zones                  = {},
        players                = {},
        npcs                   = {},
        notesCustomCategories  = {},
        itemCustomCategories   = {},
        zoneCustomCategories   = {},
        playerCustomCategories = {},
        npcCustomCategories    = {},
        notePinPositions       = {},
        zonePinPositions       = {},
        tabSortPrefs = {
            notes   = { by = "modified", ascending = false },
            npcs    = { by = "name",     ascending = true  },
            players = { by = "name",     ascending = true  },
            zones   = { by = "name",     ascending = true  },
            items   = { by = "name",     ascending = true  },
        },
        zoneAlertsEnabled  = true,
        sortCompletedTasks = false,
    },
    char = {
        notes   = {},
        items   = {},
        zones   = {},
        players = {},
        npcs    = {},
    },
}

-- Migrates the legacy "hunter" pin / "match" font color combo to the OneWoW Sync theme.
-- Mutates entries in d.global[dbKey] and d.char[dbKey] in place.
function ns:MigratePinColors(d, dbKey)
    local count = 0
    local function walk(bucket)
        if type(bucket) ~= "table" then return end
        for _, data in pairs(bucket) do
            if type(data) == "table" and data.pinColor == "hunter" and data.fontColor == "match" then
                data.pinColor = "sync"
                count = count + 1
            end
        end
    end
    walk(d.global[dbKey])
    walk(d.char[dbKey])
    if count > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. count .. " " .. dbKey .. " to OneWoW Sync theme")
    end
end

-- Maps legacy LibSharedMedia font names on each entry's fontFamily to the OneWoW_GUI font key system.
function ns:MigratePinFonts(d, dbKey)
    local count = 0
    local function walk(bucket)
        if type(bucket) ~= "table" then return end
        for _, data in pairs(bucket) do
            if type(data) == "table" and data.fontFamily then
                local newKey = OneWoW_GUI:MigrateLSMFontName(data.fontFamily)
                if newKey then
                    data.fontFamily = newKey
                    count = count + 1
                end
            end
        end
    end
    walk(d.global[dbKey])
    walk(d.char[dbKey])
    if count > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. count .. " " .. dbKey .. " font(s) to new font system")
    end
end

function ns:InitializeDatabase()
    -- Bridge from legacy DB:NewCompat (sv.char[charKey]) layout to DB:Init single mode (sv.chars[charKey]).
    -- One-time rename; future loads see sv.chars and skip this block.
    local sv = OneWoW_Notes_DB
    if sv and sv.char and not sv.chars then
        sv.chars = sv.char
        sv.char = nil
        sv.profileKeys = nil
    end

    -- Consolidate legacy char-key variants into the canonical OneWoW_GUI form.
    -- AceDB used "Name - Realm" (space-dash-space). DB:NewCompat used "Name-Realm"
    -- but didn't strip realm spaces. Current GetCharacterKey strips all whitespace
    -- from the realm, producing "Name-RealmNoSpaces". Without this pass, a single
    -- character's data fragments across multiple keys (the AceDB-era keys held the
    -- old in-Notes Trackers data; later keys held empty Notes buckets) and the
    -- Trackers Notes-char drain misses the legacy data because BuildCharKey only
    -- returns the canonical form. Idempotent: once no variants remain, no-op.
    --
    -- Snapshot keys before mutating because pairs() over a table while inserting
    -- previously-absent keys is undefined behavior in Lua 5.1.
    if sv and type(sv.chars) == "table" then
        local oldKeys = {}
        for k in pairs(sv.chars) do oldKeys[#oldKeys + 1] = k end
        for _, oldKey in ipairs(oldKeys) do
            local oldData = sv.chars[oldKey]
            local name, realm = oldKey:match("^(.-)%s*-%s*(.+)$")
            local canonical = name and realm and OneWoW_GUI:GetCharacterKey(name, realm)
            if canonical and canonical ~= oldKey and type(oldData) == "table" then
                local target = sv.chars[canonical]
                if type(target) ~= "table" then
                    sv.chars[canonical] = oldData
                else
                    -- Gap-fill merge: target wins for non-nil scalar conflicts;
                    -- table conflicts merge one level deep (sufficient for the
                    -- shapes that show up here: trackerProgress / routineProgress /
                    -- guideProgress are keyed by listID/routineID at the top level).
                    for k, v in pairs(oldData) do
                        if target[k] == nil then
                            target[k] = v
                        elseif type(target[k]) == "table" and type(v) == "table" then
                            for k2, v2 in pairs(v) do
                                if target[k][k2] == nil then
                                    target[k][k2] = v2
                                end
                            end
                        end
                    end
                end
                sv.chars[oldKey] = nil
            end
        end
    end

    local db = DB:Init({
        addonName = addonName,
        savedVar  = "OneWoW_Notes_DB",
        defaults  = defaults,
    })
    self.db = db

    -- Bridge legacy boolean migration flags to the integer _migrationVersion high-water mark.
    -- Each successive flag implies all earlier migrations also ran.
    if db.global._migrationVersion == nil then
        local v = 0
        if db.global.colorsMigrated         then v = 1 end
        if db.global.fontFamilyMigrated     then v = 2 end
        if db.global.zoneColorsMigrated     then v = 3 end
        if db.global.zoneFontFamilyMigrated then v = 4 end
        if v > 0 then
            db.global._migrationVersion = v
        end
    end

    DB:RunMigrations(db, {
        { version = 1, name = "notes_pin_colors", run = function(d)
            self:MigratePinColors(d, "notes")
        end },
        { version = 2, name = "notes_pin_fonts", run = function(d)
            self:MigratePinFonts(d, "notes")
        end },
        { version = 3, name = "zones_pin_colors", run = function(d)
            self:MigratePinColors(d, "zones")
        end },
        { version = 4, name = "zones_pin_fonts", run = function(d)
            self:MigratePinFonts(d, "zones")
        end },
        { version = 5, name = "drop_empty_legacy_buckets", run = function(d)
            for _, key in ipairs({ "playerNotes", "npcNotes", "zoneNotes", "itemNotes" }) do
                if type(d.global[key]) == "table" and not next(d.global[key]) then
                    d.global[key] = nil
                end
            end
        end },
        { version = 6, name = "cleanup_old_flags", run = function(d)
            local g = d.global
            g.colorsMigrated         = nil
            g.fontFamilyMigrated     = nil
            g.zoneColorsMigrated     = nil
            g.zoneFontFamilyMigrated = nil
        end },
    })
end
