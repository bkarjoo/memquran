import SwiftUI

struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("lineHeightMultiplier") private var lineHeightMultiplier: Double = 2.2
    @AppStorage("fontFamily") private var fontFamily: String = "ScheherazadeNew-Regular"
    @AppStorage("showPageBorder") private var showPageBorder: Bool = false
    @AppStorage("pageMarginTop") private var pageMarginTop: Double = 0
    @AppStorage("pageMarginBottom") private var pageMarginBottom: Double = 0
    @AppStorage("pageMarginLeft") private var pageMarginLeft: Double = 32
    @AppStorage("pageMarginRight") private var pageMarginRight: Double = 32
    @Environment(\.dismiss) private var dismiss

    // Callback for page navigation from History
    var onPageSelected: ((Int) -> Void)?

    // Get the proper font for the current platform
    private func getFont(fontName: String, size: CGFloat) -> Font {
        #if os(iOS)
        // iOS implementation - simpler, just use custom or system
        if UIFont(name: fontName, size: 12) != nil {
            return .custom(fontName, size: size)
        }
        // Final fallback to system font
        return .system(size: size)

        #elseif os(macOS)
        // macOS implementation - SwiftUI's .custom() doesn't work with runtime-registered fonts
        // We MUST use Font(nsFont) with the actual NSFont instance
        if let nsFont = NSFont(name: fontName, size: size) {
            return Font(nsFont)
        }
        // Final fallback to system font
        return .system(size: size)
        #endif
    }

    // Get actual available font names from the system
    var availableFonts: [String] {
        var fonts: [String] = []

        // Get font names for families we're interested in
        let families = ["Scheherazade New", "KFGQPC Uthman Taha Naskh"]

        for family in families {
            #if os(iOS)
            let fontNames = UIFont.fontNames(forFamilyName: family)
            fonts.append(contentsOf: fontNames)
            #elseif os(macOS)
            if let fontDescriptors = NSFontManager.shared.availableMembers(ofFontFamily: family) {
                for descriptor in fontDescriptors {
                    if let postScriptName = descriptor[0] as? String {
                        fonts.append(postScriptName)
                    }
                }
            }
            #endif
        }

        // If no fonts found, at least include the default
        if fonts.isEmpty {
            fonts.append("ScheherazadeNew-Regular")
        }

        return fonts
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Debug: Available Fonts") {
                    ForEach(FontUtilities.availableFontFamilies().filter { $0.contains("Kitab") || $0.contains("Uthman") || $0.contains("Scheherazade") }, id: \.self) { family in
                        Text(family)
                            .font(.caption)
                    }
                }


                Section("Text Appearance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Size: \(Int(fontSize))")
                            .font(.headline)

                        Slider(value: $fontSize, in: 16...48, step: 1)

                        Text("Line Height Multiplier: \(String(format: "%.1f", lineHeightMultiplier))x")
                            .font(.headline)

                        Slider(value: $lineHeightMultiplier, in: 1.0...3.0, step: 0.1)

                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ")
                            .font(getFont(fontName: fontFamily, size: fontSize))
                            .environment(\.layoutDirection, .rightToLeft)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Picker("Font Family", selection: $fontFamily) {
                        ForEach(availableFonts, id: \.self) { font in
                            // Display just the font name, not the full PostScript name
                            Text(font.replacingOccurrences(of: "-Regular", with: ""))
                                .font(getFont(fontName: font, size: 16))
                                .tag(font)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Page Layout") {
                    Toggle("Show Page Border", isOn: $showPageBorder)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Margin: \(Int(pageMarginTop))")
                            .font(.headline)
                        Slider(value: $pageMarginTop, in: 0...100, step: 1)

                        Text("Bottom Margin: \(Int(pageMarginBottom))")
                            .font(.headline)
                        Slider(value: $pageMarginBottom, in: 0...100, step: 1)

                        Text("Left Margin: \(Int(pageMarginLeft))")
                            .font(.headline)
                        Slider(value: $pageMarginLeft, in: 0...100, step: 1)

                        Text("Right Margin: \(Int(pageMarginRight))")
                            .font(.headline)
                        Slider(value: $pageMarginRight, in: 0...100, step: 1)
                    }
                }

                Section("Statistics") {
                    NavigationLink(destination: HistoryView(onPageSelected: { page in
                        onPageSelected?(page)
                        dismiss()
                    })) {
                        Label("History & Statistics", systemImage: "chart.bar")
                            .foregroundColor(.purple)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
