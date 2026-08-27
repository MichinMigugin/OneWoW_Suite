-- Explicit listing overrides for Catalog Journal (rare exceptions).
-- Keys are "expansionID:instanceID" strings matching JournalData cache keys.
local _, ns = ...

ns.JournalListingOverrides = {
    -- Hide an EJ membership card that we deliberately omit.
    forceHide = {
        -- ["1:63"] = true,
    },
    -- Show a card that EJ does not list (use sparingly).
    forceShow = {
        -- ["1:760"] = true, -- example: Classic Onyxia — do NOT enable; EJ is Wrath-only
    },
}
