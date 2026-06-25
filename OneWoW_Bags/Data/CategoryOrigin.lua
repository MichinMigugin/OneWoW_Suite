local _, ns = ...

ns.CategoryOrigin = ns.CategoryOrigin or {}
local CO = ns.CategoryOrigin

local SD = ns.SectionDefaults

local BUILTIN_SECTION_IDS = {
    [SD.SEC_ONEWOW_BAGS] = true,
    [SD.SEC_EQUIPMENT]    = true,
    [SD.SEC_CRAFTING]     = true,
    [SD.SEC_HOUSING]      = true,
}

local ORIGIN_ATLAS = {
    builtin  = "MonsterFriend",
    custom   = "PartyMember",
    imported = "MonsterEnemy",
}

local function resolveImportKind(data)
    if type(data) ~= "table" then return nil end
    if data.isBaganator then return "baganator" end
    if data.isTSM then return "tsm" end
    return nil
end

---@param sectionId string|nil
---@return boolean
function CO:IsBuiltinSectionId(sectionId)
    return sectionId ~= nil and BUILTIN_SECTION_IDS[sectionId] == true
end

---@param sectionId string|nil
---@param sectionData table|nil
---@return string kind "builtin"|"custom"|"imported"
---@return string|nil importKind "baganator"|"tsm"
function CO:ResolveSectionOrigin(sectionId, sectionData)
    if self:IsBuiltinSectionId(sectionId) then
        return "builtin", nil
    end
    local importKind = resolveImportKind(sectionData)
    if importKind then
        return "imported", importKind
    end
    return "custom", nil
end

---@param isBuiltin boolean
---@param catData table|nil
---@return string kind
---@return string|nil importKind
function CO:ResolveCategoryOrigin(isBuiltin, catData)
    if isBuiltin then
        return "builtin", nil
    end
    local importKind = resolveImportKind(catData)
    if importKind then
        return "imported", importKind
    end
    return "custom", nil
end

---@param kind string
---@return string atlasName
function CO:GetOriginAtlas(kind)
    return ORIGIN_ATLAS[kind] or ORIGIN_ATLAS.custom
end

---@param kind string
---@param importKind string|nil
---@param isSection boolean
---@return string localeKey
function CO:GetOriginTooltipKey(kind, importKind, isSection)
    if kind == "builtin" then
        return isSection and "ORIGIN_BUILTIN_SECTION" or "ORIGIN_BUILTIN_CATEGORY"
    end
    if kind == "custom" then
        return isSection and "ORIGIN_CUSTOM_SECTION" or "ORIGIN_CUSTOM_CATEGORY"
    end
    if importKind == "tsm" then
        return isSection and "ORIGIN_IMPORTED_TSM_SECTION" or "ORIGIN_IMPORTED_TSM_CATEGORY"
    end
    return isSection and "ORIGIN_IMPORTED_BAGANATOR_SECTION" or "ORIGIN_IMPORTED_BAGANATOR_CATEGORY"
end

---@param catData table|nil
---@param isBuiltin boolean
---@return string|nil localeKey nil means use Blizzard CUSTOM global
function CO:GetCategoryTypeLabelKey(catData, isBuiltin)
    if isBuiltin then
        return "CATEGORY_TYPE_BUILTIN"
    end
    if catData and catData.isBaganator then
        return "CATEGORY_TYPE_BAGANATOR"
    end
    if catData and catData.isTSM then
        return "CATEGORY_TYPE_TSM"
    end
    return nil
end

---@param sectionId string|nil
---@param sectionData table|nil
---@return string|nil localeKey nil means use Blizzard CUSTOM global
function CO:GetSectionTypeLabelKey(sectionId, sectionData)
    local kind, importKind = self:ResolveSectionOrigin(sectionId, sectionData)
    if kind == "builtin" then
        return "CATEGORY_TYPE_BUILTIN"
    end
    if kind == "imported" and importKind == "baganator" then
        return "CATEGORY_TYPE_BAGANATOR"
    end
    if kind == "imported" and importKind == "tsm" then
        return "CATEGORY_TYPE_TSM"
    end
    return nil
end
