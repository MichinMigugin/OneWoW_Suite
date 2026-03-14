local addonName, ns = ...

local AuctionHouseModule = {
    id          = "auctionhouse",
    title       = "AUCTIONHOUSE_TITLE",
    category    = "ECONOMY",
    description = "AUCTIONHOUSE_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
    _eventFrame = nil,
}
local AH = AuctionHouseModule

function AH:OnEnable()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AuctionHouse")
        self._eventFrame:SetScript("OnEvent", function(frame, event)
            if event == "AUCTION_HOUSE_SHOW" then
                C_Timer.After(0, function()
                    if AuctionHouseFrame and AuctionHouseFrame.SearchBar then
                        local filterBtn = AuctionHouseFrame.SearchBar.FilterButton
                        if filterBtn and filterBtn.filters then
                            filterBtn.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                            AuctionHouseFrame.SearchBar:UpdateClearFiltersButton()
                        end
                    end
                end)
            end
        end)
    end
    self._eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
end

function AH:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
end

function AH:OnToggle(toggleId, value)
end

ns.AuctionHouseModule = AuctionHouseModule
