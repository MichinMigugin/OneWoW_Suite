local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local stringsub = string.sub
local stringbyte = string.byte
local stringlen = string.len
local stringrep = string.rep
local stringfind = string.find
local stringgsub = string.gsub
local tableconcat = table.concat
local wipe = wipe
local GetTime = GetTime

Addon.EditorSyntax = {}
local ES = Addon.EditorSyntax

local TOKEN_NUMBER = 1
local TOKEN_LINEBREAK = 2
local TOKEN_WHITESPACE = 3
local TOKEN_IDENTIFIER = 4
local TOKEN_STRING = 10
local TOKEN_COMMENT_SHORT = 8
local TOKEN_COMMENT_LONG = 9
local TOKEN_KEYWORD = 33
local TOKEN_OPERATOR = 34
local TOKEN_COLORCODE_START = 37
local TOKEN_COLORCODE_STOP = 38

ES.TOKEN_NUMBER = TOKEN_NUMBER
ES.TOKEN_LINEBREAK = TOKEN_LINEBREAK
ES.TOKEN_WHITESPACE = TOKEN_WHITESPACE
ES.TOKEN_IDENTIFIER = TOKEN_IDENTIFIER
ES.TOKEN_STRING = TOKEN_STRING
ES.TOKEN_COMMENT_SHORT = TOKEN_COMMENT_SHORT
ES.TOKEN_COMMENT_LONG = TOKEN_COMMENT_LONG
ES.TOKEN_KEYWORD = TOKEN_KEYWORD
ES.TOKEN_OPERATOR = TOKEN_OPERATOR

local B_NL    = stringbyte("\n")
local B_CR    = stringbyte("\r")
local B_SQ    = stringbyte("'")
local B_DQ    = stringbyte('"')
local B_0     = stringbyte("0")
local B_9     = stringbyte("9")
local B_DOT   = stringbyte(".")
local B_SPC   = stringbyte(" ")
local B_TAB   = stringbyte("\t")
local B_E     = stringbyte("E")
local B_e     = stringbyte("e")
local B_x     = stringbyte("x")
local B_X     = stringbyte("X")
local B_a     = stringbyte("a")
local B_f     = stringbyte("f")
local B_A     = stringbyte("A")
local B_F     = stringbyte("F")
local B_MINUS = stringbyte("-")
local B_EQ    = stringbyte("=")
local B_LB    = stringbyte("[")
local B_RB    = stringbyte("]")
local B_BS    = stringbyte("\\")
local B_PIPE  = stringbyte("|")
local B_r     = stringbyte("r")
local B_c     = stringbyte("c")
local B_HASH  = stringbyte("#")
local B_PCT   = stringbyte("%")
local B_LT    = stringbyte("<")
local B_GT    = stringbyte(">")
local B_TILDE = stringbyte("~")
local B_LP    = stringbyte("(")
local B_RP    = stringbyte(")")
local B_LW    = stringbyte("{")
local B_RW    = stringbyte("}")
local B_COMMA = stringbyte(",")
local B_SEMI  = stringbyte(";")
local B_COLON = stringbyte(":")
local B_PLUS  = stringbyte("+")
local B_SLASH = stringbyte("/")
local B_CARET = stringbyte("^")
local B_STAR  = stringbyte("*")
local B_UNDER = stringbyte("_")

local isLinebreak = { [B_NL] = true, [B_CR] = true }
local isWhitespace = { [B_SPC] = true, [B_TAB] = true }

local function isDigit(b) return b and b >= B_0 and b <= B_9 end
local function isHexDigit(b)
    return b and ((b >= B_0 and b <= B_9) or (b >= B_a and b <= B_f) or (b >= B_A and b <= B_F))
end
local function isIdentChar(b)
    if not b then return false end
    if b >= B_0 and b <= B_9 then return true end
    if b == B_UNDER then return true end
    local lower = bit.bor(b, 0x20)
    return lower >= 0x61 and lower <= 0x7A
end

local function scanNumberExp(text, pos)
    local b = stringbyte(text, pos)
    if b == B_MINUS or b == B_PLUS then pos = pos + 1 end
    while isDigit(stringbyte(text, pos)) do pos = pos + 1 end
    return TOKEN_NUMBER, pos
end

local function scanNumberFrac(text, pos)
    while isDigit(stringbyte(text, pos)) do pos = pos + 1 end
    local b = stringbyte(text, pos)
    if b == B_E or b == B_e then return scanNumberExp(text, pos + 1) end
    return TOKEN_NUMBER, pos
