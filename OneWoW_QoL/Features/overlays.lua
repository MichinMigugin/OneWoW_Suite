local OneWoW = OneWoW

-- Settings catalog for the overlays tab. Storage stays in core OneWoW_DB
-- under settings.overlays — only the feature content registers from QoL.
--
-- Overlay System 2.0: only the built-ins live in the catalog. User overlays
-- are dynamic (settings.overlays.userOverlays) and are listed by the
-- Overlays tab UI directly from storage, not from this catalog.
local reg = OneWoW.SettingsFeatureRegistry

reg:Register("overlays", { id = "general",       title = "OVR_GENERAL_TITLE",       description = "OVR_GENERAL_DESC" })
reg:Register("overlays", { id = "itemlevel",     title = "OVR_ITEMLEVEL_TITLE",     description = "OVR_ITEMLEVEL_DESC" })
reg:Register("overlays", { id = "qualityborder", title = "OVR_QUALITYBORDER_TITLE", description = "OVR_QUALITYBORDER_DESC" })
reg:Register("overlays", { id = "upgrade",       title = "OVR_UPGRADE_TITLE",       description = "OVR_UPGRADE_DESC" })
