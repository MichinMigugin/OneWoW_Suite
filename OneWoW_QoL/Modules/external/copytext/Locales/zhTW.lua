local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["COPYTEXT_TITLE"] = "複製文字",
    ["COPYTEXT_DESC"] = "將提示資訊或介面元素中的可見文字複製到剪貼簿。使用 /1wcopytext（或 /1wct）複製游標下的內容。",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "提示資訊模式",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "複製時，從游標下任何可見的提示資訊中擷取文字。",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "任意模式",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "複製時，從游標下任何可見的介面元素中擷取文字，而不僅是提示資訊。",
    ["COPYTEXT_TOGGLE_FAST"] = "快速複製",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "自動選取複製對話框中的所有文字，讓你無需點擊即可立即複製。",
    ["COPYTEXT_NO_TEXT"] = "游標下找不到文字。",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "提示資訊內容",
    ["COPYTEXT_UI_CONTENT"] = "介面文字",
})
