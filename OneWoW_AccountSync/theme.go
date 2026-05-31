package main

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

// OneWoW "Classic Gold" palette — from OneWoW_GUI Constants.lua THEMES.gold
var (
	colBgPrimary     = color.NRGBA{R: 0x1C, G: 0x1A, B: 0x14, A: 0xFF}
	colBgSecondary   = color.NRGBA{R: 0x14, G: 0x12, B: 0x0D, A: 0xFF}
	colBgTertiary    = color.NRGBA{R: 0x24, G: 0x1F, B: 0x17, A: 0xFF}
	colBgHover       = color.NRGBA{R: 0x2E, G: 0x29, B: 0x1F, A: 0xFF}
	colAccentPrimary = color.NRGBA{R: 0xD9, G: 0xA6, B: 0x33, A: 0xFF}
	colAccentHigh    = color.NRGBA{R: 0xF2, G: 0xBF, B: 0x4D, A: 0xFF}
	colAccentMuted   = color.NRGBA{R: 0x99, G: 0x73, B: 0x26, A: 0xCC}
	colAccentSec     = color.NRGBA{R: 0xB8, G: 0x8C, B: 0x2E, A: 0xFF}
	colTextPrimary   = color.NRGBA{R: 0xEB, G: 0xE6, B: 0xD9, A: 0xFF}
	colTextSecondary = color.NRGBA{R: 0xAD, G: 0xA6, B: 0x94, A: 0xFF}
	colTextAccent    = color.NRGBA{R: 0xF2, G: 0xCC, B: 0x73, A: 0xFF}
	colBorder        = color.NRGBA{R: 0x59, G: 0x4D, B: 0x33, A: 0x80}
	colBorderAccent  = color.NRGBA{R: 0x9E, G: 0x7A, B: 0x38, A: 0xFF}
	colBtnNormal     = color.NRGBA{R: 0x29, G: 0x24, B: 0x1A, A: 0xFF}
	colBtnHover      = color.NRGBA{R: 0x38, G: 0x33, B: 0x24, A: 0xFF}
	colError         = color.NRGBA{R: 0xCC, G: 0x44, B: 0x44, A: 0xFF}
	colSuccess       = color.NRGBA{R: 0x59, G: 0xB3, B: 0x59, A: 0xFF}
	colShadow        = color.NRGBA{R: 0x00, G: 0x00, B: 0x00, A: 0x66}
)

type oneWoWTheme struct{}

var _ fyne.Theme = (*oneWoWTheme)(nil)

func (t *oneWoWTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	// backgrounds
	case theme.ColorNameBackground:
		return colBgPrimary
	case theme.ColorNameOverlayBackground:
		return colBgSecondary
	case theme.ColorNameMenuBackground:
		return colBgTertiary
	case theme.ColorNameInputBackground:
		return colBgSecondary
	case theme.ColorNameHeaderBackground:
		return colBgTertiary
	case theme.ColorNameHover:
		return colBgHover
	case theme.ColorNameDisabledButton:
		return colBgTertiary
	case theme.ColorNameInputBorder:
		return colBorder

	// accents
	case theme.ColorNamePrimary:
		return colAccentPrimary
	case theme.ColorNameFocus:
		return colAccentHigh
	case theme.ColorNameSelection:
		return colAccentMuted
	case theme.ColorNameHyperlink:
		return colAccentHigh

	// buttons
	case theme.ColorNameButton:
		return colBtnNormal

	// text
	case theme.ColorNameForeground:
		return colTextPrimary
	case theme.ColorNameDisabled:
		return colTextSecondary
	case theme.ColorNamePlaceHolder:
		return colTextSecondary

	// status
	case theme.ColorNameError:
		return colError
	case theme.ColorNameSuccess:
		return colSuccess
	case theme.ColorNameWarning:
		return colAccentPrimary

	// decorations
	case theme.ColorNameShadow:
		return colShadow
	case theme.ColorNameSeparator:
		return colBorder

	// scroll
	case theme.ColorNameScrollBar:
		return colAccentMuted
	}

	return theme.DefaultTheme().Color(name, variant)
}

func (t *oneWoWTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DefaultTheme().Font(style)
}

func (t *oneWoWTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (t *oneWoWTheme) Size(name fyne.ThemeSizeName) float32 {
	switch name {
	case theme.SizeNamePadding:
		return 6
	case theme.SizeNameInnerPadding:
		return 4
	case theme.SizeNameText:
		return 13
	case theme.SizeNameSubHeadingText:
		return 15
	case theme.SizeNameHeadingText:
		return 20
	case theme.SizeNameSeparatorThickness:
		return 1
	case theme.SizeNameScrollBarSmall:
		return 4
	case theme.SizeNameScrollBar:
		return 8
	}
	return theme.DefaultTheme().Size(name)
}
