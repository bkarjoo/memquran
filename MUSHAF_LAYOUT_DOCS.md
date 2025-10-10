# Mushaf Layout Documentation

## Overview

The Mushaf Layout refers to the structured data of pages in any Mushaf (printed copy of the Quran).

Layout data is essential for rendering Mushaf pages in digital applications and tools. QUL provides a Mushaf Layout Tool that allows you to design layouts for any Mushaf. Layout data is then exported as downloadable SQLite or JSON files.

## Required Resources

To render a Mushaf layout, you'll need the following resources:

1. **Quran script in word by word format** - See available Quran scripts
2. **Font compatible with your selected Quran script** - See available fonts (we use `ScheherazadeNew-Regular`)
3. **Layout data for selected Mushaf** - See available mushaf layouts
4. **Surah names** - You can download Surah names from Quran metadata resource

## Database Files

We use two SQLite databases:

### 1. Layout Database: `uthmani-15-lines.db`

Contains the `pages` table with line-level layout information.

**Schema:**
```sql
CREATE TABLE pages (
    page_number INTEGER,
    line_number INTEGER,
    line_type TEXT,
    is_centered INTEGER,
    first_word_id INTEGER,
    last_word_id INTEGER,
    surah_number INTEGER
);
```

**Column Descriptions:**

| Column | Description |
|--------|-------------|
| `page_number` | The number of the page in the Mushaf (1-604) |
| `line_number` | The line number on the page (1-15) |
| `line_type` | Type of line: `ayah`, `surah_name`, or `basmallah` |
| `is_centered` | Boolean (0/1) indicating center-aligned (1) or justified (0) |
| `first_word_id` | The ID of the first word on this line |
| `last_word_id` | The ID of the last word on this line |
| `surah_number` | Identifies the Surah displayed on this line |

**Stats:**
- Total pages: 604
- Lines per page: 15
- Total lines: 9,046

### 2. Words Database: `uthmani.db`

Contains the `words` table with individual word data.

**Schema:**
```sql
CREATE TABLE words (
    id INTEGER,
    location TEXT,
    surah INTEGER,
    ayah INTEGER,
    word INTEGER,
    text TEXT
);
```

**Column Descriptions:**

| Column | Description |
|--------|-------------|
| `id` | Unique ID for each word (referenced by `first_word_id`/`last_word_id` in pages table) |
| `location` | Word location in format "surah:ayah:word" (e.g., "2:1:1") |
| `surah` | Surah number (1-114) |
| `ayah` | Ayah number within the surah |
| `word` | Word position within the ayah |
| `text` | Arabic text of the word in Uthmani script |

**Stats:**
- Total words: 83,668

## How to Render a Mushaf Page

To render a page of the Mushaf, follow these steps:

### Step 1: Query the Layout

Query the `pages` table in the layout SQLite database to retrieve the necessary details for each line on the page:

```sql
SELECT page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number
FROM pages
WHERE page_number = ?
ORDER BY line_number;
```

### Step 2: Render Each Line

For each line, based on the `line_type`, determine the content to render:

#### If `line_type` is `ayah`:
1. Query the `words` table to get words between `first_word_id` and `last_word_id`
2. Render each word in order using the `text` column

```sql
SELECT id, location, surah, ayah, word, text
FROM words
WHERE id BETWEEN ? AND ?
ORDER BY id;
```

#### If `line_type` is `surah_name`:
- Render the Surah name on this line
- Use `surah_number` field to get the surah name

#### If `line_type` is `basmallah`:
- Display the Bismillah: "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"

### Step 3: Apply Alignment

Ensure that the text for each line is aligned correctly:
- `is_centered = 1`: Center-align the text
- `is_centered = 0`: Fully justify the text

### Step 4: Repeat

Repeat this process for each line on the page until all 15 lines are rendered.

## Example: Page 2

**Line 1:** `surah_name` - Display "سورة البقرة"
**Line 2:** `basmallah` - Display "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
**Line 3:** `ayah` - Words 37-44 from the words table
**Line 4:** `ayah` - Words 45-51 from the words table
... and so on

## Sample Query Result

### Page 2, Line 3 (Ayah):
```
page_number: 2
line_number: 3
line_type: ayah
is_centered: 1
first_word_id: 37
last_word_id: 44
```

### Words for Line 3:
```
37 | 2:1:1 | 2 | 1 | 1 | الٓمٓ
38 | 2:1:2 | 2 | 1 | 2 | ١
39 | 2:2:1 | 2 | 2 | 1 | ذَٰلِكَ
40 | 2:2:2 | 2 | 2 | 2 | ٱلْكِتَـٰبُ
41 | 2:2:3 | 2 | 2 | 3 | لَا
42 | 2:2:4 | 2 | 2 | 4 | رَيْبَ ۛ
43 | 2:2:5 | 2 | 2 | 5 | فِيهِ ۛ
44 | 2:2:6 | 2 | 2 | 6 | هُدًۭى
```

## Font Information

**Font Family:** `me_quran` (we use `ScheherazadeNew-Regular` which is compatible)

**CSS Integration Example:**
```css
.quran-text {
  font-family: 'ScheherazadeNew-Regular', 'me_quran', 'Amiri', serif;
  direction: rtl;
  text-align: right;
}
```

## Uthmani Script Features

- High-quality Arabic text rendering
- Proper diacritical marks and Tajweed annotations
- Responsive design for different screen sizes
- Word-by-word display for detailed study
- Unicode text for easy copying and searching
- Scalable vector rendering

## Implementation Notes

1. **Word Mapping:** The `id` in the `words` table corresponds to `first_word_id` and `last_word_id` in the `pages` table
2. **Line Count:** Each page always has exactly 15 lines
3. **Page Count:** The complete Mushaf has 604 pages
4. **Right-to-Left:** All Arabic text should be rendered RTL
5. **Font Size:** Should be adjustable while maintaining relative spacing
