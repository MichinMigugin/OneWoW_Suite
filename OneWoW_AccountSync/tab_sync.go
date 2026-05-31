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

func (s *appState) buildGlobalWoWBar() fyne.CanvasObject {
	s.pathEntry = widget.NewEntry()
	s.pathEntry.SetPlaceHolder("C:\\Program Files\\World of Warcraft")
	s.pathEntry.OnSubmitted = func(_ string) { s.onPathSet() }

	browseBtn := widget.NewButton("Browse", s.onBrowse)

	s.versionSelect = widget.NewSelect([]string{"(none)"}, s.onVersionChange)
	s.versionSelect.SetSelected("(none)")

	row := container.NewBorder(
		nil, nil, widget.NewLabel("Local WoW"), nil,
		container.NewBorder(nil, nil, nil,
			container.NewHBox(browseBtn, widget.NewLabel("Game version"), s.versionSelect),
			s.pathEntry,
		),
	)
	hint := canvas.NewText("Applies to all tabs: sync targets, Utilities, Characters, and local merge target on Remote Source.", colTextSecondary)
	hint.TextSize = 10
	return container.NewVBox(row, hint)
}

func (s *appState) buildSyncTab() fyne.CanvasObject {

	// ─ Accounts panel
	s.acctBox = container.NewVBox()
	acctScroll := container.NewVScroll(s.acctBox)
	acctScroll.SetMinSize(fyne.NewSize(140, 120))

	s.primarySelect = widget.NewSelect([]string{"(none)"}, nil)
	s.primarySelect.SetSelected("(none)")

	acctPanel := container.NewBorder(
		s.sectionLabel("Accounts"),
		container.NewHBox(widget.NewLabel("Primary:"), s.primarySelect),
		nil, nil,
		acctScroll,
	)

	// ─ Addons panel
	s.addonBox = container.NewVBox()
	addonScroll := container.NewVScroll(s.addonBox)
	addonScroll.SetMinSize(fyne.NewSize(160, 120))

	s.filterSelect = widget.NewSelect(
		[]string{"OneWoW Suggested Merges", "All OneWoW Addons", "All Addons (Unsupported)"},
		func(_ string) { s.refreshAddons() },
	)
	s.filterSelect.SetSelected("OneWoW Suggested Merges")

	selectAllBtn := widget.NewButton("Select All", func() { s.setAllAddons(true) })
	clearAllBtn := widget.NewButton("Clear All", func() { s.setAllAddons(false) })

	addonToolbar := container.NewHBox(selectAllBtn, clearAllBtn, layout.NewSpacer(), s.filterSelect)

	addonPanel := container.NewBorder(
		container.NewVBox(
			s.sectionLabel("SavedVariables"),
			addonToolbar,
		),
		nil, nil, nil,
		addonScroll,
	)

	// ─ Two-column
	split := container.NewHSplit(acctPanel, addonPanel)
	split.SetOffset(0.35)

	// ─ Mode
	s.modeRadio = widget.NewRadioGroup(
		[]string{"Smart Merge (recommended)", "Copy (primary overwrites all)"},
		nil,
	)
	s.modeRadio.SetSelected("Smart Merge (recommended)")
	s.modeRadio.Horizontal = false

	modeRow := container.NewHBox(s.boldLabel("Sync Mode:"), s.modeRadio)

	// ─ Actions
	s.syncBtn = widget.NewButton("  Sync Now  ", s.onSync)
	s.syncBtn.Importance = widget.HighImportance

	backupBtn := widget.NewButton("Backup All", s.onBackup)
	restoreBtn := widget.NewButton("Restore…", s.onRestore)

	s.progressBar = widget.NewProgressBar()
	s.progressBar.Hide()

	actions := container.NewHBox(
		s.syncBtn, backupBtn, restoreBtn,
		layout.NewSpacer(), s.progressBar,
	)

	return container.NewBorder(
		nil,
		container.NewVBox(widget.NewSeparator(), modeRow, widget.NewSeparator(), actions),
		nil, nil,
		split,
	)
}

// ── Sync tab event handlers ─────────────────────────────────────

func (s *appState) onBrowse() {
	d := dialog.NewFolderOpen(func(uri fyne.ListableURI, err error) {
		if uri != nil {
			s.pathEntry.SetText(uri.Path())
			s.onPathSet()
		}
	}, s.window)
	d.Show()
}

func (s *appState) onPathSet() {
	path := strings.TrimSpace(s.pathEntry.Text)
	if path == "" || !isDir(path) {
		s.appendLog("Invalid path.")
		s.wow = nil
		s.engine = nil
		s.refreshSecondaryAccountSelects()
		return
	}
	s.wow = &WoWInstallation{BasePath: path}
	s.engine = NewSyncEngine(s.wow)

	versions := s.wow.GameVersions()
	if len(versions) == 0 {
		s.appendLog("No WTF/Account folders found.")
		s.versionSelect.SetOptions([]string{"(none)"})
		s.versionSelect.SetSelected("(none)")
		s.refreshAccounts()
		return
	}
	s.versionSelect.SetOptions(versions)
	cfg := s.engine.LoadConfig()
	found := false
	for _, v := range versions {
		if v == cfg.GameVersion {
			s.versionSelect.SetSelected(v)
			found = true
			break
		}
	}
	if !found {
		s.versionSelect.SetSelected(versions[0])
	}
	s.saveConfig()
	s.refreshAccounts()
}

