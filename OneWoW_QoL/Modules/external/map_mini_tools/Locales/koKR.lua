local addonName, ns = ...

if GetLocale() ~= "koKR" then return end

local L_enUS = ns.L_enUS

L_enUS["MMSKIN_TITLE"]                                       = "미니맵 도구"
L_enUS["MMSKIN_DESC"]                                        = "미니맵 묶음을 꾸밉니다: 모양, 테두리, 지역 이름, 시계, 클릭 동작, 확대·축소, 표시 요소 등. 테마를 따르며 세부 설정이 가능합니다."

L_enUS["MMSKIN_GROUP_SHAPE"]                                 = "모양·외형"
L_enUS["MMSKIN_GROUP_INFO"]                                  = "정보 오버레이"
L_enUS["MMSKIN_GROUP_ZOOM"]                                  = "확대·스크롤"
L_enUS["MMSKIN_GROUP_CLICKS"]                                = "클릭 동작"
L_enUS["MMSKIN_GROUP_ELEMENTS"]                              = "요소 표시"
L_enUS["MMSKIN_GROUP_EXTRAS"]                                = "기타"
L_enUS["MMSKIN_GROUP_COMPAT"]                                = "호환"

L_enUS["MMSKIN_SQUARE"]                                      = "사각형 미니맵"
L_enUS["MMSKIN_SQUARE_DESC"]                                 = "미니맵을 원형에서 사각형으로 바꿉니다. 끄려면 UI를 다시 불러와야 합니다."
L_enUS["MMSKIN_BORDER"]                                      = "테두리 표시"
L_enUS["MMSKIN_BORDER_DESC"]                                 = "미니맵 주변에 색 테두리를 표시합니다."
L_enUS["MMSKIN_CLASS_BORDER"]                                = "직업 색 테두리"
L_enUS["MMSKIN_CLASS_BORDER_DESC"]                           = "테마 색 대신 직업 색으로 미니맵 테두리를 칠합니다."
L_enUS["MMSKIN_UNLOCK"]                                      = "미니맵 잠금 해제"
L_enUS["MMSKIN_UNLOCK_DESC"]                                 = "미니맵을 기본 위치에서 떼어내 자유롭게 끌어다 놓을 수 있게 합니다."
L_enUS["MMSKIN_LOCK_POS"]                                    = "위치 고정"
L_enUS["MMSKIN_LOCK_POS_DESC"]                               = "현재 위치는 유지하면서 미니맵을 더 이상 끌어다 놓지 못하게 합니다."

L_enUS["MMSKIN_ZONE_TEXT"]                                   = "지역 이름"
L_enUS["MMSKIN_ZONE_TEXT_DESC"]                              = "미니맵 위에 현재 지역 이름을 표시하고 PvP 종류에 따라 색을 입힙니다."
L_enUS["MMSKIN_CLOCK"]                                       = "시계"
L_enUS["MMSKIN_CLOCK_DESC"]                                  = "미니맵 아래에 시계를 표시합니다. 도움말에 서버/지역 시간과 일일·주간 초기화 시간이 나옵니다."

L_enUS["MMSKIN_ZONE_CLOCK_INSIDE"]                           = "지역 이름·시계를 미니맵 안에"
L_enUS["MMSKIN_ZONE_CLOCK_INSIDE_DESC"]                      = "지역 이름과 시계를 미니맵 바깥 위·아래가 아니라 안쪽 가장자리에 붙입니다."

L_enUS["MMSKIN_ZONE_CLOCK_DRAG"]                             = "지역 이름·시계 끌기(Shift)"
L_enUS["MMSKIN_ZONE_CLOCK_DRAG_DESC"]                        = "지역 이름이나 시계를 움직이려면 Shift를 누른 채로 드래그해야 합니다. 위치는 저장됩니다. Shift를 떼면 일반 클릭으로 동작합니다(시계는 여전히 시간 관리 창을 엽니다)."
L_enUS["MMSKIN_WHEEL_ZOOM"]                                  = "마우스 휠 확대/축소"
L_enUS["MMSKIN_WHEEL_ZOOM_DESC"]                             = "마우스 휠로 미니맵을 확대·축소합니다."
L_enUS["MMSKIN_AUTO_ZOOM"]                                   = "자동 축소"
L_enUS["MMSKIN_AUTO_ZOOM_DESC"]                              = "확대한 뒤 일정 시간이 지나면 미니맵이 자동으로 다시 축소됩니다."

