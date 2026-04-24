## UI Escape Sequences

Many UI elements that display text on the screen support special escape sequences starting with the pipe character.

---

### Coloring

#### Hexadecimal Coloring
**`|cAARRGGBBtext|r`**
Each pair of digits represents a color value as a hexadecimal number. The **alpha (AA)** value is currently ignored and should always be **FF**.

The **`|r`** escape sequence pops nested color sequences in-order.

* **/run print("this is \124cFFFF0000red and \124cFF00FF00this is green \124r back to red \124r back to white")**
* **Result:** this is red and this is green back to red back to white

#### Global Colors
**`|cncolorname:text|r`**
Renders a text string with a named global color.

* **/run print("Normal Text \124cmPURE_GREEN_COLOR: Green Text \124cnPURE_RED_COLOR: Red Text \124r Green Text\124r Normal Text")**

#### Item Quality Colors
**`|cnIQn:text|r`**
Renders a text string using an item quality color, where **n** is a numeric `Enum.ItemQuality` value. The color will update to match user settings for color overrides.

* **/run print("Normal Text \124cnIQ4: Epic Item Quality Text\124r Normal Text")**

---

### Textures

**`|Tpath:height:width[:offsetX:offsetY:textureWidth:textureHeight:leftTexel:rightTexel:topTexel:bottomTexel[:rVertexColor:gVertexColor:bVertexColor]]|t`**

Inserts a texture into a font string.
* **height / width:** Controls the size. If height is 0, it often defaults to the text height.
* **offsets:** Shifts the texture from its normal placement.
* **textureWidth / textureHeight:** Size of the source image in pixels.
* **texels:** Coordinates (non-normalized) that identify edges.
* **VertexColor:** RGB values (0-255) used to tint the texture.

**Note:** To display a simple square icon (spell/item), use: `|Tpath:0|t`.

---

### Texture Atlas

**`|A:atlas:height:width[:offsetX:offsetY[:rVertexColor:gVertexColor:bVertexColor]]|a`**
Atlases allow for getting part of a texture without manually defining texture coordinates.

---

### Kstrings

**`|Kq1|k`**
Prevents strings from being parsed by addons by acting as a replacement for the actual string.
* **q:** For confidentiality of Battle.net account names.
* **s:** For names and comments in group finder listings.
* **u:** Prevents using message history as data storage.
* **v:** For messages in community channels.

---

### Grammar and Localization

* **Korean Postpositions (`|1A;B;`):** Used for particles like *Eul/Reul* depending on whether the preceding word ends in a consonant or vowel.
* **French Prepositions (`|2 text`):** Switches between *de* (consonant) and *d'* (vowel).
* **Russian Declension (`|3-id(text)`):** Handles different noun forms based on usage.
* **Plural (`number |4singular:plural;`):** Assigns singular or plural forms based on the provided number.
* **A or An (`|5 text`):** Chooses the correct indefinite article. Adding a space (e.g., `| 5`) can uppercase the article.
* **Lowercase (`|6 TEXT`):** Converts the next word (or parenthesized words) to lowercase.

---

### Other Sequences

* **Word Wrapping (`|Wtext|w`):** Hints that word wrapping should be avoided for the enclosed text where possible.
* **Newline (`|n`):** Inserts a newline if the widget supports it.
* **Escape Pipe (`||`):** Escapes the pipe character itself.