package main

import (
	"fmt"
	"sort"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

const wow2APIBase = "https://wow2.xyz/api/v1"

func (s *appState) buildCharactersTab() fyne.CanvasObject {

	// ─ Coming soon banner
	banner := s.sectionLabel("Character Viewer — Preview")
	subtitle := canvas.NewText(
		"View your Alt Tracker data and push it to wow2.xyz for detailed character analysis.",
		colTextSecondary,
	)
	subtitle.TextSize = 12

	comingSoon := canvas.NewText(
		"wow2.xyz integration coming soon — website is under development",
		colAccentPrimary,
	)
	comingSoon.TextSize = 12
	comingSoon.TextStyle.Bold = true

	s.charactersVersionLabel = widget.NewLabel("Game version (from bar above): (none)")
	s.charactersVersionLabel.Wrapping = fyne.TextWrapWord

	s.charactersAcctSelect = widget.NewSelect([]string{"(set WoW path above)"}, nil)

	selRow := container.NewVBox(
		s.charactersVersionLabel,
		container.NewHBox(widget.NewLabel("Battle.net account:"), s.charactersAcctSelect),
	)

	// ─ Character list
	charList := widget.NewList(
		func() int { return len(s.charRoster) },
		func() fyne.CanvasObject {
			return container.NewHBox(
				widget.NewLabel("CharName-Realm"),
				layout.NewSpacer(),
				canvas.NewText("Lvl 70  Human Paladin", colTextSecondary),
			)
		},
		func(id widget.ListItemID, obj fyne.CanvasObject) {
			if id >= len(s.charRoster) {
				return
			}
			c := s.charRoster[id]
			box := obj.(*fyne.Container)
			box.Objects[0].(*widget.Label).SetText(c.Name)
			box.Objects[2].(*canvas.Text).Text = c.Summary
			box.Objects[2].Refresh()
		},
	)
	charList.OnSelected = func(id widget.ListItemID) {
		if id >= len(s.charRoster) {
			return
		}
		c := s.charRoster[id]
		s.showCharDetail(c)
	}

	// ─ Load button
	loadBtn := widget.NewButton("Load Characters", func() {
		if s.wow == nil || s.versionSelect == nil {
			dialog.ShowInformation("Local WoW", "Set Local WoW in the bar above first.", s.window)
			return
		}
		ver := s.versionSelect.Selected
		acct := s.charactersAcctSelect.Selected
		if ver == "" || ver == "(none)" || acct == "" || strings.HasPrefix(acct, "(") {
			dialog.ShowInformation("Select account", "Pick a game version in the bar above and a Battle.net account here.", s.window)
			return
		}
		s.loadCharRoster(ver, acct)
		charList.Refresh()
		s.appendLog(fmt.Sprintf("Loaded %d character(s) from %s.", len(s.charRoster), acct))
	})

	// ─ Push to wow2.xyz (placeholder)
	pushBtn := widget.NewButton("  Push to wow2.xyz  ", func() {
		dialog.ShowInformation("Coming Soon",
			"wow2.xyz character upload is under development.\n\n"+
				"Once live, this will push your Alt Tracker data to wow2.xyz "+
				"for detailed character analysis, gear checks, and more.",
			s.window)
	})
	pushBtn.Importance = widget.HighImportance

	actions := container.NewHBox(loadBtn, pushBtn, layout.NewSpacer(), comingSoon)

	// ─ Detail panel (right side)
	s.charDetailBox = container.NewVBox(
		widget.NewLabel("Select a character to view details."),
	)
	detailScroll := container.NewVScroll(s.charDetailBox)

	listScroll := container.NewVScroll(charList)
	listScroll.SetMinSize(fyne.NewSize(160, 140))
	detailScroll.SetMinSize(fyne.NewSize(180, 140))

	split := container.NewHSplit(listScroll, detailScroll)
	split.SetOffset(0.38)

	return container.NewBorder(
		container.NewVBox(
			banner,
			subtitle,
			widget.NewSeparator(),
			selRow,
			actions,
			widget.NewSeparator(),
		),
		nil, nil, nil,
		split,
	)
}

// ── Character roster data ──

type charEntry struct {
	Name    string
	Summary string
	Fields  [][2]string // label → value pairs for the detail panel
}

func (s *appState) loadCharRoster(ver, acct string) {
	s.charRoster = nil

	// Try to parse OneWoW_AltTracker_Character_DB
	svPath := s.wow.SVPath(ver, acct, "OneWoW_AltTracker_Character")
	f, err := ParseLuaFile(svPath)
	if err != nil {
		s.appendLog(fmt.Sprintf("Could not read AltTracker Character data: %v", err))
		return
	}

	// Find the "characters" key in the first root variable
	for _, varName := range f.order {
		root, ok := f.vars[varName].(*OrderedMap)
		if !ok {
			continue
		}
		charsVal, ok := root.Get("characters")
		if !ok {
			continue
		}
		charsMap, ok := charsVal.(*OrderedMap)
		if !ok {
			continue
		}

		for _, me := range charsMap.Entries() {
			charKey := fmt.Sprintf("%v", me.Key)
			charMap, ok := me.Value.(*OrderedMap)
			if !ok {
				continue
			}

			ce := charEntry{
				Name: charKey,
			}

			lvl := luaStr(charMap, "level")
			race := luaStr(charMap, "raceName")
			class := luaStr(charMap, "className")
			ce.Summary = fmt.Sprintf("Lvl %s  %s %s", lvl, race, class)

			ce.Fields = append(ce.Fields, [2]string{"Name", luaStr(charMap, "name")})
			ce.Fields = append(ce.Fields, [2]string{"Level", lvl})
			ce.Fields = append(ce.Fields, [2]string{"Race", race})
			ce.Fields = append(ce.Fields, [2]string{"Class", class})
			ce.Fields = append(ce.Fields, [2]string{"Faction", luaStr(charMap, "faction")})
			ce.Fields = append(ce.Fields, [2]string{"Realm", luaStr(charMap, "realm")})
			ce.Fields = append(ce.Fields, [2]string{"Item Level", luaStr(charMap, "itemLevel")})
			ce.Fields = append(ce.Fields, [2]string{"Title", luaStr(charMap, "title")})
			ce.Fields = append(ce.Fields, [2]string{"Last Login", luaStr(charMap, "lastLogin")})

			if guildVal, gOK := charMap.Get("guild"); gOK {
				if gm, gmOK := guildVal.(*OrderedMap); gmOK {
					ce.Fields = append(ce.Fields, [2]string{"Guild", luaStr(gm, "name")})
				}
			}

			if moneyVal, mOK := charMap.Get("money"); mOK {
				gold := toFloat(moneyVal) / 10000
				ce.Fields = append(ce.Fields, [2]string{"Gold", fmt.Sprintf("%.0fg", gold)})
			}

			if locVal, lOK := charMap.Get("location"); lOK {
				if lm, lmOK := locVal.(*OrderedMap); lmOK {
					zone := luaStr(lm, "zone")
					sub := luaStr(lm, "subzone")
					if sub != "" && sub != zone {
						zone = zone + " — " + sub
					}
					ce.Fields = append(ce.Fields, [2]string{"Location", zone})
				}
			}

			s.charRoster = append(s.charRoster, ce)
		}
		break
	}

	sort.Slice(s.charRoster, func(i, j int) bool {
		return s.charRoster[i].Name < s.charRoster[j].Name
	})
}

func (s *appState) showCharDetail(c charEntry) {
	s.charDetailBox.RemoveAll()

	titleText := canvas.NewText(c.Name, colAccentPrimary)
	titleText.TextSize = 16
	titleText.TextStyle.Bold = true
	s.charDetailBox.Add(titleText)
	s.charDetailBox.Add(widget.NewSeparator())

	for _, f := range c.Fields {
		if f[1] == "" || f[1] == "0" || f[1] == "nil" {
			continue
		}
		label := canvas.NewText(f[0]+":", colTextSecondary)
		label.TextSize = 12
		label.TextStyle.Bold = true
		value := canvas.NewText("  "+f[1], colTextPrimary)
		value.TextSize = 12
		s.charDetailBox.Add(container.NewHBox(label, value))
	}
}

// ── Helpers ──

func luaStr(m *OrderedMap, key string) string {
	v, ok := m.Get(key)
	if !ok {
		return ""
	}
	switch val := v.(type) {
	case string:
		return val
	case int64:
		return fmt.Sprintf("%d", val)
	case float64:
		if val == float64(int64(val)) {
			return fmt.Sprintf("%d", int64(val))
		}
		return fmt.Sprintf("%.1f", val)
	case bool:
		if val {
			return "Yes"
		}
		return "No"
	}
	return fmt.Sprintf("%v", v)
}

func toFloat(v interface{}) float64 {
	switch n := v.(type) {
	case int64:
		return float64(n)
	case float64:
		return n
	}
	return 0
}

