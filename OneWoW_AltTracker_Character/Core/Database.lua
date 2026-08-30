local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

ns.DatabaseDefaults = {
    characters = {},
    -- Account-wide buckets (housing, Trading Post). Kept separate from
    -- characters so a later Housing load unit can lift this table as-is.
    account = {},
    settings = {
        enablePlaytimeTracking = true,
        playtimeThrottle = 300,
        enableDataCollection = true,
    },
    settingsProfiles = {},
    actionBarSets = {},
}

local function ConsolidateActionBarSetSourceChars()
    for _, setData in pairs(OneWoW_AltTracker_Character_DB.actionBarSets) do
        if type(setData) == "table" and setData.sourceChar then
            local canonical = OneWoW_GUI:CanonicalizeCharacterKey(setData.sourceChar)
            if canonical then
                setData.sourceChar = canonical
            end
        end
    end
end

-- Defaults applied by BootStore (MergeMissing) before this runs, so only the
-- char-key normalizers remain here.
function ns:InitializeDatabase()
    -- Merge legacy/duplicate keys (e.g. "Name-Argent Dawn" vs "Name-ArgentDawn").
    -- Idempotent — no-op once all keys are canonical. See DB:ConsolidateCharacterKeys.
    local migrated = DB:ConsolidateCharacterKeys(OneWoW_AltTracker_Character_DB.characters)
    if migrated > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW AltTracker:|r consolidated " .. migrated .. " duplicate character key(s) in character data.")
        end)
    end
    ConsolidateActionBarSetSourceChars()
end

function ns:GetSettingsProfiles()
    return OneWoW_AltTracker_Character_DB.settingsProfiles
end

function ns:GetAccountBucket()
    return OneWoW_AltTracker_Character_DB.account
end
