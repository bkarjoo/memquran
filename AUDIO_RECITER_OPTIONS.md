# Quran Audio Reciter Options - Better Alternatives

## Current Implementation
- **API**: AlQuran.cloud
- **Reciter**: ar.alafasy (Mishary Alafasy)
- **Quality**: 128kbps
- **Issue**: Audio quality not satisfactory

## Recommended Better Options

### 🎯 Best for Memorization (Slow, Teaching Style)

#### 1. **Mahmoud Khalil Al-Husary (Mujawwad)**
- **Style**: Slow, melodic recitation specifically for learning
- **AlQuran.cloud**: `ar.husarymujawwad` (128kbps)
- **everyayah.com**: `Husary_128kbps_Mujawwad`
- **URL Example**: `https://everyayah.com/data/Husary_128kbps_Mujawwad/001001.mp3`
- **Why**: Clear pronunciation, slow pace, ideal for memorization

#### 2. **Mohamed Siddiq al-Minshawi (Mujawwad)**
- **Style**: Very slow and melodic, excellent for memorization
- **AlQuran.cloud**: `ar.minshawimujawwad` (translation type)
- **everyayah.com**: `Minshawi_Mujawwad_128kbps`
- **URL Example**: `https://everyayah.com/data/Minshawi_Mujawwad_128kbps/001001.mp3`
- **Why**: Extremely clear, slow pace, beautiful voice

### 🎖️ High Quality Audio Options

#### 3. **Abdul Basit Abdul Samad (Murattal)**
- **Style**: Normal speed, crystal clear recitation
- **Quality**: **192kbps** (highest available)
- **AlQuran.cloud**: `ar.abdulbasitmurattal` (192kbps)
- **everyayah.com**: `Abdul_Basit_Murattal_192kbps`
- **URL Example**: `https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/001001.mp3`
- **Why**: Famous reciter, highest audio quality, clear pronunciation

#### 4. **Abu Bakr al-Shatri**
- **Style**: Clear, moderate pace
- **AlQuran.cloud**: `ar.shaatree` (128kbps)
- **everyayah.com**: `Abu_Bakr_Ash-Shaatree_128kbps`
- **URL Example**: `https://everyayah.com/data/Abu_Bakr_Ash-Shaatree_128kbps/001001.mp3`
- **Why**: Popular for memorization, clear pronunciation

### 🔥 Popular Contemporary Reciters

#### 5. **Maher Al Muaiqly**
- **Style**: Emotional, powerful recitation
- **AlQuran.cloud**: `ar.mahermuaiqly`
- **everyayah.com**: `Maher_AlMuaiqly_64kbps`
- **Why**: Imam of Masjid al-Haram, beautiful voice

#### 6. **Muhammad Jibreel**
- **Style**: Emotional, touching recitation
- **AlQuran.cloud**: `ar.muhammadjibreel` (128kbps)
- **everyayah.com**: `Muhammad_Jibreel_128kbps`
- **Why**: Very emotional recitation, popular for listening

#### 7. **Muhammad Ayyoub**
- **Style**: Deep, powerful voice
- **AlQuran.cloud**: `ar.muhammadayyoub`
- **Why**: Former imam of Masjid al-Nabawi, distinct voice

## All Available Reciters from AlQuran.cloud

| Identifier | Reciter Name | Type | Quality |
|------------|--------------|------|---------|
| `ar.abdulbasitmurattal` | Abdul Basit (Murattal) | translation | 192kbps |
| `ar.abdullahbasfar` | Abdullah Basfar | versebyverse | 128kbps |
| `ar.abdurrahmaansudais` | Abdurrahmaan As-Sudais | versebyverse | 128kbps |
| `ar.abdulsamad` | Abdul Samad | versebyverse | 128kbps |
| `ar.shaatree` | Abu Bakr Ash-Shaatree | versebyverse | 128kbps |
| `ar.ahmedajamy` | Ahmed ibn Ali al-Ajamy | versebyverse | 128kbps |
| `ar.alafasy` | Alafasy (current) | versebyverse | 128kbps |
| `ar.hanirifai` | Hani Rifai | versebyverse | 128kbps |
| `ar.husary` | Husary | versebyverse | 128kbps |
| `ar.husarymujawwad` | Husary (Mujawwad) | versebyverse | 128kbps |
| `ar.hudhaify` | Hudhaify | versebyverse | 128kbps |
| `ar.ibrahimakhbar` | Ibrahim Akhdar | versebyverse | 128kbps |
| `ar.mahermuaiqly` | Maher Al Muaiqly | versebyverse | 128kbps |
| `ar.minshawi` | Minshawi | translation | - |
| `ar.minshawimujawwad` | Minshawy (Mujawwad) | translation | - |
| `ar.muhammadayyoub` | Muhammad Ayyoub | versebyverse | 128kbps |
| `ar.muhammadjibreel` | Muhammad Jibreel | versebyverse | 128kbps |
| `ar.saoodshuraym` | Saood Ash-Shuraym | versebyverse | 128kbps |
| `ar.parhizgar` | Parhizgar | versebyverse | 128kbps |
| `ar.aymanswoaid` | Ayman Sowaid | versebyverse | 128kbps |

