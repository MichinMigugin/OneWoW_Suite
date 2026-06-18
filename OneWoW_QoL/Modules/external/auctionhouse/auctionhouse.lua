local _, ns = ...
local AuctionHouseModule = ns.ModuleRegistry:Current()
if not AuctionHouseModule then return end

local AH = AuctionHouseModule

function AH:OnEnable()
    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_AuctionHouse")
        self._eventFrame:SetScript("OnEvent", function(_, event)
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

function AH:OnToggle()
end
