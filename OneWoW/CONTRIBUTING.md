# Contributing to OneWoW

Thanks for your interest in contributing! OneWoW is the core hub addon for the OneWoW Suite. We welcome help with translations and code improvements.

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
   - Log in and verify all text displays correctly (no English fallbacks)
   - For Korean testing: Use "TEST" as string values during development

4. **Submit a Pull Request** with your changes
   - Describe which strings you translated
   - Mention the language and any new languages you added

### Translation Guidelines

- **Every user-visible text must be localized** - no English fallbacks
- Strings are already in place, you just need to translate the values
- Test in-game to ensure proper display and formatting
- If adding a new language, copy `enUS.lua` and translate all strings

## Code Contributions

For code improvements, bug fixes, or new features:

### Before Starting
- **Fork** this repository
- Create a **feature branch** from `main` (e.g., `feature/my-improvement`)
- Follow the existing code style and structure

### What We Accept
- Bug fixes
- Performance improvements
- Core addon enhancements
- New features that fit OneWoW's scope
- Code quality improvements

### What We Don't Accept
- Hard-coded English text (must use locale strings)
- Breaking changes to the core API
- Features that require external dependencies
- Code that breaks localization

### Before Submitting
1. Test thoroughly in-game
2. Verify all localizations still work
3. Follow existing code patterns and naming conventions
4. Make sure your changes work with dependent addons (Notes, AltTracker, Catalog, etc.)

### Submit Your Pull Request
- Describe what the change does and why
- Include testing details
- Reference any related issues

**Note:** All submissions require approval before merging.

## Code Standards

- **Localization:** Always use `L["STRING_KEY"]` for user-visible text
- **Testing:** Test in multiple languages, especially Korean
- **Style:** Follow existing code structure and patterns
- **Comments:** Add only where logic isn't self-evident
- **Dependencies:** Don't add new external libraries without discussion

## Questions?

- **Issues:** Use GitHub Issues for bug reports
- **Discussions:** Use GitHub Discussions for questions and ideas

## License

All contributions must be compatible with the project license. By submitting, you agree your work can be included under the same terms.

---

**Thank you for helping improve OneWoW!**
