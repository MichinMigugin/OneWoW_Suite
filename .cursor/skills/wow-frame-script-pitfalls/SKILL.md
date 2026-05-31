---
name: wow-frame-script-pitfalls
description: Use this skill when authoring or reviewing WoW addon code that writes frame scripts, event handlers, or widget callbacks — anything calling SetScript, HookScript, SetBackdrop, ClearAllPoints, SetFontObject, or building popups/dropdowns. Covers closure ordering, stale upvalues, button event ordering, SetScript vs HookScript, backdrop color reset, anchor override, FontString local-override staleness, and the popup-dismiss OnUpdate hybrid pattern.
---

# WoW Frame Script Pitfalls Skill

## Context

Frame scripts and event handlers in WoW look like ordinary Lua callbacks but interact with widget system, input pipeline, and Blizzard's default handlers in ways that produce a specific class of "wasted afternoon" bugs. Pitfalls collected here are not Lua language issues — they're consequences of how WoW's widget API resets state, how input dispatches relative to OnUpdate, and how FontString inheritance shadows local overrides.

Six failure modes:

1. **Closure variable ordering** — captured upvalues nil at runtime.
2. **Stale upvalues** — closures see old values after callbacks update state.
3. **`SetBackdrop` resets colors** — backgrounds appear white after re-skinning.
4. **`SetPoint` without `ClearAllPoints`** — anchor changes silently ignored.
5. **`SetFontObject` doesn't clear local overrides** — properties from previous fonts stick.
6. **Default handlers vs custom state** — radio-style "active" styling overwritten by default OnLeave.

Plus one positive pattern: the **OnUpdate hybrid popup-dismiss** technique.

## Authoritative sources

1. https://warcraft.wiki.gg/wiki/Widget_API — frame method reference.
2. https://warcraft.wiki.gg/wiki/UIHANDLER — script handler list and dispatch order.
3. `wow-api-specialist` — for verifying widget APIs through Cursor's indexed Blizzard docs.

## Patterns

### 1. Closure variable ordering

Variables captured by closures (`OnClick`, `OnEvent`, `OnUpdate`, etc.) must be declared and initialized **before** the handler is defined. Lua closures capture by reference but the upvalue must exist at call time.

```lua
-- BAD: customRefreshCallbacks is nil when OnClick fires
toggleBtn:SetScript("OnClick", function()
    for _, fn in ipairs(customRefreshCallbacks) do fn() end  -- error
end)
local customRefreshCallbacks = {}

-- GOOD: declare and init first
local customRefreshCallbacks = {}
toggleBtn:SetScript("OnClick", function()
    for _, fn in ipairs(customRefreshCallbacks) do fn() end
end)
```

### 2. Stale upvalue sync

When a callback updates state that other closures depend on, reassign the upvalue inside the callback so dependent closures see the new value.

```lua
local isEnabled = false
local function refresh(enabled)
    isEnabled = enabled  -- keep upvalue in sync; closures below read this
    for _, btn in ipairs(toggleBtnSets) do
        btn:EnableMouse(enabled)
    end
end
```

For modular UI refresh across loosely-coupled modules, use a `registerRefresh` callback list:

```lua
local customRefreshCallbacks = {}
local function registerRefresh(fn) tinsert(customRefreshCallbacks, fn) end
-- Pass registerRefresh into module factories; modules register their UpdateRow.
-- Parent's toggle handler iterates customRefreshCallbacks to refresh all rows.
```

### 3. `SetBackdrop` resets colors

`Frame:SetBackdrop(backdrop)` (with `BackdropTemplate`) **resets backdrop colors to defaults** — typically white. Always re-apply colors after every `SetBackdrop` call.

```lua
-- BAD: appears white after SetBackdrop
frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)

-- GOOD: pair SetBackdrop with explicit color calls
frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
```

