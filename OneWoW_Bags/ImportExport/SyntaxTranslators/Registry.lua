local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.SyntaxTranslators = OneWoW_Bags.ImportExport.SyntaxTranslators or {}
local ST = OneWoW_Bags.ImportExport.SyntaxTranslators

local Registry = ST.Registry or {}
ST.Registry = Registry

local translators = {}

function Registry:Register(dialect, translator)
    if type(dialect) ~= "string" or dialect == "" then
        error("Registry:Register: dialect must be a non-empty string")
    end
    if type(translator) ~= "table" or type(translator.Translate) ~= "function" then
        error("Registry:Register: translator must expose a Translate(input, context) function")
    end
    translators[dialect] = translator
end

function Registry:Get(dialect)
    return translators[dialect]
end

function Registry:Translate(dialect, input, context)
    local t = translators[dialect]
    if not t then
        return {
            expression = type(input) == "string" and input or "",
            warnings = { { severity = "error", text = "No translator registered for dialect '" .. tostring(dialect) .. "'" } },
            translatable = false,
        }
    end
    return t:Translate(input, context or {})
end
