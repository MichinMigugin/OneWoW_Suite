local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.ItemButtonCallbacks = OneWoW_Bags.ItemButtonCallbacks or {}
local callbacks = OneWoW_Bags.ItemButtonCallbacks

function OneWoW_Bags:RegisterItemButtonCallback(name, callback)
	if not callback or type(callback) ~= "function" then
		error("InvalidCallback: callback must be a function")
		return
	end
	callbacks[name] = callback
end

function OneWoW_Bags:UnregisterItemButtonCallback(name)
	callbacks[name] = nil
end

function OneWoW_Bags:FireItemButtonCallback(button, bagID, slotID)
	for name, callback in pairs(callbacks) do
		pcall(callback, button, bagID, slotID)
	end
end

function OneWoW_Bags:FireCallbacksOnAllButtons()
	local BagSet = self.BagSet
	if not BagSet or not BagSet.slots then return end

	for bagID, bagSlots in pairs(BagSet.slots) do
		for slotID, button in pairs(bagSlots) do
			if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
				self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
			end
		end
	end
end

function OneWoW_Bags:FireCallbacksOnBankButtons()
	local db = self.db
	if not db or not db.global or not db.global.enableBankOverlays then return end

	local BankSet = self.BankSet
	if BankSet and BankSet.slots then
		for bagID, bagSlots in pairs(BankSet.slots) do
			for slotID, button in pairs(bagSlots) do
				if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
					self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
				end
			end
		end
	end

	local GuildBankSet = self.GuildBankSet
	if GuildBankSet and GuildBankSet.slots then
		for tabID, tabSlots in pairs(GuildBankSet.slots) do
			for slotID, button in pairs(tabSlots) do
				if button and button:IsVisible() and button.owb_bagID and button.owb_slotID then
					self:FireItemButtonCallback(button, button.owb_bagID, button.owb_slotID)
				end
			end
		end
	end
end

function OneWoW_Bags:ClearBankOverlays()
	local BankSet = self.BankSet
	if BankSet and BankSet.slots then
		for bagID, bagSlots in pairs(BankSet.slots) do
			for slotID, button in pairs(bagSlots) do
				if button and button.TLHOverlay then
					button.TLHOverlay:Hide()
				end
			end
		end
	end

	local GuildBankSet = self.GuildBankSet
	if GuildBankSet and GuildBankSet.slots then
		for tabID, tabSlots in pairs(GuildBankSet.slots) do
			for slotID, button in pairs(tabSlots) do
				if button and button.TLHOverlay then
					button.TLHOverlay:Hide()
				end
			end
		end
	end
end

local function HookGUIRefresh()
	local GUI = OneWoW_Bags.GUI
	if not GUI or not GUI.RefreshLayout then return end

	local originalRefreshLayout = GUI.RefreshLayout
	function GUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			OneWoW_Bags:FireCallbacksOnAllButtons()
		end)
	end
end

local function HookBankGUIRefresh()
	local BankGUI = OneWoW_Bags.BankGUI
	if not BankGUI or not BankGUI.RefreshLayout then return end

	local originalRefreshLayout = BankGUI.RefreshLayout
	function BankGUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			OneWoW_Bags:FireCallbacksOnBankButtons()
		end)
	end
end

local function HookGuildBankGUIRefresh()
	local GuildBankGUI = OneWoW_Bags.GuildBankGUI
	if not GuildBankGUI or not GuildBankGUI.RefreshLayout then return end

	local originalRefreshLayout = GuildBankGUI.RefreshLayout
	function GuildBankGUI:RefreshLayout()
		originalRefreshLayout(self)
		C_Timer.After(0.05, function()
			OneWoW_Bags:FireCallbacksOnBankButtons()
		end)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
	if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
		C_Timer.After(0.5, function()
			if OneWoW_Bags.GUI then
				HookGUIRefresh()
				OneWoW_Bags:FireCallbacksOnAllButtons()
			end
			if OneWoW_Bags.BankGUI then
				HookBankGUIRefresh()
			end
			if OneWoW_Bags.GuildBankGUI then
				HookGuildBankGUIRefresh()
			end
		end)
	end
end)
