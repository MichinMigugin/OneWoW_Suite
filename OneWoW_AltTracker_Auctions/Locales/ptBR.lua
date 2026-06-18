local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — ptBR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "ptBR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: rastreamento de dados de leilões ativado",
    ["DATA_COLLECTED"] = "Dados de leilões coletados",
    ["DATA_COLLECTION_FAILED"] = "Falha ao coletar dados de leilões",
    ["AUCTION_HOUSE_OPENED"] = "Casa de leilões aberta, coletando dados...",
    ["NO_AUCTIONS"] = "Nenhum leilão ativo",
    ["NO_BIDS"] = "Nenhum lance ativo",
    ["AH_SCAN_COOLDOWN"] = "Escaneamento completo da casa de leilões disponível em %d minutos.",
    ["AH_SCAN_REQUIRED"] = "O addon AltTracker Auctions é necessário para escanear a casa de leilões.",
})
