local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

OneWoW_Utility_DevTool = {}

local L = ns.L

local pcall = pcall
local type = type
local tostring = tostring

local function safeGet(frame, method, ...)
    local fn = frame[method]
    if not fn then return nil, false end
    local ok, result = pcall(fn, frame, ...)
    if not ok then return nil, true end
    if result ~= nil and OneWoW.Restriction.IsSecret(result) then return nil, true end
    return result, false
end

local function safeGetMulti(frame, method, ...)
    local fn = frame[method]
    if not fn then return nil end
    local callResults = { pcall(fn, frame, ...) }
    if not callResults[1] then return nil end
    local results = {}
    for i = 2, #callResults do
        if OneWoW.Restriction.IsSecret(callResults[i]) then
            tinsert(results, "[secret]")
        else
            tinsert(results, callResults[i])
        end
    end
    return results
end

ns.safeGet = safeGet
ns.safeGetMulti = safeGetMulti

function ns:Print(msg)
    print("|cFFFFD100OneWoW|r - " .. L["ADDON_TITLE"] .. ": " .. tostring(msg))
end

local function getRegisteredEvents(frame)
    if not frame.IsEventRegistered then return nil end
    local hasOnEvent = frame.GetScript and pcall(frame.GetScript, frame, "OnEvent")
    if not hasOnEvent then return nil end
    local events = {}
    for _, event in ipairs(ns.Constants.COMMON_EVENTS) do
        local ok, registered = pcall(frame.IsEventRegistered, frame, event)
        if ok and registered then
            tinsert(events, event)
        end
    end
    return events
end

local function getScriptInfo(frame)
    if not frame.GetScript then return nil end
    local scripts = {}
    for _, scriptName in ipairs(ns.Constants.COMMON_SCRIPTS) do
        local ok, handler = pcall(frame.GetScript, frame, scriptName)
        if ok and handler then
            tinsert(scripts, scriptName)
        end
    end
    return scripts
end