This applies even when replacing a backdrop set by a factory function (`OneWoW_GUI:CreateFrame`, etc.). `SetBackdrop(nil)` followed by re-setting does not preserve previous colors — `SetBackdropColor` and `SetBackdropBorderColor` must follow.

### 4. `SetPoint` without `ClearAllPoints`

To override a frame's existing anchor, call `ClearAllPoints()` first. Otherwise `SetPoint` adds an additional anchor or conflicts with prior ones, and the new positioning may be silently ignored.

```lua
-- BAD: may not override existing anchor
divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -29)

-- GOOD: clear, then set
divider:ClearAllPoints()
divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -29)
```

The exception: when initially anchoring a brand-new frame that has never had `SetPoint` called, `ClearAllPoints` is unnecessary. Use it whenever you're *changing* anchors, not when *establishing* them for the first time.

### 5. `SetFontObject` does not clear local overrides

`SetFontObject(fontObj)` sets the inheritance source but does **not** clear local property overrides created by explicit setter calls (`SetJustifyH`, `SetTextColor`, `SetFont`, etc.). Once a setter has been called directly on a FontString, that local override persists across all subsequent `SetFontObject` calls, shadowing the font object's inherited value.

```lua
-- BAD: SetJustifyH override persists across font object changes
fs:SetFontObject(RightAlignedFont)
fs:SetJustifyH("RIGHT")             -- creates local override
fs:SetFontObject(CenterAlignedFont)  -- font object says CENTER but...
print(fs:GetJustifyH())              -- "RIGHT" — stale local override
```

`GetJustifyH()` on a FontString returns the local override if one exists, otherwise the inherited value — you cannot tell which source provided the value. `GetJustifyH()` on a **Font object** always returns the correct inherited value.

**Preferred pattern: recreate the FontString** when cycling between fonts (e.g. font preview/browser):

```lua
if tab.previewFS then tab.previewFS:Hide() end
tab.previewFS = parent:CreateFontString(nil, "ARTWORK")
tab.previewFS:SetFontObject(newFontObj)  -- sole authority for all properties
```

If recreating isn't feasible, read values from the Font object and re-apply them every time:

```lua
fs:SetFontObject(fontObj)
fs:SetJustifyH(fontObj:GetJustifyH())  -- read from Font object, not FontString
```

### 6. Button event order and default-handler conflicts

For Button widgets, the dispatch order is:

```
OnMouseDown -> OnMouseUp -> PreClick -> OnClick -> PostClick
```

`OnMouseUp` runs **before** `OnClick`. Code expecting "the click finished" should hook `OnClick` (or `PostClick`), not `OnMouseUp`.

**Radio-style / active-state buttons:** Buttons created via `OneWoW_GUI:CreateButton` (and similar helpers) install default `OnEnter`/`OnLeave` handlers that revert to `BTN_NORMAL` styling when the mouse leaves. If you use `SetScript("OnLeave", ...)` to apply custom "active" styling, the default handler is replaced — but if you use `SetScript` on a button that needs *both* the default revert *and* your active overlay, you'll get one or the other depending on order.

**Fix:** use `HookScript("OnLeave", UpdateStyling)`. The hook runs *after* the default handler, letting your refresh reapply correct active-state styling.

### `SetScript` vs `HookScript`

- `SetScript(handler, fn)` — replaces the handler. Use when the frame has no existing handler or when you intentionally want to replace it.
- `HookScript(handler, fn)` — appends. Original handler runs first, then the hook. Use when layering behavior on top of Blizzard's defaults or another addon's handler.

When in doubt, prefer `HookScript` for handlers on frames you didn't create.

### 7. OnUpdate hybrid popup-dismiss pattern

WoW has no click-through or event-bubbling for sibling frames. Two naïve approaches both fail:

- A fullscreen overlay **above** the host catches clicks, but **consumes** them — forcing a second click to activate the control underneath.
- An overlay **below** the host lets controls receive clicks but never fires for in-host dismiss.

