local _, ns = ...

local format = string.format
local tinsert, wipe = tinsert, wipe
local ipairs = ipairs
local GetTime = GetTime

local PREFIX = "|cff80c0ffOneWoW_Bags Layout|r"
local RING_SIZE = 64

ns.LayoutDebug = {}
local LD = ns.LayoutDebug

LD.enabled = false
LD.ring = {}
LD.head = 0
LD.lastFlushOutcome = {}

local GUI_IN_PROGRESS = {
    GUI = "_layoutInProgress",
    BankGUI = "_layoutInProgress",
    GuildBankGUI = "_layoutInProgress",
}

local SET_BY_GUI = {
    GUI = "BagSet",
    BankGUI = "BankSet",
    GuildBankGUI = "GuildBankSet",
}

local SET_BY_TARGET = {
    bags = "BagSet",
    bank = "BankSet",
    guild = "GuildBankSet",
}

---@param setObj table|nil
---@return number total
---@return number hasItem
---@return number shown
---@return number|nil slots
---@return number|nil free
function LD:CountSetStats(setObj)
    local total, hasItem, shown = 0, 0, 0
    if setObj and setObj.isBuilt and setObj.GetAllButtons then
        local buttons = setObj:GetAllButtons()
        for i = 1, #buttons do
            local btn = buttons[i]
            total = total + 1
            if btn.owb_hasItem then
                hasItem = hasItem + 1
            end
            if btn.IsShown and btn:IsShown() then
                shown = shown + 1
            end
        end
    end
    local slots = setObj and setObj.GetSlotCount and setObj:GetSlotCount() or nil
    local free = setObj and setObj.GetFreeSlotCount and setObj:GetFreeSlotCount() or nil
    return total, hasItem, shown, slots, free
end

--- Count visible buttons among the filtered list for the current layout pass.
---@param buttons table[]|nil
---@param filterToken number|nil
---@return number shown
function LD:CountFilteredShown(buttons, filterToken)
    local shown = 0
    if not buttons then return 0 end
    for i = 1, #buttons do
        local btn = buttons[i]
        if (not filterToken or btn._owb_filterToken == filterToken) and btn.IsShown and btn:IsShown() then
            shown = shown + 1
        end
    end
    return shown
end

---@param event string
---@param detail table|nil
function LD:Record(event, detail)
    if not self.enabled then return end

    detail = detail or {}
    detail.t = detail.t or GetTime()
    detail.event = event

    self.head = (self.head % RING_SIZE) + 1
    self.ring[self.head] = detail

    if detail.guiKey and detail.outcome then
        self.lastFlushOutcome[detail.guiKey] = detail.outcome
    end
end

---@param targetKey string|nil
---@param filteredCount number|nil
---@param layoutHeight number|nil
---@param buttons table[]|nil filtered list from this layout pass
---@param filterToken number|nil
---@param totalBeforeFilter number|nil button count before filterButtons
function LD:RecordLayoutComplete(targetKey, filteredCount, layoutHeight, buttons, filterToken, totalBeforeFilter)
    if not targetKey then return end

    filteredCount = filteredCount or 0
    local filteredShown = self:CountFilteredShown(buttons, filterToken)

    local setObj = ns[SET_BY_TARGET[targetKey]]
    local total, hasItem, setShown, slots, free = self:CountSetStats(setObj)

    if self.enabled then
        self:Record("layout_done", {
            target = targetKey,
            filtered = filteredCount,
            filteredShown = filteredShown,
            layoutHeight = layoutHeight,
            total = total,
            hasItem = hasItem,
            shown = setShown,
            slots = slots,
            free = free,
            preFilter = totalBeforeFilter,
        })
        if filteredCount == 0 and (totalBeforeFilter or 0) > 0 then
            self:Record("empty_filter", {
                target = targetKey,
                preFilter = totalBeforeFilter,
                hasItem = hasItem,
            })
        end
    end
end

