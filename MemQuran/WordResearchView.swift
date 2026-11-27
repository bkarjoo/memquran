import SwiftUI

/// Helper for building the research URL used on both platforms.
enum WordResearchDestination {
    static func url(for wordId: WordIdentifier) -> URL? {
        URL(string: "https://corpus.quran.com/wordmorphology.jsp?location=(\(wordId.surah):\(wordId.ayah):\(wordId.position))")
    }
}

#if os(iOS)
import SafariServices

/// Presents corpus.quran.com inside an `SFSafariViewController` so the user can dismiss with the native "Done" button.
struct WordResearchView: View {
    let wordId: WordIdentifier

    var body: some View {
        if let url = WordResearchDestination.url(for: wordId) {
            SafariView(url: url)
                .ignoresSafeArea()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Unable to open research URL.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Nothing to update.
    }
}
#endif
