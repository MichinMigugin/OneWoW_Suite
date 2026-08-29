local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["COPYTEXT_TITLE"] = "复制文本",
    ["COPYTEXT_DESC"] = "将工具提示或界面元素中的可见文本复制到剪贴板。使用 /1wcopytext（或 /1wct）复制光标下的内容。",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "工具提示模式",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "复制时，从光标下任何可见的工具提示中获取文本。",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "任意模式",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "复制时，从光标下任何可见的界面元素中获取文本，而不仅仅是工具提示。",
    ["COPYTEXT_TOGGLE_FAST"] = "快速复制",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "自动选中复制对话框中的所有文本，让你无需点击即可立即复制。",
    ["COPYTEXT_NO_TEXT"] = "光标下未找到文本。",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "工具提示内容",
    ["COPYTEXT_UI_CONTENT"] = "界面文本",
})
