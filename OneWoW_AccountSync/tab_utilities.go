package main

import (
	"bytes"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

const catalogSubmitURL = "https://wow2.xyz/api/v1/catalog/submit"

var catalogAddons = []struct {
	FileName    string
	Label       string
	Description string
}{
	{"OneWoW_CatalogData_Vendors", "Catalog — Vendors", "NPC vendor inventories & locations"},
	{"OneWoW_CatalogData_Quests", "Catalog — Quests", "Quest data, rewards, objectives"},
	{"OneWoW_CatalogData_Tradeskills", "Catalog — Tradeskills", "Profession recipes & reagents"},
}

func (s *appState) buildUtilitiesTab() fyne.CanvasObject {

	intro := widget.NewLabel(
		"Help build OneWoW's static data. CatalogData SavedVariables hold real in-game vendor, quest, and tradeskill info. " +
			"Submitting helps everyone. Your submission is anonymous (no character names).",
	)
	intro.Wrapping = fyne.TextWrapWord

	s.utilitiesVersionLabel = widget.NewLabel("Game version (from bar above): (none)")
	s.utilitiesVersionLabel.Wrapping = fyne.TextWrapWord

	s.utilitiesAcctSelect = widget.NewSelect([]string{"(set WoW path above)"}, nil)

	acctRow := container.NewVBox(
		s.utilitiesVersionLabel,
		container.NewHBox(widget.NewLabel("Battle.net account:"), s.utilitiesAcctSelect),
	)

	// ─ Checkboxes for each catalog addon
	checks := map[string]bool{}
	checkWidgets := []*widget.Check{}
	for _, c := range catalogAddons {
		n := c.FileName
		checks[n] = true
		chk := widget.NewCheck(c.Label+" — "+c.Description, func(b bool) { checks[n] = b })
		chk.SetChecked(true)
		checkWidgets = append(checkWidgets, chk)
	}

	checkBox := container.NewVBox()
	for _, w := range checkWidgets {
		checkBox.Add(w)
	}

	// ─ Submit button
	submitProgress := widget.NewProgressBar()
	submitProgress.Hide()

	statusLabel := canvas.NewText("", colAccentPrimary)
	statusLabel.TextSize = 13

	submitBtn := widget.NewButton("  Submit Data to OneWoW  ", func() {
		if s.wow == nil || s.versionSelect == nil {
			dialog.ShowInformation("Local WoW", "Set Local WoW in the bar above first.", s.window)
			return
		}

		ver := s.versionSelect.Selected
		acct := s.utilitiesAcctSelect.Selected
		if ver == "" || ver == "(none)" || acct == "" || strings.HasPrefix(acct, "(") {
			dialog.ShowInformation("Select account", "Pick a game version in the bar above and a Battle.net account here.", s.window)
			return
		}

		var selected []string
		for name, on := range checks {
			if on {
				selected = append(selected, name)
			}
		}
		if len(selected) == 0 {
			dialog.ShowInformation("Nothing Selected", "Check at least one catalog addon.", s.window)
			return
		}

		submitProgress.Show()
		submitProgress.SetValue(0)
		statusLabel.Text = "Preparing…"
		statusLabel.Refresh()

		go func() {
			total := len(selected)
			results := []string{}
			for i, name := range selected {
				svPath := s.wow.SVPath(ver, acct, name)
				data, err := os.ReadFile(svPath)
				if err != nil {
					results = append(results, fmt.Sprintf("  SKIP  %s (not found)", name))
					submitProgress.SetValue(float64(i+1) / float64(total))
					continue
				}

				statusLabel.Text = fmt.Sprintf("Uploading %s…", name)
				statusLabel.Refresh()

				err = uploadCatalogData(name, data)
				if err != nil {
					results = append(results, fmt.Sprintf("  ERROR %s: %v", name, err))
				} else {
					results = append(results, fmt.Sprintf("  SENT  %s (%d bytes)", name, len(data)))
				}
				submitProgress.SetValue(float64(i+1) / float64(total))
			}

			s.appendLog("\n── CatalogData Submission ──")
			for _, r := range results {
				s.appendLog(r)
			}
			s.appendLog("Thank you for contributing!\n")

			statusLabel.Text = "Done! Thank you."
			statusLabel.Refresh()
			submitProgress.Hide()
		}()
	})
	submitBtn.Importance = widget.HighImportance

	actions := container.NewHBox(submitBtn, layout.NewSpacer(), statusLabel, submitProgress)

	privacyNote := canvas.NewText(
		"Files are sent to wow2.xyz over HTTPS. Only CatalogData files are uploaded — never your personal SavedVariables.",
		colTextSecondary,
	)
	privacyNote.TextSize = 11

	return container.NewVBox(
		intro,
		widget.NewSeparator(),
		acctRow,
		widget.NewSeparator(),
		checkBox,
		widget.NewSeparator(),
		actions,
		privacyNote,
	)
}

func uploadCatalogData(name string, data []byte) error {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	fw, err := w.CreateFormFile("file", name+".lua")
	if err != nil {
		return err
	}
	fw.Write(data)
	w.WriteField("addon", name)
	w.WriteField("source", "OneWoW_AccountSync")

	// Try to determine game version from path for context
	w.Close()

	req, err := http.NewRequest("POST", catalogSubmitURL, &buf)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("network error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("server returned %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}

