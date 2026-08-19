local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "auctionhouse",
    title       = "AUCTIONHOUSE_TITLE",
    category    = "ECONOMY",
    description = "AUCTIONHOUSE_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
    _eventFrame = nil,
})
