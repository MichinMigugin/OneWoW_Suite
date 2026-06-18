local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["FASTFORWARD_TITLE"] = "快轉",
    ["FASTFORWARD_DESC"] = "自動跳過遊戲內影片和過場動畫。在影片或過場動畫開始時按住任意輔助鍵即可改為觀看。",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "跳過影片",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "在遊戲內影片開始播放時自動停止。",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "跳過過場動畫",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "在遊戲內過場動畫序列開始時自動取消。",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "僅在副本中",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "僅在你身處地城、團隊副本或其他副本中時跳過影片和過場動畫。",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "尊重不可取消項",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "不嘗試跳過遊戲標記為無法取消的過場動畫。",
})