func (s *appState) onVersionChange(ver string) {
	if s.wow == nil {
		s.refreshSecondaryAccountSelects()
		return
	}
	if ver == "(none)" {
		s.refreshAccounts()
		s.saveConfig()
		return
	}
	s.refreshAccounts()
	s.saveConfig()
}

func (s *appState) refreshAccounts() {
	s.acctBox.RemoveAll()
	s.acctChecks = make(map[string]bool)
	s.acctWidgets = make(map[string]*widget.Check)

	if s.wow == nil {
		s.refreshSecondaryAccountSelects()
		return
	}
	ver := s.versionSelect.Selected
	accounts := s.wow.Accounts(ver)
	if len(accounts) == 0 {
		s.acctBox.Add(widget.NewLabel("No accounts found."))
		s.primarySelect.SetOptions([]string{"(none)"})
		s.primarySelect.SetSelected("(none)")
		s.appendLog(fmt.Sprintf("No accounts found for %s.", ver))
		s.refreshSecondaryAccountSelects()
		return
	}
	for _, acct := range accounts {
		name := acct
		s.acctChecks[name] = true
		chk := widget.NewCheck(name, func(checked bool) { s.acctChecks[name] = checked })
		chk.SetChecked(true)
		s.acctWidgets[name] = chk
		s.acctBox.Add(chk)
	}
	s.primarySelect.SetOptions(accounts)
	s.primarySelect.SetSelected(accounts[0])
	s.appendLog(fmt.Sprintf("Found %d account(s) for %s.", len(accounts), ver))
	s.refreshAddons()
	s.refreshSecondaryAccountSelects()
}

func (s *appState) refreshSecondaryAccountSelects() {
	var accts []string
	ver := ""
	if s.versionSelect != nil {
		ver = s.versionSelect.Selected
	}
	if s.wow != nil && ver != "" && ver != "(none)" {
		accts = s.wow.Accounts(ver)
	}

	placeholder := "(no accounts)"
	opts := accts
	if s.wow == nil || s.pathEntry == nil || strings.TrimSpace(s.pathEntry.Text) == "" {
		placeholder = "(set WoW path above)"
		opts = []string{placeholder}
	} else if len(accts) == 0 {
		opts = []string{placeholder}
	}

	set := func(sel *widget.Select) {
		if sel == nil {
			return
		}
		sel.SetOptions(opts)
		if len(accts) > 0 {
			sel.SetSelected(accts[0])
		} else {
			sel.SetSelected(placeholder)
		}
	}
	set(s.utilitiesAcctSelect)
	set(s.charactersAcctSelect)
	set(s.remoteLocalAcctSelect)

	verDisp := "(none)"
	if s.versionSelect != nil {
		verDisp = s.versionSelect.Selected
	}
	if s.utilitiesVersionLabel != nil {
		s.utilitiesVersionLabel.SetText("Game version (from bar above): " + verDisp)
	}
	if s.charactersVersionLabel != nil {
		s.charactersVersionLabel.SetText("Game version (from bar above): " + verDisp)
	}
}

func (s *appState) refreshAddons() {
	s.addonBox.RemoveAll()
	s.addonChecks = make(map[string]bool)
	s.addonWidgets = make(map[string]*widget.Check)

	if s.engine == nil {
		return
	}
	ver := s.versionSelect.Selected
	var selected []string
	for acct, on := range s.acctChecks {
		if on {
			selected = append(selected, acct)
		}
	}
	if len(selected) == 0 {
		return
	}

	allOnDisk := s.engine.UnionSVFiles(ver, selected)
	filter := s.filterSelect.Selected

	count := 0
	for _, name := range allOnDisk {
		switch filter {
		case "OneWoW Suggested Merges":
			info := LookupAddon(name)
			if info == nil || !info.Recommended {
				continue
			}
		case "All OneWoW Addons":
			if !IsOneWoWFile(name) {
				continue
			}
			info := LookupAddon(name)
			if info != nil && info.Kind == MergeNotRecommended {
				continue
			}
		}

		n := name
		info := LookupAddon(n)

		label := n + ".lua"
		if info != nil {
			label = info.Label
		}

		defaultOn := info != nil && info.Recommended
		s.addonChecks[n] = defaultOn

		desc := ""
		if info != nil {
			kindStr := ""
			switch info.Kind {
			case MergeCharacterMap:
				kindStr = " [character merge]"
			case MergeAccounting:
				kindStr = " [transaction merge]"
			case MergePrimaryWins:
				kindStr = " [primary wins]"
			}
			desc = info.Description + kindStr
		}

		chk := widget.NewCheck(label, func(checked bool) { s.addonChecks[n] = checked })
		chk.SetChecked(defaultOn)
		s.addonWidgets[n] = chk

		row := container.NewVBox(chk)
		if desc != "" {
			descLabel := canvas.NewText("    "+desc, colTextSecondary)
			descLabel.TextSize = 11
			row.Add(descLabel)
		}
		s.addonBox.Add(row)
		count++
	}
	s.appendLog(fmt.Sprintf("Showing %d addon(s).", count))
}

