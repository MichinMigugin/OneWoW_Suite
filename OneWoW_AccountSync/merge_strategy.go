package main

import (
	"fmt"
	"sort"
)

// ── Strategy types ──────────────────────────────────────────────

type MergeKind int

const (
	// MergeDeep performs a standard recursive deep merge.
	// Safe for maps keyed by character name, note IDs, etc.
	MergeDeep MergeKind = iota

	// MergePrimaryWins copies the entire file from the primary account.
	// Used for pure-settings addons where combining makes no sense.
	MergePrimaryWins

	// MergeCharacterMap deep-merges the "characters" sub-key and uses
	// primary-wins for everything else (settings, version, etc.).
	MergeCharacterMap

	// MergeAccounting concatenates the transactions array, recomputes
	// statistics, and uses primary-wins for settings.
	MergeAccounting

	// MergeNotRecommended means the file should not be merged.
	MergeNotRecommended
)

// AddonInfo describes a OneWoW SavedVariables file and how to merge it.
type AddonInfo struct {
	FileName    string // e.g. "OneWoW_AltTracker_Character"
	Label       string
	Description string
	Kind        MergeKind
	Recommended bool // show in "Suggested Merges"
}

// Registry of all OneWoW SavedVariables with merge strategies.
var addonRegistry = []AddonInfo{
	// ── Recommended merges (character/roster data) ──
	{
		FileName: "OneWoW_AltTracker_Character", Label: "Alt Tracker — Characters",
		Description: "Character roster, stats, equipment, currencies, action bars",
		Kind: MergeCharacterMap, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Storage", Label: "Alt Tracker — Storage",
		Description: "Bags, personal bank, mail, warband bank, guild banks",
		Kind: MergeCharacterMap, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Accounting", Label: "Alt Tracker — Accounting",
		Description: "Gold transactions, income/expense history",
		Kind: MergeAccounting, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Auctions", Label: "Alt Tracker — Auctions",
		Description: "Auction house data per character",
		Kind: MergeCharacterMap, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Collections", Label: "Alt Tracker — Collections",
		Description: "Mounts, pets, toys, transmog",
		Kind: MergeDeep, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Endgame", Label: "Alt Tracker — Endgame",
		Description: "Mythic+, raids, weekly progress",
		Kind: MergeCharacterMap, Recommended: true,
	},
	{
		FileName: "OneWoW_AltTracker_Professions", Label: "Alt Tracker — Professions",
		Description: "Profession skill data per character",
		Kind: MergeCharacterMap, Recommended: true,
	},
	{
		FileName: "OneWoW_Notes", Label: "Notes",
		Description: "Player, NPC, zone, and item notes",
		Kind: MergeDeep, Recommended: true,
	},
	{
		FileName: "OneWoW_ShoppingList", Label: "Shopping List",
		Description: "Shopping lists and tracked items",
		Kind: MergeDeep, Recommended: true,
	},
	{
		FileName: "OneWoW_Trackers", Label: "Trackers",
		Description: "Custom tracking data",
		Kind: MergeDeep, Recommended: true,
	},

	// ── Settings-only (primary wins) ──
	{
		FileName: "OneWoW", Label: "OneWoW Hub",
		Description: "Hub settings, profiles, UI preferences",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_GUI", Label: "GUI Library",
		Description: "Theme and UI framework settings",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_AltTracker", Label: "Alt Tracker — Core",
		Description: "Core alt tracker settings and migration state",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_Bags", Label: "Bags",
		Description: "Bag UI settings",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_Catalog", Label: "Catalog",
		Description: "Catalog browser UI settings",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_DirectDeposit", Label: "Direct Deposit",
		Description: "Auto-deposit settings",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_QoL", Label: "Quality of Life",
		Description: "QoL feature settings",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_Utility_DevTool", Label: "Dev Tool",
		Description: "Developer utility settings",
		Kind: MergePrimaryWins, Recommended: false,
	},

	// ── Minimap icon state (primary wins) ──
	{
		FileName: "OneWoW_DirectDeposit_MinimapLDBIconDB", Label: "Direct Deposit — Minimap",
		Description: "Minimap button position",
		Kind: MergePrimaryWins, Recommended: false,
	},
	{
		FileName: "OneWoW_ShoppingList_MinimapLDBIconDB", Label: "Shopping List — Minimap",
		Description: "Minimap button position",
		Kind: MergePrimaryWins, Recommended: false,
	},

	// ── Do NOT merge ──
	{
		FileName: "OneWoW_CatalogData_Journal", Label: "Catalog Data — Journal",
		Description: "Static reference data (do not merge)",
		Kind: MergeNotRecommended, Recommended: false,
	},
	{
		FileName: "OneWoW_CatalogData_Quests", Label: "Catalog Data — Quests",
		Description: "Static reference data (do not merge)",
		Kind: MergeNotRecommended, Recommended: false,
	},
	{
		FileName: "OneWoW_CatalogData_Tradeskills", Label: "Catalog Data — Tradeskills",
		Description: "Static reference data (do not merge)",
		Kind: MergeNotRecommended, Recommended: false,
	},
	{
		FileName: "OneWoW_CatalogData_Vendors", Label: "Catalog Data — Vendors",
		Description: "Static reference data (do not merge)",
		Kind: MergeNotRecommended, Recommended: false,
	},
	{
		FileName: "OneWoW_AHPrices", Label: "AH Prices",
		Description: "Auction house price cache (do not merge)",
		Kind: MergeNotRecommended, Recommended: false,
	},
}