local function getTypeSpecificInfo(obj)
    local objType = safeGet(obj, "GetObjectType")
    if not objType then return nil end

    local props = {}
    props._type = objType

    if objType == "Texture" or objType == "MaskTexture" then
        props.atlas = safeGet(obj, "GetAtlas")
        props.texture = safeGet(obj, "GetTexture")
        props.textureFileID = safeGet(obj, "GetTextureFileID")
        props.blendMode = safeGet(obj, "GetBlendMode")
        props.texCoord = safeGetMulti(obj, "GetTexCoord")
        local drawVals = safeGetMulti(obj, "GetDrawLayer")
        if drawVals then
            props.drawLayer = drawVals[1]
            props.drawSublevel = drawVals[2]
        end
        props.vertexColor = safeGetMulti(obj, "GetVertexColor")
        props.desaturation = safeGet(obj, "GetDesaturation")
        props.rotation = safeGet(obj, "GetRotation")
        props.horizTile = safeGet(obj, "GetHorizTile")
        props.vertTile = safeGet(obj, "GetVertTile")
    elseif objType == "FontString" then
        props.text = safeGet(obj, "GetText")
        props.font = safeGetMulti(obj, "GetFont")
        props.fontObject = safeGet(obj, "GetFontObject")
        props.justifyH = safeGet(obj, "GetJustifyH")
        props.justifyV = safeGet(obj, "GetJustifyV")
        props.shadowColor = safeGetMulti(obj, "GetShadowColor")
        props.shadowOffset = safeGetMulti(obj, "GetShadowOffset")
        props.spacing = safeGet(obj, "GetSpacing")
        props.stringWidth = safeGet(obj, "GetStringWidth")
        props.stringHeight = safeGet(obj, "GetStringHeight")
        props.numLines = safeGet(obj, "GetNumLines")
        props.isTruncated = safeGet(obj, "IsTruncated")
    elseif objType == "Line" then
        props.startPoint = safeGetMulti(obj, "GetStartPoint")
        props.endPoint = safeGetMulti(obj, "GetEndPoint")
        props.thickness = safeGet(obj, "GetThickness")
    elseif objType == "Button" or objType == "CheckButton" then
        props.buttonState = safeGet(obj, "GetButtonState")
        props.buttonText = safeGet(obj, "GetText")
        props.enabled = safeGet(obj, "IsEnabled")
        props.normalTexture = safeGet(obj, "GetNormalTexture")
        props.highlightTexture = safeGet(obj, "GetHighlightTexture")
        props.pushedTexture = safeGet(obj, "GetPushedTexture")
        props.disabledTexture = safeGet(obj, "GetDisabledTexture")
    elseif objType == "EditBox" then
        props.text = safeGet(obj, "GetText")
        props.cursorPosition = safeGet(obj, "GetCursorPosition")
        props.numLetters = safeGet(obj, "GetNumLetters")
        props.maxLetters = safeGet(obj, "GetMaxLetters")
        props.inputLanguage = safeGet(obj, "GetInputLanguage")
        props.isMultiLine = safeGet(obj, "IsMultiLine")
        props.isAutoFocus = safeGet(obj, "IsAutoFocus")
        props.isNumeric = safeGet(obj, "IsNumericFullRange")
    elseif objType == "ScrollFrame" then
        props.scrollChild = safeGet(obj, "GetScrollChild")
        props.horizontalScroll = safeGet(obj, "GetHorizontalScroll")
        props.verticalScroll = safeGet(obj, "GetVerticalScroll")
    elseif objType == "Slider" then
        props.minMax = safeGetMulti(obj, "GetMinMaxValues")
        props.value = safeGet(obj, "GetValue")
        props.valueStep = safeGet(obj, "GetValueStep")
        props.obeyStep = safeGet(obj, "GetObeyStepOnDrag")
    elseif objType == "StatusBar" then
        props.minMax = safeGetMulti(obj, "GetMinMaxValues")
        props.value = safeGet(obj, "GetValue")
        props.statusBarColor = safeGetMulti(obj, "GetStatusBarColor")
        props.statusBarTexture = safeGet(obj, "GetStatusBarTexture")
    elseif objType == "Cooldown" then
        props.cooldownTimes = safeGetMulti(obj, "GetCooldownTimes")
        props.cooldownDuration = safeGet(obj, "GetCooldownDuration")
    elseif objType == "ColorSelect" then
        props.colorRGB = safeGetMulti(obj, "GetColorRGB")
        props.colorHSV = safeGetMulti(obj, "GetColorValueHSV")
    elseif objType == "Model" or objType == "PlayerModel" or objType == "DressUpModel" or objType == "CinematicModel" then
        props.facing = safeGet(obj, "GetFacing")
        props.position = safeGetMulti(obj, "GetPosition")
        props.modelScale = safeGet(obj, "GetModelScale")
    end

    local hasAny = false
    for k, v in pairs(props) do
        if k ~= "_type" and v ~= nil then
            hasAny = true
            break
        end
    end
    if not hasAny then return nil end

    return props
end

