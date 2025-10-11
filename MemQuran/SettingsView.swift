import SwiftUI

struct SettingsView: View {
    @AppStorage("fontSize") private var fontSize: Double = 28
    @AppStorage("lineHeightMultiplier") private var lineHeightMultiplier: Double = 2.2
    @AppStorage("fontFamily") private var fontFamily: String = "ScheherazadeNew-Regular"
    @Environment(\.dismiss) private var dismiss

    let availableFonts = [
        "ScheherazadeNew-Regular"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Debug: Available Fonts") {
                    ForEach(NSFontManager.shared.availableFontFamilies.filter { $0.contains("Kitab") || $0.contains("Uthman") || $0.contains("Scheherazade") }, id: \.self) { family in
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
