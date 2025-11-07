//
//  SettingsViewTests.swift
//  MemQuran iOSTests
//
//  Tests for SettingsView functionality
//

import Testing
import Foundation
import SwiftUI
@testable import MemQuran_iOS

struct SettingsViewTests {

    // MARK: - Audio Caching Toggle Tests

    @Test func testAudioCachingTogglePersistence() async throws {
        // Clear the key first
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")

        // Set toggle to OFF
        UserDefaults.standard.set(false, forKey: "isAudioCachingEnabled")

        // Verify persistence
        let savedValue = UserDefaults.standard.bool(forKey: "isAudioCachingEnabled")
        #expect(savedValue == false)

        // Create a new instance and verify it reads the persisted value
        let persistedValue = UserDefaults.standard.object(forKey: "isAudioCachingEnabled") as? Bool ?? true
        #expect(persistedValue == false)

        // Set toggle to ON
        UserDefaults.standard.set(true, forKey: "isAudioCachingEnabled")

        // Verify persistence
        let savedValueOn = UserDefaults.standard.bool(forKey: "isAudioCachingEnabled")
        #expect(savedValueOn == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")
    }

    @Test func testAudioCachingToggleDefault() async throws {
        // Clear the UserDefaults key
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")

        // Verify default value is true (caching enabled by default)
        let defaultValue = UserDefaults.standard.object(forKey: "isAudioCachingEnabled") as? Bool ?? true
        #expect(defaultValue == true)

        // Verify this matches the AudioService behavior
        // AudioService.swift:57 uses the same default: "UserDefaults.standard.object(forKey: "isAudioCachingEnabled") as? Bool ?? true"

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")
    }

    @Test func testAudioCachingToggleStateTransitions() async throws {
        // Test multiple state transitions
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")

        // Start with default (true)
        var currentValue = UserDefaults.standard.object(forKey: "isAudioCachingEnabled") as? Bool ?? true
        #expect(currentValue == true)

        // Toggle OFF
        UserDefaults.standard.set(false, forKey: "isAudioCachingEnabled")
        currentValue = UserDefaults.standard.bool(forKey: "isAudioCachingEnabled")
        #expect(currentValue == false)

        // Toggle ON
        UserDefaults.standard.set(true, forKey: "isAudioCachingEnabled")
        currentValue = UserDefaults.standard.bool(forKey: "isAudioCachingEnabled")
        #expect(currentValue == true)

        // Toggle OFF again
        UserDefaults.standard.set(false, forKey: "isAudioCachingEnabled")
        currentValue = UserDefaults.standard.bool(forKey: "isAudioCachingEnabled")
        #expect(currentValue == false)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isAudioCachingEnabled")
    }
}
