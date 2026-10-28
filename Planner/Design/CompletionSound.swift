//
//  CompletionSound.swift
//  Petit « ding » joué quand on coche une tâche.
//
//  Le son est fabriqué en mémoire (deux notes qui s'éteignent doucement)
//  plutôt que lu depuis un fichier : pas de ressource à embarquer, et il
//  sonne pareil sur iPhone, iPad et Mac.
//

import AVFoundation

@MainActor
enum CompletionSound {
    /// Préparé une seule fois, au premier « ding ».
    private static let player: AVAudioPlayer? = {
        #if os(iOS)
        // `.ambient` : se tait avec le bouton silencieux et ne coupe pas
        // la musique en cours.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        #endif
        let player = try? AVAudioPlayer(data: makeChime())
        player?.volume = 0.6
        player?.prepareToPlay()
        return player
    }()

    static func play() {
        guard let player else { return }
        // Deux tâches cochées coup sur coup : on relance le son du début.
        player.currentTime = 0
        player.play()
    }

    // MARK: - Synthèse

    private static let sampleRate = 44_100

    /// Mi puis si aigus, le second légèrement décalé : un « ding-ding » bref.
    private static func makeChime() -> Data {
        let notes: [(frequency: Double, start: Double)] = [(1318.5, 0), (1975.5, 0.09)]
        let duration = 0.5
        let rate = Double(sampleRate)
        let samples = (0..<Int(rate * duration)).map { index -> Int16 in
            let time = Double(index) / rate
            var value = 0.0
            for note in notes where time >= note.start {
                let local = time - note.start
                // Attaque de 5 ms (évite le clic), puis extinction exponentielle.
                let envelope = min(1, local / 0.005) * exp(-local * 9)
                value += sin(2 * .pi * note.frequency * local) * envelope
            }
            return Int16(max(-1, min(1, value * 0.4)) * Double(Int16.max))
        }
        return wavData(samples)
    }

    /// Enveloppe les échantillons dans un en-tête WAV (PCM 16 bits, mono).
    private static func wavData(_ samples: [Int16]) -> Data {
        var data = Data()
        func append(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        append("RIFF"); append(36 + byteCount); append("WAVE")
        append("fmt "); append(UInt32(16))
        append(UInt16(1))                      // PCM
        append(UInt16(1))                      // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))         // octets par seconde
        append(UInt16(2))                      // octets par échantillon
        append(UInt16(16))                     // bits par échantillon
        append("data"); append(byteCount)
        samples.forEach { append($0) }
        return data
    }
}
