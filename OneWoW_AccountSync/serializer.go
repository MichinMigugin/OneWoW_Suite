package main

import (
	"fmt"
	"math"
	"os"
	"strings"
)

// SerializeLuaFile writes a LuaFile back to WoW SavedVariables format.
func SerializeLuaFile(f *LuaFile) string {
	var buf strings.Builder
	for _, name := range f.order {
		val := f.vars[name]
		buf.WriteString("\n")
		buf.WriteString(name)
		buf.WriteString(" = ")
		writeValue(&buf, val, 0)
		buf.WriteString("\n")
	}
	return buf.String()
}

// WriteLuaFile serialises and writes to disk.
func WriteLuaFile(path string, f *LuaFile) error {
	data := SerializeLuaFile(f)
	return os.WriteFile(path, []byte(data), 0644)
}

func writeValue(buf *strings.Builder, val interface{}, indent int) {
	switch v := val.(type) {
	case nil:
		buf.WriteString("nil")
	case bool:
		if v {
			buf.WriteString("true")
		} else {
			buf.WriteString("false")
		}
	case int64:
		fmt.Fprintf(buf, "%d", v)
	case float64:
		if v == math.Trunc(v) && !math.IsInf(v, 0) && !math.IsNaN(v) {
			fmt.Fprintf(buf, "%d", int64(v))
		} else {
			fmt.Fprintf(buf, "%g", v)
		}
	case string:
		writeEscaped(buf, v)
	case []interface{}:
		writeList(buf, v, indent)
	case *OrderedMap:
		writeMap(buf, v, indent)
	default:
		buf.WriteString("nil")
	}
}

func writeEscaped(buf *strings.Builder, s string) {
	buf.WriteByte('"')
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '\\':
			buf.WriteString("\\\\")
		case '"':
			buf.WriteString("\\\"")
		case '\n':
			buf.WriteString("\\n")
		case '\r':
			buf.WriteString("\\r")
		case '\t':
			buf.WriteString("\\t")
		case 0:
			buf.WriteString("\\0")
		default:
			buf.WriteByte(s[i])
		}
	}
	buf.WriteByte('"')
}

func writeList(buf *strings.Builder, list []interface{}, indent int) {
	if len(list) == 0 {
		buf.WriteString("{}")
		return
	}
	tabs := strings.Repeat("\t", indent+1)
	close := strings.Repeat("\t", indent)
	buf.WriteString("{\n")
	for _, v := range list {
		buf.WriteString(tabs)
		writeValue(buf, v, indent+1)
		buf.WriteString(",\n")
	}
	buf.WriteString(close)
	buf.WriteByte('}')
}

func writeMap(buf *strings.Builder, m *OrderedMap, indent int) {
	if m.Len() == 0 {
		buf.WriteString("{}")
		return
	}
	tabs := strings.Repeat("\t", indent+1)
	close := strings.Repeat("\t", indent)
	buf.WriteString("{\n")
	for _, e := range m.Entries() {
		buf.WriteString(tabs)
		writeKey(buf, e.Key)
		buf.WriteString(" = ")
		writeValue(buf, e.Value, indent+1)
		buf.WriteString(",\n")
	}
	buf.WriteString(close)
	buf.WriteByte('}')
}

func writeKey(buf *strings.Builder, key interface{}) {
	switch k := key.(type) {
	case string:
		buf.WriteByte('[')
		writeEscaped(buf, k)
		buf.WriteByte(']')
	case int64:
		fmt.Fprintf(buf, "[%d]", k)
	case float64:
		if k == math.Trunc(k) {
			fmt.Fprintf(buf, "[%d]", int64(k))
		} else {
			fmt.Fprintf(buf, "[%g]", k)
		}
	case bool:
		if k {
			buf.WriteString("[true]")
		} else {
			buf.WriteString("[false]")
		}
	default:
		buf.WriteString("[nil]")
	}
}
