local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(M._scope, "ptBR", {

    ["CHARINFO_TITLE"] = "Ficha de info do personagem",
    ["CHARINFO_DESC"] = "Exibe um painel de info limpo ao lado de cada item equipado na sua ficha de personagem, mostrando o nível de item (colorido por qualidade), o status de encantamento, o status de engastes e a porcentagem de durabilidade.",
    ["CHARINFO_ENCHANTED"] = "Encantado",
    ["CHARINFO_MISSING_ENCHANT"] = "Falta encantamento",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "Não precisa de encantamento",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Todos os engastes vazios",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Alguns engastes vazios",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Todos os engastes preenchidos",
    ["CHARINFO_NO_SOCKETS"] = "Sem engastes",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Mostrar durabilidade",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Exibe a porcentagem de durabilidade nos botões de item",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Mostrar ícone de sem engaste",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Mostra um ícone quando os itens não têm engastes",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Rastreamento de espaços de encantamento",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Escolha quais espaços de equipamento rastrear para encantamentos. Espaços desativados não mostrarão ícones de status de encantamento.",
    ["CHARINFO_SLOT_HEAD"] = "Cabeça",
    ["CHARINFO_SLOT_NECK"] = "Pescoço",
    ["CHARINFO_SLOT_SHOULDER"] = "Ombros",
    ["CHARINFO_SLOT_CHEST"] = "Peito",
    ["CHARINFO_SLOT_WAIST"] = "Cintura",
    ["CHARINFO_SLOT_LEGS"] = "Pernas",
    ["CHARINFO_SLOT_FEET"] = "Pés",
    ["CHARINFO_SLOT_WRIST"] = "Pulsos",
    ["CHARINFO_SLOT_HANDS"] = "Mãos",
    ["CHARINFO_SLOT_RING1"] = "Anel 1",
    ["CHARINFO_SLOT_RING2"] = "Anel 2",
    ["CHARINFO_SLOT_BACK"] = "Costas",
    ["CHARINFO_SLOT_MAINHAND"] = "Mão principal",
    ["CHARINFO_SLOT_OFFHAND"] = "Mão secundária",
    ["FEATURES_ON"] = "Ativado",
    ["FEATURES_OFF"] = "Desativado",
})