end

local function scanNumberInt(text, pos)
    while isDigit(stringbyte(text, pos)) do pos = pos + 1 end
    local b = stringbyte(text, pos)
    if b == B_DOT then return scanNumberFrac(text, pos + 1) end
    if b == B_E or b == B_e then return scanNumberExp(text, pos + 1) end
    return TOKEN_NUMBER, pos
end

local function scanHexNumber(text, pos)
    while isHexDigit(stringbyte(text, pos)) do pos = pos + 1 end
    return TOKEN_NUMBER, pos
end

local function scanIdentifier(text, pos)
    while isIdentChar(stringbyte(text, pos)) do pos = pos + 1 end
    return TOKEN_IDENTIFIER, pos
end

local function isBracketStringStart(text, pos)
    if stringbyte(text, pos) ~= B_LB then return false end
    local p = pos + 1
    local b = stringbyte(text, p)
    while b == B_EQ do p = p + 1; b = stringbyte(text, p) end
    if b == B_LB then return true, p + 1, (p - 1) - pos end
    return false
end

local function scanBracketString(text, pos, eqCount)
    local state = 0
    while true do
        local b = stringbyte(text, pos)
        if not b then return TOKEN_STRING, pos end
        if b == B_RB then
            if state == 0 then state = 1
            elseif state == eqCount + 1 then return TOKEN_STRING, pos + 1
            else state = 0 end
        elseif b == B_EQ then
            if state > 0 then state = state + 1 end
        else state = 0 end
        pos = pos + 1
    end
end

local function scanComment(text, pos)
    local ok, nxt, eq = isBracketStringStart(text, pos)
    if ok then
        local _, endPos = scanBracketString(text, nxt, eq)
        return TOKEN_COMMENT_LONG, endPos
    end
    while true do
        local b = stringbyte(text, pos)
        if not b or isLinebreak[b] then return TOKEN_COMMENT_SHORT, pos end
        pos = pos + 1
    end
end

local function scanString(text, pos, quote)
    local even = true
    while true do
        local b = stringbyte(text, pos)
        if not b or isLinebreak[b] then return TOKEN_STRING, pos end
        if b == quote and even then return TOKEN_STRING, pos + 1 end
        even = b ~= B_BS or not even
        pos = pos + 1
    end
end

function ES.nextToken(text, pos)
    local b = stringbyte(text, pos)
    if not b then return nil end

    if isLinebreak[b] then return TOKEN_LINEBREAK, pos + 1 end

    if isWhitespace[b] then
        pos = pos + 1
        while isWhitespace[stringbyte(text, pos)] do pos = pos + 1 end
        return TOKEN_WHITESPACE, pos
    end

    if b == B_PIPE then
        local b2 = stringbyte(text, pos + 1)
        if b2 == B_PIPE then return TOKEN_OPERATOR, pos + 2 end
        if b2 == B_c then return TOKEN_COLORCODE_START, pos + 10 end
        if b2 == B_r then return TOKEN_COLORCODE_STOP, pos + 2 end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_MINUS then
        if stringbyte(text, pos + 1) == B_MINUS then return scanComment(text, pos + 2) end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_SQ then return scanString(text, pos + 1, B_SQ) end
    if b == B_DQ then return scanString(text, pos + 1, B_DQ) end

    if b == B_LB then
        local ok, nxt, eq = isBracketStringStart(text, pos)
        if ok then return scanBracketString(text, nxt, eq) end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_EQ then
        if stringbyte(text, pos + 1) == B_EQ then return TOKEN_OPERATOR, pos + 2 end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_DOT then
        local b2 = stringbyte(text, pos + 1)
        if b2 == B_DOT then
            if stringbyte(text, pos + 2) == B_DOT then return TOKEN_OPERATOR, pos + 3 end
            return TOKEN_OPERATOR, pos + 2
        end
        if isDigit(b2) then return scanNumberFrac(text, pos + 2) end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_LT then
        if stringbyte(text, pos + 1) == B_EQ then return TOKEN_OPERATOR, pos + 2 end
        return TOKEN_OPERATOR, pos + 1
    end
    if b == B_GT then
        if stringbyte(text, pos + 1) == B_EQ then return TOKEN_OPERATOR, pos + 2 end
        return TOKEN_OPERATOR, pos + 1
    end
    if b == B_TILDE then
        if stringbyte(text, pos + 1) == B_EQ then return TOKEN_OPERATOR, pos + 2 end
        return TOKEN_OPERATOR, pos + 1
    end

    if b == B_RB or b == B_COMMA or b == B_SEMI or b == B_COLON
        or b == B_LP or b == B_RP or b == B_PLUS or b == B_SLASH
        or b == B_LW or b == B_RW or b == B_CARET or b == B_STAR
        or b == B_HASH or b == B_PCT then
        return TOKEN_OPERATOR, pos + 1
    end

    if isDigit(b) then
        if b == B_0 then
            local b2 = stringbyte(text, pos + 1)
            if b2 == B_x or b2 == B_X then return scanHexNumber(text, pos + 2) end
        end
        return scanNumberInt(text, pos + 1)
    end

    if isIdentChar(b) then return scanIdentifier(text, pos + 1) end

    return TOKEN_OPERATOR, pos + 1
