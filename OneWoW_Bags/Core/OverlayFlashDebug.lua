local _, ns = ...

-- ============================================================================
-- Overlay flash debug (/owboverlay)
-- ============================================================================
-- Timeline recorder for guild-bank Quality Border flashes. Live-prints when
-- enabled so a visible flash can be correlated with the last chat lines.
-- Also aggregates per-pass Clean/ApplyQualityBorder outcomes via
-- OneWoW._overlayFlashNote (wired from Overlays2).
-- ============================================================================

local format = string.format
local tinsert, wipe = tinsert, wipe
local GetTime = GetTime

local PREFIX = "|cff80c0ffOneWoW_Bags OverlayFlash|r"
local RING_SIZE = 96

ns.OverlayFlashDebug = {}
local OFD = ns.OverlayFlashDebug

OFD.enabled = false
OFD.live = true
OFD.ring = {}
OFD.head = 0
OFD.t0 = nil
OFD.pass = nil

local function Offset()
	local t = GetTime()
	if not OFD.t0 then
		OFD.t0 = t
	end
	return t - OFD.t0, t
end

---@param event string
---@param detail table|nil
function OFD:Record(event, detail)
	if not self.enabled then return end

	detail = detail or {}
	local offset, t = Offset()
	detail.event = event
	detail.t = t
	detail.dt = offset

	self.head = (self.head % RING_SIZE) + 1
	self.ring[self.head] = detail

	if self.live then
		local parts = { format("%s |cffaaaaaa+%.3f|r %s", PREFIX, offset, event) }
		if detail.reason then tinsert(parts, "reason=" .. tostring(detail.reason)) end
		if detail.note then tinsert(parts, tostring(detail.note)) end
		if detail.ms ~= nil then tinsert(parts, format("ms=%.1f", detail.ms)) end
		if detail.n ~= nil then tinsert(parts, "n=" .. tostring(detail.n)) end
		if detail.keep ~= nil then tinsert(parts, "keep=" .. tostring(detail.keep)) end
		if detail.full ~= nil then tinsert(parts, "full=" .. tostring(detail.full)) end
		if detail.clean_skip ~= nil then tinsert(parts, "clean_skip=" .. tostring(detail.clean_skip)) end
		if detail.skip_same ~= nil then tinsert(parts, "skip_same=" .. tostring(detail.skip_same)) end
		if detail.qb_noop ~= nil then tinsert(parts, "qb_noop=" .. tostring(detail.qb_noop)) end
		if detail.qb_create ~= nil then tinsert(parts, "qb_create=" .. tostring(detail.qb_create)) end
		if detail.qb_update ~= nil then tinsert(parts, "qb_update=" .. tostring(detail.qb_update)) end
		if detail.qb_hide ~= nil then tinsert(parts, "qb_hide=" .. tostring(detail.qb_hide)) end
		if detail.async_sched ~= nil then tinsert(parts, "async_sched=" .. tostring(detail.async_sched)) end
		if detail.async_paint ~= nil then tinsert(parts, "async_paint=" .. tostring(detail.async_paint)) end
		if detail.dirty ~= nil then tinsert(parts, "dirty=" .. tostring(detail.dirty)) end
		print(table.concat(parts, " "))
	end
end

function OFD:MarkEpoch(reason)
	self.t0 = GetTime()
	self:Record("epoch", { reason = reason or "mark" })
end

function OFD:InstallSink()
	OneWoW._overlayFlashNote = function(kind, detail)
		if not OFD.enabled then return end
		-- Async loads often complete after the guild fire pass ends; always
		-- emit a timeline row so a late flash can be correlated.
		if kind == "async_paint" then
			OFD:Record("async_paint", {
				note = detail and detail.itemID and ("itemID=" .. tostring(detail.itemID)) or nil,
			})
			return
		end
		if OFD.pass then
			OFD:NotePass(kind, detail)
		elseif kind == "async_sched" then
			OFD:Record("async_sched", {
				note = detail and detail.itemID and ("itemID=" .. tostring(detail.itemID)) or nil,
			})
		end
	end
end

function OFD:RemoveSink()
	OneWoW._overlayFlashNote = nil
end

function OFD:BeginPass(reason)
	self.pass = {
		reason = reason,
		keep = 0,
		full = 0,
		clean_skip = 0,
		skip_same = 0,
		qb_noop = 0,
		qb_create = 0,
		qb_update = 0,
		qb_hide = 0,
		async_sched = 0,
		async_paint = 0,
		n = 0,
	}
	self:InstallSink()
	self:Record("pass_begin", { reason = reason })
end

