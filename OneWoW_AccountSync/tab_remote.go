package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

func (s *appState) buildRemoteTab() fyne.CanvasObject {

	localHint := canvas.NewText(
		"Local installation: use Local WoW + Game version in the bar above. Choose which account receives merged files.",
		colTextSecondary,
	)
	localHint.TextSize = 11

	s.remoteLocalAcctSelect = widget.NewSelect([]string{"(set WoW path above)"}, nil)
	localRow := container.NewHBox(widget.NewLabel("Merge into local account:"), s.remoteLocalAcctSelect)

	// ─ Remote (second PC / share / folder)
	s.remotePathEntry = widget.NewEntry()
	s.remotePathEntry.SetPlaceHolder(`Other WoW folder, UNC share, SavedVariables folder, or https://…/file.lua`)
	s.remotePathEntry.OnSubmitted = func(_ string) { s.refreshRemoteMetadata() }

	remoteBrowse := widget.NewButton("Browse…", func() {
		d := dialog.NewFolderOpen(func(uri fyne.ListableURI, err error) {
			if uri != nil {
				s.remotePathEntry.SetText(uri.Path())
				s.refreshRemoteMetadata()
			}
		}, s.window)
		d.Show()
	})

	remotePathRow := container.NewBorder(nil, nil,
		widget.NewLabel("Remote source"),
		remoteBrowse,
		s.remotePathEntry,
	)

	s.remoteVersionSelect = widget.NewSelect([]string{"(enter remote path)"}, func(_ string) {
		s.refreshRemoteAccountsOnly()
	})
	s.remoteAcctSelect = widget.NewSelect([]string{"(enter remote path)"}, nil)

	detectBtn := widget.NewButton("Detect versions / accounts", func() { s.refreshRemoteMetadata() })

	verRow := container.NewHBox(widget.NewLabel("Remote game version:"), s.remoteVersionSelect)
	acctRow := container.NewHBox(widget.NewLabel("Remote account:"), s.remoteAcctSelect)

	remoteHint := canvas.NewText(
		"If the remote path is a full WoW install, pick its game version and account. If it is already a SavedVariables folder (or only .lua files), version/account show “n/a”.",
		colTextSecondary,
	)
	remoteHint.TextSize = 10

	// ─ File list
	fileBox := container.NewVBox()
	fileScroll := container.NewVScroll(fileBox)
	fileScroll.SetMinSize(fyne.NewSize(200, 140))
	fileChecks := map[string]bool{}

	scanBtn := widget.NewButton("Scan remote files", func() {
		src := strings.TrimSpace(s.remotePathEntry.Text)
		if src == "" {
			dialog.ShowInformation("No source", "Enter a remote path or URL.", s.window)
			return
		}
		fileBox.RemoveAll()
		clearMap(fileChecks)

		var files []string
		if strings.HasPrefix(src, "http://") || strings.HasPrefix(src, "https://") {
			files = scanRemoteURL(src)
		} else {
			ver := s.remoteVersionSelect.Selected
			acct := s.remoteAcctSelect.Selected
			svDir, e := ResolveRemoteSavedVariablesDir(src, ver, acct)
			if e != nil {
				dialog.ShowInformation("Remote path", e.Error(), s.window)
				return
			}
			files = ListSavedVariableStems(svDir)
		}
		if len(files) == 0 {
			s.appendLog("No .lua SavedVariables found at remote source.")
			fileBox.Add(widget.NewLabel("No .lua files found."))
			return
		}
		s.appendLog(fmt.Sprintf("Found %d SavedVariables file(s) on remote source.", len(files)))
		for _, f := range files {
			n := f
			fileChecks[n] = false
			chk := widget.NewCheck(n+".lua", func(on bool) { fileChecks[n] = on })
			if info := LookupAddon(n); info != nil && info.Recommended {
				chk.SetChecked(true)
				fileChecks[n] = true
			}
			fileBox.Add(chk)
		}
	})

	remoteProgress := widget.NewProgressBar()
	remoteProgress.Hide()

	mergeBtn := widget.NewButton("  Merge into local account  ", func() {
		if s.engine == nil || s.wow == nil {
			dialog.ShowInformation("Local WoW", "Set Local WoW in the bar above first.", s.window)
			return
		}
		target := s.remoteLocalAcctSelect.Selected
		if target == "" || strings.HasPrefix(target, "(") {
			dialog.ShowInformation("Local account", "Select a local account to merge into.", s.window)
			return
		}
		src := strings.TrimSpace(s.remotePathEntry.Text)
		if src == "" {
			return
		}

		var names []string
		for n, on := range fileChecks {
			if on {
				names = append(names, n)
			}
		}
		sort.Strings(names)
		if len(names) == 0 {
			dialog.ShowInformation("No files", "Scan the remote source and tick at least one file.", s.window)
			return
		}

		paths, err := s.resolveRemoteFilePaths(src, names)
		if err != nil {
			dialog.ShowInformation("Remote", err.Error(), s.window)
			return
		}
		if len(paths) == 0 {
			dialog.ShowInformation("Remote", "Could not resolve any file paths.", s.window)
			return
		}

		s.appendLog(fmt.Sprintf("Merging %d file(s) from remote into local account %s…", len(paths), target))
		remoteProgress.Show()
		remoteProgress.SetValue(0)

		go func() {
			ver := s.versionSelect.Selected
			log := s.engine.MergeFromRemote(ver, []string{target}, target, paths, func(pct float64, _ string) {
				remoteProgress.SetValue(pct)
			})
			for _, l := range log {
				s.appendLog(l)
			}
			remoteProgress.SetValue(1)
			s.appendLog("\nRemote merge complete.")
			remoteProgress.Hide()
		}()
	})
	mergeBtn.Importance = widget.HighImportance

	actions := container.NewHBox(scanBtn, detectBtn, mergeBtn, layout.NewSpacer(), remoteProgress)

	return container.NewBorder(
		container.NewVBox(
			s.sectionLabel("Remote / second installation"),
			localHint,
			localRow,
			widget.NewSeparator(),
			remotePathRow,
			verRow,
			acctRow,
			remoteHint,
			widget.NewSeparator(),
			actions,
			widget.NewSeparator(),
		),
		nil, nil, nil,
		fileScroll,
	)
}

