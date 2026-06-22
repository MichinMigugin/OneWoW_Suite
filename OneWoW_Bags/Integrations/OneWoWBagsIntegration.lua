local _, ns = ...

local BagSet = ns.BagSet
local BankSet = ns.BankSet
local GuildBankSet = ns.GuildBankSet

local pairs, pcall = pairs, pcall
local C_Timer = C_Timer

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
		local engine = OneWoW and OneWoW.OverlayEngine
		if engine then engine:CleanButton(button) end
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

function ns:ClearBankOverlays()
	local engine = OneWoW and OneWoW.OverlayEngine

	if BankSet.slots then
		for _, bagSlots in pairs(BankSet.slots) do
			for _, button in pairs(bagSlots) do
				if button then
					if engine then
						engine:CleanButton(button)
					end
				end
			end
		end
	end

end

function ns:ClearGuildBankOverlays()
	local engine = OneWoW and OneWoW.OverlayEngine

	if GuildBankSet.slots then
		for _, tabSlots in pairs(GuildBankSet.slots) do
			for _, button in pairs(tabSlots) do
				if button then
					if engine then
						engine:CleanButton(button)
					end
				end
			end
		end
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
		local db = ns:GetDB()
		originalGBRefresh(self)
		if db.global.enableBankOverlays then
			C_Timer.After(0.05, function()
				ns:ClearGuildBankOverlays()
			end)
		end
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

-- BANKFRAME_OPENED still needs a direct listener; login hooks run via OnPlayerLogin.
local integrationEventFrame = CreateFrame("Frame")
integrationEventFrame:RegisterEvent("BANKFRAME_OPENED")
integrationEventFrame:SetScript("OnEvent", function(_, event)
	if event == "BANKFRAME_OPENED" then
		if ns.BankController:Get("overlays") then
			C_Timer.After(0.1, function()
				ns:FireCallbacksOnBankButtons()
			end)
		end
	end
end)
