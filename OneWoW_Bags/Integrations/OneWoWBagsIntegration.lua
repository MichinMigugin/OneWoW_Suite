local _, ns = ...

local BagSet = ns.BagSet
local BankSet = ns.BankSet
local GuildBankSet = ns.GuildBankSet

local pairs, pcall = pairs, pcall
local C_Timer = C_Timer
local GetTime = GetTime

ns.ItemButtonCallbacks = ns.ItemButtonCallbacks or {}
local callbacks = ns.ItemButtonCallbacks

function ns:RegisterItemButtonCallback(name, callback)
	if not callback or type(callback) ~= "function" then
		error("InvalidCallback: callback must be a function")
	end
	callbacks[name] = callback
end

function ns:UnregisterItemButtonCallback(name)
	callbacks[name] = nil
end

function ns:FireItemButtonCallback(button, bagID, slotID)
	local altShow = self:IsAltShowActive()
	local db = self:GetDB()
	if not altShow and db.global.stripJunkOverlays and button._owb_isJunk then
		local engine = OneWoW.OverlayEngine
		engine:CleanButton(button)
		return
	end
	for name, callback in pairs(callbacks) do
		local ok, err = pcall(callback, button, bagID, slotID)
		if not ok then
			geterrorhandler()(("OneWoW_Bags item-button callback '%s' errored: %s"):format(tostring(name), tostring(err)))
		end
	end
end

function ns:FireCallbacksOnAllButtons()
	if not BagSet.slots then return end

	for _, bagSlots in pairs(BagSet.slots) do
		for _, button in pairs(bagSlots) do
			if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
				self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
			end
		end
	end
end

function ns:FireCallbacksOnBankButtons()
	if not self.BankController:Get("overlays") then return end

	if BankSet.slots then
		for _, bagSlots in pairs(BankSet.slots) do
			for _, button in pairs(bagSlots) do
				if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
					self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
				end
			end
		end
	end

end

function ns:FireCallbacksOnGuildBankButtons()
	local OFD = self.OverlayFlashDebug
	if not self:GetDB().global.enableBankOverlays then
		self._guildOverlayDirty = false
		if OFD and OFD.enabled then
			OFD:Record("guild_fire_skip", { reason = "overlays_disabled" })
		end
		return
	end

	local n = 0
	local token = self.GuildBankGUI and self.GuildBankGUI._overlayFilterToken
	local engine = OneWoW.OverlayEngine
	if OFD and OFD.enabled then
		OFD:BeginPass("guild_fire")
	end

	if GuildBankSet.slots then
		for _, tabSlots in pairs(GuildBankSet.slots) do
			for _, button in pairs(tabSlots) do
				-- Prefer the last layout's filter token: all tab slot frames can
				-- report IsVisible() even when not in the current view.
				if button and button.owb_bagID and button.owb_slotID
					and ((token and button._owb_filterToken == token)
						or (not token and button:IsVisible())) then
					n = n + 1
					if button.owb_hasItem then
						self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
					else
						-- Empty: clear leftover overlays only (clean_skip when already bare).
						engine:CleanButton(button)
					end
				end
			end
		end
	end
	self._guildOverlayDirty = false

	if OFD and OFD.enabled then
		OFD:EndPass({ n = n })
	end
end

function ns:ClearBankOverlays()
	local engine = OneWoW.OverlayEngine

	if BankSet.slots then
		for _, bagSlots in pairs(BankSet.slots) do
			for _, button in pairs(bagSlots) do
				if button then
					engine:CleanButton(button)
				end
			end
		end
	end

end

function ns:ClearGuildBankOverlays()
	local engine = OneWoW.OverlayEngine

	if GuildBankSet.slots then
		for _, tabSlots in pairs(GuildBankSet.slots) do
			for _, button in pairs(tabSlots) do
				if button then
					engine:CleanButton(button)
				end
			end
		end
	end
end

