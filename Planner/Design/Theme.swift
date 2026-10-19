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
//  thème, voir AppTheme.swift). `Theme.Colors` lit la palette du thème choisi
//  (`ThemeStore`), donc les vues n'ont jamais à savoir quel thème est actif.
//
//  Changer de thème redessine l'app sans rien faire de plus : `ThemeStore`
//  est @Observable, et lire `Theme.Colors.accent` dans un `body` suffit à
//  ce que SwiftUI note la dépendance.
//

import SwiftUI

nonisolated enum Theme {

    // MARK: - Couleurs

    @MainActor
    enum Colors {
        private static var palette: ThemePalette { ThemeStore.shared.theme.palette }

        static var background: Color   { palette.background }
        static var surface: Color      { palette.surface }
        static var tint: Color         { palette.tint }
        static var accent: Color       { palette.accent }
        static var accentDeep: Color   { palette.accentDeep }
        static var onAccent: Color     { palette.onAccent }
        static var ink: Color          { palette.ink }
        static var inkSecondary: Color { palette.inkSecondary }
        static var gridLine: Color     { palette.gridLine }

        // Couleurs communes à tous les thèmes.

        /// Texte et marques posés sur la couleur d'un cours (pastilles,
        /// cases cochées) : les couleurs de cours sont vives dans tous les thèmes.
        static let onCourse = Color.white
        /// Actions destructrices (Supprimer).
        static let danger = Color(hex: 0xE5484D)
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
    /// `color` vaut nil par défaut plutôt que `Theme.Colors.inkSecondary` :
    /// la couleur dépend du thème actif (main actor), et une valeur par défaut
    /// de paramètre est évaluée hors de tout acteur.
    func plannerLabelStyle(color: Color? = nil) -> some View {
        self
            .font(Theme.Fonts.label)
            .tracking(Theme.Fonts.labelTracking)
            .textCase(.uppercase)
            .foregroundStyle(color ?? Theme.Colors.inkSecondary)
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
