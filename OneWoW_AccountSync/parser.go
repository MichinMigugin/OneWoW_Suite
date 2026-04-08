package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// ── Token types ─────────────────────────────────────────────────

type tokenKind int

const (
	tkString tokenKind = iota
	tkNumber
	tkTrue
	tkFalse
	tkNil
	tkIdent
	tkLBrace
	tkRBrace
	tkLBracket
	tkRBracket
	tkEquals
	tkComma
	tkSemicolon
)

type token struct {
	kind tokenKind
	val  string
}

// ── Tokeniser ───────────────────────────────────────────────────

func tokenize(input string) ([]token, error) {
	var tokens []token
	i, n := 0, len(input)

	for i < n {
		ch := input[i]

		// whitespace
		if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
			i++
			continue
		}

		// comments
		if i+1 < n && ch == '-' && input[i+1] == '-' {
			if i+3 < n && input[i+2] == '[' && input[i+3] == '[' {
				end := strings.Index(input[i+4:], "]]")
				if end < 0 {
					i = n
				} else {
					i = i + 4 + end + 2
				}
			} else {
				for i < n && input[i] != '\n' {
					i++
				}
			}
			continue
		}

		// long strings [[ ... ]]
		if i+1 < n && ch == '[' && input[i+1] == '[' {
			end := strings.Index(input[i+2:], "]]")
			if end < 0 {
				return nil, fmt.Errorf("unterminated long string at %d", i)
			}
			tokens = append(tokens, token{tkString, input[i+2 : i+2+end]})
			i = i + 2 + end + 2
			continue
		}

		// quoted strings
		if ch == '"' || ch == '\'' {
			s, newI, err := scanString(input, i)
			if err != nil {
				return nil, err
			}
			tokens = append(tokens, token{tkString, s})
			i = newI
			continue
		}

		// numbers (including negative)
		if isDigit(ch) || (ch == '-' && i+1 < n && isDigit(input[i+1])) {
			j := i
			if ch == '-' {
				j++
			}
			for j < n && isDigit(input[j]) {
				j++
			}
			if j < n && input[j] == '.' {
				j++
				for j < n && isDigit(input[j]) {
					j++
				}
			}
			if j < n && (input[j] == 'e' || input[j] == 'E') {
				j++
				if j < n && (input[j] == '+' || input[j] == '-') {
					j++
				}
				for j < n && isDigit(input[j]) {
					j++
				}
			}
			tokens = append(tokens, token{tkNumber, input[i:j]})
			i = j
			continue
		}

		// identifiers / keywords
		if isIdentStart(ch) {
			j := i + 1
			for j < n && isIdentPart(input[j]) {
				j++
			}
			word := input[i:j]
			switch word {
			case "true":
				tokens = append(tokens, token{tkTrue, word})
			case "false":
				tokens = append(tokens, token{tkFalse, word})
			case "nil":
				tokens = append(tokens, token{tkNil, word})
			default:
				tokens = append(tokens, token{tkIdent, word})
			}
			i = j
			continue
		}

		// single-char tokens
		switch ch {
		case '{':
			tokens = append(tokens, token{tkLBrace, "{"})
		case '}':
			tokens = append(tokens, token{tkRBrace, "}"})
		case '[':
			tokens = append(tokens, token{tkLBracket, "["})
		case ']':
			tokens = append(tokens, token{tkRBracket, "]"})
		case '=':
			tokens = append(tokens, token{tkEquals, "="})
		case ',':
			tokens = append(tokens, token{tkComma, ","})
		case ';':
			tokens = append(tokens, token{tkSemicolon, ";"})
		default:
			i++
			continue
		}
		i++
	}
	return tokens, nil
}

func scanString(input string, start int) (string, int, error) {
	quote := input[start]
	var buf strings.Builder
	i := start + 1
	n := len(input)

	for i < n {
		ch := input[i]
		if ch == quote {
			return buf.String(), i + 1, nil
		}
		if ch == '\\' && i+1 < n {
			next := input[i+1]
			switch next {
			case 'n':
				buf.WriteByte('\n')
			case 't':
				buf.WriteByte('\t')
			case 'r':
				buf.WriteByte('\r')
			case '\\':
				buf.WriteByte('\\')
			case '"':
				buf.WriteByte('"')
			case '\'':
				buf.WriteByte('\'')
			case 'a':
				buf.WriteByte('\a')
			case 'b':
				buf.WriteByte('\b')
			case 'f':
				buf.WriteByte('\f')
			case '0':
				buf.WriteByte(0)
			default:
				if isDigit(next) {
					numStr := string(next)
					j := i + 2
					for j < n && j < i+4 && isDigit(input[j]) {
						numStr += string(input[j])
						j++
					}
					v, _ := strconv.Atoi(numStr)
					buf.WriteByte(byte(v))
					i = j
					continue
				}
				buf.WriteByte(next)
			}
			i += 2
			continue
		}
		buf.WriteByte(ch)
		i++
	}
	return "", 0, fmt.Errorf("unterminated string at %d", start)
}

