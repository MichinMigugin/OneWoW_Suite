
local ipairs = ipairs
local CreateFrame = CreateFrame
local tinsert = tinsert

local OneWoW_GUI = OneWoW_GUI

function OneWoW_GUI:EnsureSideBar(hostFrame, globalSidebarName)
    if not hostFrame then return nil end

    local sidebar = _G[globalSidebarName]
    if not sidebar then
        sidebar = CreateFrame("Frame", globalSidebarName, hostFrame, "")
        sidebar:SetWidth(1)
        sidebar:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT")
        sidebar:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMRIGHT")
        sidebar.Tabs = {}
        sidebar.selTab = 0
        _G[globalSidebarName] = sidebar
    end

    if not sidebar.Tabs then sidebar.Tabs = {} end
    if sidebar.selTab == nil then sidebar.selTab = 0 end

    return sidebar
end

function OneWoW_GUI:DeselectOtherSideBarTabs(sidebar, exceptIndex)
    if not sidebar or not sidebar.Tabs then return end
    for i, tab in ipairs(sidebar.Tabs) do
        if i ~= exceptIndex and sidebar.selTab == i then
            if tab.customOnMouseUpHandler then
                tab.customOnMouseUpHandler()
            elseif tab.GetScript and tab:GetScript("OnMouseUp") then
                tab:GetScript("OnMouseUp")(tab)
            end
        end
    end
end

---@param sidebar Frame
---@param opts table icon, tooltip, onToggle(show:boolean), name?
---@return Frame tab, number tabIndex
function OneWoW_GUI:CreateSideBarTab(sidebar, opts)
    local tab = CreateFrame("Frame", opts.name, sidebar, "QuestLogTabButtonTemplate")
    tab.displayMode = QuestLogDisplayMode and QuestLogDisplayMode.Quests or nil
    tab.tooltipText = opts.tooltip

    local existingTab = nil
    for _, t in ipairs(sidebar.Tabs) do
        if t ~= tab then
            existingTab = t
            break
        end
    end

    if existingTab then
        tab:SetPoint("BOTTOMLEFT", existingTab, "TOPLEFT", 0, -4)
    else
        tab:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", -2, -52)
    end

    local tabIndex = #sidebar.Tabs + 1
    tinsert(sidebar.Tabs, tab)

    tab.owChecked = false

    local nativeSetChecked = tab.SetChecked
    function tab:SetChecked(checked)
        self.owChecked = checked and true or false
        nativeSetChecked(self, self.owChecked)
        self.Icon:SetTexture(opts.icon)
        self.Icon:SetSize(24, 24)
    end

    local function applyVisual(checked)
        tab:SetChecked(checked)
    end

    local function onToggleInternal(show)
        if show then
            OneWoW_GUI:DeselectOtherSideBarTabs(sidebar, tabIndex)
            sidebar.selTab = tabIndex
        else
            sidebar.selTab = 0
        end
        if opts.onToggle then
            opts.onToggle(show)
        end
        if opts.repositionOpts then
            OneWoW_GUI:RepositionSideBar(sidebar, opts.repositionOpts)
        end
    end

    local function toggleTab()
        applyVisual(not tab.owChecked)
        onToggleInternal(tab.owChecked)
    end

    applyVisual(false)

    if tab.SetCustomOnMouseUpHandler then
        tab:SetCustomOnMouseUpHandler(toggleTab)
    else
        tab:SetScript("OnMouseUp", toggleTab)
    end

    tab.customOnMouseUpHandler = function()
        if tab.owChecked then
            applyVisual(false)
            onToggleInternal(false)
        end
    end

    tab.owToggle = toggleTab

    return tab, tabIndex
end

---@param sidebar Frame
---@param opts table? hostFrame, dockedPanel, anchoredTab, defaultHost
function OneWoW_GUI:RepositionSideBar(sidebar, opts)
    if not sidebar then return end
    opts = opts or {}

    local hostFrame = opts.hostFrame or opts.defaultHost
    local dockedPanel = opts.dockedPanel
    local anchoredTab = opts.anchoredTab

    if not hostFrame and not dockedPanel then return end

    sidebar:ClearAllPoints()
    if dockedPanel and dockedPanel:IsShown() then
        sidebar:SetPoint("TOPLEFT", dockedPanel, "TOPRIGHT")
        sidebar:SetPoint("BOTTOMLEFT", dockedPanel, "BOTTOMRIGHT")
        sidebar:Show()
        return
    end

    local anchoredToOther = false
    if sidebar.selTab and sidebar.selTab > 0 and sidebar.Tabs then
        for i, tab in ipairs(sidebar.Tabs) do
            if i == sidebar.selTab and tab ~= anchoredTab then
                anchoredToOther = true
                break
            end
        end
    end

    if not anchoredToOther and hostFrame then
        sidebar:SetPoint("TOPLEFT", hostFrame, "TOPRIGHT")
        sidebar:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMRIGHT")
        sidebar:Show()
        if sidebar.Tabs then
            for _, tab in ipairs(sidebar.Tabs) do
                tab:Show()
            end
        end
    end
end
