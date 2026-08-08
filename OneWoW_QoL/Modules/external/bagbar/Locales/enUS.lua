local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["BAGBAR_TITLE"] = "Bag Bar",
    ["BAGBAR_DESC"] = "Shows usable bag items on a movable bar. Items are chosen with a keyword expression (same as Bag search). Equippable gear and quest items are always excluded from the bar (applied automatically, not shown in the editor).",
    ["BAGBAR_LOCK_POSITION"] = "Lock Position",
    ["BAGBAR_MAX_BUTTONS"] = "Maximum Buttons",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Shift+Right-click to skip this session",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+Right-click to permanently blacklist",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Manual Items",
    ["BAGBAR_MANUAL_DESC"] = "Pin specific items for higher priority in the bar. They still must match your expression filter and bar usability rules.",
    ["BAGBAR_MACROS_HEADER"] = "Manual Macros",
    ["BAGBAR_MACROS_DESC"] = "Add your macros to the bar as custom buttons. Drag a macro from the macro window onto the drop area, or type a macro name and click Add. Macros appear before bag items.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Macro Name:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Drag Macro Here",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Left-click to run macro",
    ["BAGBAR_MACRO_MISSING"] = "(missing)",
    ["BAGBAR_BLACKLIST_DESC"] = "Shift+Right-click items in the bar to skip for this session. Alt+Right-click to permanently blacklist.",
    ["BAGBAR_COLUMNS"] = "Columns",
    ["BAGBAR_CONTEXT_LOCK"] = "Lock Position",
    ["BAGBAR_GROW_RIGHT"] = "Right",
    ["BAGBAR_GROW_LEFT"] = "Left",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Expression Filter",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Keyword expression for which bag items appear (same keywords as Bag search). Click ? for help. Equippable gear and quest items are excluded automatically from this expression.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "e.g. #usable & #mount",
})
