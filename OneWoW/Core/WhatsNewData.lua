local _, ns = ...

-- ============================================================================
-- What's New — per-release highlight list
-- ============================================================================
-- Replace highlights each release (titleKey/bodyKey resolve through ns.L
-- at show time). Auto-show keys off OneWoW TOC ## Version vs account
-- dismiss (whatsNewDismissedVersion) — keep this copy current whenever
-- the suite ships a new TOC version players should see.
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
