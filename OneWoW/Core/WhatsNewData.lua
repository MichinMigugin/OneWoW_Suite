local _, ns = ...

-- ============================================================================
-- What's New — per-release highlight list
-- ============================================================================
-- Replace this table each release:
--   releaseId  must equal OneWoW TOC ## Version for auto-popup to fire
--   highlights  titleKey/bodyKey resolve through ns.L at show time
-- Home "What's New" force-opens even when releaseId mismatches (stale
-- notes still beat an empty dialog). Auto-show refuses a mismatch so a
-- forgotten update never lies about the current build.
-- ============================================================================

ns.WhatsNewData = {
    releaseId = "R6.2607.2702",
    highlights = {
        { titleKey = "WHATS_NEW_H_SLASH_TITLE", bodyKey = "WHATS_NEW_H_SLASH_BODY" },
        { titleKey = "MAIL",                    bodyKey = "WHATS_NEW_H_MAIL_BODY" },
        { titleKey = "WHATS_NEW_H_QOL_TITLE",   bodyKey = "WHATS_NEW_H_QOL_BODY" },
        { titleKey = "WHATS_NEW_H_ALT_TITLE",   bodyKey = "WHATS_NEW_H_ALT_BODY" },
    },
}
