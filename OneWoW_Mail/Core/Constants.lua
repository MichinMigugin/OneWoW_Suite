local _, ns = ...

ns.Constants = {
    GUI = {
        WINDOW_WIDTH = 720,
        WINDOW_HEIGHT = 560,
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
}
