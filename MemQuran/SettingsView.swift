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

    let availableFonts = [
        "ScheherazadeNew-Regular"
    ]

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
                            .font(.custom(fontFamily, size: fontSize))
                            .environment(\.layoutDirection, .rightToLeft)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Picker("Font Family", selection: $fontFamily) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font)
                                .font(.custom(font, size: 16))
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
