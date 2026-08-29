local _, ns = ...

-- Session-only Mail pipeline debug ring. On by default (support captures);
-- does not persist across reload. /owmailtrace off to disable.
-- Usage: reproduce → /owmailtrace dump (or on → clear → reproduce → dump)

local format = string.format
local tinsert, wipe = tinsert, wipe
local pairs, ipairs, sort, type, tostring = pairs, ipairs, sort, type, tostring
local GetTime = GetTime
local debugprofilestop = debugprofilestop
local table_concat = table.concat

local PREFIX = "|cff80c0ffOneWoW_Mail Trace|r"
local RING_SIZE = 2048

-- Skip when formatting dump lines (internal / already printed).
local SKIP_KEYS = {
    t = true,
    area = true,
    event = true,
    _mark = true,
}

ns.MailTrace = {}
local MT = ns.MailTrace

MT.enabled = true
MT.ring = {}
MT.head = 0
MT.t0 = GetTime() -- dump shows seconds relative to enable / clear

function MT:IsEnabled()
    return self.enabled
end

--- High-res mark for stage durations (pass as fields._mark to Record).
---@return number
function MT:Mark()
    return debugprofilestop()
end

---@param area string
---@param event string
---@param fields table|nil
function MT:Record(area, event, fields)
    if not self.enabled then
        return
    end

    fields = fields or {}
    fields.t = GetTime()
    fields.area = area
    fields.event = event
    if fields._mark then
        fields.ms = debugprofilestop() - fields._mark
        fields._mark = nil
    end

    self.head = (self.head % RING_SIZE) + 1
    self.ring[self.head] = fields
end

function MT:Clear()
    wipe(self.ring)
    self.head = 0
    self.t0 = self.enabled and GetTime() or nil
end

function MT:SetEnabled(on)
    self.enabled = on and true or false
    if on then
        self:Clear()
        self.t0 = GetTime()
    end
end

local function FormatFields(d)
    local parts = {}
    local keys = {}
    for k in pairs(d) do
        if not SKIP_KEYS[k] then
            tinsert(keys, k)
        end
    end
    sort(keys)
    for _, k in ipairs(keys) do
        local v = d[k]
        local tv = type(v)
        if tv == "number" then
            if k == "ms" then
                tinsert(parts, format("%s=%.2f", k, v))
            elseif k == "t" then
                -- skip
            else
                tinsert(parts, format("%s=%s", k, tostring(v)))
            end
        elseif tv == "boolean" then
            tinsert(parts, format("%s=%s", k, v and "true" or "false"))
        elseif tv == "string" then
            tinsert(parts, format("%s=%s", k, v))
        elseif tv ~= "table" and tv ~= "function" then
            tinsert(parts, format("%s=%s", k, tostring(v)))
        end
    end
    return table_concat(parts, " ")
end

function MT:Dump()
    local count = 0
    for i = 1, RING_SIZE do
        if self.ring[i] then
            count = count + 1
        end
    end

    print(PREFIX .. format(": dump (%d events, recording %s)", count, self.enabled and "ON" or "OFF"))
    if count == 0 then
        print("  (no events — open mail / send a shipment, then dump)")
        return
    end

    local t0 = self.t0 or 0
    -- Chronological: oldest first. When full, oldest is head+1.
    local start = count < RING_SIZE and 1 or ((self.head % RING_SIZE) + 1)
    for i = 0, count - 1 do
        local idx = ((start + i - 1) % RING_SIZE) + 1
        local d = self.ring[idx]
        if d then
            local rel = (d.t or 0) - t0
            local rest = FormatFields(d)
            if rest ~= "" then
                print(format("  [+%6.2fs] %s.%s %s", rel, d.area or "?", d.event or "?", rest))
            else
                print(format("  [+%6.2fs] %s.%s", rel, d.area or "?", d.event or "?"))
            end
        end
    end
end

SLASH_OWMAILTRACE1 = "/1wmailtrace"
SlashCmdList["OWMAILTRACE"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        MT:SetEnabled(true)
        print(PREFIX .. ": |cff00ff00enabled|r (ring cleared). Reproduce, then /1wmailtrace dump")
    elseif msg == "off" then
        MT.enabled = false
        print(PREFIX .. ": disabled. /1wmailtrace dump still works.")
    elseif msg == "clear" or msg == "reset" then
        MT:Clear()
        print(PREFIX .. ": ring cleared.")
    elseif msg == "dump" then
        MT:Dump()
    else
        print(PREFIX .. ": usage: /1wmailtrace on | off | clear | dump  (recording "
            .. (MT.enabled and "ON" or "OFF") .. ", default ON)")
    end
end