end

local work = {}

function ES.colorCodeText(code, caretPos)
    local D = Addon.EditorSyntaxData
    if not D then return code, caretPos end

    local M = D.MONOKAI
    local stopColor = "|r"
    local stopLen = 2

    wipe(work)
    local tsize = 0
    local totalLen = 0
    local newCaret
    local prevColored = false
    local prevWidth = 0
    local pos = 1
    local prevCNamespaceName = nil
    local prevWasDot = false

    while true do
        if caretPos and not newCaret and pos >= caretPos then
            if pos == caretPos then
                newCaret = totalLen
            else
                newCaret = totalLen
                local diff = pos - caretPos
                if diff > prevWidth then diff = prevWidth end
                if prevColored then diff = diff + stopLen end
                newCaret = newCaret - diff
            end
        end

        prevColored = false
        prevWidth = 0

        local tt, nxt = ES.nextToken(code, pos)
        if not tt then break end

        if tt == TOKEN_COLORCODE_START or tt == TOKEN_COLORCODE_STOP then
            -- skip existing color codes
        elseif tt == TOKEN_LINEBREAK or tt == TOKEN_WHITESPACE then
            local s = stringsub(code, pos, nxt - 1)
            prevWidth = nxt - pos
            tsize = tsize + 1; work[tsize] = s
            totalLen = totalLen + stringlen(s)
        else
            local s = stringsub(code, pos, nxt - 1)
            prevWidth = nxt - pos

            local colorHex
            local afterCNamespaceDot = prevWasDot and prevCNamespaceName
            if tt == TOKEN_IDENTIFIER and afterCNamespaceDot then
                if D.DYNAMIC_API_NAMES[prevCNamespaceName .. "." .. s] then
                    colorHex = M.WOW_API
                else
                    colorHex = M.WOW_C
                end
                prevCNamespaceName = nil
                prevWasDot = false
            elseif tt == TOKEN_COMMENT_SHORT or tt == TOKEN_COMMENT_LONG then
                colorHex = M.COMMENT
                prevCNamespaceName = nil
                prevWasDot = false
            elseif tt == TOKEN_STRING then
                colorHex = M.STRING
                prevCNamespaceName = nil
                prevWasDot = false
            elseif tt == TOKEN_NUMBER then
                colorHex = M.NUMBER
                prevCNamespaceName = nil
                prevWasDot = false
            elseif tt == TOKEN_IDENTIFIER then
                prevCNamespaceName = nil
                prevWasDot = false
                if D.LUA_KEYWORDS[s] then
                    colorHex = M.KEYWORD
                elseif D.LUA_CONSTANTS[s] then
                    colorHex = M.CONSTANT
                elseif s == "self" then
                    colorHex = M.SELF
                elseif D.LUA_BUILTINS[s] or D.MATH_GLOBALS[s] or D.STRING_GLOBALS[s] or D.TABLE_GLOBALS[s] then
                    colorHex = M.BUILTIN
                elseif D.LIBRARY_NAMESPACES[s] then
                    colorHex = M.NAMESPACE
                elseif D.WOW_C_NAMESPACES[s] then
                    colorHex = M.WOW_C
                    prevCNamespaceName = s
                elseif D.WOW_GLOBALS[s] or D.DYNAMIC_API_NAMES[s] then
                    colorHex = M.WOW_API
                else
                    colorHex = M.FOREGROUND
                end
            elseif tt == TOKEN_OPERATOR then
                colorHex = M.OPERATOR
                if s == "." and prevCNamespaceName then
                    prevWasDot = true
                else
                    prevCNamespaceName = nil
                    prevWasDot = false
                end
            end

            if colorHex then
                local pre = "|cFF" .. colorHex
                tsize = tsize + 1; work[tsize] = pre
                tsize = tsize + 1; work[tsize] = s
                tsize = tsize + 1; work[tsize] = stopColor
                totalLen = totalLen + stringlen(pre) + (nxt - pos) + stopLen
                prevColored = true
            else
                tsize = tsize + 1; work[tsize] = s
                totalLen = totalLen + stringlen(s)
            end
        end

        pos = nxt
    end

    if caretPos and not newCaret then
        newCaret = totalLen
    end

    return tableconcat(work), newCaret
