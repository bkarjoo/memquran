# MemQuran TODO

## Next Actions

- [ ] Enable CloudKit sync (requires Apple Developer account & code signing)
  - [ ] Sign up for Apple Developer account
  - [ ] Configure code signing in Xcode
  - [ ] Re-enable CloudKit entitlements
  - [ ] Test sync between devices

## Audio Memorization Mode

- [ ] Create `AudioService` class to handle API calls to AlQuran.cloud
  - [ ] Implement verse audio fetching with ar.alafasy
  - [ ] Handle 128/64 kbps quality selection
  - [ ] Add error handling for network failures

- [ ] Design `AudioMemorizationView` UI for hands-free mode
  - [ ] Large play/pause button for easy tapping while driving
  - [ ] Current verse display (Arabic text)
  - [ ] Progress indicator showing current verse on page
  - [ ] Skip/previous verse controls

- [ ] Implement intelligent verse caching
  - [ ] Fetch next verse during practice pause
  - [ ] Keep up to 10 verses in memory cache
  - [ ] Allow quick access to recently practiced verses

- [ ] Add practice pause system matching reciter duration
  - [ ] Pause duration equals the audio duration of the verse
  - [ ] Short verses get short pauses, long verses get long pauses
  - [ ] Visual indicator during practice pause

- [ ] Implement page-based audio progression
  - [ ] Start with current page verses
  - [ ] Auto-advance through all verses on page
  - [ ] Automatically turn to next page when page completes
  - [ ] Continue as long as session is active

- [ ] Add network connectivity check
  - [ ] Alert when no internet connection
  - [ ] Disable audio mode when offline
  - [ ] Auto-retry failed fetches with user feedback

## Completed