L_enUS["MMSKIN_CLICK_ACTIONS"]                               = "클릭 동작"
L_enUS["MMSKIN_CLICK_ACTIONS_DESC"]                          = "미니맵에서 오른쪽·가운데·추가 마우스 단추 클릭 동작을 켭니다."

L_enUS["MMSKIN_MAIL"]                                        = "우편 표시"
L_enUS["MMSKIN_MAIL_DESC"]                                   = "미니맵에 우편 표시를 보여 줍니다."
L_enUS["MMSKIN_CRAFTING"]                                    = "제작 의뢰"
L_enUS["MMSKIN_CRAFTING_DESC"]                               = "미니맵에 제작 의뢰 표시를 보여 줍니다."
L_enUS["MMSKIN_DIFFICULTY"]                                  = "난이도 아이콘"
L_enUS["MMSKIN_DIFFICULTY_DESC"]                             = "미니맵에 인스턴스 난이도 아이콘을 표시합니다."

L_enUS["MMSKIN_TRACKING"]                                    = "추적 필터"
L_enUS["MMSKIN_TRACKING_DESC"]                               = "미니맵 추적 필터(자원·약초·광석 등 드롭다운)를 표시합니다. 끄면 미니맵 옆의 작은 고리/조작 부분이 사라집니다."
L_enUS["MMSKIN_MISSIONS"]                                    = "임무 단추"
L_enUS["MMSKIN_MISSIONS_DESC"]                               = "확장 랜딩/임무 단추를 표시합니다."

L_enUS["MMSKIN_PLUMBER_HIDE_BLIZZARD"]                       = "Plumber 사용 시 중복 블리자드 확장 단추 숨김"
L_enUS["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"]                  = "Plumber가 있으면 블리자드 확장 미니맵 단추를 숨겨 Plumber의 확장 요약만 보이게 합니다. 둘 다 보이게 하려면 끄세요(권장하지 않음)."
L_enUS["MMSKIN_PLUMBER_STATUS_ON"]                           = "Plumber가 로드됨 — 이 옵션이 적용됩니다."
L_enUS["MMSKIN_PLUMBER_STATUS_OFF"]                          = "Plumber가 로드되지 않음 — 접속 전에 켜거나, 설치 후 UI를 다시 불러오세요."

L_enUS["MMSKIN_HIDE_ADDONS"]                                 = "애드온 아이콘 숨김"
L_enUS["MMSKIN_HIDE_ADDONS_DESC"]                            = "미니맵 영역에 마우스를 올리기 전까지 애드온 미니맵 단추를 숨벽니다."
L_enUS["MMSKIN_COMBAT_FADE"]                                 = "전투 페이드"
L_enUS["MMSKIN_COMBAT_FADE_DESC"]                            = "전투 중 미니맵 투명도를 낮충니다."
L_enUS["MMSKIN_PET_HIDE"]                                    = "애완동물 대결 시 숨김"
L_enUS["MMSKIN_PET_HIDE_DESC"]                               = "애완동물 대결 중 미니맵을 숨벽니다."

L_enUS["MMSKIN_SCALE_LABEL"]                                 = "미니맵 묶음 크기"
L_enUS["MMSKIN_SECTION_BORDER"]                              = "테두리 설정"
L_enUS["MMSKIN_BORDER_SIZE"]                                 = "테두리 두께"
L_enUS["MMSKIN_BORDER_RED"]                                  = "빨강"
L_enUS["MMSKIN_BORDER_GREEN"]                                = "초록"
L_enUS["MMSKIN_BORDER_BLUE"]                                 = "파랑"
L_enUS["MMSKIN_USE_THEME_COLOR"]                             = "테마 색 사용"

