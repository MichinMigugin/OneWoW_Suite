-- ============================================================================
-- NavHistory
-- ============================================================================
-- Session-only hub back/forward stack (not SavedVariables).
--
-- Design decisions:
--   - Cap 8 entries including current; drop the oldest
--   - New navigation truncates the forward side (browser rule)
--   - Hide / FullReset clear the stack; lastModuleTab still persists separately
--   - Same-frame Show + SelectSubTab coalesces in MainWindow, not here
--
-- Full design rationale: OneWoW/Docs/ARCHITECTURE.md §5
-- ============================================================================
local _, ns = ...

local UI = ns.UI

local tinsert, tremove, wipe = tinsert, tremove, wipe

local MAX_ENTRIES = 8

local entries = {}
local index = 0
local armed = false
local applying = false

local NavHistory = {}
UI.NavHistory = NavHistory

local function CopyEntry(entry)
    if not entry then
        return nil
    end
    return {
        module = entry.module,
        subtab = entry.subtab,
        kind = entry.kind,
        id = entry.id,
    }
end

local function SameEntry(a, b)
    if not a or not b then
        return false
    end
    return a.module == b.module
        and a.subtab == b.subtab
        and a.kind == b.kind
        and a.id == b.id
end

function NavHistory.Clear()
    wipe(entries)
    index = 0
    armed = false
    applying = false
end

function NavHistory.SetArmed(isArmed)
    armed = isArmed and true or false
end

function NavHistory.IsArmed()
    return armed
end

function NavHistory.SetApplying(isApplying)
    applying = isApplying and true or false
end

function NavHistory.IsApplying()
    return applying
end

--- Seed the stack with the location the window opened on. Back stays disabled.
---@param entry table
function NavHistory.Seed(entry)
    if not entry or not entry.module then
        return
    end
    wipe(entries)
    entries[1] = CopyEntry(entry)
    index = 1
end

--- Record a leave -> arrive step. Refreshes the current entry from `leave`
--- (latest selected entity) before appending `arrive`.
---@param leave table|nil
---@param arrive table
function NavHistory.Commit(leave, arrive)
    if applying or not armed then
        return
    end
    if not arrive or not arrive.module then
        return
    end

    if #entries == 0 then
        if leave and leave.module and not SameEntry(leave, arrive) then
            entries[1] = CopyEntry(leave)
            index = 1
        else
            entries[1] = CopyEntry(arrive)
            index = 1
            return
        end
    elseif leave and leave.module then
        entries[index] = CopyEntry(leave)
    end

    if SameEntry(entries[index], arrive) then
        return
    end

    for i = #entries, index + 1, -1 do
        tremove(entries, i)
    end

    tinsert(entries, CopyEntry(arrive))
    index = #entries

    while #entries > MAX_ENTRIES do
        tremove(entries, 1)
        index = index - 1
    end
end

--- Fill kind/id on the current entry when it landed without an entity yet.
---@param kind string
---@param id number|string
---@return boolean filled
function NavHistory.FillCurrentEntity(kind, id)
    local current = entries[index]
    if not current then
        return false
    end
    if current.kind == nil and current.id == nil then
        current.kind = kind
        current.id = id
        return true
    end
    return false
end

function NavHistory.CanBack()
    return index > 1
end

function NavHistory.CanForward()
    return index < #entries
end

---@return table|nil
function NavHistory.Back()
    if index <= 1 then
        return nil
    end
    index = index - 1
    return CopyEntry(entries[index])
end

---@return table|nil
function NavHistory.Forward()
    if index >= #entries then
        return nil
    end
    index = index + 1
    return CopyEntry(entries[index])
end

---@return table|nil
function NavHistory.Current()
    return CopyEntry(entries[index])
end

---@return table|nil
function NavHistory.PeekBack()
    if index <= 1 then
        return nil
    end
    return CopyEntry(entries[index - 1])
end

---@return table|nil
function NavHistory.PeekForward()
    if index >= #entries then
        return nil
    end
    return CopyEntry(entries[index + 1])
end
