package main

import "fmt"

// OrderedMap preserves insertion order and supports mixed key types
// (string or numeric), which Lua tables require.
type OrderedMap struct {
	entries []MapEntry
}

type MapEntry struct {
	Key   interface{} // string | int64 | float64
	Value interface{}
}

func NewOrderedMap() *OrderedMap {
	return &OrderedMap{}
}

func keyString(k interface{}) string {
	return fmt.Sprintf("%v", k)
}

func (m *OrderedMap) Len() int { return len(m.entries) }

func (m *OrderedMap) Get(key interface{}) (interface{}, bool) {
	ks := keyString(key)
	for _, e := range m.entries {
		if keyString(e.Key) == ks {
			return e.Value, true
		}
	}
	return nil, false
}

func (m *OrderedMap) Set(key, value interface{}) {
	ks := keyString(key)
	for i, e := range m.entries {
		if keyString(e.Key) == ks {
			m.entries[i].Value = value
			return
		}
	}
	m.entries = append(m.entries, MapEntry{Key: key, Value: value})
}

func (m *OrderedMap) Entries() []MapEntry {
	return m.entries
}

// DeepMerge combines two OrderedMaps. Overlay values win for scalars;
// nested OrderedMaps are merged recursively.
func DeepMerge(base, overlay *OrderedMap) *OrderedMap {
	result := NewOrderedMap()
	for _, e := range base.entries {
		result.Set(e.Key, e.Value)
	}
	for _, e := range overlay.entries {
		existing, ok := result.Get(e.Key)
		if ok {
			baseMap, bOK := existing.(*OrderedMap)
			overMap, oOK := e.Value.(*OrderedMap)
			if bOK && oOK {
				result.Set(e.Key, DeepMerge(baseMap, overMap))
				continue
			}
		}
		result.Set(e.Key, e.Value)
	}
	return result
}
