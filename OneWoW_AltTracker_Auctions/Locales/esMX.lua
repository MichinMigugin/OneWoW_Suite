local ADDON_NAME = ...

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(ADDON_NAME, "esMX", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: seguimiento de datos de subastas activado",
    ["DATA_COLLECTED"] = "Datos de subastas recopilados",
    ["DATA_COLLECTION_FAILED"] = "No se pudieron recopilar los datos de subastas",
    ["AUCTION_HOUSE_OPENED"] = "Casa de subastas abierta, recopilando datos...",
    ["NO_AUCTIONS"] = "No hay subastas activas",
    ["NO_BIDS"] = "No hay pujas activas",
    ["AH_SCAN_COOLDOWN"] = "Escaneo completo de la casa de subastas disponible en %d minutos.",
    ["AH_SCAN_REQUIRED"] = "Se requiere el addon AltTracker Auctions para escanear la casa de subastas.",
})
