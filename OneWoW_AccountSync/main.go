package main

import (
	_ "embed"
	"fmt"
	"sort"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

//go:embed icon.png
var iconBytes []byte

// ── Application state ───────────────────────────────────────────

type appState struct {
	window fyne.Window
	wow    *WoWInstallation
	engine *SyncEngine

	// widgets
	pathEntry     *widget.Entry
	versionSelect *widget.Select
	primarySelect *widget.Select
	modeRadio     *widget.RadioGroup
	filterSelect  *widget.Select
	logEntry      *widget.Entry
	progressBar   *widget.ProgressBar
	syncBtn       *widget.Button

	// dynamic checkbox containers
	acctBox  *fyne.Container
	addonBox *fyne.Container

	// checkbox state
	acctChecks  map[string]bool
	addonChecks map[string]bool
	acctWidgets map[string]*widget.Check
	addonWidgets map[string]*widget.Check
}

// ── Entry point ─────────────────────────────────────────────────

func main() {
	a := app.NewWithID("com.onewow.accountsync")
	a.Settings().SetTheme(&oneWoWTheme{})

	iconRes := fyne.NewStaticResource("icon.png", iconBytes)
	a.SetIcon(iconRes)

	w := a.NewWindow("OneWoW Account Sync")
	w.Resize(fyne.NewSize(880, 740))
	w.SetFixedSize(false)

	s := &appState{
		window:       w,
		acctChecks:   make(map[string]bool),
		addonChecks:  make(map[string]bool),
		acctWidgets:  make(map[string]*widget.Check),
		addonWidgets: make(map[string]*widget.Check),
	}

	w.SetContent(s.buildUI(iconRes))
	s.loadConfig()
	s.autoDetect()

	w.ShowAndRun()
}

// ── UI Builder ──────────────────────────────────────────────────

func (s *appState) buildUI(iconRes fyne.Resource) fyne.CanvasObject {

	// ─ Header
	logo := canvas.NewImageFromResource(iconRes)
	logo.SetMinSize(fyne.NewSize(48, 48))
	logo.FillMode = canvas.ImageFillContain

	title := widget.NewRichTextFromMarkdown("## OneWoW Account Sync")
	subtitle := widget.NewLabel("Sync addon data across multiple Battle.net accounts")
	subtitle.Importance = widget.LowImportance

	header := container.NewHBox(
		logo,
		container.NewVBox(title, subtitle),
	)

	// ─ Path row
	s.pathEntry = widget.NewEntry()
	s.pathEntry.SetPlaceHolder("C:\\Program Files\\World of Warcraft")
	s.pathEntry.OnSubmitted = func(_ string) { s.onPathSet() }

	browseBtn := widget.NewButton("Browse", s.onBrowse)

	s.versionSelect = widget.NewSelect([]string{"(none)"}, s.onVersionChange)
	s.versionSelect.SetSelected("(none)")

	pathRow := container.NewBorder(
		nil, nil, widget.NewLabel("WoW Path"), nil,
		container.NewBorder(nil, nil, nil,
			container.NewHBox(browseBtn, widget.NewLabel("  Version"), s.versionSelect),
			s.pathEntry,
		),
	)

	// ─ Accounts panel
	s.acctBox = container.NewVBox()
	acctScroll := container.NewVScroll(s.acctBox)
	acctScroll.SetMinSize(fyne.NewSize(0, 150))

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
	addonScroll.SetMinSize(fyne.NewSize(0, 150))

	s.filterSelect = widget.NewSelect([]string{"OneWoW Only", "All Addons"}, func(_ string) {
		s.refreshAddons()
	})
	s.filterSelect.SetSelected("OneWoW Only")

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

	// ─ Two-column split
	split := container.NewHSplit(acctPanel, addonPanel)
	split.SetOffset(0.35)

	// ─ Mode
	s.modeRadio = widget.NewRadioGroup(
		[]string{"Merge (combine data from all accounts)", "Copy (primary overwrites all targets)"},
		nil,
	)
	s.modeRadio.SetSelected("Merge (combine data from all accounts)")
	s.modeRadio.Horizontal = true

	modeRow := container.NewHBox(
		s.boldLabel("Sync Mode:"),
		s.modeRadio,
	)

	// ─ Action buttons
	s.syncBtn = widget.NewButton("  Sync Now  ", s.onSync)
	s.syncBtn.Importance = widget.HighImportance

	backupBtn := widget.NewButton("Backup All", s.onBackup)
	restoreBtn := widget.NewButton("Restore…", s.onRestore)

	s.progressBar = widget.NewProgressBar()
	s.progressBar.Hide()

	actions := container.NewHBox(
		s.syncBtn, backupBtn, restoreBtn,
		layout.NewSpacer(),
		s.progressBar,
	)

	// ─ Log
	s.logEntry = widget.NewMultiLineEntry()
	s.logEntry.Wrapping = fyne.TextWrapWord
	s.logEntry.SetMinRowsVisible(8)
	s.logEntry.TextStyle = fyne.TextStyle{Monospace: true}

	s.appendLog("Ready. Set your WoW installation path above to begin.")

	logContainer := container.NewBorder(
		s.sectionLabel("Log"),
		nil, nil, nil,
		s.logEntry,
	)

	// ─ Assemble
	return container.NewBorder(
		container.NewVBox(
			header,
			widget.NewSeparator(),
			pathRow,
			widget.NewSeparator(),
		),
		container.NewVBox(
			widget.NewSeparator(),
			logContainer,
		),
		nil, nil,
		container.NewVBox(
			split,
			widget.NewSeparator(),
			modeRow,
			widget.NewSeparator(),
			actions,
		),
	)
}

// ── Helpers ──────────────────────────────────────────────────────

func (s *appState) sectionLabel(text string) *canvas.Text {
	t := canvas.NewText(text, colAccentPrimary)
	t.TextStyle = fyne.TextStyle{Bold: true}
	t.TextSize = 15
	return t
}

func (s *appState) boldLabel(text string) *widget.RichText {
	seg := &widget.TextSegment{Text: text, Style: widget.RichTextStyle{
		TextStyle: fyne.TextStyle{Bold: true},
	}}
	return widget.NewRichText(seg)
}

func (s *appState) appendLog(msg string) {
	current := s.logEntry.Text
	if current != "" {
		current += "\n"
	}
	s.logEntry.SetText(current + msg)
	s.logEntry.CursorRow = len(strings.Split(s.logEntry.Text, "\n"))
}

func (s *appState) clearLog() {
	s.logEntry.SetText("")
}

// ── Config ───────────────────────────────────────────────────────

func (s *appState) loadConfig() {
	tmpEngine := NewSyncEngine(&WoWInstallation{})
	cfg := tmpEngine.LoadConfig()
	if cfg.WoWPath != "" {
		s.pathEntry.SetText(cfg.WoWPath)
	}
	if cfg.Mode == "copy" {
		s.modeRadio.SetSelected("Copy (primary overwrites all targets)")
	}
}

func (s *appState) saveConfig() {
	if s.engine == nil {
		return
	}
	mode := "merge"
	if strings.HasPrefix(s.modeRadio.Selected, "Copy") {
		mode = "copy"
	}
	s.engine.SaveConfig(AppConfig{
		WoWPath:     s.pathEntry.Text,
		GameVersion: s.versionSelect.Selected,
		Mode:        mode,
	})
}

// ── WoW detection ────────────────────────────────────────────────

func (s *appState) autoDetect() {
	path := strings.TrimSpace(s.pathEntry.Text)
	if path == "" {
		path = DetectWoW()
		if path != "" {
			s.pathEntry.SetText(path)
			s.appendLog("Auto-detected WoW: " + path)
		}
	}
	if path != "" {
		s.onPathSet()
	}
}

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
		return
	}
	s.wow = &WoWInstallation{BasePath: path}
	s.engine = NewSyncEngine(s.wow)

	versions := s.wow.GameVersions()
	if len(versions) == 0 {
		s.appendLog("No WTF/Account folders found under that path.")
		s.versionSelect.SetOptions([]string{"(none)"})
		s.versionSelect.SetSelected("(none)")
		return
	}
	s.versionSelect.SetOptions(versions)

	// Restore saved version or pick first
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
}

