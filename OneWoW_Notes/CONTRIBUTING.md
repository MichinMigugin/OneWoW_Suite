# Contributing to OneWoW - Notes

Thanks for your interest in contributing! We welcome help with translations and code improvements.

## Translation Contributions (Localizations)

The easiest way to help is by contributing translations for new languages or improving existing ones.

### How to Contribute Translations

1. **Fork** this repository
2. **Edit the locale file** for your language in `Locales/`:
   - `enUS.lua` - English
   - `koKR.lua` - Korean
   - Or create a new locale file for a new language

3. **Test your translation:**
   - Set the locale to your language in WoW settings
   - Open Notes and verify all text displays correctly (no English fallbacks)
   - For Korean testing: Use "TEST" as string values during development

4. **Submit a Pull Request** with your changes

### Translation Guidelines

- **Every user-visible text must be localized** - no English fallbacks
- Strings are already in place, just translate the values
- Test in-game to ensure proper display

## Code Contributions

For code improvements, bug fixes, or new features:

### Before Starting
- **Fork** this repository
- Create a **feature branch** from `main`
- Follow the existing code style

### What We Accept
- Bug fixes
- Performance improvements
- UI/UX enhancements
- Code quality improvements

### Submit Your Pull Request
- Describe the change and why
- Include testing details

**Note:** All submissions require approval before merging.

## Code Standards

- **Localization:** Always use `L["STRING_KEY"]` for user-visible text
- **Testing:** Test in multiple languages
- **Style:** Follow existing patterns

## License

All contributions must be compatible with the project license. By submitting, you agree your work can be included under the same terms.

---

**Thank you for helping improve OneWoW - Notes!**
