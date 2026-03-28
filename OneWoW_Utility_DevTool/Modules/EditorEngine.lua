local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local format = string.format
local tinsert, tremove = tinsert, tremove
local GetTime = GetTime

Addon.EditorEngine = {}
local EE = Addon.EditorEngine

local undoQueues = {}
local undoPositions = {}
local savedSnapshots = {}

local function getDB()
    return Addon.db and Addon.db.editor
end

local function getDefaultCategory()
    local db = getDB()
    local L = Addon.L or {}
    return (db and db.defaultCategory) or L["EDITOR_CATEGORY_DEFAULT"]
end

local function normalizeSnippetName(name)
    return strtrim(name or "")
end

local function nextSnippetId()
    local db = getDB()
    if not db then return tostring(GetTime()) end
    local maxId = 0
    for _, snippet in pairs(db.snippets) do
        local n = tonumber(snippet.id)
        if n and n > maxId then maxId = n end
    end
    return tostring(maxId + 1)
end

function EE:CreateSnippet(name, category)
    local db = getDB()
    if not db then return end
    local L = Addon.L

    local untitled = false
    name = normalizeSnippetName(name)
    if name == "" then
        name = format(L["EDITOR_DEFAULT_SNIPPET_NAME"], db.untitledCounter)
        db.untitledCounter = db.untitledCounter + 1
        untitled = true
    end

    category = category or getDefaultCategory()
    if not untitled and self:IsSnippetNameTakenInCategory(category, name) then
        return nil
    end

    local id = nextSnippetId()
    local snippet = {
        id = id,
        name = name,
        category = category,
        code = "",
        indentSize = db.indentSize or 3,
        created = GetTime(),
        modified = GetTime(),
        untitled = untitled,
    }
    db.snippets[id] = snippet
    return id, snippet
end

function EE:GetSnippet(id)
    local db = getDB()
    return db and db.snippets[id]
end

function EE:GetAllSnippets()
    local db = getDB()
    return db and db.snippets or {}
end

function EE:GetSnippetsByCategory(cat)
    local db = getDB()
    if not db then return {} end
    local result = {}
    for _, snippet in pairs(db.snippets) do
        if snippet.category == cat then
            tinsert(result, snippet)
        end
    end
    sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
    return result
end

function EE:IsSnippetNameTakenInCategory(category, name, excludeId)
    local db = getDB()
    if not db then return false end

    name = normalizeSnippetName(name)
    if name == "" then return false end

    for id, snippet in pairs(db.snippets) do
        if id ~= excludeId and snippet.category == category and snippet.name == name then
            return true
        end
    end

    return false
end

function EE:RenameSnippet(id, newName)
    local snippet = self:GetSnippet(id)
    newName = normalizeSnippetName(newName)
    if not snippet or newName == "" then return false end
    if self:IsSnippetNameTakenInCategory(snippet.category, newName, id) then return false end
    snippet.name = newName
    snippet.untitled = nil
    snippet.modified = GetTime()
    return true
end

function EE:DeleteSnippet(id)
    local db = getDB()
    if not db or not db.snippets[id] then return false end
    db.snippets[id] = nil
    undoQueues[id] = nil
    undoPositions[id] = nil
    savedSnapshots[id] = nil
    return true
end

function EE:DuplicateSnippet(id)
    local snippet = self:GetSnippet(id)
    if not snippet then return end
    local L = Addon.L
    local newName = format(L["EDITOR_COPY_OF"], snippet.name)
    local newId, newSnippet = self:CreateSnippet(newName, snippet.category)
    if newSnippet then
        newSnippet.code = snippet.code
        newSnippet.indentSize = snippet.indentSize
        newSnippet.untitled = nil
    end
    return newId, newSnippet
end

function EE:SaveSnippet(id, content)
    local snippet = self:GetSnippet(id)
    if not snippet then return false end
    snippet.code = content or ""
    snippet.modified = GetTime()
    savedSnapshots[id] = content or ""
    return true
end

function EE:MoveSnippet(id, newCategory)
    local snippet = self:GetSnippet(id)
    if not snippet or not newCategory then return false end
    if self:IsSnippetNameTakenInCategory(newCategory, snippet.name, id) then return false end
    snippet.category = newCategory
    snippet.modified = GetTime()
    return true
end

function EE:CreateCategory(name)
    local db = getDB()
    if not db then return false end
    name = strtrim(name or "")
    if name == "" then return false end
    for _, cat in ipairs(db.categories) do
        if cat == name then return false end
    end
    tinsert(db.categories, name)
    return true
end

function EE:RenameCategory(oldName, newName)
    local db = getDB()
    if not db then return false end
    newName = strtrim(newName or "")
    if newName == "" then return false end
    if oldName == getDefaultCategory() then return false end
    for _, cat in ipairs(db.categories) do
        if cat == newName and cat ~= oldName then
            return false
        end
    end
    for i, cat in ipairs(db.categories) do
        if cat == oldName then
            db.categories[i] = newName
            for _, snippet in pairs(db.snippets) do
                if snippet.category == oldName then
                    snippet.category = newName
                end
            end
            if db.categoryCollapsed[oldName] ~= nil then
                db.categoryCollapsed[newName] = db.categoryCollapsed[oldName]
                db.categoryCollapsed[oldName] = nil
            end
            return true
        end
    end
    return false
end

function EE:DeleteCategory(name)
    local db = getDB()
    if not db then return false end
    local defaultCat = getDefaultCategory()
    if name == defaultCat then return false end
    for i, cat in ipairs(db.categories) do
        if cat == name then
            tremove(db.categories, i)
            for _, snippet in pairs(db.snippets) do
                if snippet.category == name then
                    snippet.category = defaultCat
                end
            end
            db.categoryCollapsed[name] = nil
            return true
        end
    end
    return false
