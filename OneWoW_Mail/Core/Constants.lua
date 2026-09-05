local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH = 720,
        WINDOW_HEIGHT = 668,
        LEFT_PANEL_WIDTH = 220,
        ROW_HEIGHT = 40,
        BUTTON_HEIGHT = 24,
    }),
    -- Keep this many free bag slots while collecting mail.
    DEFAULT_KEEP_FREE = 1,
    -- Blind wait for MAIL_SEND_SUCCESS / MAIL_FAILED (SendResult).
    SEND_ACK_TIMEOUT_DEFAULT = 8,
    SEND_ACK_TIMEOUT_MIN = 5,
    SEND_ACK_TIMEOUT_MAX = 30,
    -- Delay between collect steps when C_Mail.IsCommandPending is clear.
    COLLECT_POLL = 0.05,
    COLLECT_SETTLE = 0.15,
    SEND_ATTACH_SLOTS = ATTACHMENTS_MAX_SEND or 12,
    SUBJECT_PREFIX = "OneWoW Mail: ",
    -- Named key on the shipments array table (`shipments.schema_version`).
    SHIPMENTS_SCHEMA_VERSION = 1,
    -- Coin-tinted edit-box borders (Compose money row + gold shipment fields).
    MONEY_COLORS = {
        GOLD = { 1.00, 0.82, 0.10 },
        SILVER = { 0.78, 0.78, 0.82 },
        COPPER = { 0.85, 0.48, 0.22 },
    },
}