func (s *appState) onVersionChange(ver string) {
	if ver == "(none)" || s.wow == nil {
		return
	}
	s.refreshAccounts()
	s.saveConfig()
}

// ── Account list ─────────────────────────────────────────────────

func (s *appState) refreshAccounts() {
	s.acctBox.RemoveAll()
	s.acctChecks = make(map[string]bool)
	s.acctWidgets = make(map[string]*widget.Check)

	if s.wow == nil {
		return
	}
	ver := s.versionSelect.Selected
	accounts := s.wow.Accounts(ver)

	if len(accounts) == 0 {
		s.acctBox.Add(widget.NewLabel("No accounts found."))
		s.primarySelect.SetOptions([]string{"(none)"})
		s.primarySelect.SetSelected("(none)")
		s.appendLog(fmt.Sprintf("No accounts found for %s.", ver))
		return
	}

	for _, acct := range accounts {
		name := acct
		s.acctChecks[name] = true
		chk := widget.NewCheck(name, func(checked bool) {
			s.acctChecks[name] = checked
		})
		chk.SetChecked(true)
		s.acctWidgets[name] = chk
		s.acctBox.Add(chk)
	}

	s.primarySelect.SetOptions(accounts)
	s.primarySelect.SetSelected(accounts[0])

	s.appendLog(fmt.Sprintf("Found %d account(s) for %s.", len(accounts), ver))
	s.refreshAddons()
}