end

function ES.stripWowColors(code)
    wipe(work)
    local tsize = 0
    local pos = 1
    local prevVertical = false
    local even = true
    local selStart = 1

    while true do
        local b = stringbyte(code, pos)
        if not b then break end
        if b == B_PIPE then
            even = not even
            prevVertical = true
        else
            if prevVertical and not even then
                if b == B_c then
                    if pos - 2 >= selStart then
                        tsize = tsize + 1; work[tsize] = stringsub(code, selStart, pos - 2)
                    end
                    pos = pos + 8
                    selStart = pos + 1
                elseif b == B_r then
                    if pos - 2 >= selStart then
                        tsize = tsize + 1; work[tsize] = stringsub(code, selStart, pos - 2)
                    end
                    selStart = pos + 1
                end
            end
            prevVertical = false
            even = true
        end
        pos = pos + 1
    end
    if pos >= selStart then
        tsize = tsize + 1; work[tsize] = stringsub(code, selStart, pos - 1)
    end
    return tableconcat(work)
end

local function stringinsert(s, pos, insertStr)
    return stringsub(s, 1, pos - 1) .. insertStr .. stringsub(s, pos)
end
local function stringdelete(s, p1, p2)
    return stringsub(s, 1, p1 - 1) .. stringsub(s, p2 + 1)
end

function ES.stripWowColorsWithPos(code, pos)
    code = stringinsert(code, pos + 1, "\2")
    code = ES.stripWowColors(code)
    pos = stringfind(code, "\2", 1, true)
    if pos then
        code = stringdelete(code, pos, pos)
    else
        pos = 1
    end
    return code, pos
end

function ES.decode(code)
    if code then
        code = ES.stripWowColors(code)
        code = stringgsub(code, "||", "|")
    end
    return code or ""
end

function ES.encode(code)
    if code then
        code = stringgsub(code, "|", "||")
    end
    return code or ""
end

local noEffect = {0, 0}
local indentLeft = {-1, 0}
local indentRight = {0, 1}
local indentBoth = {-1, 1}

local keywordIndent = {
    ["do"] = indentRight, ["then"] = indentRight, ["repeat"] = indentRight, ["function"] = indentRight,
    ["end"] = indentLeft, ["until"] = indentLeft, ["elseif"] = indentLeft,
    ["else"] = indentBoth,
}

local bracketIndent = {
    ["("] = indentRight, ["["] = indentRight, ["{"] = indentRight,
    [")"] = indentLeft, ["]"] = indentLeft, ["}"] = indentLeft,
}

function ES.indentCode(code, tabWidth)
    wipe(work)
    local tsize = 0

    local lineTokens = {}
    local ltSize = 0

    local pos = 1
    local level = 0
    local hitNonWS = false
    local lineDelta = 0
    local lineMinDelta = 0
    local mathmin = math.min

    local function flushLine(includeBreak, breakStr)
        local lineShift = mathmin(0, lineMinDelta)
        local thisLevel = level + lineShift
        if thisLevel < 0 then thisLevel = 0 end

        local indent = stringrep(" ", thisLevel * tabWidth)
        tsize = tsize + 1; work[tsize] = indent

        for i = 1, ltSize do
            tsize = tsize + 1; work[tsize] = lineTokens[i]
        end

        if includeBreak then
            tsize = tsize + 1; work[tsize] = breakStr
        end

        level = thisLevel + (lineDelta - lineShift)
        if level < 0 then level = 0 end

        wipe(lineTokens); ltSize = 0
        hitNonWS = false
        lineDelta = 0
        lineMinDelta = 0
    end

    while true do
        local tt, nxt = ES.nextToken(code, pos)

        if not tt then
            flushLine(false)
            break
        end

        if tt == TOKEN_LINEBREAK then
            flushLine(true, stringsub(code, pos, nxt - 1))
        elseif tt == TOKEN_WHITESPACE then
            if hitNonWS then
                ltSize = ltSize + 1; lineTokens[ltSize] = stringsub(code, pos, nxt - 1)
            end
        elseif tt == TOKEN_COLORCODE_START or tt == TOKEN_COLORCODE_STOP then
            -- skip
        else
            hitNonWS = true
            local s = stringsub(code, pos, nxt - 1)
            ltSize = ltSize + 1; lineTokens[ltSize] = s

            local effect = keywordIndent[s] or bracketIndent[s]
            if effect then
                lineDelta = lineDelta + effect[1]
                if lineDelta < lineMinDelta then
                    lineMinDelta = lineDelta
                end
                lineDelta = lineDelta + effect[2]
            end
        end

        pos = nxt
    end

    return tableconcat(work)