func isDigit(c byte) bool    { return c >= '0' && c <= '9' }
func isIdentStart(c byte) bool { return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') }
func isIdentPart(c byte) bool  { return isIdentStart(c) || isDigit(c) }

// ── Parser ──────────────────────────────────────────────────────

// LuaFile holds top-level variable assignments in order.
type LuaFile struct {
	order []string
	vars  map[string]interface{}
}

func NewLuaFile() *LuaFile {
	return &LuaFile{vars: make(map[string]interface{})}
}

func (f *LuaFile) Set(name string, val interface{}) {
	if _, exists := f.vars[name]; !exists {
		f.order = append(f.order, name)
	}
	f.vars[name] = val
}

type parser struct {
	tokens []token
	pos    int
}

func (p *parser) peek() *token {
	if p.pos < len(p.tokens) {
		return &p.tokens[p.pos]
	}
	return nil
}

func (p *parser) consume() token {
	t := p.tokens[p.pos]
	p.pos++
	return t
}

func (p *parser) expect(kind tokenKind) (string, error) {
	t := p.peek()
	if t == nil {
		return "", fmt.Errorf("unexpected EOF")
	}
	if t.kind != kind {
		return "", fmt.Errorf("expected %d got %d (%q)", kind, t.kind, t.val)
	}
	return p.consume().val, nil
}

func (p *parser) more() bool { return p.pos < len(p.tokens) }

// ParseLuaString parses WoW SavedVariables text.
func ParseLuaString(input string) (*LuaFile, error) {
	toks, err := tokenize(input)
	if err != nil {
		return nil, err
	}
	pa := &parser{tokens: toks}
	f := NewLuaFile()

	for pa.more() {
		t := pa.peek()
		if t.kind == tkIdent {
			name := pa.consume().val
			if _, err := pa.expect(tkEquals); err != nil {
				return nil, err
			}
			val, err := pa.parseValue()
			if err != nil {
				return nil, fmt.Errorf("parsing %s: %w", name, err)
			}
			f.Set(name, val)
		} else {
			pa.consume()
		}
	}
	return f, nil
}

// ParseLuaFile reads and parses a .lua SavedVariables file.
func ParseLuaFile(path string) (*LuaFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseLuaString(string(data))
}

func (p *parser) parseValue() (interface{}, error) {
	t := p.peek()
	if t == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}
	switch t.kind {
	case tkLBrace:
		return p.parseTable()
	case tkString:
		p.consume()
		return t.val, nil
	case tkNumber:
		p.consume()
		if strings.ContainsAny(t.val, ".eE") {
			return strconv.ParseFloat(t.val, 64)
		}
		return strconv.ParseInt(t.val, 10, 64)
	case tkTrue:
		p.consume()
		return true, nil
	case tkFalse:
		p.consume()
		return false, nil
	case tkNil:
		p.consume()
		return nil, nil
	default:
		return nil, fmt.Errorf("unexpected token %d (%q)", t.kind, t.val)
	}
}

func (p *parser) parseTable() (interface{}, error) {
	if _, err := p.expect(tkLBrace); err != nil {
		return nil, err
	}

	type entry struct {
		key, val interface{}
	}
	var entries []entry
	hasExplicit, hasImplicit := false, false

	for p.more() {
		t := p.peek()
		if t.kind == tkRBrace {
			p.consume()
			break
		}

		if t.kind == tkLBracket {
			p.consume()
			key, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			if _, err := p.expect(tkRBracket); err != nil {
				return nil, err
			}
			if _, err := p.expect(tkEquals); err != nil {
				return nil, err
			}
			val, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			entries = append(entries, entry{key, val})
			hasExplicit = true
		} else if t.kind == tkIdent {
			saved := p.pos
			name := p.consume().val
			next := p.peek()
			if next != nil && next.kind == tkEquals {
				p.consume()
				val, err := p.parseValue()
				if err != nil {
					return nil, err
				}
				entries = append(entries, entry{name, val})
				hasExplicit = true
			} else {
				p.pos = saved
				val, err := p.parseValue()
				if err != nil {
					return nil, err
				}
				entries = append(entries, entry{nil, val})
				hasImplicit = true
			}
		} else {
			val, err := p.parseValue()
			if err != nil {
				return nil, err
			}
			entries = append(entries, entry{nil, val})
			hasImplicit = true
		}

		// optional comma / semicolon
		t = p.peek()
		if t != nil && (t.kind == tkComma || t.kind == tkSemicolon) {
			p.consume()
		}
	}

	// Pure array
	if hasImplicit && !hasExplicit {
		list := make([]interface{}, len(entries))
		for i, e := range entries {
			list[i] = e.val
		}
		return list, nil
	}

	// Map (preserves key order & type)
	m := NewOrderedMap()
	autoIdx := int64(1)
	for _, e := range entries {
		if e.key == nil {
			m.Set(autoIdx, e.val)
			autoIdx++
		} else {
			m.Set(e.key, e.val)
		}
	}
	return m, nil
}
