local _, ns = ...

-- AltScope owns user-defined character roles and resolves per-feature "alt
-- scope" configs into a character-inclusion test. Roles are stored account-wide
-- on core OneWoW_DB (global.roles); characters are read from AltTracker's
-- public API (optional dependency — absent means "no alts to group").
--
-- Role shape:  roles[id] = { id = id, name = "Crafter", members = { [charKey] = true } }
-- Scope shape: { mode = "all" | "selected", chars = { [charKey] = true }, roles = { [roleId] = true } }
--   mode "all" (or nil / missing scope) includes every character.
--   mode "selected" includes a character when it is explicitly listed OR is a
--   member of any selected role.

local AltScope = {}
ns.AltScope = AltScope

local pairs, type, next = pairs, type, next
local sort = sort

local changeCallbacks = {}

local function FireChanged()
    for _, fn in pairs(changeCallbacks) do
        fn()
    end
end

---@param id string
---@param fn fun()
function AltScope:RegisterChangedCallback(id, fn)
    changeCallbacks[id] = fn
end

---@param id string
function AltScope:UnregisterChangedCallback(id)
    changeCallbacks[id] = nil
end

local function GetRolesStore()
    return ns.db.global.roles
end

-- Smallest unused "r<n>" id so ids stay short and stable across deletes.
local function NextRoleId(roles)
    local n = 1
    while roles["r" .. n] do
        n = n + 1
    end
    return "r" .. n
end

--- Live roles map (id -> role). READ-ONLY by contract; mutate via the methods
--- below so storage stays consistent.
---@return table<string, table>
function AltScope:GetRoles()
    return GetRolesStore()
end

---@param id string
---@return table|nil role
function AltScope:GetRole(id)
    return GetRolesStore()[id]
end

--- Roles as an array sorted by display name (allocates; not for hot paths).
---@return table[] roles
function AltScope:GetRolesSorted()
    local out = {}
    for _, role in pairs(self:GetRoles()) do
        out[#out + 1] = role
    end
    sort(out, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return out
end

--- Create a role with the given display name.
---@param name string
---@return string|nil id
function AltScope:CreateRole(name)
    local roles = GetRolesStore()
    if not roles or type(name) ~= "string" or name:trim() == "" then return nil end
    local id = NextRoleId(roles)
    roles[id] = { id = id, name = name:trim(), members = {} }
    FireChanged()
    return id
end

---@param id string
---@param name string
function AltScope:RenameRole(id, name)
    local role = self:GetRole(id)
    if role and type(name) == "string" and name:trim() ~= "" then
        role.name = name:trim()
        FireChanged()
    end
end

---@param id string
function AltScope:DeleteRole(id)
    local roles = GetRolesStore()
    if roles then
        roles[id] = nil
        FireChanged()
    end
end

---@param id string
---@param charKey string
---@return boolean
function AltScope:IsCharInRole(id, charKey)
    local role = self:GetRole(id)
    return (role and role.members and role.members[charKey]) == true
end

---@param id string
---@param charKey string
---@param inRole boolean
function AltScope:SetCharInRole(id, charKey, inRole)
    local role = self:GetRole(id)
    if not role then return end
    role.members = role.members or {}
    role.members[charKey] = inRole and true or nil
    FireChanged()
end

---@param id string
---@return number
function AltScope:GetRoleMemberCount(id)
    local role = self:GetRole(id)
    if not role or not role.members then return 0 end
    local count = 0
    for _ in pairs(role.members) do count = count + 1 end
    return count
end

--- Whether a character passes a scope config. A nil/"all" scope always passes.
---@param charKey string
---@param scope table|nil { mode, chars, roles }
---@return boolean
function AltScope:IsCharIncluded(charKey, scope)
    if not scope or scope.mode ~= "selected" then return true end
    if not charKey then return false end
    if scope.chars and scope.chars[charKey] then return true end
    if scope.roles then
        for roleId in pairs(scope.roles) do
            if self:IsCharInRole(roleId, charKey) then return true end
        end
    end
    return false
end

--- Drop a character from every role's member list (e.g. after a database purge).
---@param charKey string
function AltScope:RemoveCharFromAllRoles(charKey)
    if not charKey then return end
    for _, role in pairs(self:GetRoles()) do
        if role.members then
            role.members[charKey] = nil
        end
    end
    FireChanged()
end

--- Whether a scope actually restricts anything (selected mode with at least one
--- chosen char or role). Used by callers to short-circuit "show all".
---@param scope table|nil
---@return boolean
function AltScope:IsScopeRestricted(scope)
    if not scope or scope.mode ~= "selected" then return false end
    if scope.chars and next(scope.chars) then return true end
    if scope.roles and next(scope.roles) then return true end
    return false
end
