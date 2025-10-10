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

    @AppStorage("historyStartPage") private var startPage: Int = 1
    @AppStorage("historyEndPage") private var endPage: Int = 604
    @AppStorage("historyPeriodValue") private var periodValue: Int = 24
    @AppStorage("historyPeriodUnit") private var periodUnitRaw: String = "hours"

    @State private var reviewCount: Int = 0
    @State private var mistakeCount: Int = 0
    @State private var oldestReview: Date?

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
                    // Page Range Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Page Range:")
                            .font(.headline)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("From:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextField("Start", value: $startPage, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .onChange(of: startPage) { oldValue, newValue in
                                        validatePageRange()
                                    }
                            }

                            Text("─────")
                                .foregroundColor(.secondary)
                                .padding(.top, 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("To:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                TextField("End", value: $endPage, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .onChange(of: endPage) { oldValue, newValue in
                                        validatePageRange()
                                    }
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
                                    Text("Total mistakes in this range")
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
                }
                .padding()
            }
        }
        .frame(width: 550, height: 700)
        .onAppear {
            calculateStatistics()
        }
    }

    private func validatePageRange() {
        // Ensure pages are within valid range
        if startPage < 1 {
            startPage = 1
        }
        if startPage > 604 {
            startPage = 604
        }
        if endPage < 1 {
            endPage = 1
        }
        if endPage > 604 {
            endPage = 604
        }

        // Ensure start <= end
        if startPage > endPage {
            endPage = startPage
        }

        calculateStatistics()
    }

    private func calculateStatistics() {
        let now = Date()
        let cutoffDate = calculateCutoffDate(from: now)

        // Get all words in the page range
        let wordsInRange = getWordsInPageRange(startPage: startPage, endPage: endPage)

        // Filter interactions: within time period and in page range
        let filteredInteractions = allInteractions.filter { interaction in
            guard let wordData = interaction.wordData else { return false }

            // Check if word is in page range
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            guard wordsInRange.contains(wordId) else { return false }

            // Check if within time period
            return interaction.timestamp >= cutoffDate
        }

        reviewCount = filteredInteractions.count
        oldestReview = filteredInteractions.map { $0.timestamp }.min()

        // Filter mistakes: within time period and in page range
        let filteredMistakes = allMistakes.filter { mistake in
            guard let wordData = mistake.wordData else { return false }

            // Check if word is in page range
            let wordId = "\(wordData.surahNumber):\(wordData.ayahNumber):\(wordData.wordPosition)"
            guard wordsInRange.contains(wordId) else { return false }

            // Check if within time period
            return mistake.timestamp >= cutoffDate
        }

        mistakeCount = filteredMistakes.count

        print("📊 Statistics calculated:")
        print("   Pages: \(startPage)-\(endPage)")
        print("   Period: Last \(periodValue) \(periodUnit.rawValue)")
        print("   Reviews: \(reviewCount)")
        print("   Mistakes: \(mistakeCount)")
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

    private func getWordsInPageRange(startPage: Int, endPage: Int) -> Set<String> {
        var wordIds = Set<String>()

        for page in startPage...endPage {
            let pageWords = MushafCache.shared.getPageWords(page)
            for (_, words) in pageWords {
                for word in words {
                    let wordId = "\(word.surah):\(word.ayah):\(word.word)"
                    wordIds.insert(wordId)
                }
            }
        }

        return wordIds
    }
}