function ns:GetFrameInfo(frame)
    if not frame then return nil end

    -- Tier 1: Universal properties (all objects)
    local info = {
        name = safeGet(frame, "GetName") or "Anonymous",
        type = safeGet(frame, "GetObjectType") or "Unknown",
        debugName = safeGet(frame, "GetDebugName"),
        parentKey = safeGet(frame, "GetParentKey"),
    }

    local parentRef = frame.GetParent and frame:GetParent()
    info.parent = parentRef
    if parentRef then
        info.parentName = safeGet(parentRef, "GetName") or safeGet(parentRef, "GetDebugName") or "Anonymous"
    end

    info.width = safeGet(frame, "GetWidth")
    info.height = safeGet(frame, "GetHeight")
    info.left = safeGet(frame, "GetLeft")
    info.top = safeGet(frame, "GetTop")
    info.right = safeGet(frame, "GetRight")
    info.bottom = safeGet(frame, "GetBottom")
    info.scale = safeGet(frame, "GetScale")
    info.effectiveScale = safeGet(frame, "GetEffectiveScale")
    info.alpha = safeGet(frame, "GetAlpha")
    info.effectiveAlpha = safeGet(frame, "GetEffectiveAlpha")
    info.shown = frame.IsShown and frame:IsShown() or false
    info.isVisible = frame.IsVisible and frame:IsVisible() or false
    info.ignoreParentAlpha = safeGet(frame, "IsIgnoringParentAlpha")
    info.ignoreParentScale = safeGet(frame, "IsIgnoringParentScale")
    info.objectLoaded = safeGet(frame, "IsObjectLoaded")
    info.sourceLocation = safeGet(frame, "GetSourceLocation")
    info.hasSecretValues = safeGet(frame, "HasSecretValues")
    info.hasAnySecretAspect = safeGet(frame, "HasAnySecretAspect")

    -- Anchors
    if frame.GetNumPoints then
        local ok, numPoints = pcall(frame.GetNumPoints, frame)
        if ok and numPoints then
            info.points = {}
            for i = 1, numPoints do
                local vals = safeGetMulti(frame, "GetPoint", i)
                if vals then
                    local relName = "nil"
                    local relativeTo = vals[2]
                    if relativeTo and type(relativeTo) ~= "string" then
                        relName = safeGet(relativeTo, "GetName") or "Anonymous"
                    elseif type(relativeTo) == "string" then
                        relName = relativeTo
                    end
                    tinsert(info.points, {
                        point = vals[1],
                        relativeTo = relName,
                        relativePoint = vals[3],
                        x = vals[4],
                        y = vals[5],
                    })
                end
            end
        end
    end

    -- Tier 2: Frame-only properties (gate on GetFrameStrata)
    if frame.GetFrameStrata then
        info.strata = safeGet(frame, "GetFrameStrata")
        info.level = safeGet(frame, "GetFrameLevel")
        info.mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() or false
        info.keyboard = frame.IsKeyboardEnabled and frame:IsKeyboardEnabled() or false
        info.protected = frame.IsProtected and frame:IsProtected() or false
        info.forbidden = frame.IsForbidden and frame:IsForbidden() or false
        info.numChildren = safeGet(frame, "GetNumChildren")
        info.numRegions = safeGet(frame, "GetNumRegions")
        info.ID = safeGet(frame, "GetID")
        info.clipsChildren = safeGet(frame, "DoesClipChildren")
        info.ignoreChildrenBounds = safeGet(frame, "IsIgnoringChildrenForBounds")
        info.clampedToScreen = safeGet(frame, "IsClampedToScreen")
        info.clampInsets = safeGetMulti(frame, "GetClampRectInsets")
        info.hitRectInsets = safeGetMulti(frame, "GetHitRectInsets")
        info.movable = safeGet(frame, "IsMovable")
        info.resizable = safeGet(frame, "IsResizable")
        info.resizeBounds = safeGetMulti(frame, "GetResizeBounds")
        info.userPlaced = safeGet(frame, "IsUserPlaced")
        info.dontSavePosition = safeGet(frame, "GetDontSavePosition")
        info.propagateKeyboard = safeGet(frame, "GetPropagateKeyboardInput")
        info.hyperlinksEnabled = safeGet(frame, "GetHyperlinksEnabled")
        info.hyperlinkPropagate = safeGet(frame, "DoesHyperlinkPropagateToParent")
        info.flattensRenderLayers = safeGet(frame, "GetFlattensRenderLayers")
        info.effectivelyFlattens = safeGet(frame, "GetEffectivelyFlattensRenderLayers")
        info.isFrameBuffer = safeGet(frame, "IsFrameBuffer")
        info.hasAlphaGradient = safeGet(frame, "HasAlphaGradient")
        info.gamePadButton = safeGet(frame, "IsGamePadButtonEnabled")
        info.gamePadStick = safeGet(frame, "IsGamePadStickEnabled")
        info.fixedLevel = safeGet(frame, "HasFixedFrameLevel")
        info.fixedStrata = safeGet(frame, "HasFixedFrameStrata")
        info.toplevel = safeGet(frame, "IsToplevel")
        info.usingParentLevel = safeGet(frame, "IsUsingParentLevel")
        info.raisedLevel = safeGet(frame, "GetRaisedFrameLevel")
        info.highestLevel = safeGet(frame, "GetHighestFrameLevel")
        info.canChangeAttribute = safeGet(frame, "CanChangeAttribute")
        info.boundsRect = safeGetMulti(frame, "GetBoundsRect")
    end

    -- Tier 3: Screen position (from GetRect)
    if frame.GetRect then
        local ok, l, b, w, h = pcall(frame.GetRect, frame)
        if ok and l then
            local t = b + h
            local r = l + w
            info.screenPos = {
                left = l, right = r, bottom = b, top = t,
                centerX = l + (w / 2),
                centerY = b + (h / 2),
            }
            if parentRef and parentRef.GetRect then
                local pok, pl, pb, pw, ph = pcall(parentRef.GetRect, parentRef)
                if pok and pl then
                    info.relativeToParent = {
                        fromLeft = l - pl,
                        fromRight = (pl + pw) - r,
                        fromBottom = b - pb,
                        fromTop = (pb + ph) - t,
                        fromCenterX = (l + w / 2) - (pl + pw / 2),
                        fromCenterY = (b + h / 2) - (pb + ph / 2),
                    }
                end
            end
        end
    end

    -- Tier 4: Events and Scripts
    info.registeredEvents = getRegisteredEvents(frame)
    info.scripts = getScriptInfo(frame)

    -- Tier 5: Type-specific
    info.typeSpecific = getTypeSpecificInfo(frame)

    return info