**Solution:** WoW processes input handlers (`OnClick`, `OnMouseDown`) *before* `OnUpdate` scripts in the same frame. Use an `OnUpdate` on the popup that detects `IsMouseButtonDown` transitions while `IsMouseOver()` is false. The clicked control fires first; then OnUpdate hides the popup.

```lua
local wasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
menu:SetScript("OnUpdate", function(self)
    local isDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
    if isDown and not wasDown then
        if not self:IsMouseOver() then
            self:Hide()
        end
    end
    wasDown = isDown
end)
```

Pair with a **game-world overlay** (fullscreen `UIParent` Button at `hostLevel - 2`, same strata) to block 3D viewport interaction while the popup is open. The overlay catches clicks only outside the host window — the host and popup remain interactive.

**Key rules:**

- Initialize `wasDown` from the current button state. A popup opened mid-click would otherwise self-close on the click that opened it.
- `IsMouseOver()` checks the frame's bounding rect; children within those bounds (search box, scroll children, items) are covered automatically.
- Do **not** use a fullscreen overlay above the host for dismiss — it consumes clicks.
- Do **not** sprinkle explicit `Hide()` calls at every navigation boundary (tab switches, list selections). The OnUpdate handles this automatically.

## Review checklist — anti-patterns to flag

1. **Closure references upvalue declared after the handler.** `SetScript("OnClick", function() ... var ... end)` followed by `local var = ...`. Reorder: declare and init the upvalue first.

2. **Callback updates state without syncing closure upvalues.** A handler writes to a local that other closures read, but doesn't reassign so they see the change. Especially common with enable/disable flags and selection state.

3. **`SetBackdrop` without re-applying colors.** Any `SetBackdrop` call not immediately followed by `SetBackdropColor` and `SetBackdropBorderColor` (when colors are intended to be non-default).

4. **`SetPoint` overriding an existing anchor without `ClearAllPoints`.** When code is changing where an existing frame is anchored, `ClearAllPoints()` must come first. New frames being anchored for the first time don't need it.

5. **Reusing a FontString across multiple FontObjects.** Code that calls `SetFontObject` more than once on the same FontString (font preview, theme switcher, dynamic font selection). Either recreate the FontString each time or re-apply every property explicitly from the Font object.

6. **Reading FontString properties to make decisions.** `fs:GetJustifyH()`, `fs:GetTextColor()`, etc. used to drive logic — values may be stale local overrides. Read from the Font object instead.

7. **`SetScript("OnLeave", ...)` on a button with custom active state.** Replaces the default handler; your refresh logic for the active state is now the only OnLeave. Use `HookScript` so the default revert runs first, then your hook reapplies active styling.

8. **Logic in `OnMouseUp` that should be in `OnClick`.** OnMouseUp fires before OnClick — code waiting for "the click to finish" runs early.

9. **`SetScript` on a frame that already has a handler you didn't write.** Replaces silently. If the frame is from `OneWoW_GUI:CreateFrame`, a Blizzard template, or another addon's factory, prefer `HookScript`.

10. **Fullscreen click-eating overlay for popup dismiss.** A `UIParent`-parented Button above the host that catches clicks to close the popup. The two-click-to-activate symptom is the giveaway. Replace with the OnUpdate hybrid pattern.

11. **Explicit popup-close calls scattered through navigation handlers.** `popup:Hide()` at every tab switch, every list selection, every menu transition. Indicates the dismiss pattern is missing — let an OnUpdate watcher handle it.

12. **`OnUpdate` watcher without `wasDown` initialization.** Detecting mouse-button-down transitions but starting with `wasDown = false` means a popup opened mid-click immediately fires the dismiss check on the next tick. Initialize `wasDown` from `IsMouseButtonDown` at registration time.

## Related rules

- `.cursor/rules/WoW-Lua-Addon-Development.mdc` — sections 4.6, 4.7, 4.8, 6.6 (numbering current as of recent extractions) live in the big rule today; this skill replaces them on extraction.
