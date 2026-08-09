local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "deDE", {

    ["CTX_OPEN_DD"] = "Direct Deposit öffnen",
    ["ADDON_TITLE"] = "Direkte Einzahlung",
    ["ADDON_SUBTITLE"] = "Automatische Kriegsmeutenbank Gold-Verwaltung",


    ["TAB_GOLD"] = "Gold",

    ["DIRECT_DEPOSIT_TITLE"] = "Direkte Einzahlung",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Verwalten Sie automatisch Gold zwischen Ihrem Charakter und der Kriegsmeutenbank. Legen Sie einen Zielbetrag fest, den Sie auf Ihrem Charakter behalten möchten, und das System wird überschüssiges Gold einzahlen oder abheben, wenn Sie zu wenig haben. Perfekt für die Verwaltung von Gold über mehrere Charaktere hinweg.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Direkte Einzahlung Aktivieren",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Gold automatisch von Ihrer Kriegsmeutenbank einzahlen oder abheben, um einen Zielbetrag auf Ihrem Charakter zu halten, wenn Sie die Bank öffnen.",

    ["ACCOUNT_SETTINGS"] = "Kontoweite Einstellungen",
    ["ACCOUNT_SETTINGS_DESC"] = "Diese Einstellungen gelten für alle Charaktere in Ihrem Konto.",

    ["CHARACTER_SETTINGS"] = "Charakterspezifische Überschreibung",
    ["CHARACTER_SETTINGS_DESC"] = "Überschreiben Sie kontoweite Einstellungen mit benutzerdefinierten Einstellungen für diesen spezifischen Charakter. Nützlich für Bank-Twinks oder Charaktere mit besonderen Gold-Verwaltungsanforderungen.",

    ["USE_CHAR_SETTINGS"] = "Charakterspezifische Einstellungen Verwenden",
    ["USE_CHAR_SETTINGS_DESC"] = "Aktivieren Sie dies, um unterschiedliche Einstellungen für diesen Charakter anstelle der kontoweiten Einstellungen zu verwenden.",

    ["TARGET_GOLD"] = "Betrag auf dem Charakter Behalten",
    ["TARGET_GOLD_DESC"] = "Geben Sie den Betrag an Gold (in Goldstücken) ein, den Sie auf Ihrem Charakter behalten möchten. Leer lassen, um automatische Goldbewegungen zu deaktivieren, bis ein Wert gesetzt ist. 0 = kein Gold auf dem Charakter.",
    ["GOLD"] = "Gold",

    ["DEPOSIT_ENABLE"] = "Gold in Kriegsmeutenbank Einzahlen",
    ["DEPOSIT_ENABLE_DESC"] = "Wenn Sie mehr als den Zielbetrag haben, zahlen Sie den Überschuss automatisch in Ihre Kriegsmeutenbank ein.",

    ["WITHDRAW_ENABLE"] = "Gold aus Kriegsmeutenbank Abheben",
    ["WITHDRAW_ENABLE_DESC"] = "Wenn Sie weniger als den Zielbetrag haben, heben Sie automatisch aus Ihrer Kriegsmeutenbank ab, um das Ziel zu erreichen.",

    ["ITEM_DEPOSIT"] = "Automatische Gegenstands-Einzahlung",
    ["ITEM_DEPOSIT_ENABLE"] = "Automatische Gegenstands-Einzahlung Aktivieren",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Zahlen Sie beim Öffnen der Bank automatisch bestimmte Gegenstände in Ihre ausgewählte Bank ein.",
    ["ITEM_DEPOSIT_LIST"] = "Liste der Auto-Einzahlungs-Gegenstände",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Geben Sie die Gegenstands-ID ein oder Shift+Klick auf einen Gegenstand zum Hinzufügen:",
    ["ITEM_DEPOSIT_WARBAND"] = "Kriegsmeute",
    ["ITEM_DEPOSIT_PERSONAL"] = "Persönlich",

    ["CLEAR"] = "Löschen",


    ["MINIMAP_TOOLTIP_HINT"] = "Klicken, um Einstellungen umzuschalten",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Jetzt einzahlen",

    ["TAB_KEYBINDS"] = "Tastenbelegung",

    ["KEYBIND_SECTION"] = "Schnellzuweisungs-Tasten",
    ["KEYBIND_DESC"] = "Fahren Sie über einen Gegenstand und drücken Sie eine Taste, um ihn sofort zur Einzahlungsliste hinzuzufügen. Tasten zuweisen unter Spielmenü > Tastaturbelegung > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Anvisierten Gegenstand hinzufügen – Persönliche Bank",
    ["KEYBIND_ADD_WARBAND"] = "Anvisierten Gegenstand hinzufügen – Kriegsmeutenbank",
    ["KEYBIND_ADD_GUILD"] = "Anvisierten Gegenstand hinzufügen – Gildenbank",
    ["KEYBIND_NO_ITEM"] = "Kein Gegenstand gefunden – fahren Sie zuerst über einen Gegenstand.",

    ["WARBOUND_SECTION"] = "Kriegsmeuten-Auto-Einzahlung",
    ["WARBOUND_ENABLE"] = "Alle kriegsmeutengebundenen Gegenstände automatisch einzahlen",
    ["WARBOUND_ENABLE_DESC"] = "Beim Öffnen einer Bank werden automatisch alle kriegsmeutengebundenen (accountgebundenen) Gegenstände aus Ihren Taschen in die Kriegsmeutenbank eingezahlt. Gegenstände, die bereits in Ihrer obigen Einzahlungsliste stehen, werden ausgeschlossen.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Nach Schlüsselwort behalten",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Gegenstände, die diesem Schlüsselwort-Ausdruck entsprechen, werden in Ihren Taschen behalten und niemals automatisch eingezahlt. Verwenden Sie Schlüsselwörter wie #potion, #flask, #elixir, #consumable, getrennt durch | für \"oder\". Beispiel: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "z. B. #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Bestimmte Gegenstände behalten",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "Diese Gegenstände werden immer in Ihren Taschen behalten, auch wenn sie kriegsmeutengebunden sind. Ziehen Sie einen Gegenstand hierher oder geben Sie seine Gegenstands-ID ein.",

    ["TOOLTIP_SECTION"] = "Tooltip-Overlay",
    ["TOOLTIP_ENABLE"] = "Einzahlungsstatus in Tooltips anzeigen",
    ["TOOLTIP_ENABLE_DESC"] = "Für die Einzahlung vorgemerkte Gegenstände zeigen ihre Zielbank am unteren Rand ihres Tooltips an.",
    ["TOOLTIP_LABEL"] = "Direkteinzahlung:",
    ["TOOLTIP_PERSONAL"] = "Persönlich",
    ["TOOLTIP_WARBAND"] = "Kriegsmeute",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Direct-Deposit-Fenster umschalten",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Gegenstände jetzt einzahlen",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Schnell hinzufügen: Persönliche Bank",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Schnell hinzufügen: Kriegsmeutenbank",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Schnell hinzufügen: Gildenbank",
})