L_enUS["MMSKIN_AUTO_ZOOM_DELAY"]                             = "자동 축소 지연"
L_enUS["MMSKIN_SHOW_ZOOM_BTNS"]                              = "확대 단추 표시"

L_enUS["MMSKIN_HIDE_WM_BTN"]                                 = "세계 지도 단추 숨김"
L_enUS["MMSKIN_HIDE_WM_BTN_DESC"]                            = "미니맵의 작은 세계 지도 전환 단추를 숨벽니다(단축키로 지도는 여전히 열 수 있습니다)."

L_enUS["MMSKIN_SECTION_COMBAT"]                              = "전투 페이드 설정"
L_enUS["MMSKIN_COMBAT_ALPHA"]                                = "전투 중 불투명도"

L_enUS["MMSKIN_SECTION_CLICKS"]                              = "클릭 단축 설정"
L_enUS["MMSKIN_CLICK_RIGHT"]                                 = "오른쪽 클릭"
L_enUS["MMSKIN_CLICK_MIDDLE"]                                = "가운데 클릭"
L_enUS["MMSKIN_CLICK_BTN4"]                                  = "단추 4"
L_enUS["MMSKIN_CLICK_BTN5"]                                  = "단추 5"
L_enUS["MMSKIN_ACTION_NONE"]                                 = "없음"
L_enUS["MMSKIN_ACTION_CALENDAR"]                             = "달력"
L_enUS["MMSKIN_ACTION_TRACKING"]                             = "추적"
L_enUS["MMSKIN_ACTION_MISSIONS"]                             = "임무"
L_enUS["MMSKIN_ACTION_MAP"]                                  = "지도"

L_enUS["MMSKIN_SHOW_COMPARTMENT"]                            = "애드온 칸"
L_enUS["MMSKIN_CLOCK_TT_TOGGLE"]                             = "클릭: 시간 관리 창 켜기/끄기"
L_enUS["MMSKIN_UNCLAMP"]                                     = "화면 가장자리 제한 해제"

L_enUS["MMSKIN_ZONE_FONT_LABEL"]                             = "글꼴"
L_enUS["MMSKIN_ZONE_FONT_SIZE"]                              = "글꼴 크기"
L_enUS["MMSKIN_CLOCK_FONT_LABEL"]                            = "글꼴"
L_enUS["MMSKIN_CLOCK_FONT_SIZE"]                             = "글꼴 크기"
L_enUS["MMSKIN_FONT_GLOBAL"]                                 = "전역 글꼴"
L_enUS["MMSKIN_FONT_WOW_DEFAULT"]                            = "와우 기본(작음)"

L_enUS["MMSKIN_SECTION_OPACITY"]                             = "크기·투명도"
L_enUS["MMSKIN_OPACITY"]                                     = "미니맵 투명도"

L_enUS["MMSKIN_SECTION_DEBUG"]                               = "개발자 도구"
L_enUS["MMSKIN_DEBUG_SHOW"]                                  = "디버그 아이콘 표시"
L_enUS["MMSKIN_DEBUG_HIDE"]                                  = "디버그 아이콘 숨김"
L_enUS["MMSKIN_DEBUG_DESC"]                                  = "추적 중인 아이콘을 색 라벨과 함께 모두 보이게 합니다. 라벨을 끌면 해당 아이콘의 미니맵 위치가 저장됩니다. 디버그를 끄면 아이콘이 다시 묶음으로 돌아갑니다(미니맵을 떼어 놓은 경우는 예외). 우편함에 우편이 없을 때처럼 아이콘이 바로 나타나지 않을 때 확인하기에 좋습니다."
L_enUS["MMSKIN_DEBUG_TT_DRAG_HINT"]                          = "왼쪽 클릭으로 끌어서 미니맵에 배치합니다."
L_enUS["MMSKIN_DEBUG_TT_POS_FMT"]                            = "저장된 오프셋: %.0f, %.0f"
L_enUS["MMSKIN_RELOAD_PROMPT"]                               = "미니맵 모양을 바꾸려면 UI를 다시 불러와야 합니다.\n지금 다시 불러올까요?"