func LookupAddon(fileName string) *AddonInfo {
	for i := range addonRegistry {
		if addonRegistry[i].FileName == fileName {
			return &addonRegistry[i]
		}
	}
	return nil
}

func SuggestedFileNames() []string {
	var out []string
	for _, a := range addonRegistry {
		if a.Recommended {
			out = append(out, a.FileName)
		}
	}
	return out
}

func AllOneWoWFileNames() []string {
	var out []string
	for _, a := range addonRegistry {
		if a.Kind != MergeNotRecommended {
			out = append(out, a.FileName)
		}
	}
	return out
}

// ── Smart merge ─────────────────────────────────────────────────

// SmartMerge merges a single SavedVariables file across accounts using
// the appropriate strategy for that addon.
func SmartMerge(fileName string, files map[string]*LuaFile, primary string, accounts []string) *LuaFile {
	info := LookupAddon(fileName)
	kind := MergeDeep
	if info != nil {
		kind = info.Kind
	}

	switch kind {
	case MergePrimaryWins:
		if f, ok := files[primary]; ok {
			return f
		}
		// Fall through to first available
		for _, acct := range accounts {
			if f, ok := files[acct]; ok {
				return f
			}
		}
		return NewLuaFile()

	case MergeCharacterMap:
		return mergeCharacterMap(files, primary, accounts)

	case MergeAccounting:
		return mergeAccounting(files, primary, accounts)

	default: // MergeDeep
		return mergeDeepAllAccounts(files, primary, accounts)
	}
}

