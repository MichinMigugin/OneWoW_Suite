local _, ns = ...

ns.JournalScanner = {}
local JournalScanner = ns.JournalScanner

function JournalScanner:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUi)
        if event == "PLAYER_ENTERING_WORLD" then
            if not isInitialLogin and not isReloadingUi then
                ns:FireScanCallbacks(nil)
            end
        end
    end)
end
