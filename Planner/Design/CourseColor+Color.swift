//
//  CourseColor+Color.swift
//  Traduit la palette des cours (modèle) en couleurs SwiftUI (interface).
//  Les 8 premières valeurs sont identiques aux variables Figma `class/*`.
//
//  Toutes les teintes restent assez soutenues pour porter du texte blanc
//  (pastilles du calendrier) et se détacher du fond rose pâle.
//

import SwiftUI

nonisolated extension CourseColor {
    var color: Color {
        switch self {
        // Chauds
        case .raspberry: Color(hex: 0xC2185B)
        // Valeur fixe : la couleur d'un cours ne change pas avec le thème.
        case .pink:      Color(hex: 0xFF4F8B)
        case .red:       Color(hex: 0xFF3B30)
        case .orange:    Color(hex: 0xFF8A3D)
        case .mustard:   Color(hex: 0xD99A00)
        // Verts
        case .olive:     Color(hex: 0x8A9A1B)
        case .lime:      Color(hex: 0x5DAA1E)
        case .green:     Color(hex: 0x1FB86A)
        case .forest:    Color(hex: 0x0E7A4F)
        case .teal:      Color(hex: 0x12B5B0)
        // Bleus
        case .sky:       Color(hex: 0x1AA3E8)
        case .cobalt:    Color(hex: 0x2F6BFF)
        case .blue:      Color(hex: 0x3B3BFF)
        case .lavender:  Color(hex: 0x8C7CFF)
        case .violet:    Color(hex: 0xA64DFF)
        // Violets et neutres
        case .orchid:    Color(hex: 0xD63AF9)
        case .plum:      Color(hex: 0x7B2D8E)
        case .cocoa:     Color(hex: 0x9A6B4F)
        case .slate:     Color(hex: 0x5E7A8C)
        case .graphite:  Color(hex: 0x3A3A3C)
        }
    }

    /// Nom lisible, pour l'accessibilité (VoiceOver) et les sélecteurs.
    var displayName: String {
        switch self {
        case .raspberry: "Framboise"
        case .pink:      "Rose"
        case .red:       "Rouge"
        case .orange:    "Orange"
        case .mustard:   "Moutarde"
        case .olive:     "Olive"
        case .lime:      "Pomme"
        case .green:     "Vert"
        case .forest:    "Sapin"
        case .teal:      "Turquoise"
        case .sky:       "Ciel"
        case .cobalt:    "Cobalt"
        case .blue:      "Bleu"
        case .lavender:  "Lavande"
        case .violet:    "Violet"
        case .orchid:    "Orchidée"
        case .plum:      "Prune"
        case .cocoa:     "Cacao"
        case .slate:     "Ardoise"
        case .graphite:  "Graphite"
        }
    }
}
