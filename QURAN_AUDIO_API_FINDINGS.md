# Quran Audio API Research Findings

## Overview
This document summarizes the findings from researching various Quran APIs that provide audio recitation capabilities for implementing an audio memorization mode.

## 1. Quran Foundation API (api-docs.quran.foundation)

### Audio Endpoints
- **Get chapter's audio file of a reciter**: Individual chapter audio retrieval
- **List of all chapter audio files of a reciter**: Bulk retrieval for a reciter
- **Ayah recitations**: Verse-level audio across various Quranic divisions

### Key Features
- **Word-level timing data**: Available via `segments=true` parameter
  - Returns triplets: [word_index, start_ms, end_ms]
- **Verse timestamp data**: Millisecond offsets for verse synchronization
- **Multiple divisions supported**: Surah, Juz, page, Hizb

### API Requirements
- **Authentication**: Required (returns 401 if unauthorized)
- **Rate limiting**: Enforced (429 responses for exceeded limits)
- **Parameters**:
  - `id`: Reciter identifier (required)
  - `chapter_number`: 1-114 (required)
  - `segments`: Boolean for word-level timing (optional)

### Response Format
```json
{
  "audio_file": {
    "id": number,
    "chapter_id": number,
    "file_size": number,
    "format": "string",
    "audio_url": "string"
  },
  "timestamps": [...],
  "segments": [...]  // If segments=true
}
```

## 2. AlQuran.cloud API

### Base URL
`http://api.alquran.cloud/v1/`

### Audio Endpoints
- **Complete Quran**: `/quran/{edition}`
- **Single Chapter**: `/surah/{surah}/{edition}`
- **Single Verse**: `/ayah/{reference}/{edition}`
  - Reference format: ayah number or `surah:ayah`

### Known Reciters
- **Mishary Alafasy**: `ar.alafasy`
- Additional reciters available (need to query editions endpoint)

### Features
- No authentication required
- Returns JSON format
- Free to use (no documented rate limits)

### Example Calls
```
http://api.alquran.cloud/v1/ayah/262/ar.alafasy
http://api.alquran.cloud/v1/surah/1/ar.alafasy
http://api.alquran.cloud/v1/quran/ar.alafasy
```

## 3. QuranJS API

### Audio Functions
```javascript
// Get all chapters for a reciter
audio.findAllChapterRecitations(reciterId)

// Get specific chapter audio
audio.findChapterRecitationById(chapterId, reciterId)

// Get verse-by-verse audio
audio.findVerseRecitationsByChapter(chapterId, reciterId)
audio.findVerseRecitationsByKey('1:1', reciterId)
audio.findVerseRecitationsByPage(pageNumber, reciterId)
audio.findVerseRecitationsByJuz(juzNumber, reciterId)
audio.findVerseRecitationsByHizb(hizbNumber, reciterId)
audio.findVerseRecitationsByRub(rubNumber, reciterId)
```

### Known Reciters
- **AbdulBaset AbdulSamad**: ID `2`
- Additional reciters available (IDs not documented)

### Features
- JavaScript/TypeScript SDK available
- Supports multiple Quranic divisions
- Verse-level granularity

## 4. MP3Quran.net API

### Features
- Extensive reciter filtering options
- Filter by:
  - Language
  - Reciter code
  - Rewayah (Hafs, Warsh, etc.)
  - Specific surahs
  - Combinations of parameters

### Audio Quality
- Primarily MP3 format
- Various quality levels available

## 5. Quran.com API

### Audio Features
- Verse-by-verse recitations
- Multiple reciters available
- Audio file format: MP3
- URL structure: `https://verses.quran.com/{Reciter}/{Style}/mp3/{SSSAAA}.mp3`
  - SSS = Surah number (padded to 3 digits)
  - AAA = Ayah number (padded to 3 digits)

### Example Audio URLs
```
https://verses.quran.com/AbdulBaset/Mujawwad/mp3/001001.mp3
https://verses.quran.com/AbdulBaset/Murattal/mp3/002255.mp3
```

### Recitation Styles
- **Mujawwad**: Slow, melodic recitation for learning
- **Murattal**: Normal speed recitation

## Recommendations for Implementation

### For Audio Memorization Mode

1. **Primary API Choice**: Quran Foundation API
   - Pros: Word-level timing data, comprehensive verse timestamps
   - Cons: Requires authentication, rate limited

2. **Fallback API**: AlQuran.cloud
   - Pros: No authentication, free, simple to use
   - Cons: Less detailed timing data

3. **For JavaScript/Swift Integration**: QuranJS
   - Pros: Native SDK, good documentation
   - Cons: May need wrapper for Swift

### Key Features to Implement

1. **Verse-by-verse playback** with automatic progression
2. **Repeat options** (single verse, range, full surah)
3. **Speed adjustment** (0.5x, 0.75x, 1x, 1.25x, 1.5x)
4. **Offline caching** of frequently used audio
5. **Multiple reciter selection**
6. **Background playback** for when app is not in focus
7. **Audio controls** (play, pause, skip, previous)
8. **Bookmarking** to resume from last position

### Audio Synchronization Features

Using Quran Foundation API's segments feature:
- Highlight words as they're being recited
- Jump to specific words in audio
- Create fill-in-the-blank memorization tests

### Hands-Free Features for Road Use

1. **Voice commands** or large gesture areas
2. **Auto-repeat** with configurable count
3. **Playlist mode** for multiple surahs
4. **Audio-only interface** with voice feedback
5. **Lock screen controls**

## Next Steps

1. Test API endpoints to verify audio quality
2. Evaluate reciter options for clarity and pronunciation
3. Design caching strategy for offline use
4. Implement audio service layer in Swift
5. Create UI mockups for hands-free mode
6. Test background audio on iOS/macOS

## API Status Summary

| API | Auth Required | Rate Limits | Word Timing | Verse Timing | Free |
|-----|--------------|-------------|-------------|--------------|------|
| Quran Foundation | Yes | Yes | Yes | Yes | Unknown |
| AlQuran.cloud | No | No (documented) | No | No | Yes |
| QuranJS | Unknown | Unknown | No | Yes | Unknown |
| MP3Quran.net | Unknown | Unknown | No | No | Unknown |
| Quran.com | Unknown | Unknown | No | Yes | Unknown |