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
//    brand/pink      → Theme.Colors.accent
//    brand/pink-deep → Theme.Colors.accentDeep
//    ink/primary     → Theme.Colors.ink
//    ink/secondary   → Theme.Colors.inkSecondary
//    line/grid       → Theme.Colors.gridLine
//    class/*         → CourseColor (voir CourseColor+Color.swift)
//
//  Plusieurs thèmes : les valeurs vivent dans une `ThemePalette` (une par
//  thème, voir `ThemePalette.rose`). `Theme.Colors` lit la palette active,
//  donc les vues n'ont jamais à savoir quel thème est choisi.
//

import SwiftUI

nonisolated enum Theme {

    /// Palette utilisée par toute l'app.
    /// Pour l'instant fixe ; plus tard, elle viendra du choix de l'utilisateur.
    static let palette: ThemePalette = .rose

    // MARK: - Couleurs

    enum Colors {
        static var background: Color   { palette.background }
        static var surface: Color      { palette.surface }
        static var tint: Color         { palette.tint }
        static var accent: Color       { palette.accent }
        static var accentDeep: Color   { palette.accentDeep }
        static var onAccent: Color     { palette.onAccent }
        static var ink: Color          { palette.ink }
        static var inkSecondary: Color { palette.inkSecondary }
        static var gridLine: Color     { palette.gridLine }
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

// MARK: - Palettes

/// Toutes les couleurs d'un thème.
/// Ajouter un thème = ajouter une constante `static let` ci-dessous.
nonisolated struct ThemePalette {
    /// Fond des écrans.
    let background: Color
    /// Cartes et blocs posés sur le fond.
    let surface: Color
    /// Fond léger (sélection, survol).
    let tint: Color
    /// Couleur principale : boutons, aujourd'hui, liens.
    let accent: Color
    /// Variante foncée de l'accent (appui, ombres).
    let accentDeep: Color
    /// Texte et icônes posés sur l'accent.
    let onAccent: Color
    /// Texte principal.
    let ink: Color
    /// Texte secondaire, labels.
    let inkSecondary: Color
    /// Traits de la grille du calendrier.
    let gridLine: Color
}

nonisolated extension ThemePalette {
    /// Thème d'origine, identique aux variables Figma.
    static let rose = ThemePalette(
        background:   Color(hex: 0xFFF1F4),
        surface:      Color(hex: 0xFFFFFF),
        tint:         Color(hex: 0xFFDDE7),
        accent:       Color(hex: 0xFF4F8B),
        accentDeep:   Color(hex: 0xE0306E),
        onAccent:     Color(hex: 0xFFFFFF),
        ink:          Color(hex: 0x1C1216),
        inkSecondary: Color(hex: 0x8A6D77),
        gridLine:     Color(hex: 0xF3CAD6)
    )
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

    /// La carte blanche de l'app : fond `surface`, coins arrondis et ombre rose
    /// très douce. C'est ce qui se pose sur le fond rose pâle — les lignes de
    /// l'agenda comme les blocs de l'éditeur.
    func plannerCard(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(Theme.Colors.surface, in: .rect(cornerRadius: cornerRadius))
            .shadow(color: Theme.Colors.accentDeep.opacity(0.06), radius: 6, y: 2)
    }
}
