//
//  Theme.swift
//  Les « tokens » de design, identiques aux variables Figma (collection « Planner »).
//
//  Règle d'or : aucune vue ne doit écrire une couleur ou une taille « en dur ».
//  Elles passent toutes par `Theme`. Changer le rose de l'app = changer UNE ligne.
//
//  Correspondance Figma → Swift :
//    bg/blush        → Theme.Colors.background
//    bg/surface      → Theme.Colors.surface
//    bg/tint         → Theme.Colors.tint
//    brand/pink      → Theme.Colors.pink
//    brand/pink-deep → Theme.Colors.pinkDeep
//    ink/primary     → Theme.Colors.ink
//    ink/secondary   → Theme.Colors.inkSecondary
//    line/grid       → Theme.Colors.gridLine
//    class/*         → CourseColor (voir CourseColor+Color.swift)
//

import SwiftUI

nonisolated enum Theme {

    // MARK: - Couleurs

    enum Colors {
        static let background   = Color(hex: 0xFFF1F4)
        static let surface      = Color(hex: 0xFFFFFF)
        static let tint         = Color(hex: 0xFFDDE7)
        static let pink         = Color(hex: 0xFF4F8B)
        static let pinkDeep     = Color(hex: 0xE0306E)
        static let ink          = Color(hex: 0x1C1216)
        static let inkSecondary = Color(hex: 0x8A6D77)
        static let gridLine     = Color(hex: 0xF3CAD6)
    }

    // MARK: - Typographie
    //
    // Style « Swiss » : très gros chiffres en Black, labels en petites
    // capitales espacées. On utilise la police système (SF Pro).

    enum Fonts {
        /// Gros titres et chiffres (« 10 », « Octobre »).
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .black)
        }

        /// Petits labels en capitales (« MES COURS », « LUN »).
        /// À combiner avec `.tracking(Theme.Fonts.labelTracking)` et `.textCase(.uppercase)`.
        static let label = Font.system(size: 11, weight: .bold)
        static let labelTracking: CGFloat = 1.2

        /// Texte des pastilles dans la grille.
        static let pill = Font.system(size: 11, weight: .semibold)
    }

    // MARK: - Espacements (grille de 4 pt)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Rayons d'arrondi

    enum Radius {
        static let pill: CGFloat = 6
        static let cell: CGFloat = 14
        static let card: CGFloat = 18
    }
}

// MARK: - Helpers

nonisolated extension Color {
    /// Crée une couleur depuis un code hexadécimal, ex. `Color(hex: 0xFF4F8B)`.
    /// Pratique pour recopier les valeurs directement depuis Figma.
    init(hex: UInt32, opacity: Double = 1) {
        let red   = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue  = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension View {
    /// Style des petits labels en capitales (« MES COURS », « LUN »).
    func plannerLabelStyle(color: Color = Theme.Colors.inkSecondary) -> some View {
        self
            .font(Theme.Fonts.label)
            .tracking(Theme.Fonts.labelTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
