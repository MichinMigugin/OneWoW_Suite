local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.SyntaxTranslators = OneWoW_Bags.ImportExport.SyntaxTranslators or {}
local ST = OneWoW_Bags.ImportExport.SyntaxTranslators

local Registry = ST.Registry or {}
ST.Registry = Registry

local L = OneWoW_Bags.L
local string_format = string.format

local translators = {}

--- Register a search-syntax translator by dialect name.
---@param dialect string
---@param translator table Must expose `Translate(input, context)`.
function Registry:Register(dialect, translator)
    if type(dialect) ~= "string" or dialect == "" then
        error("Registry:Register: dialect must be a non-empty string")
    end
    if type(translator) ~= "table" or type(translator.Translate) ~= "function" then
        error("Registry:Register: translator must expose a Translate(input, context) function")
    end
    translators[dialect] = translator
end

--- Return the translator registered for a dialect.
---@param dialect string
---@return table|nil translator
function Registry:Get(dialect)
    return translators[dialect]
end

--- Translate a source search expression into OneWoW PredicateEngine syntax.
---@param dialect string
---@param input string
---@param context table|nil
---@return table result `{ expression, warnings, translatable }`.
function Registry:Translate(dialect, input, context)
    local t = translators[dialect]
    if not t then
        return {
            expression = type(input) == "string" and input or "",
            warnings = { { severity = "error", text = string_format(L["IMPORT_WARN_NO_TRANSLATOR"], tostring(dialect)) } },
            translatable = false,
        }
    end
    return t:Translate(input, context or {})
end
