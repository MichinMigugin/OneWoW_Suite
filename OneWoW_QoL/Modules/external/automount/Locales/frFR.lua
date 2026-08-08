local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOMOUNT_TITLE"] = "Monture auto",
    ["AUTOMOUNT_DESC"] = "Vous fait monter automatiquement sur la monture la plus rapide disponible lorsque vous arrêtez de bouger dans une zone où la monte est autorisée. Remonte après la récolte.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Préférences de monture",
    ["AUTOMOUNT_GROUND_LABEL"] = "Monture terrestre",
    ["AUTOMOUNT_FLYING_LABEL"] = "Monture volante",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Monture aquatique",
    ["AUTOMOUNT_CAT_ON"] = "Activé",
    ["AUTOMOUNT_CAT_OFF"] = "Désactivé",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Favori aléatoire",
    ["AUTOMOUNT_SELECT_TITLE"] = "Choisir une monture %s",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Cliquez pour choisir une monture",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Choisissez une monture spécifique ou laissez la sélection auto prendre la plus rapide disponible.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Druide",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Mode druide",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Lorsque activé, la monte auto est ignorée afin que vous puissiez passer manuellement en Forme de voyage après la récolte.",
    ["AUTOMOUNT_STATUS_LABEL"] = "État de la monture",
    ["AUTOMOUNT_STATUS_READY"] = "Prêt à monter",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Actuellement monté",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Monture auto désactivée",
    ["AUTOMOUNT_TIMING_SECTION"] = "Minutage",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Délai après descente",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Combien de temps après être descendu avant que la monte auto reprenne.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Délai de pêche",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Combien de temps après la pêche avant que la monte auto reprenne.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Délai de remonte après récolte",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "À quelle vitesse remonter après la récolte.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Annuler auto la Forme de voyage",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Annule automatiquement la Forme de voyage lorsque vous entrez dans une zone où le vol est autorisé, vous permettant d'enfourcher une monture volante à la place.",
})
