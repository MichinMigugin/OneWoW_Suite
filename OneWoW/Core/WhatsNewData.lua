local _, ns = ...

-- ============================================================================
-- What's New — in-progress release highlight list
-- ============================================================================
-- Concise summary of root CHANGELOG.md for the current cycle (not a full
-- mirror). Up to 7 { titleKey, bodyKey } entries — fewer is fine; do not
-- pad. Reassess when CHANGELOG changes; edit only when the set or wording
-- should change. titleKey/bodyKey resolve through ns.L at show time.
-- Auto-show keys off OneWoW TOC ## Version vs account dismiss
-- (whatsNewDismissedVersion). Policy: OneWoW-Changelog.mdc § What's New /
-- onewow-changelog skill.
-- ============================================================================

ns.WhatsNewData = {
    highlights = {
        { titleKey = "HOME_TAB",                   bodyKey = "WHATS_NEW_H_HOME_BODY" },
        { titleKey = "WHATS_NEW_H_SLASH_TITLE",    bodyKey = "WHATS_NEW_H_SLASH_BODY" },
        { titleKey = "WHATS_NEW_H_JOURNAL_TITLE",  bodyKey = "WHATS_NEW_H_JOURNAL_BODY" },
        { titleKey = "WHATS_NEW_H_VENDORS_TITLE",  bodyKey = "WHATS_NEW_H_VENDORS_BODY" },
        { titleKey = "WIZARD_FEATURE_NOTES",       bodyKey = "WHATS_NEW_H_NOTES_BODY" },
        { titleKey = "WHATS_NEW_H_ALT_TITLE",      bodyKey = "WHATS_NEW_H_ALT_BODY" },
        { titleKey = "MAIL",                       bodyKey = "WHATS_NEW_H_MAIL_BODY" },
    },
}
