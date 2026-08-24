-- Community / Wowhead door pins. Used only when JournalInstanceEntrance has no
-- row for that instanceID. JournalData prefers DB2 at cache build; do not
-- duplicate an id that already has a Generated InstanceEntrances row.
--
-- When `python bin/journal_db2_tools.py validate` reports overlap, delete that
-- id here. Rows are UiMapID + 0-100 (TomTom /way #map x y), not continent XYZ.
local _, ns = ...

ns.JournalInstanceEntranceFallbacks = {
    -- Midnight
    [1299] = { { uiMapID = 2395, x = 35.63, y = 78.87, faction = -1 } }, -- Windrunner Spire (Eversong Woods)
    [1300] = { { uiMapID = 2424, x = 62.39, y = 14.55, faction = -1 } }, -- Magisters' Terrace (Isle of Quel'Danas)
    [1304] = { { uiMapID = 2393, x = 56.61, y = 61.10, faction = -1 } }, -- Murder Row (Silvermoon City)
    [1305] = { { uiMapID = 2413, x = 73.7, y = 66.5, faction = -1 } }, -- Sporefall (Harandar)
    [1307] = { { uiMapID = 2405, x = 45.5, y = 64.4, faction = -1 } }, -- The Voidspire (Voidstorm)
    [1308] = { { uiMapID = 2424, x = 52.7, y = 84.9, faction = -1 } }, -- March on Quel'Danas (Isle of Quel'Danas)
    [1309] = { { uiMapID = 2413, x = 27.43, y = 77.98, faction = -1 } }, -- The Blinding Vale (Harandar)
    [1311] = { { uiMapID = 2437, x = 29.99, y = 84.45, faction = -1 } }, -- Den of Nalorakk (Zul'Aman)
    [1313] = { { uiMapID = 2405, x = 53.62, y = 35.45, faction = -1 } }, -- Voidscar Arena (Voidstorm)
    [1314] = { { uiMapID = 2413, x = 61.7, y = 62.3, faction = -1 } }, -- The Dreamrift (Harandar)
    [1315] = { { uiMapID = 2437, x = 43.93, y = 39.71, faction = -1 } }, -- Maisara Caverns (Zul'Aman)
    [1316] = { { uiMapID = 2405, x = 64.70, y = 61.77, faction = -1 } }, -- Nexus-Point Xenas (Voidstorm)
    [1317] = { { uiMapID = 2512, x = 59.9, y = 66.3, faction = -1 } }, -- The Tidebound Grotto (The Coiled Isle)
    [1320] = { { uiMapID = 2509, x = 47.24, y = 22.87, faction = -1 } }, -- The Venomous Abyss (Vaults of Atal'Utek)
    [1322] = { { uiMapID = 2509, x = 47.29, y = 68.16, faction = -1 } }, -- Altar of Fangs (Vaults of Atal'Utek)

    -- Classic / Cata / MoP / BfA doors with no JournalInstanceEntrance row
    [324] = { { uiMapID = 388, x = 34.7, y = 81.7, faction = -1 } }, -- Siege of Niuzao Temple (Townlong Steppes)
    [742] = { { uiMapID = 36, x = 23.2, y = 26.3, faction = -1 } }, -- Blackwing Lair (Burning Steppes)
    [1012] = { -- The MOTHERLODE!! (Zuldazar)
        { uiMapID = 862, x = 39.80, y = 71.90, faction = 1 },
        { uiMapID = 862, x = 56.18, y = 59.98, faction = 0 },
    },
    [1178] = { { uiMapID = 1462, x = 73.2, y = 36.4, faction = -1 } }, -- Operation: Mechagon (Mechagon)
    [1301] = { { uiMapID = 32, x = 34.8, y = 83.8, faction = -1 } }, -- Blackrock Depths (Searing Gorge)

    -- The War Within (no JournalInstanceEntrance row on the current build pin)
    [1267] = { { uiMapID = 2215, x = 42.0, y = 50.0, faction = -1 } }, -- Priory of the Sacred Flame (Hallowfall)
    [1302] = { { uiMapID = 2371, x = 42.19, y = 21.73, faction = -1 } }, -- Manaforge Omega (K'aresh; not Dornogal 2339)
    [1303] = { { uiMapID = 2472, x = 43.8, y = 4.5, faction = -1 } }, -- Eco-Dome Al'dani (Tazavesh)
}