// mergeDeepAllAccounts: standard deep merge, primary applied last.
func mergeDeepAllAccounts(files map[string]*LuaFile, primary string, accounts []string) *LuaFile {
	merged := NewLuaFile()
	for _, acct := range accounts {
		if acct == primary {
			continue
		}
		f, ok := files[acct]
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
	if pf, ok := files[primary]; ok {
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
	return merged
}

// mergeCharacterMap: deep-merges the "characters" key inside the root
// variable, uses primary-wins for all other keys (settings, version, etc.).
func mergeCharacterMap(files map[string]*LuaFile, primary string, accounts []string) *LuaFile {
	merged := NewLuaFile()

	// Start with primary as base for settings
	if pf, ok := files[primary]; ok {
		for _, varName := range pf.order {
			merged.Set(varName, pf.vars[varName])
		}
	}

	// Now merge in characters from all accounts
	for _, acct := range accounts {
		f, ok := files[acct]
		if !ok {
			continue
		}
		for _, varName := range f.order {
			val := f.vars[varName]
			rootMap, isMap := val.(*OrderedMap)
			if !isMap {
				if acct == primary {
					merged.Set(varName, val)
				}
				continue
			}

			existingVal, exists := merged.vars[varName]
			if !exists {
				merged.Set(varName, rootMap)
				continue
			}
			existingMap, existingIsMap := existingVal.(*OrderedMap)
			if !existingIsMap {
				if acct == primary {
					merged.Set(varName, val)
				}
				continue
			}

			// Merge "characters" key (union by charKey)
			mergeSubKey(existingMap, rootMap, "characters")
			// Merge "char" key (AceDB character scope)
			mergeSubKey(existingMap, rootMap, "char")
			// Merge "profileKeys" (AceDB)
			mergeSubKey(existingMap, rootMap, "profileKeys")
			// Merge "guildBanks" if present
			mergeSubKey(existingMap, rootMap, "guildBanks")
			// For warbandBank, use the one with the latest lastUpdateTime
			mergeByTimestamp(existingMap, rootMap, "warbandBank", "lastUpdateTime")
		}
	}
	return merged
}

// mergeSubKey deep-merges a specific key from src into dst.
func mergeSubKey(dst, src *OrderedMap, key string) {
	srcVal, srcOK := src.Get(key)
	if !srcOK {
		return
	}
	srcMap, srcIsMap := srcVal.(*OrderedMap)
	if !srcIsMap {
		return
	}
	dstVal, dstOK := dst.Get(key)
	if !dstOK {
		dst.Set(key, srcMap)
		return
	}
	dstMap, dstIsMap := dstVal.(*OrderedMap)
	if !dstIsMap {
		dst.Set(key, srcMap)
		return
	}
	dst.Set(key, DeepMerge(dstMap, srcMap))
}

// mergeByTimestamp picks the sub-table with the higher timestamp field.
func mergeByTimestamp(dst, src *OrderedMap, key, tsField string) {
	srcVal, srcOK := src.Get(key)
	if !srcOK {
		return
	}
	dstVal, dstOK := dst.Get(key)
	if !dstOK {
		dst.Set(key, srcVal)
		return
	}
	srcTS := getNumericField(srcVal, tsField)
	dstTS := getNumericField(dstVal, tsField)
	if srcTS > dstTS {
		dst.Set(key, srcVal)
	}
}

func getNumericField(val interface{}, field string) float64 {
	m, ok := val.(*OrderedMap)
	if !ok {
		return 0
	}
	v, ok := m.Get(field)
	if !ok {
		return 0
	}
	switch n := v.(type) {
	case int64:
		return float64(n)
	case float64:
		return n
	}
	return 0
}

// ── Accounting merge ────────────────────────────────────────────

// mergeAccounting concatenates transaction arrays and uses primary for settings.
func mergeAccounting(files map[string]*LuaFile, primary string, accounts []string) *LuaFile {
	merged := NewLuaFile()

	// Start with primary as base
	if pf, ok := files[primary]; ok {
		for _, varName := range pf.order {
			merged.Set(varName, pf.vars[varName])
		}
	}

	for _, varName := range merged.order {
		rootVal := merged.vars[varName]
		rootMap, isMap := rootVal.(*OrderedMap)
		if !isMap {
			continue
		}

		// Collect all transactions from all accounts
		var allTx []interface{}
		seenIDs := map[string]bool{}

		for _, acct := range accounts {
			f, ok := files[acct]
			if !ok {
				continue
			}
			av, ok := f.vars[varName]
			if !ok {
				continue
			}
			am, ok := av.(*OrderedMap)
			if !ok {
				continue
			}
			txVal, ok := am.Get("transactions")
			if !ok {
				continue
			}
			txList, ok := txVal.([]interface{})
			if !ok {
				continue
			}
			for _, tx := range txList {
				txMap, ok := tx.(*OrderedMap)
				if !ok {
					allTx = append(allTx, tx)
					continue
				}
				// Deduplicate by id field
				idVal, hasID := txMap.Get("id")
				idStr := fmt.Sprintf("%v", idVal)
				if hasID && seenIDs[idStr] {
					continue
				}
				if hasID {
					seenIDs[idStr] = true
				}
				allTx = append(allTx, tx)
			}
		}

		// Sort by timestamp descending
		sort.SliceStable(allTx, func(i, j int) bool {
			ti := getTxTimestamp(allTx[i])
			tj := getTxTimestamp(allTx[j])
			return ti > tj
		})

		// Reassign sequential IDs
		for i, tx := range allTx {
			if txMap, ok := tx.(*OrderedMap); ok {
				txMap.Set("id", int64(i+1))
			}
		}

		rootMap.Set("transactions", allTx)

		// Recompute statistics from merged transactions
		recomputeStats(rootMap, allTx)
	}

	return merged
}

func getTxTimestamp(tx interface{}) float64 {
	m, ok := tx.(*OrderedMap)
	if !ok {
		return 0
	}
	v, ok := m.Get("timestamp")
	if !ok {
		return 0
	}
	switch n := v.(type) {
	case int64:
		return float64(n)
	case float64:
		return n
	}
	return 0
}

func recomputeStats(root *OrderedMap, transactions []interface{}) {
	var totalIncome, totalExpense float64
	for _, tx := range transactions {
		m, ok := tx.(*OrderedMap)
		if !ok {
			continue
		}
		amtVal, ok := m.Get("amount")
		if !ok {
			continue
		}
		var amt float64
		switch a := amtVal.(type) {
		case int64:
			amt = float64(a)
		case float64:
			amt = a
		default:
			continue
		}
		typeVal, _ := m.Get("type")
		typeStr, _ := typeVal.(string)
		if typeStr == "income" {
			totalIncome += amt
		} else {
			totalExpense += amt
		}
	}

	stats := NewOrderedMap()
	stats.Set("totalIncome", int64(totalIncome))
	stats.Set("totalExpense", int64(totalExpense))
	stats.Set("netProfit", int64(totalIncome-totalExpense))
	stats.Set("lastCalculated", int64(0)) // will be set by addon on next load
	root.Set("statistics", stats)
}
