import SwiftUI
import TycoonEngine

/// What a seed field's text means, read as the player types: a code off
/// a share card, a plain number, nothing (a random seed), or something
/// the game cannot read.
enum SeedEntry: Equatable {
    case random
    case code(SeedCode)
    case number(UInt64)
    case invalid

    /// Reads `text`: a code (any case, with or without its hyphens), or a
    /// decimal number up to 64 bits, or blank.
    static func parse(_ text: String) -> SeedEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .random }
        if let code = SeedCode.decode(trimmed) { return .code(code) }
        let digits = trimmed.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
        if digits.allSatisfy(\.isNumber), let number = UInt64(digits) { return .number(number) }
        return .invalid
    }

    /// The seed the entry names; `nil` for random.
    var seed: UInt64? {
        switch self {
        case .random, .invalid: nil
        case .code(let code): code.seed
        case .number(let number): number
        }
    }

    var isValid: Bool {
        if case .invalid = self { return false }
        return true
    }

    /// Whether the player named a seed — a code or a number — which makes
    /// the run a custom one.
    var isTyped: Bool {
        seed != nil
    }

    /// One line under the field saying what was read.
    var statusLine: String {
        switch self {
        case .random:
            "Random — a company nobody has run before."
        case .code(let code):
            "A share card's code · \(code.origin.displayName) · \(code.difficulty.displayName)"
        case .number(let number):
            "Seed \(number). The same number founds the same company."
        case .invalid:
            "Not a code or a number. A code looks like \(SeedCode.prefix)-XXXXXXXX-XXXXXXXX-X."
        }
    }
}

/// A text field for a seed: a code off a share card or a plain number,
/// with a status line saying which it read, a paste button and a die that
/// rolls a fresh number.
struct SeedCodeField: View {
    @Binding var text: String
    /// Whether the field offers *Random*. Off on the *From a code* sheet,
    /// where only a code makes sense.
    var offersRandom = true

    @FocusState private var focused: Bool

    private var entry: SeedEntry { SeedEntry.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Code or number", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.system(.body, design: .monospaced))
                    .focused($focused)
                    .submitLabel(.done)
                    .accessibilityLabel("Seed: a code or a number")
                    .accessibilityValue(entry.statusLine)
                if !text.isEmpty {
                    Button {
                        Haptics.tap()
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear the seed")
                }
                PasteButton(payloadType: String.self) { strings in
                    if let pasted = strings.first {
                        text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle)
                .tint(Theme.accent)
                if offersRandom {
                    Button {
                        Haptics.tap()
                        Sounds.play(.tap)
                        text = String(UInt64.random(in: 1 ... 999_999_999))
                        focused = false
                    } label: {
                        Image(systemName: "die.face.5.fill")
                            .font(.body.weight(.semibold))
                            .padding(Theme.Spacing.sm)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Roll a random seed")
                }
            }
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: statusIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.isValid ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.negativeCash))
                Text(entry.statusLine)
                    .font(.caption)
                    .foregroundStyle(entry.isValid ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.negativeCash))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityHidden(true)
            if case .code(let code) = entry {
                PixelText(text: code.encoded, scale: 2, color: Theme.pixelAccent)
                    .accessibilityHidden(true)
            }
        }
    }

    private var statusIcon: String {
        switch entry {
        case .random: "dice"
        case .code: "checkmark.seal.fill"
        case .number: "number"
        case .invalid: "exclamationmark.triangle.fill"
        }
    }
}

/// The *From a code* sheet: one field, and the button that opens the
/// custom page prefilled with what it read. Prefilled itself by a code
/// that arrived by URL.
struct SeedCodeEntrySheet: View {
    var prefill: SeedCode?
    let onOpen: (SeedCode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var code: SeedCode? {
        if case .code(let code) = SeedEntry.parse(text) { return code }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("A code off a share card founds the same company on this phone: the same seed, the same start, the same stakes — and everything that comes with them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                CardView("The code", systemImage: "number") {
                    SeedCodeField(text: $text, offersRandom: false)
                }
                Button {
                    guard let code else { return }
                    Haptics.commit()
                    Sounds.play(.tap)
                    onOpen(code)
                    dismiss()
                } label: {
                    Label("Open the custom page", systemImage: "slider.horizontal.3")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(code == nil)
                .accessibilityHint("Opens the new-game flow on the custom page with this code filled in")
                Text("A company from a code earns achievements but does not post to leaderboards.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.screenBackground)
            .navigationTitle("From a code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if text.isEmpty, let prefill { text = prefill.encoded }
            }
        }
    }
}