end

function EE:GetCategories()
    local db = getDB()
    return db and db.categories or {}
end

function EE:GetDefaultCategory()
    return getDefaultCategory()
end

function EE:GetSnippetIndent(id)
    local snippet = self:GetSnippet(id)
    if not snippet then return nil end
    return snippet.indentSize
end

function EE:SetSnippetIndent(id, size)
    local snippet = self:GetSnippet(id)
    if not snippet then return end
    snippet.indentSize = size
end

function EE:QueueUndo(snippetId, text)
    if not snippetId or not text then return end
    local queue = undoQueues[snippetId]
    if not queue then
        queue = {}
        undoQueues[snippetId] = queue
        undoPositions[snippetId] = 0
    end

    local pos = undoPositions[snippetId]
    if pos == 0 then
        queue[1] = text
        undoPositions[snippetId] = 1
        return
    end

    if text == queue[pos] then return end

    pos = pos + 1
    queue[pos] = text
    for i = pos + 1, #queue do queue[i] = nil end
    undoPositions[snippetId] = pos
end

function EE:Undo(snippetId, currentText)
    if not snippetId then return currentText end
    self:QueueUndo(snippetId, currentText)

    local queue = undoQueues[snippetId]
    local pos = undoPositions[snippetId]
    if not queue or not pos then return currentText end

    if pos > 1 then
        pos = pos - 1
        undoPositions[snippetId] = pos
        return queue[pos]
    end
    return queue[pos] or currentText
end

function EE:Redo(snippetId)
    if not snippetId then return nil end
    local queue = undoQueues[snippetId]
    local pos = undoPositions[snippetId]
    if not queue or not pos then return nil end

    if pos < #queue then
        pos = pos + 1
        undoPositions[snippetId] = pos
        return queue[pos]
    end
    return nil
end

function EE:ClearUndo(snippetId)
    undoQueues[snippetId] = nil
    undoPositions[snippetId] = nil
end

local outputHandler

function EE:SetOutputHandler(fn)
    outputHandler = fn
end

local function editorPrint(...)
    if not outputHandler then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    outputHandler(table.concat(parts, "    "), "print")
end

function EE:RunSnippet(code, snippetName)
    if not code or code == "" then return true end

    local chunkName = snippetName or "editor"
    local func, compileErr = loadstring(code, chunkName)

    if not func then
        if outputHandler then
            outputHandler(compileErr, "error")
        end
        local lineNum = compileErr and compileErr:match(':(%d+):')
        return false, compileErr, tonumber(lineNum)
    end

    local oldPrint = print
    print = editorPrint

    local ok, runtimeErr = pcall(func)

    print = oldPrint

    if not ok then
        if outputHandler then
            outputHandler(runtimeErr, "error")
        end
        local lineNum = runtimeErr and runtimeErr:match(':(%d+):')
        return false, runtimeErr, tonumber(lineNum)
    end

    return true
end

function EE:RunCommand(text)
    if not text or text == "" then return true end

    text = text:gsub("^%s*=%s*(.+)", "print(%1)")
    text = strtrim(text)

    return self:RunSnippet(text, "command")
end

function EE:IsModified(id, currentText)
    if not id then return false end
    local snippet = self:GetSnippet(id)
    if not snippet then return false end
    local saved = savedSnapshots[id]
    if saved == nil then saved = snippet.code or "" end
    return (currentText or "") ~= saved
end

function EE:MarkSaved(id, content)
    savedSnapshots[id] = content or ""
end

function EE:InitSavedSnapshot(id)
    local snippet = self:GetSnippet(id)
    if snippet then
        savedSnapshots[id] = snippet.code or ""
    end
end

function EE:FindNext(text, pattern, startPos, wrapAround)
    if not text or not pattern or pattern == "" then return nil end
    local s, e = string.find(text, pattern, startPos, true)
    if not s and wrapAround and startPos > 1 then
        s, e = string.find(text, pattern, 1, true)
    end
    return s, e
end

function EE:FindPrevious(text, pattern, startPos, wrapAround)
    if not text or not pattern or pattern == "" then return nil end
    startPos = startPos or 1
    if startPos < 1 then
        startPos = 1
    end
    local lastS, lastE
    local s, e = string.find(text, pattern, 1, true)
    while s do
        if s >= startPos then break end
        lastS, lastE = s, e
        s, e = string.find(text, pattern, e + 1, true)
    end
    if not lastS and wrapAround then
        local wrapS, wrapE
        local cs, ce = string.find(text, pattern, startPos, true)
        while cs do
            wrapS, wrapE = cs, ce
            cs, ce = string.find(text, pattern, ce + 1, true)
        end
        return wrapS, wrapE
    end
    return lastS, lastE
end

function EE:ReplaceNext(text, pattern, replacement, startPos)
    if not text or not pattern or pattern == "" then return text, false end
    local s, e = string.find(text, pattern, startPos or 1, true)
    if not s then return text, false end
    local result = string.sub(text, 1, s - 1) .. replacement .. string.sub(text, e + 1)
    return result, true, s, s + string.len(replacement) - 1
end

function EE:ReplaceAll(text, pattern, replacement)
    if not text or not pattern or pattern == "" then return text, 0 end
    local count = 0
    local result = {}
    local pos = 1
    while true do
        local s, e = string.find(text, pattern, pos, true)
        if not s then
            tinsert(result, string.sub(text, pos))
            break
        end
        tinsert(result, string.sub(text, pos, s - 1))
        tinsert(result, replacement)
        count = count + 1
        pos = e + 1
    end
    return table.concat(result), count
end
