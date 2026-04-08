package main

import (
	_ "embed"
	"image/color"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

//go:embed icon.png
var iconBytes []byte

// Minimum window size (user-requested: allow smaller than default content min).
const winMinW, winMinH float32 = 520, 480

const appVersion = "B6.2604.0900"

// ── Application state ───────────────────────────────────────────

type appState struct {
	window fyne.Window
	wow    *WoWInstallation
	engine *SyncEngine

	// Global WoW (all tabs)
	pathEntry     *widget.Entry
	versionSelect *widget.Select

	// Sync tab
	primarySelect *widget.Select
	modeRadio     *widget.RadioGroup
	filterSelect  *widget.Select
	logEntry      *widget.Entry
	progressBar   *widget.ProgressBar
	syncBtn       *widget.Button
	acctBox       *fyne.Container
	addonBox      *fyne.Container
	acctChecks    map[string]bool
	addonChecks   map[string]bool
	acctWidgets   map[string]*widget.Check
	addonWidgets  map[string]*widget.Check

	// Other tabs — account dropdowns (refreshed when local WoW / version changes)
	utilitiesAcctSelect *widget.Select
	charactersAcctSelect *widget.Select
	remoteLocalAcctSelect *widget.Select

	// Remote tab — second install / source
	remotePathEntry     *widget.Entry
	remoteVersionSelect *widget.Select
	remoteAcctSelect    *widget.Select

	// Utilities / Characters — show effective local version
	utilitiesVersionLabel   *widget.Label
	charactersVersionLabel  *widget.Label

	// Characters tab
	charRoster    []charEntry
	charDetailBox *fyne.Container
}

// ── Entry point ─────────────────────────────────────────────────

func main() {
	a := app.NewWithID("com.onewow.accountsync")
	a.Settings().SetTheme(&oneWoWTheme{})

	iconRes := fyne.NewStaticResource("icon.png", iconBytes)
	a.SetIcon(iconRes)

	w := a.NewWindow("OneWoW Account Sync — " + appVersion)
	w.SetFixedSize(false)
	w.Resize(fyne.NewSize(720, 640))

	s := &appState{
		window:       w,
		acctChecks:   make(map[string]bool),
		addonChecks:  make(map[string]bool),
		acctWidgets:  make(map[string]*widget.Check),
		addonWidgets: make(map[string]*widget.Check),
	}

	w.SetContent(s.wrapWithMinWindow(s.buildUI(iconRes)))
	s.loadConfig()
	s.autoDetect()

	w.ShowAndRun()
}

// wrapWithMinWindow constrains minimum window size so the user can resize down.
func (s *appState) wrapWithMinWindow(content fyne.CanvasObject) fyne.CanvasObject {
	// Border layout: single child; we use a custom min by stacking with transparent spacer.
	// Fyne 2.7: driver honors the minimum of the content tree; we attach a tiny MinSize
	// overlay using a container that reports at least winMinW x winMinH.
	min := canvas.NewRectangle(color.Transparent)
	min.SetMinSize(fyne.NewSize(winMinW, winMinH))
	min.Hide()
	return container.NewStack(content, min)
}

// ── UI Builder ──────────────────────────────────────────────────

func (s *appState) buildUI(iconRes fyne.Resource) fyne.CanvasObject {

	logo := canvas.NewImageFromResource(iconRes)
	logo.SetMinSize(fyne.NewSize(40, 40))
	logo.FillMode = canvas.ImageFillContain

	title := widget.NewRichTextFromMarkdown("## OneWoW Account Sync")
	sub := widget.NewLabel("Sync addon data across multiple Battle.net accounts")
	sub.Importance = widget.LowImportance
	sub.Wrapping = fyne.TextWrapWord

	header := container.NewHBox(
		logo,
		container.NewVBox(title, sub),
	)

	globalBar := s.buildGlobalWoWBar()

	tabs := container.NewAppTabs(
		container.NewTabItem("Account Sync", s.buildSyncTab()),
		container.NewTabItem("Remote Source", s.buildRemoteTab()),
		container.NewTabItem("Utilities", s.buildUtilitiesTab()),
		container.NewTabItem("Characters", s.buildCharactersTab()),
	)
	tabs.SetTabLocation(container.TabLocationTop)

	tabScroll := container.NewScroll(tabs)
	tabScroll.SetMinSize(fyne.NewSize(360, 260))

	s.logEntry = widget.NewMultiLineEntry()
	s.logEntry.Wrapping = fyne.TextWrapWord
	s.logEntry.SetMinRowsVisible(4)
	s.logEntry.TextStyle = fyne.TextStyle{Monospace: true}
	s.appendLog("Ready. Set your WoW installation path above (applies to all tabs).")

	logScroll := container.NewScroll(s.logEntry)
	logScroll.SetMinSize(fyne.NewSize(200, 100))

	logHeader := s.sectionLabel("Log")
	logHeader.TextSize = 13

	logContainer := container.NewBorder(
		logHeader,
		nil, nil, nil,
		logScroll,
	)

	root := container.NewBorder(
		container.NewVBox(header, widget.NewSeparator(), globalBar, widget.NewSeparator()),
		container.NewVBox(widget.NewSeparator(), logContainer),
		nil, nil,
		tabScroll,
	)

	s.refreshSecondaryAccountSelects()
	s.refreshRemoteMetadata()

	return root
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
	if s.logEntry == nil {
		return
	}
	current := s.logEntry.Text
	if current != "" {
		current += "\n"
	}
	s.logEntry.SetText(current + msg)
	s.logEntry.CursorRow = len(strings.Split(s.logEntry.Text, "\n"))
}

func (s *appState) clearLog() {
	if s.logEntry != nil {
		s.logEntry.SetText("")
	}
}

// ── Config ───────────────────────────────────────────────────────

func (s *appState) loadConfig() {
	tmpEngine := NewSyncEngine(&WoWInstallation{})
	cfg := tmpEngine.LoadConfig()
	if cfg.WoWPath != "" && s.pathEntry != nil {
		s.pathEntry.SetText(cfg.WoWPath)
	}
	if cfg.Mode == "copy" && s.modeRadio != nil {
		s.modeRadio.SetSelected("Copy (primary overwrites all)")
	}
}

func (s *appState) saveConfig() {
	if s.engine == nil || s.pathEntry == nil || s.versionSelect == nil {
		return
	}
	mode := "merge"
	if s.modeRadio != nil && strings.HasPrefix(s.modeRadio.Selected, "Copy") {
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
	if s.pathEntry == nil {
		return
	}
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