end

local editboxSetText
local editboxGetText
local enabled = {}
local recolorTimers = {}
local editboxStringCache = {}
local decodeCache = {}
local RECOLOR_DELAY = 0.2

local function hookHandler(editbox, handler, newFn)
    local oldFn = editbox:GetScript(handler)
    if oldFn == newFn then return end
    editbox["es_old_" .. handler] = oldFn
    editbox:SetScript(handler, newFn)
end

local function cancelRecolor(editbox)
    local timer = recolorTimers[editbox]
    if timer then
        timer:Cancel()
        recolorTimers[editbox] = nil
    end
end

local function scheduleRecolor(editbox, delay)
    if not enabled[editbox] then
        return
    end
    cancelRecolor(editbox)
    recolorTimers[editbox] = C_Timer.NewTimer(delay or RECOLOR_DELAY, function()
        recolorTimers[editbox] = nil
        if not enabled[editbox] then
            return
        end
        decodeCache[editbox] = nil
        ES.colorCodeEditbox(editbox)
    end)
end

function ES.colorCodeEditbox(editbox)
    cancelRecolor(editbox)

    local orgCode = editboxGetText(editbox)
    if editboxStringCache[editbox] == orgCode then return end

    local cursorPos = editbox:GetCursorPosition()
    local code, adjPos = ES.stripWowColorsWithPos(orgCode, cursorPos)

    local newCode, newCaret = ES.colorCodeText(code, adjPos)

    editboxStringCache[editbox] = newCode
    if orgCode ~= newCode then
        decodeCache[editbox] = nil
        local codeLen = stringlen(newCode)
        editbox.es_internalColorizing = true
        editboxSetText(editbox, newCode)
        editbox.es_internalColorizing = nil
        if newCaret then
            if newCaret < 0 then newCaret = 0 end
            if newCaret > codeLen then newCaret = codeLen end
            editbox:SetCursorPosition(newCaret)
        end
    end
end

local function textChangedHook(editbox, ...)
    local oldFn = editbox["es_old_OnTextChanged"]
    if oldFn then oldFn(editbox, ...) end
    if enabled[editbox] then
        decodeCache[editbox] = nil
        if not editbox.es_internalColorizing then
            scheduleRecolor(editbox)
        end
    end
end

local function tabPressedHook(editbox, ...)
    local oldFn = editbox["es_old_OnTabPressed"]
    if oldFn then oldFn(editbox, ...) end
    if not enabled[editbox] then return end

    local indentSize = editbox.es_tabWidth or 3
    local spaces = stringrep(" ", indentSize)
    editbox:Insert(spaces)
end

local function newGetText(editbox, raw)
    if raw then
        return ES.decode(editboxGetText(editbox))
    end
    local cached = decodeCache[editbox]
    if not cached then
        cached = ES.decode(editboxGetText(editbox))
        decodeCache[editbox] = cached
    end
    return cached or ""
end

local function newSetText(editbox, text)
    decodeCache[editbox] = nil
    editboxStringCache[editbox] = nil
    if text then
        return editboxSetText(editbox, ES.encode(text))
    end
end

function ES.enable(editbox, tabWidth)
    if not editboxSetText then
        editboxSetText = editbox.SetText
        editboxGetText = editbox.GetText
    end

    editbox.es_tabWidth = tabWidth or 3

    if enabled[editbox] then return end

    enabled[editbox] = true
    editbox.oldMaxBytes = editbox:GetMaxBytes()
    editbox.oldMaxLetters = editbox:GetMaxLetters()
    editbox:SetMaxBytes(0)
    editbox:SetMaxLetters(0)

    editbox.GetText = newGetText
    editbox.SetText = newSetText

    hookHandler(editbox, "OnTextChanged", textChangedHook)
    hookHandler(editbox, "OnTabPressed", tabPressedHook)

    ES.colorCodeEditbox(editbox)
