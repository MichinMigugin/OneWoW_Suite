local AddonName, Addon = ...

OneWoW_UtilityDevTool = Addon

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

Addon.version = "R6.2602.1920"
Addon.frames = {}
Addon.selectedFrame = nil
Addon.pickerActive = false

local pcall = pcall
local type = type
local tostring = tostring

local function safeGet(frame, method, ...)
    local fn = frame[method]
    if not fn then return nil, false end
    local ok, result = pcall(fn, frame, ...)
    if not ok then return nil, true end
    if result ~= nil then
        if type(result) == "table" and issecrettable(result) then return nil, true end
        if issecretvalue(result) then return nil, true end
    end
    return result, false
end

local function safeGetMulti(frame, method, ...)
    local fn = frame[method]
    if not fn then return nil end
    local results = { pcall(fn, frame, ...) }
    if not results[1] then return nil end
    for i = 2, #results do
        if issecretvalue(results[i]) then
            results[i] = "[secret]"
        end
    end
    tremove(results, 1)
    return results
end

Addon.safeGet = safeGet
Addon.safeGetMulti = safeGetMulti

function Addon:Print(msg)
    local L = self.L or {}
    print("|cFFFFD100OneWoW|r - " .. L["ADDON_TITLE"] .. ": " .. tostring(msg))
end

local function getRegisteredEvents(frame)
    if not frame.IsEventRegistered then return nil end
    local hasOnEvent = frame.GetScript and pcall(frame.GetScript, frame, "OnEvent")
    if not hasOnEvent then return nil end
    local events = {}
    for _, event in ipairs(Addon.Constants.COMMON_EVENTS) do
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
    for _, scriptName in ipairs(Addon.Constants.COMMON_SCRIPTS) do
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

function Addon:GetFrameInfo(frame)
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

function Addon:GetParentChain(frame)
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

function Addon:GetChildren(frame)
    if not frame or not frame.GetChildren then
        return {}
    end

    local children = {frame:GetChildren()}
    return children
end

function Addon:GetAllChildren(frame)
    if not frame then return {} end

    local all = {}
    local function addChildren(f)
        local children = Addon:GetChildren(f)
        for _, child in ipairs(children) do
            tinsert(all, child)
            addChildren(child)
        end
    end
    addChildren(frame)
    return all
end

function Addon:SearchFramesByName(searchText)
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

function Addon:CopyToClipboard(text)
    local lib = LibStub("LibCopyPaste-1.0")
    -- Omit readOnly: when true, SetReadOnly captures GetText() from a hidden EditBox (which can return ""), then OnTextChanged overwrites with that empty value
    lib:Copy("Copy", text)
    self:Print("Press Ctrl+C to copy, then close the window.")
end

function Addon:ToggleMainWindow()
    if not self.UI then return end
    if self.UI.mainFrame and self.UI.mainFrame:IsShown() then
        self.UI:Hide()
    else
        self.UI:Show()
        local DU = self.Constants and self.Constants.DEVTOOL_UI
        local luaTab = (DU and DU.TAB_INDEX_LUA) or 3
        if self.ErrorLogger and self.ErrorLogger.HasCurrentSessionErrors and self.ErrorLogger:HasCurrentSessionErrors() then
            self.UI:SelectTab(luaTab)
        end
    end
end

function Addon:OnInitialize()
    self:InitializeDatabase()

    OneWoW_GUI:MigrateSettings({
        theme = self.db.theme,
        language = self.db.language,
        minimap = self.db.minimap,
    })

    self:ApplyTheme()
    self:ApplyLanguage()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
        self:ApplyTheme()
        if self.UI and self.UI.FullReset then
            local wasShown = self.UI.mainFrame and self.UI.mainFrame:IsShown()
            self.UI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.UI and self.UI.Show then self.UI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
    end)

    if self.ErrorLogger then
        self.ErrorLogger:Initialize()
    end

end

function Addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function Addon:ApplyLanguage()
    local lang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language or "enUS"
    else
        lang = self.db and self.db.language or "enUS"
    end
    if lang == "esMX" then lang = "esES" end
    local localeData = self.Locales and (self.Locales[lang] or self.Locales["enUS"])
    local fallback = self.Locales and self.Locales["enUS"]
    if localeData and fallback then
        for k, v in pairs(fallback) do
            self.L[k] = localeData[k] or v
        end
    end
end

function Addon:LoadBuiltInAtlases()
    local list = {}
    local count = C_Texture.GetAtlasCount()
    for i = 0, count - 1 do
        local atlasName = C_Texture.GetAtlasByIndex(i)
        if atlasName then
            tinsert(list, atlasName)
        end
    end
    sort(list)
    return list
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        Addon:OnInitialize()
        local _ver = C_AddOns.GetAddOnMetadata(AddonName, "Version") or Addon.version
        if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
            _G.OneWoW:RegisterLoadComponent("DevTools", _ver, "/1wdt")
        else
            Addon._pendingLoadVer = _ver
        end
    elseif event == "PLAYER_LOGIN" then
        if _G.OneWoW == nil then
            Addon.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_UtilityDevTool", {
                label = "DevTool",
                onClick = function()
                    Addon:ToggleMainWindow()
                end,
                onRightClick = function()
                    if Addon.UI then
                        local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI
                        Addon.UI:Show()
                        Addon.UI:SelectTab((DU and DU.TAB_INDEX_SETTINGS) or 8)
                    end
                end,
                onTooltip = function(frame)
                    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                    GameTooltip:AddLine("|cFFFFD100OneWoW|r - Utility: DevTool", 1, 0.82, 0, 1)
                    if Addon.L and Addon.L["MINIMAP_TOOLTIP_HINT"] then
                        GameTooltip:AddLine(Addon.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                    end
                    GameTooltip:Show()
                end,
            })
            if Addon._pendingLoadVer then
                print("|cFF00FF00OneWoW|r: |cFFFFFFFFDev Tools|r |cFF888888\226\128\147 v." .. Addon._pendingLoadVer .. " \226\128\147|r |cFF00FF00Loaded|r - /1wdt")
            end
        end
        if _G.OneWoW then
            _G.OneWoW:RegisterMinimap("OneWoW_UtilityDevTool", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_DEVTOOLS"]) or "Open DevTools", nil, function()
                Addon:ToggleMainWindow()
            end)
        end
        if Addon.db and Addon.db.monitor and Addon.db.monitor.showOnLoad then
            C_Timer.After(0.5, function()
                if Addon.UI then
                    local DU = Addon.Constants and Addon.Constants.DEVTOOL_UI
                    Addon.UI:Show()
                    Addon.UI:SelectTab((DU and DU.TAB_INDEX_MONITOR) or 7)
                end
            end)
        end
        C_Timer.After(1.0, function()
            if Addon.MonitorTab then
                Addon.MonitorTab:RestorePinnedAddon()
            end
        end)
    end
end)

SLASH_ONEWOW_DEVTOOL1 = "/dt"
SLASH_ONEWOW_DEVTOOL2 = "/devtool"
SLASH_ONEWOW_DEVTOOL3 = "/devtools"
SLASH_ONEWOW_DEVTOOL4 = "/1wdt"
SlashCmdList["ONEWOW_DEVTOOL"] = function(msg)
    if not Addon.UI then
        Addon:Print("UI not loaded yet")
        return
    end

    Addon:ToggleMainWindow()
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentClick"] = function(addonName, buttonName)
    Addon:ToggleMainWindow()
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r - Utility: DevTool", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle window", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end
