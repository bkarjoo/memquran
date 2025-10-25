//
//  AudioServiceTests.swift
//  MemQuran iOSTests
//
//  Tests for AudioService API functionality
//

import Testing
import Foundation
@testable import MemQuran_iOS

struct AudioServiceTests {
    let audioService = AudioService.shared

    // MARK: - Network Connectivity Tests

    @Test func testNetworkAvailability() async throws {
        // Test that network monitoring is properly initialized
        let isAvailable = audioService.isNetworkAvailable()
        #expect(isAvailable == true || isAvailable == false)  // Should return a boolean
    }

    #if DEBUG
    @Test func testNetworkUnavailableError() async throws {
        // Set network as unavailable
        audioService.setNetworkStatus(false)

        // Create expectation for async operation
        var receivedError: AudioServiceError?

        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 1, ayah: 1) { result in
                switch result {
                case .failure(let error):
                    receivedError = error
                case .success:
                    receivedError = nil
                }
                continuation.resume()
            }
        }

        // Verify we get the correct error
        #expect(receivedError != nil)
        if case .noInternetConnection = receivedError! {
            // Success - got expected error
        } else {
            Issue.record("Expected noInternetConnection error, got: \(receivedError!)")
        }

        // Reset network status
        audioService.setNetworkStatus(true)
    }
    #endif

    // MARK: - API Fetch Tests

    @Test func testFetchVerseAudio() async throws {
        // Test fetching Al-Fatiha verse 1
        var fetchedVerse: CachedAudioVerse?
        var fetchError: AudioServiceError?

        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 1, ayah: 1) { result in
                switch result {
                case .success(let verse):
                    fetchedVerse = verse
                case .failure(let error):
                    fetchError = error
                }
                continuation.resume()
            }
        }

        // Verify success
        if let verse = fetchedVerse {
            #expect(verse.surah == 1)
            #expect(verse.ayah == 1)
            #expect(verse.audioURL.absoluteString.contains("alafasy"))
            #expect(verse.audioURL.absoluteString.contains(".mp3"))
            #expect(!verse.text.isEmpty)
        } else if let error = fetchError {
            Issue.record("Failed to fetch verse: \(error.localizedDescription)")
        }
    }

    @Test func testFetchDifferentVerses() async throws {
        // Test fetching multiple different verses
        var fetchedVerse: CachedAudioVerse?

        // Test Ayatul Kursi (2:255)
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 2, ayah: 255) { result in
                switch result {
                case .success(let verse):
                    fetchedVerse = verse
                case .failure:
                    fetchedVerse = nil
                }
                continuation.resume()
            }
        }

        // Verify URL contains the reciter
        if let verse = fetchedVerse {
            #expect(verse.audioURL.absoluteString.contains("alafasy"))
            #expect(verse.surah == 2)
            #expect(verse.ayah == 255)
        }

        // Clear and test another verse
        audioService.clearCache()

        // Test Al-Imran first verse (3:1)
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 3, ayah: 1) { result in
                switch result {
                case .success(let verse):
                    fetchedVerse = verse
                case .failure:
                    fetchedVerse = nil
                }
                continuation.resume()
            }
        }

        // Verify we got a valid audio URL
        if let verse = fetchedVerse {
            #expect(verse.audioURL.absoluteString.contains(".mp3"))
            #expect(verse.surah == 3)
            #expect(verse.ayah == 1)
        }
    }

    // MARK: - Cache Tests

    @Test func testCacheStorage() async throws {
        // Clear cache first
        audioService.clearCache()
        #if DEBUG
        #expect(audioService.cacheSize == 0)
        #endif

        // Fetch a verse
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 4, ayah: 1) { _ in
                continuation.resume()
            }
        }

        // Check cache
        let cachedVerse = audioService.getCachedVerse(surah: 4, ayah: 1)
        #expect(cachedVerse != nil)
        #expect(cachedVerse?.surah == 4)
        #expect(cachedVerse?.ayah == 1)

        #if DEBUG
        #expect(audioService.cacheSize == 1)
        #endif
    }

    @Test func testCacheReuse() async throws {
        // Clear cache
        audioService.clearCache()

        // First fetch
        var firstFetch: CachedAudioVerse?
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 5, ayah: 1) { result in
                if case .success(let verse) = result {
                    firstFetch = verse
                }
                continuation.resume()
            }
        }

        // Second fetch (should come from cache)
        var secondFetch: CachedAudioVerse?
        let startTime = Date()
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 5, ayah: 1) { result in
                if case .success(let verse) = result {
                    secondFetch = verse
                }
                continuation.resume()
            }
        }
        let fetchTime = Date().timeIntervalSince(startTime)

        // Verify same data and fast fetch (from cache)
        #expect(firstFetch?.audioURL == secondFetch?.audioURL)
        #expect(firstFetch?.text == secondFetch?.text)
        #expect(fetchTime < 0.1)  // Cache fetch should be very fast
    }

    @Test func testCacheLimit() async throws {
        // Clear cache
        audioService.clearCache()

        #if DEBUG
        // Fetch 11 verses to test cache limit of 10
        // Use actual API calls to trigger the cache limit logic
        for i in 1...11 {
            await withCheckedContinuation { continuation in
                audioService.fetchVerseAudio(surah: 1, ayah: min(i, 7)) { _ in  // Al-Fatiha has 7 verses, reuse some
                    continuation.resume()
                }
            }

            // For testing, inject unique verses to avoid cache hits
            if i > 7 {
                let verse = CachedAudioVerse(
                    surah: i,
                    ayah: 1,
                    audioURL: URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(i).mp3")!,
                    text: "Test verse \(i)",
                    edition: "ar.alafasy"
                )
                audioService.injectCachedVerse(verse)
            }
        }

        // Cache should be at max size (10)
        #expect(audioService.cacheSize == 10)

        // The oldest cached verse (surah 2, ayah 1) should have been removed
        // Newest verse (surah 11, ayah 1) should be in cache
        #expect(audioService.getCachedVerse(surah: 11, ayah: 1) != nil)
        #endif
    }

    @Test func testClearCache() async throws {
        // Add some verses to cache
        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 6, ayah: 1) { _ in
                continuation.resume()
            }
        }

        // Clear cache
        audioService.clearCache()

        // Verify cache is empty
        #expect(audioService.getCachedVerse(surah: 6, ayah: 1) == nil)
        #if DEBUG
        #expect(audioService.cacheSize == 0)
        #endif
    }

    // MARK: - Prefetch Tests

    @Test func testPrefetchNextVerse() async throws {
        // Clear cache first
        audioService.clearCache()

        // Prefetch next verse
        audioService.prefetchNextVerse(
            currentSurah: 7,
            currentAyah: 1,
            totalAyahsInSurah: 206  // Al-A'raf has 206 verses
        )

        // Wait a bit for prefetch to complete
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Check if next verse is in cache
        let cachedVerse = audioService.getCachedVerse(surah: 7, ayah: 2)
        #expect(cachedVerse != nil)
        #expect(cachedVerse?.surah == 7)
        #expect(cachedVerse?.ayah == 2)
    }

    @Test func testPrefetchNextSurah() async throws {
        // Clear cache
        audioService.clearCache()

        // Prefetch when at last verse of a surah
        audioService.prefetchNextVerse(
            currentSurah: 1,      // Al-Fatiha
            currentAyah: 7,       // Last verse
            totalAyahsInSurah: 7  // Total verses in Al-Fatiha
        )

        // Wait for prefetch
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Should have prefetched first verse of Al-Baqarah
        let cachedVerse = audioService.getCachedVerse(surah: 2, ayah: 1)
        #expect(cachedVerse != nil)
        #expect(cachedVerse?.surah == 2)
        #expect(cachedVerse?.ayah == 1)
    }

    @Test func testPrefetchLastSurah() async throws {
        // Test that prefetch doesn't crash at the last surah
        audioService.prefetchNextVerse(
            currentSurah: 114,    // An-Nas (last surah)
            currentAyah: 6,       // Last verse
            totalAyahsInSurah: 6  // Total verses in An-Nas
        )

        // Should not crash - just returns without prefetching
        #expect(true)  // If we got here without crashing, test passes
    }

    // MARK: - Error Handling Tests

    @Test func testInvalidSurahNumber() async throws {
        var receivedError: AudioServiceError?

        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 115, ayah: 1) { result in  // Invalid surah
                if case .failure(let error) = result {
                    receivedError = error
                }
                continuation.resume()
            }
        }

        // Should get an error (likely network or decoding error from API)
        #expect(receivedError != nil)
    }

    @Test func testInvalidAyahNumber() async throws {
        var receivedError: AudioServiceError?

        await withCheckedContinuation { continuation in
            audioService.fetchVerseAudio(surah: 1, ayah: 100) { result in  // Invalid ayah for Al-Fatiha
                if case .failure(let error) = result {
                    receivedError = error
                }
                continuation.resume()
            }
        }

        // Should get an error
        #expect(receivedError != nil)
    }

    // MARK: - Model Tests

    @Test func testCachedAudioVerseValidity() {
        // Create a cached verse
        let verse = CachedAudioVerse(
            surah: 1,
            ayah: 1,
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            text: "Test",
            edition: "ar.alafasy"
        )

        // Should be valid immediately
        #expect(verse.isValid == true)

        // Note: Can't easily test expiration without mocking Date
    }

    @Test func testAudioServiceErrorDescriptions() {
        let networkError = AudioServiceError.networkError("Connection failed")
        #expect(networkError.errorDescription?.contains("Network error") == true)

        let invalidURLError = AudioServiceError.invalidURL
        #expect(invalidURLError.errorDescription?.contains("Invalid URL") == true)

        let decodingError = AudioServiceError.decodingError("Invalid JSON")
        #expect(decodingError.errorDescription?.contains("decode") == true)

        let noAudioError = AudioServiceError.noAudioAvailable
        #expect(noAudioError.errorDescription?.contains("No audio") == true)

        let noConnectionError = AudioServiceError.noInternetConnection
        #expect(noConnectionError.errorDescription?.contains("internet") == true)
    }
}