import AVFoundation
import Foundation
import TycoonEngine

/// The game's eight sound effects, synthesized at runtime — square and
/// triangle chiptune blips built from an `AVAudioSourceNode`, so the app
/// ships no audio assets at all.
///
/// Everything is generated from a tiny note script per effect: a list of
/// (waveform, frequency, duration, envelope) steps mixed into one buffer
/// the first time the effect plays, then cached.
enum SoundEffect: String, CaseIterable, Sendable {
    /// UI taps and page turns.
    case tap
    /// Money landing: contract payout, sale week, loan.
    case cash
    /// A product shipped — the one fanfare in the game.
    case ship
    /// A review score stamping down.
    case review
    /// Someone joined the team.
    case hire
    /// Something is going wrong (debt, bankruptcy warning, resignation).
    case warning
    /// A goal or chapter completed.
    case goal
    /// The weekly report chip appearing.
    case weekEnd

    /// The note script for the effect: pitch in Hz, length in seconds, and
    /// which oscillator to use.
    fileprivate var notes: [ChipNote] {
        switch self {
        case .tap:
            [ChipNote(frequency: 880, duration: 0.045, wave: .square, gain: 0.16)]
        case .cash:
            [
                ChipNote(frequency: 1046, duration: 0.055, wave: .square, gain: 0.18),
                ChipNote(frequency: 1568, duration: 0.09, wave: .square, gain: 0.16),
            ]
        case .ship:
            [
                ChipNote(frequency: 523, duration: 0.09, wave: .square, gain: 0.18),
                ChipNote(frequency: 659, duration: 0.09, wave: .square, gain: 0.18),
                ChipNote(frequency: 784, duration: 0.09, wave: .square, gain: 0.18),
                ChipNote(frequency: 1046, duration: 0.22, wave: .triangle, gain: 0.22),
            ]
        case .review:
            [
                ChipNote(frequency: 392, duration: 0.05, wave: .triangle, gain: 0.2),
                ChipNote(frequency: 294, duration: 0.14, wave: .square, gain: 0.16),
            ]
        case .hire:
            [
                ChipNote(frequency: 659, duration: 0.07, wave: .triangle, gain: 0.18),
                ChipNote(frequency: 988, duration: 0.12, wave: .triangle, gain: 0.18),
            ]
        case .warning:
            [
                ChipNote(frequency: 233, duration: 0.13, wave: .square, gain: 0.18),
                ChipNote(frequency: 175, duration: 0.20, wave: .square, gain: 0.18),
            ]
        case .goal:
            [
                ChipNote(frequency: 784, duration: 0.07, wave: .square, gain: 0.18),
                ChipNote(frequency: 1046, duration: 0.07, wave: .square, gain: 0.18),
                ChipNote(frequency: 1318, duration: 0.16, wave: .triangle, gain: 0.2),
            ]
        case .weekEnd:
            [
                ChipNote(frequency: 587, duration: 0.06, wave: .triangle, gain: 0.16),
                ChipNote(frequency: 880, duration: 0.10, wave: .triangle, gain: 0.16),
            ]
        }
    }
}

/// One synthesized note.
private struct ChipNote {
    enum Wave { case square, triangle }

    let frequency: Double
    let duration: Double
    let wave: Wave
    let gain: Float
}

/// Plays the synthesized effects and owns the shared audio engine.
///
/// The engine is started lazily on the first sound and torn down when the
/// player turns sound off, so a silent game costs nothing. The session
/// category is `.ambient`, which means the game respects the silent switch
/// and never interrupts music the player is already listening to.
@MainActor
final class Sounds {
    /// Whether effects play at all. Mirrors the Settings toggle and is
    /// persisted in `UserDefaults` under `GameSettings.soundEnabledKey`.
    static var isEnabled: Bool {
        get { GameSettings.soundEnabled }
        set {
            GameSettings.soundEnabled = newValue
            if !newValue { shared.stop() }
        }
    }

    private static let shared = Sounds()

    /// Plays `effect`, doing nothing if sound is off or audio is
    /// unavailable (a failed audio session must never break the game).
    static func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        shared.play(effect)
    }

    /// The effect that best matches an event's severity, for the toast
    /// layer. `.quiet` events make no sound at all.
    static func play(severity: EventSeverity) {
        switch severity {
        case .quiet: break
        case .info: play(.tap)
        case .notable: play(.cash)
        case .critical: play(.warning)
        }
    }

    // MARK: - Engine

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44_100

    private func play(_ effect: SoundEffect) {
        guard let player = startedPlayer() else { return }
        guard let buffer = buffer(for: effect) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func startedPlayer() -> AVAudioPlayerNode? {
        if let player, engine?.isRunning == true { return player }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            // `.ambient` respects the silent switch and mixes with the
            // player's own music instead of stopping it.
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            return nil
        }
        self.engine = engine
        self.player = player
        return player
    }

    private func stop() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
    }

    private func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        if let cached = buffers[effect] { return cached }
        guard let built = render(effect.notes) else { return nil }
        buffers[effect] = built
        return built
    }

    /// Renders a note script into one mono buffer. Each note gets a short
    /// linear attack and an exponential decay so the blips don't click.
    private func render(_ notes: [ChipNote]) -> AVAudioPCMBuffer? {
        let totalSeconds = notes.reduce(0) { $0 + $1.duration }
        let frameCount = AVAudioFrameCount(totalSeconds * sampleRate)
        guard frameCount > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount

        var writeIndex = 0
        for note in notes {
            let noteFrames = Int(note.duration * sampleRate)
            let attackFrames = max(1, Int(0.004 * sampleRate))
            for frame in 0..<noteFrames where writeIndex < Int(frameCount) {
                let time = Double(frame) / sampleRate
                let phase = (time * note.frequency).truncatingRemainder(dividingBy: 1)
                let raw: Double = switch note.wave {
                case .square: phase < 0.5 ? 1 : -1
                case .triangle: 4 * abs(phase - 0.5) - 1
                }
                let attack = min(1, Double(frame) / Double(attackFrames))
                let decay = exp(-3.2 * time / max(note.duration, 0.001))
                channel[writeIndex] = Float(raw * attack * decay) * note.gain
                writeIndex += 1
            }
        }
        return buffer
    }
}
