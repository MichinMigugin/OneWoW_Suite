# License

Copyright (c) 2026 OneWoW Development Team
https://onewow.net/

The contents of this repository, excluding third-party resources listed in
[THIRD_PARTY.md](THIRD_PARTY.md) and community QoL modules listed in
[MODULE_CREDITS.md](MODULE_CREDITS.md), are copyrighted to the OneWoW
Development Team (the authors who maintain this project) with all rights
reserved.

This is not an OSI open-source license. The source is public so you can
inspect it and contribute.

World of Warcraft and related game data are copyright Blizzard
Entertainment. This file does not grant any rights in Blizzard intellectual
property. OneWoW claims copyright only in original OneWoW code and in the
original arrangement of shipped tables, not in Blizzard's underlying game
data.

Third-party libraries and fonts remain under their own licenses. See
[THIRD_PARTY.md](THIRD_PARTY.md). Community QoL module credit and copyright
follow the rules below and [MODULE_CREDITS.md](MODULE_CREDITS.md).

## QoL modules

Each module under `OneWoW_QoL/Modules/external/<id>/` is credited by the
`author` string in that folder's `module.lua` (shown in the in-game Details
dialog).

- If `author` is omitted or empty, credit and copyright are the OneWoW
  Development Team.
- If `author` is a team credit (for example `OneWoW`, `OneWoW Development
  Team`, or a Development Team member's name on a team-written module), that
  is in-game credit. Copyright in that folder stays with the OneWoW
  Development Team unless the module is listed in MODULE_CREDITS.md.
- If `author` names a **community** contributor, that person keeps copyright
  in that module folder. By submitting a pull request they grant the OneWoW
  Development Team a license to include, maintain, and distribute the module
  as part of official OneWoW under this LICENSE.md. Keep their `author`
  string. List the module in [MODULE_CREDITS.md](MODULE_CREDITS.md).

## You may

1. Install and use OneWoW in World of Warcraft Retail from official
   distribution (CurseForge, the Discord community zip, or this
   repository's releases).
2. Read the source.
3. Modify it for **private personal use** only. Do not distribute those
   modifications.
4. Fork this repository on GitHub **in order to send pull requests** to the
   official project (bug fixes, translations, features, and original QoL
   modules).
5. Write **original** QoL modules under
   `OneWoW_QoL/Modules/external/<id>/` (see
   [OneWoW_QoL/DEVELOPERS.md](OneWoW_QoL/DEVELOPERS.md)) and submit them as
   pull requests. Put your name in `author` so players see it in Details.
   That folder remains your original work; the grant in **QoL modules** above
   lets us ship it with the suite. We keep your credit.
6. Call published `_API` surfaces from other addons (for example OneWoW
   Bags overlays). Integrate; do not copy OneWoW source. Credit OneWoW if
   you depend on it.

## You may not

1. Distribute a modified OneWoW (CurseForge, Wago, GitHub releases, zip, or
   renamed addon folders). A GitHub fork exists for pull requests, not as a
   second product.
2. Copy OneWoW core, Bags, Catalog, shipped databases, GUI toolkit, or
   other suite code into another addon or product, commercially or otherwise.
3. Use OneWoW code or shipped data for a commercial product, or redistribute
   that code or data, except as granted above.
4. Use OneWoW code without keeping copyright notices and credit to the
   OneWoW Development Team, or strip a community module author's credit
   (see MODULE_CREDITS.md).
5. Use a modified copy of OneWoW except privately.
6. Claim the work as your own or remove the OneWoW name from a copy.

All rights not granted above are reserved.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
