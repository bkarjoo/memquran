import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

/// A view that displays corpus.quran.com morphology data for a specific word.
/// The HTML is fetched on-demand and rendered in a WebView, then discarded when closed.
struct WordResearchView: View {
    @Environment(\.dismiss) private var dismiss

    let wordId: WordIdentifier

    /// The corpus.quran.com URL for word morphology
    /// Format: location=(surah:ayah:word)
    private var morphologyURL: URL? {
        URL(string: "https://corpus.quran.com/wordmorphology.jsp?location=(\(wordId.surah):\(wordId.ayah):\(wordId.position))")
    }

    /// Alternative URLs for different views
    private var wordByWordURL: URL? {
        URL(string: "https://corpus.quran.com/wordbyword.jsp?chapter=\(wordId.surah)&verse=\(wordId.ayah)#(\(wordId.surah):\(wordId.ayah):\(wordId.position))")
    }

    @State private var currentURL: URL?
    @State private var isLoading = true
    @State private var selectedTab: ResearchTab = .morphology

    enum ResearchTab: String, CaseIterable {
        case morphology = "Morphology"
        case wordByWord = "Word by Word"

        var icon: String {
            switch self {
            case .morphology: return "text.book.closed"
            case .wordByWord: return "list.bullet"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Tab selector
            tabSelector

            Divider()

            // WebView content
            ZStack {
                if let url = currentURL {
                    WebViewRepresentable(url: url, isLoading: $isLoading)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Invalid URL")
                            .foregroundColor(.secondary)
                    }
                }

                if isLoading {
                    ProgressView("Loading from corpus.quran.com...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(loadingBackgroundColor.opacity(0.8))
                }
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            currentURL = morphologyURL
        }
    }

    /// Platform-specific background color for loading overlay
    private var loadingBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Word Research")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Surah \(wordId.surah), Ayah \(wordId.ayah), Word \(wordId.position)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Open in browser button (platform-specific)
            if let url = currentURL {
                Button(action: {
                    openInBrowser(url)
                }) {
                    Image(systemName: "safari")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                #if os(macOS)
                .help("Open in browser")
                #endif
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    /// Platform-specific URL opening
    private func openInBrowser(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 12) {
            ForEach(ResearchTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                    isLoading = true
                    switch tab {
                    case .morphology:
                        currentURL = morphologyURL
                    case .wordByWord:
                        currentURL = wordByWordURL
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Refresh button
            Button(action: {
                isLoading = true
                // Force reload by resetting URL
                let url = currentURL
                currentURL = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    currentURL = url
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .help("Refresh")
            #endif
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - WebView Representable (macOS)

#if os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only load if URL has changed to prevent infinite reload loop
        if context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        var lastLoadedURL: URL?

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("❌ WebView failed to load: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
#endif

// MARK: - WebView Representable (iOS)

#if os(iOS)
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if URL has changed to prevent infinite reload loop
        if context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        var lastLoadedURL: URL?

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("❌ WebView failed to load: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
#endif
