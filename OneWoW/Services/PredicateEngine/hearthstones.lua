local _, ns = ...

-- Hearthstone item IDs: base + known toy variants. Toys whose name contains
-- "hearthstone" are also matched at runtime in PredicateEngine.
ns.HearthstoneIDs = {
    [6948] = true, [64488] = true, [54452] = true, [93672] = true, [110560] = true,
    [140192] = true, [141605] = true, [162973] = true, [163045] = true, [165669] = true,
    [165670] = true, [165802] = true, [166746] = true, [166747] = true, [168907] = true,
    [172179] = true, [180290] = true, [182773] = true, [183716] = true, [184353] = true,
    [188952] = true, [190196] = true, [193588] = true, [200630] = true, [206195] = true,
    [208704] = true, [209035] = true, [210455] = true, [212337] = true, [228940] = true,
}
