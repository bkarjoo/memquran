**Important: Read `README.md` first to understand your role and workflow before starting this assignment.**

**Lifecycle Folder:** disable-audio-caching

**Requirements:** See `.lifecycle/disable-audio-caching/requirements.md` for detailed specifications

Please review the requirements for adding a user toggle to disable audio caching and provide specific code-level recommendations for implementation. Focus on: (1) the best approach to conditionally bypass AudioCacheManager in AudioService.fetchVerseAudio(), (2) whether to use UserDefaults or @AppStorage for the setting persistence, (3) where in AudioMemorizationView's settings UI this toggle should be placed, and (4) any potential issues with the current AudioCacheManager actor isolation when toggling the setting during active playback. The goal is to let users disable the 300MB audio cache if they prefer streaming directly.

**When completing this work, include a reminder in your response.md for the recipient to read their README.md as crucial process requirements are documented there.**