-- Guild bank opens/queries tabs in bursts, then ScheduleTooltipCatchupRefresh
-- (~0.75s) triggers another layout. Re-painting overlays on every layout made
-- Quality Border flash. Only schedule overlay paint when content is dirty
-- (open / slot updates / search); skip pure re-categorize layouts.
local guildOverlayTimer = nil
local GUILD_OVERLAY_DEBOUNCE = 0.35

function ns:MarkGuildOverlaysDirty(reason)
	self._guildOverlayDirty = true
	local OFD = self.OverlayFlashDebug
	if OFD and OFD.enabled then
		OFD:Record("dirty", { reason = reason or "?", dirty = true })
	end
end

function ns:ScheduleGuildOverlayRefresh()
	local OFD = self.OverlayFlashDebug
	if not self._guildOverlayDirty then
		if OFD and OFD.enabled then
			OFD:Record("overlay_sched_skip", { reason = "not_dirty", dirty = false })
		end
		return
	end
	if guildOverlayTimer then
		guildOverlayTimer:Cancel()
		guildOverlayTimer = nil
		if OFD and OFD.enabled then
			OFD:Record("overlay_sched_rearm", { reason = "debounce", dirty = true })
		end
	elseif OFD and OFD.enabled then
		OFD:Record("overlay_sched_arm", {
			reason = "debounce",
			note = ("delay=%.2f"):format(GUILD_OVERLAY_DEBOUNCE),
			dirty = true,
		})
	end
	guildOverlayTimer = C_Timer.NewTimer(GUILD_OVERLAY_DEBOUNCE, function()
		guildOverlayTimer = nil
		if OFD and OFD.enabled then
			OFD:Record("overlay_timer_fire", { dirty = ns._guildOverlayDirty and true or false })
		end
		local db = ns:GetDB()
		if db.global.enableBankOverlays then
			ns:FireCallbacksOnGuildBankButtons()
		else
			ns:ClearGuildBankOverlays()
			ns._guildOverlayDirty = false
		end
	end)
end

function ns:CancelPendingGuildOverlayRefresh()
	if guildOverlayTimer then
		guildOverlayTimer:Cancel()
		guildOverlayTimer = nil
	end
end

local function HookGUIRefresh()
	local GUI = ns.GUI
	if not GUI then return end

	local originalRefreshLayout = GUI.RefreshLayout
	function GUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			ns:FireCallbacksOnAllButtons()
		end)
	end

	local originalBankRefresh = ns.BankGUI.RefreshLayout
	function ns.BankGUI:RefreshLayout()
		originalBankRefresh(self)
		if ns.BankController:Get("overlays") then
			C_Timer.After(0.05, function()
				ns:FireCallbacksOnBankButtons()
			end)
		end
	end

	local originalGBRefresh = ns.GuildBankGUI.RefreshLayout
	function ns.GuildBankGUI:RefreshLayout()
		local OFD = ns.OverlayFlashDebug
		local t0 = GetTime()
		local reason = ns._currentRefreshReason
		if OFD and OFD.enabled then
			OFD:Record("layout_begin", { reason = reason or "(nil)" })
		end
		originalGBRefresh(self)
		if OFD and OFD.enabled then
			OFD:Record("layout_end", {
				reason = reason or "(nil)",
				ms = (GetTime() - t0) * 1000,
			})
		end
		ns:ScheduleGuildOverlayRefresh()
	end
end

-- Core force-loads OneWoW_Bags during its own ADDON_LOADED, which eats Bags'
-- ADDON_LOADED event. Login hooks run via ns:OnPlayerLogin().
function ns:InstallIntegrationHooks()
	if self._integrationHooksInstalled then return end
	self._integrationHooksInstalled = true
	if self.GUI then
		HookGUIRefresh()
		self:FireCallbacksOnAllButtons()
	end
end

-- Bank-open overlay repaint routes through OneWoW.Inventory (single BANKFRAME_* owner).
OneWoW.Inventory.RegisterBankOpenCallback("Bags_Integration", function()
	if ns.BankController:Get("overlays") then
		C_Timer.After(0.1, function()
			ns:FireCallbacksOnBankButtons()
		end)
	end
end)