func clearMap(m map[string]bool) {
	for k := range m {
		delete(m, k)
	}
}

func (s *appState) refreshRemoteMetadata() {
	if s.remotePathEntry == nil || s.remoteVersionSelect == nil || s.remoteAcctSelect == nil {
		return
	}
	root := strings.TrimSpace(s.remotePathEntry.Text)
	if root == "" {
		s.remoteVersionSelect.SetOptions([]string{"(enter remote path)"})
		s.remoteVersionSelect.SetSelected("(enter remote path)")
		s.remoteAcctSelect.SetOptions([]string{"(enter remote path)"})
		s.remoteAcctSelect.SetSelected("(enter remote path)")
		return
	}

	if strings.HasPrefix(root, "http://") || strings.HasPrefix(root, "https://") {
		s.remoteVersionSelect.SetOptions([]string{"— URL (single .lua) —"})
		s.remoteVersionSelect.SetSelected("— URL (single .lua) —")
		s.remoteAcctSelect.SetOptions([]string{"— n/a —"})
		s.remoteAcctSelect.SetSelected("— n/a —")
		return
	}

	if !isDir(root) {
		s.remoteVersionSelect.SetOptions([]string{"(not a directory)"})
		s.remoteVersionSelect.SetSelected("(not a directory)")
		s.remoteAcctSelect.SetOptions([]string{"(not a directory)"})
		return
	}

	if strings.EqualFold(filepath.Base(root), "SavedVariables") {
		s.remoteVersionSelect.SetOptions([]string{remoteSVFolderSentinel})
		s.remoteVersionSelect.SetSelected(remoteSVFolderSentinel)
		s.remoteAcctSelect.SetOptions([]string{"— n/a —"})
		s.remoteAcctSelect.SetSelected("— n/a —")
		return
	}

	if len(GameVersionsAt(root)) == 0 {
		if dirLooksLikeSavedVariables(root) {
			s.remoteVersionSelect.SetOptions([]string{remoteSVFolderSentinel})
			s.remoteVersionSelect.SetSelected(remoteSVFolderSentinel)
			s.remoteAcctSelect.SetOptions([]string{"— n/a —"})
			s.remoteAcctSelect.SetSelected("— n/a —")
			return
		}
		s.remoteVersionSelect.SetOptions([]string{"(not a WoW install)"})
		s.remoteVersionSelect.SetSelected("(not a WoW install)")
		s.remoteAcctSelect.SetOptions([]string{"(not a WoW install)"})
		return
	}

	vers := GameVersionsAt(root)
	s.remoteVersionSelect.SetOptions(vers)
	s.remoteVersionSelect.SetSelected(vers[0])
	s.refreshRemoteAccountsOnly()
}

func (s *appState) refreshRemoteAccountsOnly() {
	if s.remotePathEntry == nil || s.remoteVersionSelect == nil || s.remoteAcctSelect == nil {
		return
	}
	root := strings.TrimSpace(s.remotePathEntry.Text)
	ver := s.remoteVersionSelect.Selected
	if ver == remoteSVFolderSentinel || strings.HasPrefix(ver, "—") || strings.HasPrefix(ver, "(") {
		s.remoteAcctSelect.SetOptions([]string{"— n/a —"})
		s.remoteAcctSelect.SetSelected("— n/a —")
		return
	}
	accts := AccountsAt(root, ver)
	if len(accts) == 0 {
		s.remoteAcctSelect.SetOptions([]string{"(no accounts)"})
		s.remoteAcctSelect.SetSelected("(no accounts)")
		return
	}
	s.remoteAcctSelect.SetOptions(accts)
	s.remoteAcctSelect.SetSelected(accts[0])
}

func scanRemoteURL(src string) []string {
	name := filepath.Base(src)
	name = strings.TrimSuffix(name, ".lua")
	if name == "" || name == "/" {
		return nil
	}
	return []string{name}
}

func (s *appState) resolveRemoteFilePaths(src string, names []string) (map[string]string, error) {
	src = strings.TrimSpace(src)
	if strings.HasPrefix(src, "http://") || strings.HasPrefix(src, "https://") {
		return downloadRemoteLuaURL(src, names)
	}
	ver := s.remoteVersionSelect.Selected
	acct := s.remoteAcctSelect.Selected
	svDir, err := ResolveRemoteSavedVariablesDir(src, ver, acct)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string)
	for _, name := range names {
		p := filepath.Join(svDir, name+".lua")
		if _, e := os.Stat(p); e == nil {
			out[name] = p
		}
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no matching .lua files in %s", svDir)
	}
	return out, nil
}

func downloadRemoteLuaURL(src string, names []string) (map[string]string, error) {
	out := make(map[string]string)
	tmpDir := os.TempDir()
	resp, err := http.Get(src)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	for _, name := range names {
		tmp := filepath.Join(tmpDir, fmt.Sprintf("onewow_remote_%s.lua", name))
		if err := os.WriteFile(tmp, data, 0644); err != nil {
			return nil, err
		}
		out[name] = tmp
	}
	return out, nil
}