## Alternative Audio Sources

### 1. everyayah.com (Direct CDN Access)
- **Format**: `https://everyayah.com/data/{RECITER_FOLDER}/{SSSAAA}.mp3`
- **Example**: `https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/001001.mp3`
- **Pros**:
  - Higher quality options (up to 192kbps)
  - Reliable BunnyCDN hosting
  - Multiple bitrate options per reciter
- **Cons**:
  - No API for metadata
  - Need to construct URLs manually

### 2. Quran.com API (with quranicaudio.com hosting)
- **API**: `https://api.quran.com/api/v4/recitations/{reciter_id}/by_ayah/{verse_key}`
- **Example Response**: `{"audio_files": [{"verse_key": "1:1", "url": "Alafasy/mp3/001001.mp3"}]}`
- **Base URL**: `https://verses.quran.com/` or `https://download.quranicaudio.com/`
- **Pros**:
  - Well-documented API
  - Verse timing data available
  - Chapter and verse-level audio
- **Cons**:
  - Fewer reciter options
  - May require more complex integration

### 3. Quran Foundation API (api-docs.quran.foundation)
- **Features**: Word-level timing data with `segments=true`
- **Pros**: Most detailed timing information for highlighting words
- **Cons**: Requires authentication, rate-limited

## Recommendation for Implementation

### Immediate Improvement (Easy to Implement)
Simply change the reciter identifier in `AudioService.swift`:

```swift
// Current (line 10):
private let reciterIdentifier = "ar.alafasy"  // Mishary Alafasy

// Change to one of these:
private let reciterIdentifier = "ar.husarymujawwad"  // Best for memorization (slow)
// OR
private let reciterIdentifier = "ar.abdulbasitmurattal"  // Best quality (192kbps)
// OR
private let reciterIdentifier = "ar.shaatree"  // Popular for memorization
```

### Medium-term Enhancement
1. **Add reciter selection in Settings**
2. **Allow user to choose based on preference**:
   - Learning mode: Husary Mujawwad or Minshawi Mujawwad (slow)
   - High quality: Abdul Basit Murattal (192kbps)
   - Contemporary: Maher Al Muaiqly or Muhammad Jibreel

### Long-term Enhancement
1. **Switch to everyayah.com for higher quality**
2. **Implement multiple quality options** (64kbps for data saving, 192kbps for quality)
3. **Add reciter profiles** with samples for preview
4. **Implement speed control** for any reciter

## Audio Quality Comparison

| Source | Reciter | Bitrate | File Size (1:1) | CDN |
|--------|---------|---------|-----------------|-----|
| AlQuran.cloud | Alafasy | 128kbps | ~40KB | CloudFlare |
| AlQuran.cloud | Abdul Basit | 192kbps | ~60KB | CloudFlare |
| everyayah.com | Abdul Basit | 192kbps | ~60KB | BunnyCDN |
| everyayah.com | Husary Mujawwad | 128kbps | ~168KB | BunnyCDN |

## Test URLs (Verse 1:1 - Bismillah)

```bash
# Current (Alafasy 128kbps):
https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3

# Husary Mujawwad (Slow, for learning):
https://cdn.islamic.network/quran/audio/128/ar.husarymujawwad/1.mp3
https://everyayah.com/data/Husary_128kbps_Mujawwad/001001.mp3

# Abdul Basit (Highest quality 192kbps):
https://cdn.islamic.network/quran/audio/192/ar.abdulbasitmurattal/1.mp3
https://everyayah.com/data/Abdul_Basit_Murattal_192kbps/001001.mp3

# Abu Bakr Ash-Shaatree (Popular for memorization):
https://cdn.islamic.network/quran/audio/128/ar.shaatree/1.mp3
```

## Next Steps

1. **Test different reciters** by listening to sample verses
2. **Choose primary reciter** based on user preference
3. **Consider implementing reciter selection** in Settings
4. **Evaluate switching to everyayah.com** for higher quality options