end

function ns:GetParentChain(frame)
    local chain = {}
    local current = frame
    while current do
        tinsert(chain, current)
        if current.GetParent then
            current = current:GetParent()
        else
            break
        end
    end
    return chain
end

function ns:GetChildren(frame)
    if not frame or not frame.GetChildren then
        return {}
    end

    local children = {frame:GetChildren()}
    return children
end

function ns:GetAllChildren(frame)
    if not frame then return {} end

    local all = {}
    local function addChildren(f)
        local children = ns:GetChildren(f)
        for _, child in ipairs(children) do
            tinsert(all, child)
            addChildren(child)
        end
    end
    addChildren(frame)
    return all
end

function ns:SearchFramesByName(searchText)
    if not searchText or searchText == "" then
        return {}
    end

    searchText = string.lower(searchText)
    local results = {}

    local function searchFrame(frame)
        if not frame then return end

        local ok, name = pcall(function() return frame.GetName and frame:GetName() end)
        if ok and name then
            if type(name) ~= "string" then
                local tok, text = pcall(function() return name.GetText and name:GetText() end)
                name = (tok and type(text) == "string") and text or nil
            end
            if name and string.find(string.lower(name), searchText, 1, true) then
                tinsert(results, frame)
            end
        end

        if frame.GetChildren then
            local cok, children = pcall(function() return { frame:GetChildren() } end)
            if cok and children then
                for _, child in ipairs(children) do
                    searchFrame(child)
                end
            end
        end
    end

    searchFrame(UIParent)

    return results
end

function ns:CopyToClipboard(text, title)
    OneWoW.CopyPaste:Copy(title or L["COPY_DEFAULT_TITLE"], text, { readOnly = true })
    self:Print(L["MSG_PRESS_CTRL_C"])
end

function ns:ToggleMainWindow()
    if not self.UI then return end
    if self.UI.mainFrame and self.UI.mainFrame:IsShown() then
        self.UI:Hide()
    else
        self.UI:Show()
        if self.ErrorLogger and self.ErrorLogger.HasCurrentSessionErrors and self.ErrorLogger:HasCurrentSessionErrors() then
            self.UI:SelectTab("errors")
        end
    end
end

function ns:OpenDevToolErrorsTab()
    if not self.UI then return end
    self.UI:Show()
    self.UI:SelectTab("errors")
end

