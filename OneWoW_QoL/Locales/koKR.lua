local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "koKR", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "불러옴.",

    ["TAB_FEATURES"] = "QoL 기능",
    ["TAB_TOGGLES"] = "토글",

    ["FEATURES_LIST_TITLE"] = "기능",
    ["FEATURES_FAVORITE_TT_TITLE"] = "즐겨찾기",
    ["FEATURES_FAVORITE_TT_DESC"] = "이 기능을 상단의 즐겨찾기 구역에 고정합니다. 다시 누르면 즐겨찾기에서 제거됩니다.",
    ["FEATURES_DETAIL_TITLE"] = "세부 정보",
    ["FEATURES_EMPTY"] = "불러온 모듈이 없습니다.",
    ["FEATURES_NO_SELECTION"] = "목록에서 기능을 선택하세요.",
    ["FEATURES_ENABLED"] = "활성화됨",
    ["FEATURES_DISABLED"] = "비활성화됨",
    ["FEATURES_CATEGORY_LABEL"] = "분류:",
    ["FEATURES_VERSION_LABEL"] = "버전:",
    ["FEATURES_AUTHOR_LABEL"] = "제작자:",
    ["FEATURES_CONTACT_LABEL"] = "연락처:",
    ["FEATURES_LINK_LABEL"] = "링크:",
    ["FEATURES_DETAILS_BTN"] = "세부 정보",
    ["FEATURES_DETAILS_TITLE"] = "모듈 세부 정보",
    ["FEATURES_TOGGLES_HEADER"] = "모듈 토글",
    ["FEATURES_ON"] = "켜기",
    ["FEATURES_OFF"] = "끄기",
    ["FEATURES_PREVIEW_LABEL"] = "미리보기:",

    ["CATEGORY_AUTOMATION"] = "자동화",
    ["CATEGORY_INTERFACE"] = "인터페이스",
    ["CATEGORY_SOCIAL"] = "친목",
    ["CATEGORY_COMBAT"] = "전투",
    ["CATEGORY_ECONOMY"] = "경제",
    ["CATEGORY_UTILITY"] = "유틸리티",

    ["TOGGLES_LIST_TITLE"] = "게임 플래그",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "즐겨찾기",
    ["TOGGLES_FAVORITE_TT_DESC"] = "이 토글을 상단의 즐겨찾기 구역에 고정합니다. 다시 누르면 즐겨찾기에서 제거됩니다.",
    ["TOGGLES_DETAIL_TITLE"] = "플래그 세부 정보",
    ["TOGGLES_COMING_SOON"] = "게임 토글 플래그는 향후 업데이트에서 추가됩니다.",
    ["TOGGLES_NO_SELECTION"] = "목록에서 플래그를 선택하세요.",

    ["SETTINGS_THEME_HEADER"] = "색상 테마",
    ["SETTINGS_THEME_DESC"] = "색상 테마를 선택하세요. 변경 사항은 즉시 적용됩니다.",
    ["SETTINGS_LANGUAGE_DESC"] = "선호하는 언어를 선택하세요. 변경 사항은 즉시 적용됩니다.",
    ["SETTINGS_DEVELOPER_HEADER"] = "개발자 정보",
    ["SETTINGS_DEVELOPER_DESC"] = "이 애드온은 외부 모듈을 지원합니다. Modules\\external\\ 에 모듈 폴더를 만들어 QoL 기능을 추가하세요. 전체 문서는 개발자 도움말 버튼을 사용하세요.",
    ["SETTINGS_DEV_HELP_BTN"] = "개발자 도움말",

    ["DEVHELP_TITLE"] = "모듈 개발자 안내서",
    ["DEVHELP_BODY"] = [[드롭인 모듈 시스템

폴더를 만드세요:
  Modules\external\yourmodule\

파일 (module.lua가 가장 먼저 로드됨):
  module.lua      - 메타데이터 + 등록
  yourmodule.lua  - 모듈 로직
  Locales\enUS.lua  (koKR.lua 선택)

module.lua에서 모듈을 정의하세요
(id는 오직 여기에만 존재):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "당신의 이름",
    contact     = "your@email.com",
    link        = "https://yoursite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

yourmodule.lua에서 모듈 + 로케일
뷰를 가져오세요 (로드 시 캡처, 런타임 금지):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

Locales\enUS.lua에서:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

scope는 ADDON_NAME .. "." .. id 입니다. 예:
OneWoW_QoL.yourmodule (자동 도출, 하드코딩된
scope 문자열 없음).

다른 모듈을 id로 참조하세요:
  ns.ModuleRegistry:GetById("othermodule")
ns.<X>Module은 절대 사용하지 마세요.

title, description 그리고 토글의 라벨과
설명 값은 로케일 키입니다. author, contact,
link는 선택 항목입니다. contact와 link는 모듈
세부 정보 대화상자에 복사 가능한 칸으로 표시됩니다.

사용 가능한 분류:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

TOC의 EXTERNAL MODULES 아래에 파일을
추가하세요. 순서: module.lua 먼저, 그다음
Locales, 그다음 코드 파일.

SavedVariables 데이터베이스 공간:
  OneWoW_QoL_DB.modules.yourmodule

완전한 작동 예제는
Modules\external\autodelete\ 를 참고하세요.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "눌러서 열기",
    ["MINIMAP_RIGHT_CLICK"] = "우클릭하여 옵션 보기",
    ["MINIMAP_OPEN"] = "QoL 열기",

    ["LANG_ENGLISH"] = "영어",
    ["LANG_KOREAN"] = "한국어",


    ["SEARCH_HINT"] = "필터...",
    ["TOGGLES_STATUS_ALL"] = "CVar %d개 표시 중",
    ["TOGGLES_STATUS_FILTERED"] = "%d / %d개 표시 중",
    ["FEATURES_STATUS_ENABLED"] = "%d / %d개 활성화됨",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "켜기",
    ["TOGGLES_OFF"] = "끄기",
    ["TOGGLES_VALUE_LABEL"] = "값:",

    ["TOGGLE_CAT_GAMEPLAY"] = "게임 플레이",
    ["TOGGLE_CAT_INTERFACE"] = "인터페이스",
    ["TOGGLE_CAT_NAMEPLATES"] = "이름표",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "전투 문자",
    ["TOGGLE_CAT_CAMERA"] = "카메라",
    ["TOGGLE_CAT_CHAT"] = "대화 및 친목",
    ["TOGGLE_CAT_AUDIO"] = "소리",
    ["TOGGLE_CAT_GRAPHICS"] = "그래픽",
    ["TOGGLE_CAT_NETWORK"] = "네트워크",

    ["TOGGLE_NAME_autoLootDefault"] = "자동 획득",
    ["TOGGLE_NAME_autoSelfCast"] = "자신에게 자동 시전",
    ["TOGGLE_NAME_autoDismount"] = "자동 탈것 내리기",
    ["TOGGLE_NAME_autoDismountFlying"] = "비행 중 자동 내리기",
    ["TOGGLE_NAME_autoStand"] = "자동 일어서기",
    ["TOGGLE_NAME_autoUnshift"] = "자동 변신 해제",
    ["TOGGLE_NAME_assistAttack"] = "지원 공격",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "누를 때 행동 단추 발동",
    ["TOGGLE_NAME_deselectOnClick"] = "클릭 시 대상 해제",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "대상 변경 시 자동 공격 중지",
    ["TOGGLE_NAME_lootUnderMouse"] = "마우스 위치에 전리품 창",
    ["TOGGLE_NAME_lootLeftmostBag"] = "가장 왼쪽 가방에 획득",
    ["TOGGLE_NAME_interactOnLeftClick"] = "좌클릭 상호작용",
    ["TOGGLE_NAME_autointeract"] = "자동 상호작용",
    ["TOGGLE_NAME_autoClearAFK"] = "자동 자리 비움 해제",

    ["TOGGLE_NAME_countdownForCooldowns"] = "재사용 대기시간 카운트다운",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "주문 발동 효과",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "행동 단축바 항상 표시",
    ["TOGGLE_NAME_lockActionBars"] = "행동 단축바 잠금",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "왼쪽 아래 행동 단축바",
    ["TOGGLE_NAME_bottomRightActionBar"] = "오른쪽 아래 행동 단축바",
    ["TOGGLE_NAME_rightActionBar"] = "오른쪽 행동 단축바",
    ["TOGGLE_NAME_rightTwoActionBar"] = "오른쪽 행동 단축바 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "빈 가방 칸 표시",
    ["TOGGLE_NAME_buffDurations"] = "강화 효과 지속시간 표시",
    ["TOGGLE_NAME_showTargetOfTarget"] = "대상의 대상 표시",
    ["TOGGLE_NAME_showTargetCastbar"] = "대상 시전 막대 표시",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "전체 크기 주시 대상 창",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "큰 숫자 서식 지정",
    ["TOGGLE_NAME_alwaysCompareItems"] = "항상 아이템 비교",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "미보유 형상변환 출처",
    ["TOGGLE_NAME_autoQuestWatch"] = "자동 퀘스트 추적",
    ["TOGGLE_NAME_autoQuestProgress"] = "퀘스트 진행 알림창",
    ["TOGGLE_NAME_mapFade"] = "이동 시 지도 흐려짐",
    ["TOGGLE_NAME_rotateMinimap"] = "미니맵 회전",
    ["TOGGLE_NAME_useUiScale"] = "사용자 지정 UI 크기 사용",
    ["TOGGLE_NAME_uiScale"] = "UI 크기",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "적 이름표 표시",
    ["TOGGLE_NAME_nameplateShowFriends"] = "아군 이름표 표시",
    ["TOGGLE_NAME_nameplateShowSelf"] = "개인 이름표 표시",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "개인 이름표 항상 표시",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "전투 중 개인 이름표",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "적 이름표 직업 색상",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "아군 이름표 직업 색상",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "위협 상실 시 깜빡임",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "적 이름표 클릭 통과",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "아군 이름표 클릭 통과",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "이름표 표시 거리",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "이름표 전체 크기",
    ["TOGGLE_NAME_namePlateEnemySize"] = "적 이름표 크기",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "아군 이름표 크기",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "표시되는 전투 문자",
    ["TOGGLE_NAME_enableCombatText"] = "기본 전투 문자",
    ["TOGGLE_NAME_fctCombatState"] = "전투 상태 문자",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "피해 수치",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "치유 수치",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "전투 진입/이탈 문자",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "강화/약화 변화 문자",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "회피/무기 막기/빗나감 문자",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "명예 획득",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "평판 변화",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "기력/마나 획득",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "연계 점수 획득",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "반응형 발동",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "소환수 근접 피해",

    ["TOGGLE_NAME_cameraBobbing"] = "카메라 흔들림",
    ["TOGGLE_NAME_cameraWaterCollision"] = "카메라 수면 충돌",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "비행 각도 예측",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "동적 카메라 기울기",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "최대 카메라 축소 거리",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "카메라 수평 회전 속도",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "카메라 수직 기울기 속도",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "카메라 확대/축소 속도",

    ["TOGGLE_NAME_chatBubbles"] = "말풍선 (/say)",
    ["TOGGLE_NAME_chatBubblesParty"] = "말풍선 (파티)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "대화창 직업별 이름 색상",
    ["TOGGLE_NAME_blockTrades"] = "거래 요청 차단",
    ["TOGGLE_NAME_blockChannelInvites"] = "대화 채널 초대 차단",
    ["TOGGLE_NAME_guildMemberNotify"] = "길드 접속 알림",
    ["TOGGLE_NAME_removeChatDelay"] = "대화 지연 제거",
    ["TOGGLE_NAME_chatMouseScroll"] = "마우스 휠 대화 스크롤",
    ["TOGGLE_NAME_profanityFilter"] = "비속어 필터",
    ["TOGGLE_NAME_chatStyle"] = "대화창 방식",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "모든 소리",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "음악",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "음향 효과",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "대사 / 음성",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "주변 소리",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "소환수 소리",
    ["TOGGLE_NAME_FootstepSounds"] = "발걸음 소리",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "주 음량",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "음악 음량",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "효과음 음량",

    ["TOGGLE_NAME_ffxDeath"] = "사망 화면 효과",
    ["TOGGLE_NAME_ffxGlow"] = "블룸 / 발광 효과",
    ["TOGGLE_NAME_ffxNether"] = "황천 시각 효과",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "내 주문 효과 강조",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "낮은 생명력 깜빡임 비활성화",
    ["TOGGLE_NAME_hdPlayerModels"] = "HD 캐릭터 모델",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "캐릭터 강조 표시",
    ["TOGGLE_NAME_gxVSync"] = "수직 동기화",
    ["TOGGLE_NAME_gxTripleBuffer"] = "삼중 버퍼링",
    ["TOGGLE_NAME_particleDensity"] = "입자 밀도",
    ["TOGGLE_NAME_maxFPS"] = "최대 FPS (전경)",
    ["TOGGLE_NAME_maxFPSBk"] = "최대 FPS (배경)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "최대 프레임 지연",
    ["TOGGLE_NAME_RenderScale"] = "렌더링 배율",
    ["TOGGLE_NAME_graphicsQuality"] = "그래픽 품질 사전 설정",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "안티앨리어싱 방식",
    ["TOGGLE_NAME_colorblindMode"] = "색맹 모드",

    ["TOGGLE_NAME_disableServerNagle"] = "Nagle 알고리즘 비활성화",
    ["TOGGLE_NAME_gxFixLag"] = "입력 지연 해결",
    ["TOGGLE_NAME_reducedLagTolerance"] = "지연 허용치 감소",
    ["TOGGLE_NAME_SpellQueueWindow"] = "주문 대기열 창",

    ["TOGGLE_DESC_autoLootDefault"] = "각 아이템을 클릭하지 않고 모든 전리품을 자동으로 획득합니다.",
    ["TOGGLE_DESC_autoSelfCast"] = "대상을 선택하지 않았을 때 이로운 주문을 자신에게 시전합니다.",
    ["TOGGLE_DESC_autoDismount"] = "채집, NPC 대화, 전투 진입을 시도할 때 자동으로 탈것에서 내립니다.",
    ["TOGGLE_DESC_autoDismountFlying"] = "비행 중에도 자동으로 내립니다. 경고: 떨어집니다!",
    ["TOGGLE_DESC_autoStand"] = "앉은 상태에서 이동하거나 행동을 시도하면 자동으로 일어섭니다.",
    ["TOGGLE_DESC_autoUnshift"] = "변신이 필요한 능력을 사용할 때 자동으로 형태나 변신을 해제합니다.",
    ["TOGGLE_DESC_assistAttack"] = "아군 대상을 지원할 때 그 대상의 목표를 자동으로 공격하기 시작합니다.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "켜기: 키를 누르는 즉시 주문이 시전됩니다. 끄기: 키를 떼야 주문이 시전되어 먼저 사거리를 확인할 수 있습니다.",
    ["TOGGLE_DESC_deselectOnClick"] = "빈 땅을 클릭하면 대상을 해제합니다.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "새 대상으로 전환하면 자동 공격을 중지합니다.",
    ["TOGGLE_DESC_lootUnderMouse"] = "고정된 위치 대신 마우스 커서가 있는 곳에 전리품 창을 엽니다.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "획득한 아이템을 가장 오른쪽 대신 가장 왼쪽 가방에 넣습니다.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "우클릭 대신 좌클릭으로 NPC와 사물에 상호작용합니다.",
    ["TOGGLE_DESC_autointeract"] = "NPC를 우클릭하면 자동으로 대화하거나 전리품을 획득합니다.",
    ["TOGGLE_DESC_autoClearAFK"] = "이동하거나 어떤 행동을 하면 자동으로 자리 비움 상태를 해제합니다.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "재사용 대기 중인 능력 아이콘 중앙에 카운트다운 숫자를 표시합니다.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "즉시 시전 발동 등 발동 효과가 일어날 때 능력에 빛나는 테두리를 표시합니다.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "비어 있어도 행동 단축바를 계속 표시하여 숨겨지지 않게 합니다.",
    ["TOGGLE_DESC_lockActionBars"] = "행동 단축바에서 능력을 실수로 끌어내는 것을 방지합니다.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "기본 단축바 위 왼쪽에 추가 행동 단축바를 표시합니다.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "기본 단축바 위 오른쪽에 추가 행동 단축바를 표시합니다.",
    ["TOGGLE_DESC_rightActionBar"] = "화면 오른쪽에 세로 행동 단축바를 표시합니다.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "화면 오른쪽에 두 번째 세로 행동 단축바를 표시합니다.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "가방 막대에 빈 가방 칸 수를 표시합니다.",
    ["TOGGLE_DESC_buffDurations"] = "강화 효과의 남은 시간을 카운트다운 숫자로 표시합니다.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "대상이 누구를 목표로 삼고 있는지 표시합니다. 방어 전담과 치유 전담에게 유용합니다.",
    ["TOGGLE_DESC_showTargetCastbar"] = "현재 대상의 시전 막대를 표시하여 무엇을 시전하는지 볼 수 있습니다.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "주시 대상에 작은 창 대신 전체 크기의 유닛 창을 사용합니다.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "큰 숫자를 구분 기호와 함께 표시합니다. 예: 1000000 대신 1,000,000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "장비에 마우스를 올리면 자동으로 아이템 비교 툴팁을 표시합니다. Shift 키가 필요 없습니다.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "이 외형을 보유하고 있지만 이 특정 아이템 출처에서는 얻지 않았는지 아이템 툴팁에 표시합니다.",
    ["TOGGLE_DESC_autoQuestWatch"] = "새 퀘스트를 화면 오른쪽의 퀘스트 추적기에 자동으로 추가합니다.",
    ["TOGGLE_DESC_autoQuestProgress"] = "퀘스트 진행 상황이 있을 때 알림창을 표시합니다.",
    ["TOGGLE_DESC_mapFade"] = "이동할 때 지도를 반투명하게 만들어 게임 세계를 계속 볼 수 있게 합니다.",
    ["TOGGLE_DESC_rotateMinimap"] = "미니맵이 북쪽 고정 대신 나침반처럼 방향에 따라 회전합니다.",
    ["TOGGLE_DESC_useUiScale"] = "UI 크기를 사용자 지정할 수 있게 합니다. UI 크기 슬라이더를 사용하려면 이 항목을 켜세요.",
    ["TOGGLE_DESC_uiScale"] = "사용자 인터페이스의 전체 크기입니다. 사용자 지정 UI 크기가 켜져 있어야 합니다.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "적 유닛 위에 생명력 막대 이름표를 표시합니다.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "아군 유닛 위에 생명력 막대 이름표를 표시합니다.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "캐릭터 위에 개인 자원 막대를 이름표로 표시합니다.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "전투 중이 아니어도 개인 자원 막대 이름표를 항상 표시합니다.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "전투 중에만 개인 자원 막대 이름표를 표시합니다.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "PvP에서 적 이름표를 직업별로 색칠합니다.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "아군 이름표를 직업별로 색칠합니다.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "방어 전담으로서 적에 대한 위협을 잃으면 이름표를 깜빡입니다.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "적 이름표를 클릭 통과합니다. 생명력 막대는 보이지만 클릭하여 대상으로 지정할 수 없습니다.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "아군 이름표를 클릭 통과합니다. 생명력 막대는 보이지만 클릭하여 아군을 대상으로 지정할 수 없습니다.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "이름표가 보이는 최대 거리(미터)입니다. 인스턴스에서는 최대 60입니다.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "모든 이름표의 주 크기 배율입니다. 다른 크기 설정 이후에 적용됩니다.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "적 이름표의 크기 배율입니다. 클수록 전투 중에 더 잘 보입니다.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "아군 플레이어 이름표의 크기 배율입니다.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "적과 아군에게서 떠오르는 표시되는 피해 및 치유 수치를 보여줍니다.",
    ["TOGGLE_DESC_enableCombatText"] = "캐릭터 근처의 기본 전투 문자 영역에 피해 및 치유 수치를 표시합니다.",
    ["TOGGLE_DESC_fctCombatState"] = "기본 전투 문자 시스템을 사용하여 '전투 중입니다!' 같은 표시되는 문자 알림을 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "당신이 입히는 피해를 표시되는 수치로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "당신이 받는 치유를 표시되는 녹색 수치로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "전투 진입과 이탈을 표시되는 문자 메시지로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "강화 및 약화 효과를 얻거나 잃을 때 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "회피, 무기 막기, 빗나감 결과를 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "PvP에서 명예 점수 획득을 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "평판의 획득과 손실을 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "기력, 분노, 마나 획득을 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "연계 점수 획득을 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "반응형 능력 발동을 표시되는 문자로 보여줍니다.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "소환수의 근접 피해를 표시되는 수치로 보여줍니다.",

    ["TOGGLE_DESC_cameraBobbing"] = "걷고 달릴 때 카메라가 위아래로 부드럽게 흔들립니다. 더 몰입감 있지만 멀미를 유발할 수 있습니다.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "캐릭터가 수면 위에 있을 때 카메라가 물속으로 들어가지 않게 합니다.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "비행 탈것이 향하는 방향을 보여주도록 기울어져 더 사실적인 느낌을 줍니다.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "카메라가 이동 방향에 따라 자동으로 기울어집니다. 액션 캠 기능입니다.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "최대 카메라 축소 거리의 배율입니다. 값이 높을수록 더 멀리 축소할 수 있습니다.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "카메라가 좌우로 회전하는 속도입니다.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "카메라가 위아래로 기울어지는 속도입니다.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "스크롤 휠로 카메라를 확대하고 축소하는 속도입니다.",

    ["TOGGLE_DESC_chatBubbles"] = "캐릭터가 /say 또는 /yell을 사용할 때 머리 위에 말풍선을 표시합니다.",
    ["TOGGLE_DESC_chatBubblesParty"] = "파티 및 공격대 대화 메시지의 말풍선을 캐릭터 머리 위에 표시합니다.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "대화창에서 플레이어 이름을 직업별로 색칠합니다.",
    ["TOGGLE_DESC_blockTrades"] = "다른 플레이어가 당신과 거래 창을 여는 것을 방지합니다.",
    ["TOGGLE_DESC_blockChannelInvites"] = "다른 플레이어가 당신을 대화 채널에 초대하는 것을 방지합니다.",
    ["TOGGLE_DESC_guildMemberNotify"] = "길드원이 접속하거나 접속을 종료하면 대화창에 메시지를 표시합니다.",
    ["TOGGLE_DESC_removeChatDelay"] = "대화 메시지 전송 사이의 도배 방지 지연을 제거합니다.",
    ["TOGGLE_DESC_chatMouseScroll"] = "마우스 휠로 대화 기록을 스크롤합니다.",
    ["TOGGLE_DESC_profanityFilter"] = "대화창에서 욕설을 기호로 대체합니다.",
    ["TOGGLE_DESC_chatStyle"] = "고전 방식은 별도의 대화창을 사용합니다. 현대 방식은 탭 형식의 대화창을 사용합니다.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "모든 게임 소리의 주 스위치입니다. 끄면 모든 소리가 음소거됩니다.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "지역과 이벤트 중에 배경 음악을 재생합니다.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "능력, 전투 소리, UI 클릭음 등 음향 효과를 재생합니다.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "NPC 음성 연기와 퀘스트 대사 음성을 재생합니다.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "바람, 새, 물 등 환경 배경 소리를 재생합니다.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "으르렁거림과 움직임 등 소환수의 소리를 재생합니다.",
    ["TOGGLE_DESC_FootstepSounds"] = "걷고 달릴 때 발걸음 소리를 재생합니다.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "게임의 전체 음량입니다. 다른 모든 음량 슬라이더에 영향을 줍니다.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "배경 음악의 음량입니다.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "능력과 전투를 포함한 음향 효과의 음량입니다.",

    ["TOGGLE_DESC_ffxDeath"] = "사망 시 채도가 빠진 흑백 화면 효과를 표시합니다.",
    ["TOGGLE_DESC_ffxGlow"] = "밝은 물체 주변의 부드러운 블룸 발광 효과를 활성화합니다.",
    ["TOGGLE_DESC_ffxNether"] = "황천과 공허 지역에서 특수 시각 효과를 활성화합니다.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "다른 플레이어의 효과에 비해 자신의 주문 효과를 더 잘 보이게 합니다.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "생명력이 위험할 정도로 낮을 때 나타나는 빨간 화면 깜빡임을 비활성화합니다.",
    ["TOGGLE_DESC_hdPlayerModels"] = "고화질 플레이어 캐릭터 모델을 사용합니다. 더 보기 좋지만 메모리를 더 사용합니다.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "캐릭터 아래에 강조 원을 표시하여 무리 속에서 항상 자신을 찾을 수 있게 합니다.",
    ["TOGGLE_DESC_gxVSync"] = "프레임을 모니터의 주사율로 제한합니다. 화면 찢어짐을 방지하지만 약간의 입력 지연이 추가됩니다.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "더 부드러운 프레임 흐름을 위한 삼중 버퍼링입니다. 약간의 입력 지연이 추가됩니다.",
    ["TOGGLE_DESC_particleDensity"] = "한 번에 나타나는 주문 효과와 입자의 양입니다. 값이 낮을수록 붐비는 공격대에서 FPS가 향상됩니다.",
    ["TOGGLE_DESC_maxFPS"] = "게임 창이 활성화되어 있을 때의 최대 초당 프레임입니다. 0으로 설정하면 무제한입니다.",
    ["TOGGLE_DESC_maxFPSBk"] = "게임 창이 배경에 있을 때의 최대 초당 프레임입니다. 값이 낮을수록 다른 창으로 전환 시 전력을 절약합니다.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "렌더링을 위해 미리 대기시키는 최대 프레임 수입니다. 값이 낮을수록 입력 지연이 줄고, 높을수록 출력이 부드러워집니다.",
    ["TOGGLE_DESC_RenderScale"] = "내부 해상도 배율입니다. 1.0 이상은 더 선명한 이미지를 위해 슈퍼샘플링하고, 1.0 미만은 성능을 향상합니다.",
    ["TOGGLE_DESC_graphicsQuality"] = "주 그래픽 품질 사전 설정입니다. 변경하면 다른 모든 그래픽 설정이 자동으로 조정됩니다.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "물체의 들쭉날쭉한 가장자리를 부드럽게 합니다. 높은 모드일수록 품질이 좋지만 GPU 자원을 더 사용합니다.",
    ["TOGGLE_DESC_colorblindMode"] = "색맹 친화적인 색상 조정을 활성화합니다. 당신의 색각 이상 유형에 맞는 모드를 선택하세요.",

    ["TOGGLE_DESC_disableServerNagle"] = "패킷 묶음을 비활성화하여 네트워크 지연을 줄입니다. 대역폭 사용량이 약간 늘 수 있습니다.",
    ["TOGGLE_DESC_gxFixLag"] = "렌더링 대기열을 수정하여 일부 시스템에서 마우스 커서 입력 지연을 줄입니다.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "낮은 지연 연결에 맞게 네트워크 성능을 최적화합니다. 주문 대기열 동작에 영향을 줄 수 있습니다.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "현재 주문이 끝나기 전에 다음 주문을 대기열에 넣을 수 있는 시간(밀리초)입니다. 값이 높을수록 타이밍에 너그럽습니다.",

    ["TOGGLE_OPT_chatStyle_classic"] = "고전",
    ["TOGGLE_OPT_chatStyle_im"] = "현대",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "끄기",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA 낮음",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA 높음",
    ["TOGGLE_OPT_colorblindMode_0"] = "끄기",
    ["TOGGLE_OPT_colorblindMode_1"] = "적색맹",
    ["TOGGLE_OPT_colorblindMode_2"] = "녹색맹",
    ["TOGGLE_OPT_colorblindMode_3"] = "청색맹",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "퀘스트 아이템 1",
    ["BINDING_NAME_QUESTITEM_2"] = "퀘스트 아이템 2",
    ["BINDING_NAME_QUESTITEM_3"] = "퀘스트 아이템 3",
    ["BINDING_NAME_QUESTITEM_4"] = "퀘스트 아이템 4",
    ["BINDING_NAME_BAGITEM_1"] = "가방 아이템 1",
    ["BINDING_NAME_BAGITEM_2"] = "가방 아이템 2",
    ["BINDING_NAME_BAGITEM_3"] = "가방 아이템 3",
    ["BINDING_NAME_BAGITEM_4"] = "가방 아이템 4",
    ["BINDING_NAME_COPY_TEXT"] = "텍스트 복사",
})
