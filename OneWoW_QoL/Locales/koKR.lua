local addonName, ns = ...
ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = ns.Locales["koKR"] or {}
local L = ns.Locales["koKR"]

for k, _ in pairs(ns.Locales["enUS"]) do
    if L[k] == nil then
        L[k] = "TEST"
    end
end

L["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r Quality of Life"
L["BINDING_NAME_QUESTITEM_1"] = "퀘스트 아이템 1"
L["BINDING_NAME_QUESTITEM_2"] = "퀘스트 아이템 2"
L["BINDING_NAME_QUESTITEM_3"] = "퀘스트 아이템 3"
L["BINDING_NAME_QUESTITEM_4"] = "퀘스트 아이템 4"
L["BINDING_NAME_BAGITEM_1"] = "가방 아이템 1"
L["BINDING_NAME_BAGITEM_2"] = "가방 아이템 2"
L["BINDING_NAME_BAGITEM_3"] = "가방 아이템 3"
L["BINDING_NAME_BAGITEM_4"] = "가방 아이템 4"
L["BINDING_NAME_COPY_TEXT"] = "텍스트 복사"
