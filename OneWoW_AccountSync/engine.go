package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
)

// ── WoW Installation ────────────────────────────────────────────

var gameVersions = []string{"_retail_", "_classic_", "_classic_era_", "_ptr_", "_beta_"}

type WoWInstallation struct {
	BasePath string
}

func DetectWoW() string {
	if runtime.GOOS == "windows" {
		return detectWoWWindows()
	}
	return detectWoWMac()
}

func detectWoWWindows() string {
	// Try registry via reg query
	for _, regPath := range []string{
		`HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft`,
		`HKLM\SOFTWARE\Blizzard Entertainment\World of Warcraft`,
	} {
		out, err := exec.Command("reg", "query", regPath, "/v", "InstallPath").Output()
		if err == nil {
			for _, line := range strings.Split(string(out), "\n") {
				line = strings.TrimSpace(line)
				if strings.Contains(line, "InstallPath") {
					parts := strings.SplitN(line, "REG_SZ", 2)
					if len(parts) == 2 {
						p := strings.TrimSpace(parts[1])
						parent := filepath.Dir(p)
						if isDir(parent) {
							return parent
						}
					}
				}
			}
		}
	}

	for _, drive := range []string{"C", "D", "E", "F"} {
		for _, sub := range []string{
			`Program Files (x86)\World of Warcraft`,
			`Program Files\World of Warcraft`,
			`World of Warcraft`,
			`Games\World of Warcraft`,
		} {
			p := drive + `:\` + sub
			if isDir(p) {
				return p
			}
		}
	}
	return ""
}

func detectWoWMac() string {
	home, _ := os.UserHomeDir()
	for _, p := range []string{
		"/Applications/World of Warcraft",
		filepath.Join(home, "Applications", "World of Warcraft"),
		filepath.Join(home, "Games", "World of Warcraft"),
	} {
		if isDir(p) {
			return p
		}
	}
	return ""
}

func (w *WoWInstallation) GameVersions() []string {
	var out []string
	for _, v := range gameVersions {
		if isDir(filepath.Join(w.BasePath, v, "WTF", "Account")) {
			out = append(out, v)
		}
	}
	return out
}

func (w *WoWInstallation) Accounts(gameVer string) []string {
	root := filepath.Join(w.BasePath, gameVer, "WTF", "Account")
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var accts []string
	for _, e := range entries {
		if e.IsDir() && e.Name() != "SavedVariables" {
			sv := filepath.Join(root, e.Name(), "SavedVariables")
			if isDir(sv) {
				accts = append(accts, e.Name())
			}
		}
	}
	sort.Strings(accts)
	return accts
}

func (w *WoWInstallation) SVFiles(gameVer, account string) []string {
	dir := w.svDir(gameVer, account)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		n := e.Name()
		if strings.HasSuffix(n, ".lua") && !strings.HasSuffix(n, ".lua.bak") {
			names = append(names, strings.TrimSuffix(n, ".lua"))
		}
	}
	sort.Strings(names)
	return names
}

func (w *WoWInstallation) SVPath(gameVer, account, name string) string {
	return filepath.Join(w.svDir(gameVer, account), name+".lua")
}

func (w *WoWInstallation) svDir(gameVer, account string) string {
	return filepath.Join(w.BasePath, gameVer, "WTF", "Account", account, "SavedVariables")
}

// ── Helpers ─────────────────────────────────────────────────────

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}

func IsOneWoWFile(name string) bool {
	return name == "OneWoW" || strings.HasPrefix(name, "OneWoW_")
}

func IsWoWRunning() bool {
	if runtime.GOOS == "windows" {
		for _, exe := range []string{"Wow.exe", "WowClassic.exe"} {
			out, err := exec.Command("tasklist", "/FI", "IMAGENAME eq "+exe).Output()
			if err == nil && strings.Contains(string(out), exe) {
				return true
			}
		}
		return false
	}
	// macOS / linux
	for _, name := range []string{"World of Warcraft", "Wow", "WowClassic"} {
		if err := exec.Command("pgrep", "-x", name).Run(); err == nil {
			return true
		}
	}
	return false
}

// ── Sync Engine ─────────────────────────────────────────────────

type SyncEngine struct {
	WoW       *WoWInstallation
	BackupDir string
	ConfigDir string
}

func NewSyncEngine(wow *WoWInstallation) *SyncEngine {
	home, _ := os.UserHomeDir()
	base := filepath.Join(home, ".onewow_sync")
	return &SyncEngine{
		WoW:       wow,
		BackupDir: filepath.Join(base, "backups"),
		ConfigDir: base,
	}
}

// ── config ──

type AppConfig struct {
	WoWPath     string `json:"wow_path"`
	GameVersion string `json:"game_version"`
	Mode        string `json:"mode"`
}

func (e *SyncEngine) LoadConfig() AppConfig {
	path := filepath.Join(e.ConfigDir, "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return AppConfig{}
	}
	var cfg AppConfig
	json.Unmarshal(data, &cfg)
	return cfg
}

func (e *SyncEngine) SaveConfig(cfg AppConfig) {
	os.MkdirAll(e.ConfigDir, 0755)
	data, _ := json.MarshalIndent(cfg, "", "  ")
	os.WriteFile(filepath.Join(e.ConfigDir, "config.json"), data, 0644)
}

// ── backup ──

func (e *SyncEngine) CreateBackup(gameVer, account string, files []string) (string, int) {
	stamp := time.Now().Format("20060102_150405")
	dest := filepath.Join(e.BackupDir, stamp, account)
	os.MkdirAll(dest, 0755)
	count := 0
	for _, name := range files {
		src := e.WoW.SVPath(gameVer, account, name)
		if data, err := os.ReadFile(src); err == nil {
			os.WriteFile(filepath.Join(dest, name+".lua"), data, 0644)
			count++
		}
	}
	return dest, count
}

func (e *SyncEngine) ListBackups() []string {
	entries, err := os.ReadDir(e.BackupDir)
	if err != nil {
		return nil
	}
	var stamps []string
	for _, en := range entries {
		if en.IsDir() {
			stamps = append(stamps, en.Name())
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(stamps)))
	return stamps
}

func (e *SyncEngine) RestoreBackup(stamp, gameVer, account string) []string {
	srcDir := filepath.Join(e.BackupDir, stamp, account)
	if !isDir(srcDir) {
		return []string{fmt.Sprintf("No backup for %s at %s", account, stamp)}
	}
	var log []string
	filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if strings.HasSuffix(d.Name(), ".lua") {
			name := strings.TrimSuffix(d.Name(), ".lua")
			dst := e.WoW.SVPath(gameVer, account, name)
			os.MkdirAll(filepath.Dir(dst), 0755)
			data, _ := os.ReadFile(path)
			os.WriteFile(dst, data, 0644)
			log = append(log, fmt.Sprintf("  RESTORED %s -> %s", d.Name(), account))
		}
		return nil
	})
	return log
}

func (e *SyncEngine) CleanupBackups(keep int) {
	stamps := e.ListBackups()
	if len(stamps) <= keep {
		return
	}
	for _, s := range stamps[keep:] {
		os.RemoveAll(filepath.Join(e.BackupDir, s))
	}
}

// ── sync: copy ──

func (e *SyncEngine) SyncCopy(gameVer, source string, targets, files []string, cb func(float64, string)) []string {
	var log []string
	total := len(targets) * len(files)
	done := 0

	for _, target := range targets {
		log = append(log, fmt.Sprintf("── Syncing to %s ──", target))
		bkPath, bkN := e.CreateBackup(gameVer, target, files)
		log = append(log, fmt.Sprintf("   Backup: %d file(s) -> %s", bkN, bkPath))

		for _, name := range files {
			src := e.WoW.SVPath(gameVer, source, name)
			dst := e.WoW.SVPath(gameVer, target, name)
			data, err := os.ReadFile(src)
			if err != nil {
				log = append(log, fmt.Sprintf("   SKIP  %s.lua (missing in source)", name))
			} else {
				os.MkdirAll(filepath.Dir(dst), 0755)
				os.WriteFile(dst, data, 0644)
				log = append(log, fmt.Sprintf("   COPY  %s.lua", name))
			}
			done++
			if cb != nil {
				cb(float64(done)/float64(total), "Copying "+name+"…")
			}
		}
	}
	return log
}

// ── sync: merge ──

func (e *SyncEngine) SyncMerge(gameVer string, accounts []string, primary string, files []string, cb func(float64, string)) []string {
	var log []string
	total := len(files) * len(accounts) * 2
	done := 0

	for _, name := range files {
		log = append(log, fmt.Sprintf("── Merging %s.lua ──", name))

		parsed := make(map[string]*LuaFile)
		for _, acct := range accounts {
			src := e.WoW.SVPath(gameVer, acct, name)
			f, err := ParseLuaFile(src)
			if err == nil {
				parsed[acct] = f
				log = append(log, fmt.Sprintf("   READ  %s", acct))
			} else if os.IsNotExist(err) {
				log = append(log, fmt.Sprintf("   SKIP  %s (no file)", acct))
			} else {
				log = append(log, fmt.Sprintf("   ERROR reading %s: %v", acct, err))
			}
			done++
			if cb != nil {
				cb(float64(done)/float64(total), fmt.Sprintf("Reading %s from %s…", name, acct))
			}
		}

		if len(parsed) < 1 {
			log = append(log, "   Nothing to merge.")
			done += len(accounts)
			continue
		}

		// Build merged result: non-primary first, primary last (wins scalars)
		merged := NewLuaFile()
		for _, acct := range accounts {
			if acct == primary {
				continue
			}
			f, ok := parsed[acct]
			if !ok {
				continue
			}
			for _, varName := range f.order {
				val := f.vars[varName]
				if existing, exists := merged.vars[varName]; exists {
					eMap, eOK := existing.(*OrderedMap)
					vMap, vOK := val.(*OrderedMap)
					if eOK && vOK {
						merged.Set(varName, DeepMerge(eMap, vMap))
						continue
					}
				}
				merged.Set(varName, val)
			}
		}
		// Primary last
		if pf, ok := parsed[primary]; ok {
			for _, varName := range pf.order {
				val := pf.vars[varName]
				if existing, exists := merged.vars[varName]; exists {
					eMap, eOK := existing.(*OrderedMap)
					vMap, vOK := val.(*OrderedMap)
					if eOK && vOK {
						merged.Set(varName, DeepMerge(eMap, vMap))
						continue
					}
				}
				merged.Set(varName, val)
			}
		}

		// Write to all accounts
		for _, acct := range accounts {
			e.CreateBackup(gameVer, acct, []string{name})
			dst := e.WoW.SVPath(gameVer, acct, name)
			os.MkdirAll(filepath.Dir(dst), 0755)
			if err := WriteLuaFile(dst, merged); err != nil {
				log = append(log, fmt.Sprintf("   ERROR writing %s: %v", acct, err))
			} else {
				log = append(log, fmt.Sprintf("   WRITE %s", acct))
			}
			done++
			if cb != nil {
				cb(float64(done)/float64(total), fmt.Sprintf("Writing %s to %s…", name, acct))
			}
		}
	}
	return log
}

// ── convenience ──

func (e *SyncEngine) UnionSVFiles(gameVer string, accounts []string) []string {
	seen := map[string]bool{}
	for _, acct := range accounts {
		for _, f := range e.WoW.SVFiles(gameVer, acct) {
			seen[f] = true
		}
	}
	var out []string
	for f := range seen {
		out = append(out, f)
	}
	sort.Strings(out)
	return out
}
