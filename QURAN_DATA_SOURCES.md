# Quran Data Sources - Available Data Categories

## Primary Source: Quranic Arabic Corpus (corpus.quran.com)

### 1. Text Data
- **Arabic Text (Uthmani)** - Source: Tanzil project
- **Buckwalter Transliteration** - ASCII representation of Arabic
- **Phonetic Transcription** - Based on "Arabic Through the Quran" by Alan Jones
- **Unicode Encoding** - Standard Unicode text format

### 2. Structural Data
- **Chapters (114 Suras)** - Chapter names, numbers, Bismillah
- **Verses (6,236 total)** - Individual verse text and location
- **Tokens (Words)** - Individual word-level segmentation

### 3. Morphological Analysis (98.7% accuracy)
**Categories:**
- Part-of-Speech
- Root
- Lemma
- Stem
- Person
- Gender
- Number
- Case
- Mood
- Voice
- Aspect
- Verb Form
- Derivation
- State

### 4. Syntactic Analysis
- **Dependency Grammar Treebank** - Syntactic relationships between words
- **Traditional Arabic Grammar** - Based on classical i'rāb approach

### 5. Semantic Data
- **Ontology of Concepts** - Network of 300 concepts with 350 relations
  - Named Entities (historic people and places)
  - Astronomical Bodies
  - Sentient Creations
  - Divine Concepts
  - Textual Entities

### 6. Translation Data
- **Word-by-Word English Translation**
- **Seven Parallel English Translations** (verse level)

### 7. Linguistic Reference
- **Quran Dictionary** - Dictionary of terms
- **Lemma Frequency Lists** - Sorted by usage
- **Grammar Documentation** - Traditional Arabic grammar rules

## Access Methods

### JQuranTree Java API
**Package:** org.jqurantree
- Document, Chapter, Verse, Token classes
- Arabic text with diacritics
- Search capabilities
- Multiple encoding support

### Downloadable Data (Version 0.4)
- XML format
- Plain text format
- Requires email verification
- GNU GPL licensed

## License & Usage
- **License:** GNU General Public License
- **Attribution:** Must cite "Quranic Arabic Corpus" and link to corpus.quran.com
- **Restrictions:** Cannot modify original files, must distribute verbatim

## Data Quality
- Supervised collaborative annotation
- University of Leeds research project
- 2,500+ daily users from 165 countries