function OFD:NotePass(kind, detail)
	local p = self.pass
	if not p then return end
	detail = detail or {}
	if kind == "clean" then
		if detail.keep then
			p.keep = p.keep + 1
		else
			p.full = p.full + 1
		end
	elseif kind == "clean_skip" then
		p.clean_skip = p.clean_skip + 1
	elseif kind == "skip_same" then
		p.skip_same = p.skip_same + 1
	elseif kind == "qb_noop" then
		p.qb_noop = p.qb_noop + 1
	elseif kind == "qb_create" then
		p.qb_create = p.qb_create + 1
	elseif kind == "qb_update" then
		p.qb_update = p.qb_update + 1
	elseif kind == "qb_hide" then
		p.qb_hide = p.qb_hide + 1
	elseif kind == "async_sched" then
		p.async_sched = p.async_sched + 1
	end
end

function OFD:EndPass(extra)
	local p = self.pass
	self.pass = nil
	-- Keep sink installed while recording so late async_paint rows still land.
	if not p then return end
	extra = extra or {}
	self:Record("pass_end", {
		reason = p.reason,
		n = extra.n or p.n,
		keep = p.keep,
		full = p.full,
		clean_skip = p.clean_skip,
		skip_same = p.skip_same,
		qb_noop = p.qb_noop,
		qb_create = p.qb_create,
		qb_update = p.qb_update,
		qb_hide = p.qb_hide,
		async_sched = p.async_sched,
	})
end

function OFD:Clear()
	wipe(self.ring)
	self.head = 0
	self.t0 = nil
	self.pass = nil
	if not self.enabled then
		self:RemoveSink()
	else
		self:InstallSink()
	end
end

function OFD:Dump()
	print(PREFIX .. " dump @ " .. format("%.2f", GetTime())
		.. (self.enabled and " (recording on)" or " (recording off)"))
	if self.head == 0 then
		print("    (no events — run /1wboverlay on, open guild bank, flash, then dump)")
		return
	end
	-- Ring is circular; walk oldest→newest.
	local start = (self.head % RING_SIZE) + 1
	local count = 0
	for i = 0, RING_SIZE - 1 do
		local idx = ((start + i - 1) % RING_SIZE) + 1
		local d = self.ring[idx]
		if d then
			count = count + 1
			local parts = { format("  |cffaaaaaa+%7.3f|r %s", d.dt or 0, d.event or "?") }
			if d.reason then tinsert(parts, "reason=" .. tostring(d.reason)) end
			if d.note then tinsert(parts, tostring(d.note)) end
			if d.ms ~= nil then tinsert(parts, format("ms=%.1f", d.ms)) end
			if d.n ~= nil then tinsert(parts, "n=" .. tostring(d.n)) end
			if d.keep ~= nil then tinsert(parts, "keep=" .. tostring(d.keep)) end
			if d.full ~= nil then tinsert(parts, "full=" .. tostring(d.full)) end
			if d.clean_skip ~= nil then tinsert(parts, "clean_skip=" .. tostring(d.clean_skip)) end
			if d.skip_same ~= nil then tinsert(parts, "skip_same=" .. tostring(d.skip_same)) end
			if d.qb_noop ~= nil then tinsert(parts, "qb_noop=" .. tostring(d.qb_noop)) end
			if d.qb_create ~= nil then tinsert(parts, "qb_create=" .. tostring(d.qb_create)) end
			if d.qb_update ~= nil then tinsert(parts, "qb_update=" .. tostring(d.qb_update)) end
			if d.qb_hide ~= nil then tinsert(parts, "qb_hide=" .. tostring(d.qb_hide)) end
			if d.async_sched ~= nil then tinsert(parts, "async_sched=" .. tostring(d.async_sched)) end
			if d.dirty ~= nil then tinsert(parts, "dirty=" .. tostring(d.dirty)) end
			print(table.concat(parts, " "))
		end
	end
	print(PREFIX .. " " .. count .. " events")
end

SLASH_OWBOVERLAY1 = "/1wboverlay"
SlashCmdList["OWBOVERLAY"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "on" then
		OFD.enabled = true
		OFD.live = true
		OFD:Clear()
		OFD:MarkEpoch("enable")
		print(PREFIX .. ": |cff00ff00enabled|r (live + ring). Open guild bank, note flash time vs +offsets, then /1wboverlay dump")
	elseif msg == "quiet" then
		OFD.enabled = true
		OFD.live = false
		OFD:Clear()
		OFD:MarkEpoch("enable")
		print(PREFIX .. ": |cff00ff00enabled|r (ring only, no live spam). /1wboverlay dump after repro")
	elseif msg == "off" then
		OFD.enabled = false
		OFD:RemoveSink()
		print(PREFIX .. ": disabled. /1wboverlay dump still works.")
	elseif msg == "mark" then
		OFD:MarkEpoch("manual")
		print(PREFIX .. ": epoch reset to now")
	elseif msg == "clear" or msg == "reset" then
		OFD:Clear()
		print(PREFIX .. ": ring cleared.")
	elseif msg == "dump" then
		OFD:Dump()
	else
		print(PREFIX .. ": usage: /1wboverlay on | quiet | off | mark | clear | dump")
	end
end