// ── Addon list ───────────────────────────────────────────────────

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

	allFiles := s.engine.UnionSVFiles(ver, selected)
	showAll := s.filterSelect.Selected == "All Addons"

	count := 0
	for _, name := range allFiles {
		if !showAll && !IsOneWoWFile(name) {
			continue
		}
		n := name
		isOW := IsOneWoWFile(n)
		s.addonChecks[n] = isOW

		chk := widget.NewCheck(n+".lua", func(checked bool) {
			s.addonChecks[n] = checked
		})
		chk.SetChecked(isOW)
		s.addonWidgets[n] = chk
		s.addonBox.Add(chk)
		count++
	}

	s.appendLog(fmt.Sprintf("Showing %d SavedVariables file(s).", count))
}

func (s *appState) setAllAddons(state bool) {
	for name, chk := range s.addonWidgets {
		chk.SetChecked(state)
		s.addonChecks[name] = state
	}
}

// ── Sync ─────────────────────────────────────────────────────────

func (s *appState) onSync() {
	if s.engine == nil {
		dialog.ShowInformation("No WoW Path", "Set your WoW installation path first.", s.window)
		return
	}

	if IsWoWRunning() {
		dialog.ShowConfirm("WoW Is Running",
			"WoW appears to be running. Syncing while WoW is open can "+
				"cause data loss because WoW overwrites SavedVariables on logout.\n\n"+
				"Continue anyway?",
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
		dialog.ShowInformation("Select Accounts", "Select at least 2 accounts to sync.", s.window)
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
		dialog.ShowInformation("Select Addons", "Select at least 1 SavedVariables file to sync.", s.window)
		return
	}

	primary := s.primarySelect.Selected
	found := false
	for _, a := range accounts {
		if a == primary {
			found = true
			break
		}
	}
	if !found {
		dialog.ShowInformation("Primary", "Primary account must be one of the selected accounts.", s.window)
		return
	}

	isMerge := strings.HasPrefix(s.modeRadio.Selected, "Merge")
	modeName := "merge"
	if !isMerge {
		modeName = "copy"
	}
	ver := s.versionSelect.Selected

	s.clearLog()
	s.appendLog(fmt.Sprintf("Starting %s sync — %d file(s), %d account(s)", modeName, len(files), len(accounts)))
	s.appendLog(fmt.Sprintf("Primary: %s  |  Version: %s\n", primary, ver))

	s.syncBtn.Disable()
	s.progressBar.Show()
	s.progressBar.SetValue(0)

	go func() {
		cb := func(pct float64, _ string) {
			s.progressBar.SetValue(pct)
		}

		var log []string
		if isMerge {
			log = s.engine.SyncMerge(ver, accounts, primary, files, cb)
		} else {
			targets := make([]string, 0, len(accounts)-1)
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

// ── Backup / Restore ─────────────────────────────────────────────

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

	// Show a selection dialog
	sel := widget.NewSelect(stamps, nil)
	if len(stamps) > 0 {
		sel.SetSelected(stamps[0])
	}

	dialog.ShowCustomConfirm("Restore Backup", "Restore", "Cancel",
		container.NewVBox(
			widget.NewLabel("Select a backup to restore:"),
			sel,
		),
		func(ok bool) {
			if !ok || sel.Selected == "" {
				return
			}
			s.clearLog()
			s.appendLog(fmt.Sprintf("Restoring backup %s…\n", sel.Selected))
			ver := s.versionSelect.Selected
			for acct, on := range s.acctChecks {
				if on {
					lines := s.engine.RestoreBackup(sel.Selected, ver, acct)
					for _, l := range lines {
						s.appendLog(l)
					}
				}
			}
			s.appendLog("\nRestore complete.")
		}, s.window)
}
