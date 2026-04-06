local addonName, ns = ...
ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = {}
for k, _ in pairs(ns.Locales["enUS"]) do
    ns.Locales["koKR"][k] = "TEST"
end

_G["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r Quality of Life"
_G["BINDING_NAME_QUESTITEM_1"] = "Quest Item 1"
_G["BINDING_NAME_QUESTITEM_2"] = "Quest Item 2"
_G["BINDING_NAME_QUESTITEM_3"] = "Quest Item 3"
_G["BINDING_NAME_QUESTITEM_4"] = "Quest Item 4"
_G["BINDING_NAME_BAGITEM_1"] = "Bag Item 1"
_G["BINDING_NAME_BAGITEM_2"] = "Bag Item 2"
_G["BINDING_NAME_BAGITEM_3"] = "Bag Item 3"
_G["BINDING_NAME_BAGITEM_4"] = "Bag Item 4"
_G["BINDING_NAME_COPY_TEXT"] = "Copy Text"
