local _, ns = ...

ns.Constants = {
    GUI = {
        WINDOW_WIDTH = 720,
        WINDOW_HEIGHT = 620,
    },
    -- Keep this many free bag slots while collecting mail.
    DEFAULT_KEEP_FREE = 1,
    -- Delay between collect steps when C_Mail.IsCommandPending is clear.
    COLLECT_POLL = 0.05,
    COLLECT_SETTLE = 0.15,
    SEND_ATTACH_SLOTS = ATTACHMENTS_MAX_SEND or 12,
    SUBJECT_PREFIX = "OneWoW Mail: ",
    ICON_ATLAS = "Crosshair_mail_64",
    ICON_TEXTURE = "Interface\\Icons\\achievement_guildperk_gmail",
    -- Coin-tinted edit-box borders (Compose money row + gold shipment fields).
    MONEY_COLORS = {
        GOLD = { 1.00, 0.82, 0.10 },
        SILVER = { 0.78, 0.78, 0.82 },
        COPPER = { 0.85, 0.48, 0.22 },
    },
}