function LD:FormatDetail(d)
    local parts = { d.event or "?" }
    if d.target then tinsert(parts, "target=" .. d.target) end
    if d.guiKey then tinsert(parts, "gui=" .. d.guiKey) end
    if d.reason then tinsert(parts, "reason=" .. d.reason) end
    if d.outcome then tinsert(parts, "outcome=" .. d.outcome) end
    if d.visible ~= nil then tinsert(parts, "visible=" .. tostring(d.visible)) end
    if d.building ~= nil then tinsert(parts, "building=" .. tostring(d.building)) end
    if d.inProgress ~= nil then tinsert(parts, "inProg=" .. tostring(d.inProgress)) end
    if d.filtered ~= nil then tinsert(parts, "filtered=" .. tostring(d.filtered)) end
    if d.filteredShown ~= nil then tinsert(parts, "filtShown=" .. tostring(d.filteredShown)) end
    if d.preFilter ~= nil then tinsert(parts, "preFilter=" .. tostring(d.preFilter)) end
    if d.hasItem ~= nil then tinsert(parts, "hasItem=" .. tostring(d.hasItem)) end
    if d.shown ~= nil then tinsert(parts, "shown=" .. tostring(d.shown)) end
    if d.slots ~= nil and d.free ~= nil then
        tinsert(parts, format("slots=%d/%d", (d.slots - d.free), d.slots))
    end
    if d.err then tinsert(parts, "err=" .. tostring(d.err)) end
    if d.note then tinsert(parts, d.note) end
    return table.concat(parts, " ")
end

function LD:Dump()
    local addon = OneWoW_Bags
    print(PREFIX .. " dump @ " .. format("%.2f", GetTime()) .. (self.enabled and " (recording on)" or " (recording off)"))

    local sched = addon.GetLayoutDebugSchedulerSnapshot and addon:GetLayoutDebugSchedulerSnapshot()
    if sched then
        print("  scheduler: refreshScheduled=" .. tostring(sched.refreshScheduled))
        for _, guiKey in ipairs({ "GUI", "BankGUI", "GuildBankGUI" }) do
            local entry = sched.pending[guiKey]
            if entry then
                print(format("    pending %s=true reason=%s", guiKey, tostring(entry.reason or "?")))
            else
                print(format("    pending %s=false", guiKey))
            end
        end
    end

    for _, guiKey in ipairs({ "GUI", "BankGUI", "GuildBankGUI" }) do
        local gui = addon[guiKey]
        local flagKey = GUI_IN_PROGRESS[guiKey]
        local inProg = gui and flagKey and gui[flagKey]
        local setKey = SET_BY_GUI[guiKey]
        local setObj = setKey and addon[setKey]
        local total, hasItem, shown, slots, free = self:CountSetStats(setObj)
        local guiShown = gui and gui.IsShown and gui:IsShown()
        print(format(
            "  %s: frameShown=%s inProgress=%s built=%s building=%s buttons=%d hasItem=%d shown=%d slots=%s lastFlush=%s",
            guiKey,
            tostring(guiShown),
            tostring(inProg),
            tostring(setObj and setObj.isBuilt),
            tostring(setObj and setObj._building),
            total,
            hasItem,
            shown,
            (slots and free) and format("%d/%d", slots - free, slots) or "n/a",
            tostring(self.lastFlushOutcome[guiKey] or "n/a")
        ))
    end

    print("  bankOpen=" .. tostring(addon.bankOpen) .. " guildBankOpen=" .. tostring(addon.guildBankOpen))

    local count = 0
    for i = 1, RING_SIZE do
        local idx = ((self.head - i - 1) % RING_SIZE) + 1
        local d = self.ring[idx]
        if d then
            count = count + 1
        end
    end

    local show = count < 32 and count or 32
    print("  last events (newest first, max " .. show .. "):")
    for i = 0, show - 1 do
        local idx = ((self.head - i - 1) % RING_SIZE) + 1
        local d = self.ring[idx]
        if d then
            print(format("    [%.2f] %s", d.t or 0, self:FormatDetail(d)))
        end
    end

    if count == 0 then
        print("    (no events — run /1wblayout on before reproducing)")
    end
end

function LD:Clear()
    wipe(self.ring)
    wipe(self.lastFlushOutcome)
    self.head = 0
end

SLASH_OWBLAYOUT1 = "/1wblayout"
SlashCmdList["OWBLAYOUT"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        LD:Clear()
        LD.enabled = true
        print(PREFIX .. ": |cff00ff00enabled|r (ring cleared). Reproduce bug, then /1wblayout dump")
    elseif msg == "off" then
        LD.enabled = false
        print(PREFIX .. ": disabled. /1wblayout dump still works.")
    elseif msg == "clear" or msg == "reset" then
        LD:Clear()
        print(PREFIX .. ": ring cleared.")
    elseif msg == "dump" then
        LD:Dump()
    else
        print(PREFIX .. ": usage: /1wblayout on | off | clear | dump")
    end
end
