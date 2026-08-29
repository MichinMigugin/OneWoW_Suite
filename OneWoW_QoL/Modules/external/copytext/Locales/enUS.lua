local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["COPYTEXT_TITLE"] = "Copy Text",
    ["COPYTEXT_DESC"] = "Copies visible text from tooltips or UI elements to your clipboard. Use /1wcopytext (or /1wct) to copy what is under your cursor.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Tooltip Mode",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "When copying, capture text from any visible tooltips under your cursor.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Anything Mode",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "When copying, capture text from any visible UI element under your cursor, not just tooltips.",
    ["COPYTEXT_TOGGLE_FAST"] = "Fast Copy",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Auto-select all text in the copy dialog so you can copy it instantly without having to click.",
    ["COPYTEXT_NO_TEXT"] = "No text found under cursor.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Tooltip Content",
    ["COPYTEXT_UI_CONTENT"] = "UI Text",
})
