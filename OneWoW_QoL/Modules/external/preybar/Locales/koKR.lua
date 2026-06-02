-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/preybar/Locales/koKR.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

if GetLocale() ~= "koKR" then return end

ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = ns.Locales["koKR"] or {}
local L = ns.Locales["koKR"]

L["PREYBAR_TITLE"]                   = "사냥감 추적 막대"
L["PREYBAR_DESC"]                    = "현재 지역의 사냥감 추적 진행도(차가움 > 따뜻함 > 뜨거움 > 준비됨)를 보여주는 이동 가능한 막대입니다. 진행 중인 사냥의 우두머리, 난이도, 고유 능력을 함께 표시합니다. 잠금을 해제하면 원하는 위치로 끌어다 놓을 수 있습니다."

L["PREYBAR_TOGGLE_BOSS"]             = "우두머리 이름 표시"
L["PREYBAR_TOGGLE_BOSS_DESC"]        = "막대 위에 진행 중인 사냥감의 이름을 표시합니다."
L["PREYBAR_TOGGLE_DIFFICULTY"]       = "난이도 표시"
L["PREYBAR_TOGGLE_DIFFICULTY_DESC"]  = "사냥 난이도(일반, 어려움, 악몽)를 표시합니다."
L["PREYBAR_TOGGLE_AFFIXES"]          = "고유 능력 표시"
L["PREYBAR_TOGGLE_AFFIXES_DESC"]     = "막대 아래에 진행 중인 사냥의 고유 능력 아이콘을 표시합니다."
L["PREYBAR_TOGGLE_HIDE_BLIZZARD"]    = "블리자드 위젯 숨기기"
L["PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC"] = "이 막대가 활성화된 동안 블리자드 기본 사냥감 진행도 위젯을 숨깁니다."
L["PREYBAR_TOGGLE_LOCK"]             = "위치 고정"
L["PREYBAR_TOGGLE_LOCK_DESC"]        = "막대를 끌 수 없도록 고정합니다. 이 설정을 끄고 설정 패널을 열면 예시 미리보기로 막대 위치를 옮길 수 있습니다."

L["PREYBAR_STATE_COLD"]              = "차가움"
L["PREYBAR_STATE_WARM"]              = "따뜻함"
L["PREYBAR_STATE_HOT"]               = "뜨거움"
L["PREYBAR_STATE_READY"]             = "준비됨"

L["PREYBAR_DIFFICULTY_NORMAL"]       = "일반"
L["PREYBAR_DIFFICULTY_HARD"]         = "어려움"
L["PREYBAR_DIFFICULTY_NIGHTMARE"]    = "악몽"

L["PREYBAR_AFFIX_AMBUSH"]            = "매복"
L["PREYBAR_AFFIX_TORMENT"]           = "고통"
L["PREYBAR_AFFIX_SEEPING_GORE"]      = "스며드는 피"
L["PREYBAR_AFFIX_ECHO"]              = "포식의 메아리"
L["PREYBAR_AFFIX_BLOODY"]            = "피의 명령"

L["PREYBAR_ADVICE_AMBUSHED"]         = "기습당함!"
L["PREYBAR_ADVICE_KILL"]             = "무언가를 처치하세요!"
L["PREYBAR_ADVICE_READY"]            = "사냥감 준비 완료 - 사냥하세요!"

L["PREYBAR_STATE_LABEL"]             = "%s  %d%%"
L["PREYBAR_DEMO_BOSS"]               = "예시 사냥감"
L["PREYBAR_DRAG_HINT"]               = "잠금 해제 후 끌어 이동  -  사냥감 추적 막대"
L["PREYBAR_SETTINGS_HINT"]           = "이 패널이 열려 있는 동안 위치를 잡을 수 있도록 예시 막대가 표시됩니다. 위치 고정을 끄고 끌어다 놓은 뒤 다시 고정하세요. 이 패널 밖에서는 사냥이 진행 중일 때만 막대가 표시됩니다."
