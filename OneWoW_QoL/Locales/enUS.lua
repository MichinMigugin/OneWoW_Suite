local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "loaded.",

    ["TAB_FEATURES"] = "QoL Features",
    ["TAB_TOGGLES"] = "Toggles",

    ["FEATURES_LIST_TITLE"] = "Features",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Favorite",
    ["FEATURES_FAVORITE_TT_DESC"] = "Pin this feature to the Favorites section at the top. Click again to remove it from Favorites.",
    ["FEATURES_DETAIL_TITLE"] = "Details",
    ["FEATURES_EMPTY"] = "No modules loaded.",
    ["FEATURES_NO_SELECTION"] = "Select a feature from the list.",
    ["FEATURES_ENABLED"] = "Enabled",
    ["FEATURES_DISABLED"] = "Disabled",
    ["FEATURES_CATEGORY_LABEL"] = "Category:",
    ["FEATURES_VERSION_LABEL"] = "Version:",
    ["FEATURES_AUTHOR_LABEL"] = "Author:",
    ["FEATURES_CONTACT_LABEL"] = "Contact:",
    ["FEATURES_LINK_LABEL"] = "Link:",
    ["FEATURES_DETAILS_BTN"] = "Details",
    ["FEATURES_DETAILS_TITLE"] = "Module Details",
    ["FEATURES_TOGGLES_HEADER"] = "Module Toggles",
    ["FEATURES_ON"] = "On",
    ["FEATURES_OFF"] = "Off",
    ["FEATURES_PREVIEW_LABEL"] = "Preview:",

    ["CATEGORY_AUTOMATION"] = "Automation",
    ["CATEGORY_INTERFACE"] = "Interface",
    ["CATEGORY_SOCIAL"] = "Social",
    ["CATEGORY_COMBAT"] = "Combat",
    ["CATEGORY_ECONOMY"] = "Economy",
    ["CATEGORY_UTILITY"] = "Utility",

    ["TOGGLES_LIST_TITLE"] = "Game Flags",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Favorite",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Pin this toggle to the Favorites section at the top. Click again to remove it from Favorites.",
    ["TOGGLES_DETAIL_TITLE"] = "Flag Details",
    ["TOGGLES_COMING_SOON"] = "Game toggle flags will be added in a future update.",
    ["TOGGLES_NO_SELECTION"] = "Select a flag from the list.",

    ["SETTINGS_THEME_HEADER"] = "Color Theme",
    ["SETTINGS_THEME_DESC"] = "Choose a color theme. Changes apply instantly.",
    ["SETTINGS_LANGUAGE_DESC"] = "Choose your preferred language. Changes apply instantly.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Developer Information",
    ["SETTINGS_DEVELOPER_DESC"] = "This addon supports external modules. Add QoL features by creating a module folder in Modules\\external\\. Use the Developer Help button for complete documentation.",
    ["SETTINGS_DEV_HELP_BTN"] = "Developer Help",

    ["DEVHELP_TITLE"] = "Module Developer Guide",
    ["DEVHELP_BODY"] = [[DROP-IN MODULE SYSTEM

Create your folder:
  Modules\external\yourmodule\

Files (module.lua loads FIRST):
  module.lua      - Metadata + registration
  yourmodule.lua  - Module logic
  Locales\enUS.lua  (koKR.lua optional)

In module.lua define your module
(the id lives ONLY here):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Your Name",
    contact     = "your@email.com",
    link        = "https://yoursite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

In yourmodule.lua grab it + your locale
view (capture at load, never at runtime):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

In Locales\enUS.lua:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

Scope is ADDON_NAME .. "." .. id, e.g.
OneWoW_QoL.yourmodule (derived, no
hardcoded scope string).

Reference another module by id:
  ns.ModuleRegistry:GetById("othermodule")
Never use ns.<X>Module.

title, description, and toggle label and
description values are locale keys.
author, contact, and link are optional.
contact and link show as copyable boxes
in the module Details dialog.

Available categories:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Add your files to the TOC under EXTERNAL
MODULES. Order: module.lua FIRST, then
Locales, then your code files.

SavedVariables database space:
  OneWoW_QoL_DB.modules.yourmodule

See Modules\external\autodelete\ for a
complete working example.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Click to open",
    ["MINIMAP_RIGHT_CLICK"] = "Right-click for options",
    ["MINIMAP_OPEN"] = "Open QoL",

    ["LANG_ENGLISH"] = "English",
    ["LANG_KOREAN"] = "Korean",


    ["SEARCH_HINT"] = "Filter...",
    ["TOGGLES_STATUS_ALL"] = "Showing %d CVars",
    ["TOGGLES_STATUS_FILTERED"] = "Showing %d of %d",
    ["FEATURES_STATUS_ENABLED"] = "%d of %d enabled",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "On",
    ["TOGGLES_OFF"] = "Off",
    ["TOGGLES_VALUE_LABEL"] = "Value:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Gameplay",
    ["TOGGLE_CAT_INTERFACE"] = "Interface",
    ["TOGGLE_CAT_NAMEPLATES"] = "Nameplates",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Combat Text",
    ["TOGGLE_CAT_CAMERA"] = "Camera",
    ["TOGGLE_CAT_CHAT"] = "Chat & Social",
    ["TOGGLE_CAT_AUDIO"] = "Audio",
    ["TOGGLE_CAT_GRAPHICS"] = "Graphics",
    ["TOGGLE_CAT_NETWORK"] = "Network",

    ["TOGGLE_NAME_autoLootDefault"] = "Auto Loot",
    ["TOGGLE_NAME_autoSelfCast"] = "Auto Self Cast",
    ["TOGGLE_NAME_autoDismount"] = "Auto Dismount",
    ["TOGGLE_NAME_autoDismountFlying"] = "Auto Dismount While Flying",
    ["TOGGLE_NAME_autoStand"] = "Auto Stand Up",
    ["TOGGLE_NAME_autoUnshift"] = "Auto Unshift",
    ["TOGGLE_NAME_assistAttack"] = "Assist Attack",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Action Buttons on Key Down",
    ["TOGGLE_NAME_deselectOnClick"] = "Deselect Target on Click",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Stop Auto Attack on Target Change",
    ["TOGGLE_NAME_lootUnderMouse"] = "Loot Window Under Mouse",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Loot Into Leftmost Bag",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Left-Click Interact",
    ["TOGGLE_NAME_autointeract"] = "Auto Interact",
    ["TOGGLE_NAME_autoClearAFK"] = "Auto Clear AFK",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Cooldown Countdown",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Spell Proc Glow",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Always Show Action Bars",
    ["TOGGLE_NAME_lockActionBars"] = "Lock Action Bars",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Bottom Left Action Bar",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Bottom Right Action Bar",
    ["TOGGLE_NAME_rightActionBar"] = "Right Action Bar",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Right Action Bar 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Show Free Bag Slots",
    ["TOGGLE_NAME_buffDurations"] = "Show Buff Durations",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Show Target of Target",
    ["TOGGLE_NAME_showTargetCastbar"] = "Show Target Castbar",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Full Size Focus Frame",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Format Large Numbers",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Always Compare Items",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Missing Transmog Source",
    ["TOGGLE_NAME_autoQuestWatch"] = "Auto Track Quests",
    ["TOGGLE_NAME_autoQuestProgress"] = "Quest Progress Popups",
    ["TOGGLE_NAME_mapFade"] = "Map Fades While Moving",
    ["TOGGLE_NAME_rotateMinimap"] = "Rotate Minimap",
    ["TOGGLE_NAME_useUiScale"] = "Enable Custom UI Scale",
    ["TOGGLE_NAME_uiScale"] = "UI Scale",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Show Enemy Nameplates",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Show Friendly Nameplates",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Show Personal Nameplate",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Personal Nameplate Always",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Personal Nameplate in Combat",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Class Colors on Enemy Nameplates",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Class Colors on Friendly Nameplates",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Lose Aggro Flash",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Enemy Nameplates Click-Through",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Friendly Nameplates Click-Through",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Nameplate View Distance",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Nameplate Global Scale",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Enemy Nameplate Size",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Friendly Nameplate Size",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Floating Combat Text",
    ["TOGGLE_NAME_enableCombatText"] = "Default Combat Text",
    ["TOGGLE_NAME_fctCombatState"] = "Combat State Text",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Damage Numbers",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Healing Numbers",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Enter/Leave Combat Text",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Buff/Debuff Change Text",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Dodge/Parry/Miss Text",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Honor Gains",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Reputation Changes",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Energy/Mana Gains",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Combo Point Gains",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Reactive Procs",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Pet Melee Damage",

    ["TOGGLE_NAME_cameraBobbing"] = "Camera Bobbing",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Camera Water Collision",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Flight Angle Look-Ahead",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Dynamic Camera Pitch",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Max Camera Zoom Distance",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Camera Horizontal Turn Speed",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Camera Vertical Turn Speed",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Camera Zoom Speed",

    ["TOGGLE_NAME_chatBubbles"] = "Speech Bubbles (/say)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Speech Bubbles (Party)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Class Colors in Chat",
    ["TOGGLE_NAME_blockTrades"] = "Block Trade Requests",
    ["TOGGLE_NAME_blockChannelInvites"] = "Block Channel Invites",
    ["TOGGLE_NAME_guildMemberNotify"] = "Guild Login Notifications",
    ["TOGGLE_NAME_removeChatDelay"] = "Remove Chat Delay",
    ["TOGGLE_NAME_chatMouseScroll"] = "Mouse Wheel Chat Scroll",
    ["TOGGLE_NAME_profanityFilter"] = "Profanity Filter",
    ["TOGGLE_NAME_chatStyle"] = "Chat Style",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "All Sound",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Music",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Sound Effects",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Dialog / Voice",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Ambience",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Pet Sounds",
    ["TOGGLE_NAME_FootstepSounds"] = "Footstep Sounds",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Master Volume",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Music Volume",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Effects Volume",

    ["TOGGLE_NAME_ffxDeath"] = "Death Screen Effect",
    ["TOGGLE_NAME_ffxGlow"] = "Bloom / Glow Effect",
    ["TOGGLE_NAME_ffxNether"] = "Nether Visual Effect",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Emphasize My Spell Effects",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Disable Low Health Flash",
    ["TOGGLE_NAME_hdPlayerModels"] = "HD Player Models",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Character Highlight",
    ["TOGGLE_NAME_gxVSync"] = "VSync",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Triple Buffer",
    ["TOGGLE_NAME_particleDensity"] = "Particle Density",
    ["TOGGLE_NAME_maxFPS"] = "Max FPS (Foreground)",
    ["TOGGLE_NAME_maxFPSBk"] = "Max FPS (Background)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Max Frame Latency",
    ["TOGGLE_NAME_RenderScale"] = "Render Scale",
    ["TOGGLE_NAME_graphicsQuality"] = "Graphics Quality Preset",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Anti-Aliasing Mode",
    ["TOGGLE_NAME_colorblindMode"] = "Colorblind Mode",

    ["TOGGLE_NAME_disableServerNagle"] = "Disable Server Nagle",
    ["TOGGLE_NAME_gxFixLag"] = "Fix Input Lag",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Reduced Lag Tolerance",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Spell Queue Window",

    ["TOGGLE_DESC_autoLootDefault"] = "Automatically pick up all loot without clicking each item.",
    ["TOGGLE_DESC_autoSelfCast"] = "Cast helpful spells on yourself when you have no target selected.",
    ["TOGGLE_DESC_autoDismount"] = "Automatically get off your mount when you try to gather, talk to NPCs, or enter combat.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Automatically dismount even while flying. Warning: You will fall!",
    ["TOGGLE_DESC_autoStand"] = "Automatically stand up when you try to move or take action while sitting.",
    ["TOGGLE_DESC_autoUnshift"] = "Automatically leave forms or shapeshifts when you use an ability that requires it.",
    ["TOGGLE_DESC_assistAttack"] = "When you assist a friendly target, automatically start attacking their target.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "When ON: Spells fire instantly when you press the key. When OFF: Spells fire when you release the key, letting you see ability range first.",
    ["TOGGLE_DESC_deselectOnClick"] = "Clear your target when you click on empty ground.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Stop auto-attacking when you switch to a new target.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Open the loot window wherever your mouse cursor is instead of at a fixed position.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Put looted items in your leftmost bag instead of rightmost.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Left-click NPCs and objects to interact instead of right-click.",
    ["TOGGLE_DESC_autointeract"] = "Right-clicking an NPC automatically talks to them or loots them.",
    ["TOGGLE_DESC_autoClearAFK"] = "Automatically remove your Away status when you move or take any action.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Show countdown numbers in the middle of ability icons when on cooldown.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Show glowing borders on abilities when procs trigger, such as instant cast procs.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Keep action bars visible even when empty, preventing bars from hiding.",
    ["TOGGLE_DESC_lockActionBars"] = "Prevent accidentally dragging abilities off your action bars.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Show the extra action bar above your main bar on the left side.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Show the extra action bar above your main bar on the right side.",
    ["TOGGLE_DESC_rightActionBar"] = "Show the vertical action bar on the right side of the screen.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Show a second vertical action bar on the right side of the screen.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Show the number of empty bag slots on your bag bar.",
    ["TOGGLE_DESC_buffDurations"] = "Show how much time is left on your buffs as countdown numbers.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Show who your target is targeting. Useful for tanks and healers.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Show a cast bar for your current target so you can see what they are casting.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Use a full-size unit frame for your focus target instead of the small frame.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Display large numbers with commas, such as 1,000,000 instead of 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Automatically show item comparison tooltip when hovering over gear. No Shift key needed.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Show in item tooltips whether you own this appearance but not from this specific item source.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Automatically add new quests to your quest tracker on the right side of the screen.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Show popup notifications when you make progress on quests.",
    ["TOGGLE_DESC_mapFade"] = "Make the map fade transparent when you move so you can still see the game world.",
    ["TOGGLE_DESC_rotateMinimap"] = "Minimap rotates as you turn like a compass instead of staying fixed north-up.",
    ["TOGGLE_DESC_useUiScale"] = "Allow the UI scale to be customized. Enable this to use the UI Scale slider.",
    ["TOGGLE_DESC_uiScale"] = "Overall size of the user interface. Requires Use Custom UI Scale to be enabled.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Display health bar nameplates above enemy units.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Display health bar nameplates above friendly units.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Show your personal resource bar as a nameplate above your character.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Always show your personal resource bar nameplate, even out of combat.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Show your personal resource bar nameplate only during combat.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Color enemy nameplates by class in PvP.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Color friendly nameplates by class.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Flash a nameplate when you lose threat on an enemy as the tank.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Click through enemy nameplates. You can see health bars but cannot click to target.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Click through friendly nameplates. You can see health bars but cannot click to target allies.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Maximum distance in yards at which nameplates are visible. Maximum is 60 in instances.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Master size multiplier for all nameplates. Affects everything after other scale settings.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Size multiplier for enemy nameplates. Larger makes them easier to see in combat.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Size multiplier for friendly player nameplates.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Show floating damage and healing numbers that rise from enemies and allies.",
    ["TOGGLE_DESC_enableCombatText"] = "Show damage and healing numbers in the default combat text area near your character.",
    ["TOGGLE_DESC_fctCombatState"] = "Show 'You are now in combat!' floating text notifications using the default combat text system.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Show damage you deal as floating numbers.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Show healing you receive as floating green numbers.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Show entering and leaving combat as floating text messages.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Show when you gain or lose buffs and debuffs as floating text.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Show Dodge, Parry, and Miss results as floating text.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Show honor point gains as floating text in PvP.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Show reputation gains and losses as floating text.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Show energy, rage, and mana gains as floating text.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Show combo point gains as floating text.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Show reactive ability procs in floating text.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Show your pet's melee damage as floating numbers.",

    ["TOGGLE_DESC_cameraBobbing"] = "Camera gently bounces up and down while walking and running. More immersive but may cause motion sickness.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Prevent the camera from going underwater when your character is above the surface.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Your flying mount tilts to show the direction you are heading for a more realistic feel.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "Camera automatically tilts based on your movement direction. This is the Action Cam feature.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Multiplier for the maximum camera zoom distance. Higher values let you zoom out further.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "How fast the camera rotates left and right.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "How fast the camera tilts up and down.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "How fast the camera zooms in and out with the scroll wheel.",

    ["TOGGLE_DESC_chatBubbles"] = "Show speech bubbles above characters' heads when they use /say or /yell.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Show speech bubbles for party and raid chat messages above character heads.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Color player names in chat by their class.",
    ["TOGGLE_DESC_blockTrades"] = "Prevent other players from opening trade windows with you.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Prevent other players from inviting you to chat channels.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Show a message in chat when guild members log in or out.",
    ["TOGGLE_DESC_removeChatDelay"] = "Remove the anti-spam delay between sending chat messages.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Scroll through chat history using the mouse wheel.",
    ["TOGGLE_DESC_profanityFilter"] = "Replace swear words with symbols in chat.",
    ["TOGGLE_DESC_chatStyle"] = "Classic uses separate chat windows. Modern uses a tabbed chat style.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Master switch for all game audio. Turning this off silences everything.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Play background music in zones and during events.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Play sound effects including abilities, combat sounds, and UI clicks.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Play NPC voice acting and quest dialogue audio.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Play environmental background sounds such as wind, birds, and water.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Play sounds from your pet such as growls and movement.",
    ["TOGGLE_DESC_FootstepSounds"] = "Play footstep sounds when walking and running.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Overall game volume. This affects all other volume sliders.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Volume of background music.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Volume of sound effects including abilities and combat.",

    ["TOGGLE_DESC_ffxDeath"] = "Show a greyscale desaturated screen effect when you die.",
    ["TOGGLE_DESC_ffxGlow"] = "Enable the soft bloom glow effect around bright objects.",
    ["TOGGLE_DESC_ffxNether"] = "Enable special visual effects in Nether and void areas.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Make your own spell effects more visible compared to other players' effects.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Disable the red screen flash that appears when your health is critically low.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Use high-definition player character models. Better looking but uses more memory.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Show a highlight circle under your character so you can always find yourself in crowds.",
    ["TOGGLE_DESC_gxVSync"] = "Limit frames to your monitor's refresh rate. Prevents screen tearing but adds a small input delay.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Triple buffering for smoother frame pacing. Adds a slight input delay.",
    ["TOGGLE_DESC_particleDensity"] = "How many spell effects and particles appear at once. Lower values improve FPS in busy raids.",
    ["TOGGLE_DESC_maxFPS"] = "Maximum frames per second when the game window is active. Set to 0 for unlimited.",
    ["TOGGLE_DESC_maxFPSBk"] = "Maximum frames per second when the game window is in the background. Lower values save power when alt-tabbed.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Maximum frames to queue ahead for rendering. Lower values reduce input lag. Higher values produce smoother output.",
    ["TOGGLE_DESC_RenderScale"] = "Internal resolution multiplier. Values above 1.0 super-sample for a sharper image. Values below 1.0 improve performance.",
    ["TOGGLE_DESC_graphicsQuality"] = "Master graphics quality preset. Changing this adjusts all other graphics settings automatically.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Smooth jagged edges on objects. Higher modes produce better quality but use more GPU resources.",
    ["TOGGLE_DESC_colorblindMode"] = "Enable colorblind-friendly color adjustments. Choose a mode that matches your type of color vision deficiency.",

    ["TOGGLE_DESC_disableServerNagle"] = "Reduce network latency by disabling packet batching. May slightly increase bandwidth usage.",
    ["TOGGLE_DESC_gxFixLag"] = "Reduce mouse cursor input lag on some systems by modifying the render queue.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Optimize network performance for lower-latency connections. May affect spell queueing behavior.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "How early in milliseconds you can queue your next spell before the current one finishes. Higher values are more forgiving for timing.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Classic",
    ["TOGGLE_OPT_chatStyle_im"] = "Modern",
    ["TOGGLE_OPT_graphicsQuality_1"] = "1",
    ["TOGGLE_OPT_graphicsQuality_2"] = "2",
    ["TOGGLE_OPT_graphicsQuality_3"] = "3",
    ["TOGGLE_OPT_graphicsQuality_4"] = "4",
    ["TOGGLE_OPT_graphicsQuality_5"] = "5",
    ["TOGGLE_OPT_graphicsQuality_6"] = "6",
    ["TOGGLE_OPT_graphicsQuality_7"] = "7",
    ["TOGGLE_OPT_graphicsQuality_8"] = "8",
    ["TOGGLE_OPT_graphicsQuality_9"] = "9",
    ["TOGGLE_OPT_graphicsQuality_10"] = "10",
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "Off",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA Low",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA High",
    ["TOGGLE_OPT_colorblindMode_0"] = "Off",
    ["TOGGLE_OPT_colorblindMode_1"] = "Protanopia",
    ["TOGGLE_OPT_colorblindMode_2"] = "Deuteranopia",
    ["TOGGLE_OPT_colorblindMode_3"] = "Tritanopia",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Quest Item 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Quest Item 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Quest Item 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Quest Item 4",
    ["BINDING_NAME_BAGITEM_1"] = "Bag Item 1",
    ["BINDING_NAME_BAGITEM_2"] = "Bag Item 2",
    ["BINDING_NAME_BAGITEM_3"] = "Bag Item 3",
    ["BINDING_NAME_BAGITEM_4"] = "Bag Item 4",
    ["BINDING_NAME_COPY_TEXT"] = "Copy Text",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
