-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autodelete/logic.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local M = ns.AutoDeleteModule

local function HandleDeleteConfirm(self)
    if not ns.ModuleRegistry:IsEnabled("autodelete") then return end

    local skipTyping = ns.ModuleRegistry:GetToggleValue("autodelete", "skip_typing")
    local showLink   = ns.ModuleRegistry:GetToggleValue("autodelete", "show_link")

    if skipTyping and StaticPopup1EditBox and StaticPopup1EditBox:IsShown() then
        StaticPopup1EditBox:Hide()
        if StaticPopup1Button1 then
            StaticPopup1Button1:Enable()
        end

        if showLink and self._linkFontString then
            local infoType, _, itemLink = GetCursorInfo()
            if infoType == "item" and itemLink then
                self._linkFontString:SetText(itemLink)
                self._linkFontString:Show()
            end
        end
    end
end

function M:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoDelete")

        if StaticPopup1 and StaticPopup1EditBox then
            self._linkFontString = StaticPopup1:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            self._linkFontString:SetPoint("CENTER", StaticPopup1EditBox)
            self._linkFontString:Hide()

            StaticPopup1:HookScript("OnHide", function()
                if self._linkFontString then
                    self._linkFontString:Hide()
                end
            end)
        end
    end

    self._frame:RegisterEvent("DELETE_ITEM_CONFIRM")
    self._frame:SetScript("OnEvent", function(frame, event)
        if event == "DELETE_ITEM_CONFIRM" then
            HandleDeleteConfirm(self)
        end
    end)
end

function M:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
        self._frame:SetScript("OnEvent", nil)
    end
    if self._linkFontString then
        self._linkFontString:Hide()
    end
end

function M:OnToggle(toggleId, value)
    if toggleId == "show_link" and not value and self._linkFontString then
        self._linkFontString:Hide()
    end
end
