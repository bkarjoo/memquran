import SwiftUI
import SwiftData

enum TimePeriodUnit: String, CaseIterable {
    case hours = "Hours"
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
}

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allInteractions: [WordInteraction]
    @Query private var allMistakes: [WordMistake]

    @AppStorage("historyPage") private var historyPage: Int = 1
    @AppStorage("historyPeriodValue") private var periodValue: Int = 24
    @AppStorage("historyPeriodUnit") private var periodUnitRaw: String = "hours"

    @State private var reviewCount: Int = 0
    @State private var mistakeCount: Int = 0
    @State private var oldestReview: Date?
    @State private var showAllPages: Bool = false
    @State private var pagesSummary: [(page: Int, mistakes: Int)] = []

    private var periodUnit: TimePeriodUnit {
        get { TimePeriodUnit(rawValue: periodUnitRaw.capitalized) ?? .hours }
        set { periodUnitRaw = newValue.rawValue.lowercased() }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Page Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Page:")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Toggle("All Pages", isOn: $showAllPages)
                                .onChange(of: showAllPages) { oldValue, newValue in
                                    calculateStatistics()
                                }

                            if !showAllPages {
                                TextField("Page", value: $historyPage, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .onChange(of: historyPage) { oldValue, newValue in
                                        validatePage()
                                    }

                                Text("(1-604)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    // Time Period Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Period:")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Text("Last:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Value", value: $periodValue, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: periodValue) { oldValue, newValue in
                                    if newValue < 1 {
                                        periodValue = 1
                                    }
                                    calculateStatistics()
                                }

                            Picker("", selection: Binding(
                                get: { periodUnit },
                                set: { newValue in
                                    periodUnitRaw = newValue.rawValue.lowercased()
                                    calculateStatistics()
                                }
                            )) {
                                ForEach(TimePeriodUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .frame(width: 120)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    Divider()
                        .padding(.vertical, 8)

                    // Statistics Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("📊 Statistics")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()

                            Button(action: calculateStatistics) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .help("Refresh Statistics")
                        }

                        VStack(spacing: 16) {
                            // Reviews
                            HStack {
                                Image(systemName: "book.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reviews")
                                        .font(.headline)
                                    Text("Word interactions in hidden mode")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(reviewCount)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                            // Mistakes
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mistakes")
                                        .font(.headline)
                                    Text(showAllPages ? "Total mistakes (all pages)" : "Total mistakes on this page")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(mistakeCount)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)

                            // Oldest Review
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Oldest Review")
                                        .font(.headline)
                                    Text("Earliest interaction timestamp")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if let oldest = oldestReview {
                                    Text(oldest, style: .relative)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                } else {
                                    Text("No data")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)

                    // Pages Summary Section (only shown when "All Pages" is enabled)
                    if showAllPages && !pagesSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("📚 Pages Reviewed")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Pages where all words have been reviewed in this time period")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(pagesSummary, id: \.page) { item in
                                        HStack {
                                            Text("Page \(item.page)")
                                                .font(.body)
                                                .fontWeight(.medium)

                                            Spacer()

                                            HStack(spacing: 4) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                                Text("\(item.mistakes)")
                                                    .font(.body)
                                                    .foregroundColor(.red)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 550, height: 700)
        .onAppear {
            calculateStatistics()
        }
    }

    private func validatePage() {
        // Ensure page is within valid range
        if historyPage < 1 {
            historyPage = 1
        }
        if historyPage > 604 {
            historyPage = 604
        }

        calculateStatistics()
    }

    private func calculateStatistics() {
        let now = Date()
        let cutoffDate = calculateCutoffDate(from: now)

        if showAllPages {
            // Calculate statistics for all pages
            calculateAllPagesStatistics(cutoffDate: cutoffDate)
        } else {
            // Calculate statistics for single page
            calculateSinglePageStatistics(page: historyPage, cutoffDate: cutoffDate)
        }
    }

    private func calculateSinglePageStatistics(page: Int, cutoffDate: Date) {
        // Get all words on the single page
        let wordsOnPage = getWordsOnPage(page: page)

        // Filter interactions: within time period and on page
        let filteredInteractions = allInteractions.filter { interaction in
            guard let wordData = interaction.wordData else { return false }

            // Check if word is on page
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            guard wordsOnPage.contains(wordId) else { return false }

            // Check if within time period
            return interaction.timestamp >= cutoffDate
        }

        reviewCount = filteredInteractions.count
        oldestReview = filteredInteractions.map { $0.timestamp }.min()

        // Filter mistakes: within time period and on page
        let filteredMistakes = allMistakes.filter { mistake in
            guard let wordData = mistake.wordData else { return false }

            // Check if word is on page
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            guard wordsOnPage.contains(wordId) else { return false }

            // Check if within time period
            return mistake.timestamp >= cutoffDate
        }

        mistakeCount = filteredMistakes.count
        pagesSummary = []  // Clear summary for single page mode

        print("📊 Statistics calculated:")
        print("   Page: \(page)")
        print("   Period: Last \(periodValue) \(periodUnit.rawValue)")
        print("   Reviews: \(reviewCount)")
        print("   Mistakes: \(mistakeCount)")
        if let oldest = oldestReview {
            print("   Oldest: \(oldest)")
        }
    }

    private func calculateAllPagesStatistics(cutoffDate: Date) {
        // Filter interactions and mistakes once upfront (O(n) instead of repeated filtering)
        let filteredInteractions = allInteractions.filter { $0.timestamp >= cutoffDate }
        let filteredMistakes = allMistakes.filter { $0.timestamp >= cutoffDate }

        // Build lookup sets for fast O(1) checking
        var reviewedWords = Set<String>()  // wordId -> has review
        var mistakesByWord = [String: Int]()  // wordId -> mistake count

        for interaction in filteredInteractions {
            guard let wordData = interaction.wordData else { continue }
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            reviewedWords.insert(wordId)
        }

        for mistake in filteredMistakes {
            guard let wordData = mistake.wordData else { continue }
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            mistakesByWord[wordId, default: 0] += 1
        }

        // Now iterate through pages and check using O(1) lookups
        var pagesReviewed: [(page: Int, mistakes: Int)] = []

        for page in 1...604 {
            let wordsOnPage = getWordsOnPage(page: page)

            // Check if all words on this page have been reviewed
            var allWordsReviewed = true
            var pageMistakes = 0

            for wordId in wordsOnPage {
                if !reviewedWords.contains(wordId) {
                    allWordsReviewed = false
                    break
                }
                pageMistakes += mistakesByWord[wordId, default: 0]
            }

            // Only include pages where all words were reviewed
            if allWordsReviewed && !wordsOnPage.isEmpty {
                pagesReviewed.append((page: page, mistakes: pageMistakes))
            }
        }

        // Update state
        reviewCount = filteredInteractions.count
        mistakeCount = pagesReviewed.reduce(0) { $0 + $1.mistakes }
        oldestReview = filteredInteractions.map { $0.timestamp }.min()
        pagesSummary = pagesReviewed.sorted { $0.page < $1.page }

        print("📊 Statistics calculated:")
        print("   All Pages")
        print("   Period: Last \(periodValue) \(periodUnit.rawValue)")
        print("   Total Reviews: \(reviewCount)")
        print("   Total Mistakes: \(mistakeCount)")
        print("   Pages Fully Reviewed: \(pagesSummary.count)")
        if let oldest = oldestReview {
            print("   Oldest: \(oldest)")
        }
    }

    private func calculateCutoffDate(from now: Date) -> Date {
        let calendar = Calendar.current

        switch periodUnit {
        case .hours:
            return calendar.date(byAdding: .hour, value: -periodValue, to: now) ?? now
        case .days:
            return calendar.date(byAdding: .day, value: -periodValue, to: now) ?? now
        case .weeks:
            return calendar.date(byAdding: .weekOfYear, value: -periodValue, to: now) ?? now
        case .months:
            return calendar.date(byAdding: .month, value: -periodValue, to: now) ?? now
        }
    }

    private func getWordsOnPage(page: Int) -> Set<String> {
        var wordIds = Set<String>()

        let pageWords = MushafCache.shared.getPageWords(page)
        for (_, words) in pageWords {
            for word in words {
                let wordId = "\(word.surah):\(word.ayah):\(word.word)"
                wordIds.insert(wordId)
            }
        }

        return wordIds
    }
}