function ns:OnInitialize()
    self:InitializeDatabase()

    local g = self.db.global

    if not g.deferTextureBrowserData and self.DevTool_LoadTextureAssetData then
        self.DevTool_LoadTextureAssetData()
    end
    self.DevTool_LoadTextureAssetData = nil
    if g.deferTextureBrowserData then
        self._DevToolTextureAssetsPurgedSession = true
    end

    if not g.deferSoundBrowserData and self._SoundDataLoaders then
        for _, loader in ipairs(self._SoundDataLoaders) do
            loader()
        end
    end
    self._SoundDataLoaders = nil
    if g.deferSoundBrowserData then
        self._DevToolSoundAssetsPurgedSession = true
    end

    if g.deferTextureBrowserData or g.deferSoundBrowserData then
        collectgarbage("collect")
    end

    if self.MonitorTab and self.MonitorTab.RegisterPinnedRestoreEvents then
        self.MonitorTab:RegisterPinnedRestoreEvents()
    end

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_Utility_DevTool:ApplyTheme()
    OneWoW_Utility_DevTool:ApplyLanguage()
    ns:NormalizeEditorDatabase()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Utility_DevTool, function(myself)
        myself:ApplyTheme()
        ns:RebuildUI()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Utility_DevTool, function(myself)
        myself:ApplyLanguage()
        ns:RebuildUI()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Utility_DevTool, function()
        ns:RebuildUI()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_Utility_DevTool, function()
        ns:RebuildUI()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", OneWoW_Utility_DevTool, function(_, hidden)
        if ns.Minimap then ns.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", OneWoW_Utility_DevTool, function()
        if ns.Minimap then ns.Minimap:UpdateIcon() end
    end)

    if self.ErrorLogger then
        self.ErrorLogger:Initialize()
    end

end

function OneWoW_Utility_DevTool:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
    ns.ErrorFloat:ApplyTheme()
end

function OneWoW_Utility_DevTool:ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or "enUS"
    OneWoW.Locale:SetLanguage(lang)
end

-- Rebuild the window in place (preserving shown state) so a settings change —
-- theme, language, or font — takes effect without forcing another change.
function ns:RebuildUI()
    if self.UI and self.UI.FullReset then
        local wasShown = self.UI.mainFrame and self.UI.mainFrame:IsShown()
        self.UI:FullReset()
        if wasShown then
            C_Timer.After(0.1, function()
                if self.UI and self.UI.Show then self.UI:Show() end
            end)
        end
    end
    if self.ErrorFloat:IsShown() then
        self.ErrorFloat:Refresh(nil, false)
    end
end

function OneWoW_Utility_DevTool:OnAddonLoaded()
    ns:OnInitialize()
    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    OneWoW:RegisterLoadComponent("DevTools", _ver, "/1wdt", ADDON_NAME)
end

local didLogin = false
function OneWoW_Utility_DevTool:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OneWoW:RegisterMinimap("OneWoW_Utility_DevTool", L["CTX_OPEN_DEVTOOLS"], nil, function()
        ns:ToggleMainWindow()
    end)
    if ns.db.global.monitor.showOnLoad then
        C_Timer.After(0.5, function()
            if ns.UI then
                ns.UI:Show()
                ns.UI:SelectTab("monitor")
            end
        end)
    end
    C_Timer.After(1.0, function()
        if ns.MonitorTab then
            ns.MonitorTab:RestorePinnedMonitorsPending()
        end
    end)
    C_Timer.After(3.0, function()
        if ns.MonitorTab then
            ns.MonitorTab:RestorePinnedMonitorsPending()
        end
    end)
    if ns.InstallNotice and not ns.InstallNotice:IsAcknowledged() then
        C_Timer.After(4.0, function()
            if ns.InstallNotice and not ns.InstallNotice:IsAcknowledged() then
                ns.InstallNotice:Show()
            end
        end)
    end
end

function ns:ToggleDevMode()
    local db = ns.db.global.errorDB
    db.devMode = not db.devMode
    ns:Print(db.devMode and L["ERR_DEVMODE_ON"] or L["ERR_DEVMODE_OFF"])
    if db.devMode then
        ns.ErrorFloat:ShowNow()
    else
        ns.ErrorFloat:Hide()
    end
    ns.ErrorFloat:SyncSettingsFromDB()
end

SLASH_ONEWOW_DEVTOOL1 = "/1wdt"
SlashCmdList["ONEWOW_DEVTOOL"] = function(msg)
    msg = (type(msg) == "string") and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

    if msg == "notice" then
        if ns.InstallNotice then
            ns.InstallNotice:ResetAck()
            ns.InstallNotice:Show(true)
        end
        return
    end

    if not ns.UI then
        ns:Print(L["MSG_UI_NOT_LOADED"])
        return
    end

    ns:ToggleMainWindow()
end

SLASH_ONEWOW_DEVMODE1 = "/1wdev"
SlashCmdList["ONEWOW_DEVMODE"] = function()
    ns:ToggleDevMode()
end