func (s *appState) setAllAddons(state bool) {
	for name, chk := range s.addonWidgets {
		chk.SetChecked(state)
		s.addonChecks[name] = state
	}
}

func (s *appState) onSync() {
	if s.engine == nil {
		dialog.ShowInformation("No WoW Path", "Set your WoW installation path first.", s.window)
		return
	}
	if IsWoWRunning() {
		dialog.ShowConfirm("WoW Is Running",
			"WoW appears to be running. Syncing while WoW is open can cause data loss.\n\nContinue anyway?",
			func(ok bool) {
				if ok {
					s.doSync()
				}
			}, s.window)
		return
	}
	s.doSync()
}

func (s *appState) doSync() {
	var accounts []string
	for acct, on := range s.acctChecks {
		if on {
			accounts = append(accounts, acct)
		}
	}
	sort.Strings(accounts)
	if len(accounts) < 2 {
		dialog.ShowInformation("Select Accounts", "Select at least 2 accounts.", s.window)
		return
	}

	var files []string
	for name, on := range s.addonChecks {
		if on {
			files = append(files, name)
		}
	}
	sort.Strings(files)
	if len(files) == 0 {
		dialog.ShowInformation("Select Addons", "Select at least 1 addon.", s.window)
		return
	}

	primary := s.primarySelect.Selected
	found := false
	for _, a := range accounts {
		if a == primary {
			found = true
		}
	}
	if !found {
		dialog.ShowInformation("Primary", "Primary must be a selected account.", s.window)
		return
	}

	isMerge := strings.HasPrefix(s.modeRadio.Selected, "Smart")
	ver := s.versionSelect.Selected

	s.clearLog()
	mode := "smart merge"
	if !isMerge {
		mode = "copy"
	}
	s.appendLog(fmt.Sprintf("Starting %s — %d file(s), %d account(s)", mode, len(files), len(accounts)))
	s.appendLog(fmt.Sprintf("Primary: %s  |  Version: %s\n", primary, ver))

	s.syncBtn.Disable()
	s.progressBar.Show()
	s.progressBar.SetValue(0)

	go func() {
		cb := func(pct float64, _ string) { s.progressBar.SetValue(pct) }
		var log []string
		if isMerge {
			log = s.engine.SyncMerge(ver, accounts, primary, files, cb)
		} else {
			targets := make([]string, 0)
			for _, a := range accounts {
				if a != primary {
					targets = append(targets, a)
				}
			}
			log = s.engine.SyncCopy(ver, primary, targets, files, cb)
		}
		s.progressBar.SetValue(1)
		for _, line := range log {
			s.appendLog(line)
		}
		s.appendLog("\nSync complete.")
		s.syncBtn.Enable()
		s.progressBar.Hide()
		s.engine.CleanupBackups(20)
		s.saveConfig()
	}()
}

func (s *appState) onBackup() {
	if s.engine == nil {
		return
	}
	ver := s.versionSelect.Selected
	var accounts, files []string
	for acct, on := range s.acctChecks {
		if on {
			accounts = append(accounts, acct)
		}
	}
	for name, on := range s.addonChecks {
		if on {
			files = append(files, name)
		}
	}
	if len(accounts) == 0 || len(files) == 0 {
		dialog.ShowInformation("Nothing Selected", "Select accounts and files first.", s.window)
		return
	}
	s.clearLog()
	for _, acct := range accounts {
		path, n := s.engine.CreateBackup(ver, acct, files)
		s.appendLog(fmt.Sprintf("Backed up %d file(s) for %s", n, acct))
		s.appendLog(fmt.Sprintf("  → %s", path))
	}
	s.appendLog("\nBackup complete.")
}

func (s *appState) onRestore() {
	if s.engine == nil {
		return
	}
	stamps := s.engine.ListBackups()
	if len(stamps) == 0 {
		dialog.ShowInformation("No Backups", "No backups found.", s.window)
		return
	}
	sel := widget.NewSelect(stamps, nil)
	if len(stamps) > 0 {
		sel.SetSelected(stamps[0])
	}
	dialog.ShowCustomConfirm("Restore Backup", "Restore", "Cancel",
		container.NewVBox(widget.NewLabel("Select a backup to restore:"), sel),
		func(ok bool) {
			if !ok || sel.Selected == "" {
				return
			}
			s.clearLog()
			s.appendLog(fmt.Sprintf("Restoring backup %s…\n", sel.Selected))
			ver := s.versionSelect.Selected
			for acct, on := range s.acctChecks {
				if on {
					for _, l := range s.engine.RestoreBackup(sel.Selected, ver, acct) {
						s.appendLog(l)
					}
				}
			}
			s.appendLog("\nRestore complete.")
		}, s.window)
}
