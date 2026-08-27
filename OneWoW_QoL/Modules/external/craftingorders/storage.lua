local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI

-- Elsewhere = Storage locations this character cannot spend on an order
-- (alts, mail, guild, warband). This character's bags / bank / reagent bank
-- are owned via GetItemCount, not this path.

function M:GetPlayerCharKey()
    return OneWoW_GUI:BuildCharKey()
end

local function IsElsewhere(loc, playerKey)
    local sameChar = not playerKey or not loc.charKey or loc.charKey == playerKey
    if sameChar and (loc.locationType == "bags" or loc.locationType == "bank") then
        return false
    end
    return true
end

function M:GetElsewhereTooltip(entry)
    if not OneWoW_AltTracker_Storage_API or not entry or not entry.missingReagents then
        return nil
    end
    local idx = OneWoW_AltTracker_Storage_API.GetItemIndex()
    local playerKey = M:GetPlayerCharKey()
    local lines = {}
    local seen = {}
    for i = 1, #entry.missingReagents do
        local itemID = entry.missingReagents[i].itemID
        if itemID then
            local locs = idx:GetFamilyLocations(itemID)
            if locs then
                for l = 1, #locs do
                    local loc = locs[l]
                    if IsElsewhere(loc, playerKey) then
                        local label = loc.name or loc.charKey or loc.locationType or ""
                        if loc.locationType and loc.locationType ~= "bags" then
                            label = label .. " - " .. loc.locationType
                        end
                        if not seen[label] then
                            seen[label] = true
                            lines[#lines + 1] = label
                        end
                    end
                end
            end
        end
    end
    if #lines == 0 then return nil end
    return L["CRAFTORDERS_ELSEWHERE_TIP"]:format(table.concat(lines, " | "))
end

function M:OnStorageReady()
    if not OneWoW_AltTracker_Storage_API then return end
    if M._storageWatching then return end
    M._storageWatching = true
    OneWoW_AltTracker_Storage_API.RegisterStorageChanged(function()
        if ns.ModuleRegistry:IsEnabled("craftingorders") then
            M:RefreshOverlay()
        end
    end)
end