end

function ES.disable(editbox)
    if not enabled[editbox] then return end
    enabled[editbox] = nil
    cancelRecolor(editbox)

    editbox:SetMaxBytes(editbox.oldMaxBytes or 0)
    editbox:SetMaxLetters(editbox.oldMaxLetters or 0)

    if editbox:GetScript("OnTextChanged") == textChangedHook then
        editbox:SetScript("OnTextChanged", editbox["es_old_OnTextChanged"])
    end
    if editbox:GetScript("OnTabPressed") == tabPressedHook then
        editbox:SetScript("OnTabPressed", editbox["es_old_OnTabPressed"])
    end

    editbox.GetText = nil
    editbox.SetText = nil

    editbox:SetText(newGetText(editbox))

    editboxStringCache[editbox] = nil
    decodeCache[editbox] = nil
end

function ES.isEnabled(editbox)
    return enabled[editbox] == true
end

function ES.setTabWidth(editbox, width)
    editbox.es_tabWidth = width or 3
end

function ES.forceDirty(editbox)
    if enabled[editbox] then
        decodeCache[editbox] = nil
        scheduleRecolor(editbox, 0)
    end
end

function ES.getPlainCursorPos(editbox)
    if not enabled[editbox] or not editboxGetText then
        return editbox:GetCursorPosition()
    end
    local rawText = editboxGetText(editbox)
    local rawPos = editbox:GetCursorPosition()
    local _, adjPos = ES.stripWowColorsWithPos(rawText, rawPos)
    return adjPos - 1
end

function ES.getPlainTextForSearch(editbox)
    if not enabled[editbox] or not editboxGetText then
        return editbox:GetText() or ""
    end
    return ES.stripWowColors(editboxGetText(editbox)) or ""
end

function ES.plainRangeToRaw(editbox, plainStart, plainEnd)
    if not enabled[editbox] or not editboxGetText then
        return plainStart, plainEnd
    end
    local rawText = editboxGetText(editbox)
    local rawStart, rawEnd
    local pos = 1
    local plainIdx = 0
    local prevVertical = false
    local even = true
    local selStart = 1
    while pos <= stringlen(rawText) + 1 do
        local b = pos <= stringlen(rawText) and stringbyte(rawText, pos) or nil
        if not b then
            if pos >= selStart then
                local segLen = (pos - 1) - selStart + 1
                local segStartRaw = selStart - 1
                if plainIdx <= plainStart and plainIdx + segLen > plainStart and not rawStart then
                    rawStart = segStartRaw + (plainStart - plainIdx)
                end
                if plainIdx <= plainEnd and plainIdx + segLen >= plainEnd and not rawEnd then
                    rawEnd = segStartRaw + (plainEnd - plainIdx)
                end
                plainIdx = plainIdx + segLen
            end
            break
        end
        if b == B_PIPE then
            even = not even
            prevVertical = true
        else
            if prevVertical and not even then
                if b == B_c then
                    if pos - 2 >= selStart then
                        local segLen = (pos - 2) - selStart + 1
                        local segStartRaw = selStart - 1
                        if plainIdx <= plainStart and plainIdx + segLen > plainStart and not rawStart then
                            rawStart = segStartRaw + (plainStart - plainIdx)
                        end
                        if plainIdx <= plainEnd and plainIdx + segLen >= plainEnd and not rawEnd then
                            rawEnd = segStartRaw + (plainEnd - plainIdx)
                        end
                        plainIdx = plainIdx + segLen
                    end
                    pos = pos + 8
                    selStart = pos + 1
                elseif b == B_r then
                    if pos - 2 >= selStart then
                        local segLen = (pos - 2) - selStart + 1
                        local segStartRaw = selStart - 1
                        if plainIdx <= plainStart and plainIdx + segLen > plainStart and not rawStart then
                            rawStart = segStartRaw + (plainStart - plainIdx)
                        end
                        if plainIdx <= plainEnd and plainIdx + segLen >= plainEnd and not rawEnd then
                            rawEnd = segStartRaw + (plainEnd - plainIdx)
                        end
                        plainIdx = plainIdx + segLen
                    end
                    selStart = pos + 1
                end
            end
            prevVertical = false
            even = true
        end
        pos = pos + 1
    end
    return rawStart or 0, rawEnd or rawStart or 0
end
