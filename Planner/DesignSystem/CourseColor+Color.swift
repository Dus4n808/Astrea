//
//  CourseColor+Color.swift
//  Traduit la palette des cours (modèle) en couleurs SwiftUI (interface).
//  Valeurs identiques aux variables Figma `class/*`.
//

import SwiftUI

nonisolated extension CourseColor {
    var color: Color {
        switch self {
        case .blue:     Color(hex: 0x3B3BFF)
        case .graphite: Color(hex: 0x3A3A3C)
        case .orange:   Color(hex: 0xFF8A3D)
        case .violet:   Color(hex: 0xA64DFF)
        case .red:      Color(hex: 0xFF3B30)
        case .green:    Color(hex: 0x1FB86A)
        case .teal:     Color(hex: 0x12B5B0)
        case .pink:     Theme.Colors.pink
        }
    }

    /// Nom lisible, pour l'accessibilité (VoiceOver) et les sélecteurs.
    var displayName: String {
        switch self {
        case .blue:     "Bleu"
        case .graphite: "Graphite"
        case .orange:   "Orange"
        case .violet:   "Violet"
        case .red:      "Rouge"
        case .green:    "Vert"
        case .teal:     "Turquoise"
        case .pink:     "Rose"
        }
    }
}
