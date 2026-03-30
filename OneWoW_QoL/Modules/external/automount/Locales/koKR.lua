-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/automount/Locales/koKR.lua
local addonName, ns = ...
if GetLocale() ~= "koKR" then return end

local L_enUS = ns.L_enUS

L_enUS["AUTOMOUNT_TITLE"]               = "자동 탈것"
L_enUS["AUTOMOUNT_DESC"]                = "탈 수 있는 구역에서 이동을 멈추면 사용 가능한 가장 빠른 탈것을 자동으로 소환합니다. 채집 후에도 다시 탑승합니다."
L_enUS["AUTOMOUNT_MOUNT_PREFS"]         = "탈것 설정"
L_enUS["AUTOMOUNT_GROUND_LABEL"]        = "지상 탈것:"
L_enUS["AUTOMOUNT_FLYING_LABEL"]        = "비행 탈것:"
L_enUS["AUTOMOUNT_AQUATIC_LABEL"]       = "수중 탈것:"
L_enUS["AUTOMOUNT_CAT_ON"]              = "켜짐"
L_enUS["AUTOMOUNT_CAT_OFF"]             = "꺼짐"
L_enUS["AUTOMOUNT_RANDOM_FAVORITE"]     = "즐겨찾기 무작위"
L_enUS["AUTOMOUNT_SELECT_TITLE"]        = "%s 탈것 선택"
L_enUS["AUTOMOUNT_SEARCH"]              = "검색..."
L_enUS["AUTOMOUNT_SELECT_TOOLTIP"]      = "클릭하여 탈것 선택"
L_enUS["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "특정 탈것을 고르거나 자동 선택이 가장 빠른 탈것을 고르도록 할 수 있습니다."
L_enUS["AUTOMOUNT_CLOSE"]               = "닫기"
L_enUS["AUTOMOUNT_DRUID_SECTION"]       = "드루이드"
L_enUS["AUTOMOUNT_DRUID_MODE_LABEL"]    = "드루이드 모드:"
L_enUS["AUTOMOUNT_DRUID_MODE_DESC"]     = "켜면 자동 탑승을 하지 않아, 채집 후 여행 형상으로 직접 변신할 수 있습니다."
L_enUS["AUTOMOUNT_STATUS_LABEL"]        = "탈것 상태"
L_enUS["AUTOMOUNT_STATUS_READY"]        = "탈것 가능"
L_enUS["AUTOMOUNT_STATUS_MOUNTED"]      = "탈것 탑승 중"
L_enUS["AUTOMOUNT_STATUS_DISABLED"]     = "자동 탈것 꺼짐"
L_enUS["AUTOMOUNT_TIMING_SECTION"]      = "시간"
L_enUS["AUTOMOUNT_DISMOUNT_DELAY"]      = "탑승 해제 지연"
L_enUS["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "탑승 해제 후 자동 탑승이 다시 시작되기까지의 시간입니다."
L_enUS["AUTOMOUNT_FISHING_DELAY"]       = "낚시 지연"
L_enUS["AUTOMOUNT_FISHING_DELAY_DESC"]  = "낚시 후 자동 탑승이 다시 시작되기까지의 시간입니다."
L_enUS["AUTOMOUNT_GATHER_DELAY"]        = "채집 후 재탑승 지연"
L_enUS["AUTOMOUNT_GATHER_DELAY_DESC"]   = "채집 후 다시 탈것에 올라타기까지의 시간입니다."
L_enUS["AUTOMOUNT_DISABLE"]             = "끄기"
