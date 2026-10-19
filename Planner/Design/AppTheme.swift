//
//  AppTheme.swift
//  Les thèmes au choix (Réglages → Thème) et le thème actif.
//
//  Tous les thèmes restent clairs et pastel : fond très pâle, cartes
//  blanches, une couleur d'accent assez soutenue pour porter un texte blanc
//  (boutons, case du jour).
//
//  Ajouter un thème = ajouter un `case`, son nom et sa palette. La valeur
//  brute est enregistrée dans les réglages : ne jamais la renommer.
//

import Foundation
import SwiftUI

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case rose
    case lavender
    case mint
    case peach
    case sky

    /// Thème d'origine de l'app, et repli si la valeur enregistrée est inconnue.
    static let `default`: AppTheme = .rose

    var id: String { rawValue }

    /// Nom affiché dans les réglages.
    var name: String {
        switch self {
        case .rose:     "Rose"
        case .lavender: "Lavande"
        case .mint:     "Menthe"
        case .peach:    "Pêche"
        case .sky:      "Ciel"
        }
    }

    var palette: ThemePalette {
        switch self {
        // Identique aux variables Figma.
        case .rose: ThemePalette(
            background:   Color(hex: 0xFFF1F4),
            surface:      Color(hex: 0xFFFFFF),
            tint:         Color(hex: 0xFFDDE7),
            accent:       Color(hex: 0xFF4F8B),
            accentDeep:   Color(hex: 0xE0306E),
            onAccent:     Color(hex: 0xFFFFFF),
            ink:          Color(hex: 0x1C1216),
            inkSecondary: Color(hex: 0x8A6D77),
            gridLine:     Color(hex: 0xF3CAD6))

        case .lavender: ThemePalette(
            background:   Color(hex: 0xF6F2FF),
            surface:      Color(hex: 0xFFFFFF),
            tint:         Color(hex: 0xE7DEFF),
            accent:       Color(hex: 0x8B6CF0),
            accentDeep:   Color(hex: 0x6D4FD6),
            onAccent:     Color(hex: 0xFFFFFF),
            ink:          Color(hex: 0x1A1626),
            inkSecondary: Color(hex: 0x7A7090),
            gridLine:     Color(hex: 0xDED4F7))

        case .mint: ThemePalette(
            background:   Color(hex: 0xEFFAF5),
            surface:      Color(hex: 0xFFFFFF),
            tint:         Color(hex: 0xD3F2E4),
            accent:       Color(hex: 0x1FA67A),
            accentDeep:   Color(hex: 0x16865F),
            onAccent:     Color(hex: 0xFFFFFF),
            ink:          Color(hex: 0x12201B),
            inkSecondary: Color(hex: 0x667E75),
            gridLine:     Color(hex: 0xC6E9D9))

        case .peach: ThemePalette(
            background:   Color(hex: 0xFFF5EE),
            surface:      Color(hex: 0xFFFFFF),
            tint:         Color(hex: 0xFFE3CF),
            accent:       Color(hex: 0xF2703A),
            accentDeep:   Color(hex: 0xD45A26),
            onAccent:     Color(hex: 0xFFFFFF),
            ink:          Color(hex: 0x21160F),
            inkSecondary: Color(hex: 0x8C7364),
            gridLine:     Color(hex: 0xF5D5BF))

        case .sky: ThemePalette(
            background:   Color(hex: 0xEFF6FF),
            surface:      Color(hex: 0xFFFFFF),
            tint:         Color(hex: 0xD7E9FF),
            accent:       Color(hex: 0x3D8BE0),
            accentDeep:   Color(hex: 0x2A6FC2),
            onAccent:     Color(hex: 0xFFFFFF),
            ink:          Color(hex: 0x111A26),
            inkSecondary: Color(hex: 0x667588),
            gridLine:     Color(hex: 0xCBDFF5))
        }
    }

    /// Lit une valeur enregistrée ; une valeur inconnue (thème retiré, données
    /// abîmées) retombe sur le thème par défaut.
    init(storedValue: String?) {
        self = storedValue.flatMap(AppTheme.init(rawValue:)) ?? .default
    }
}

/// Le thème choisi, partagé par toute l'app et enregistré dans les réglages.
///
/// @Observable : une vue qui lit `Theme.Colors.…` dans son `body` est
/// redessinée automatiquement quand on change de thème.
@Observable
final class ThemeStore {
    static let storageKey = "appTheme"

    static let shared = ThemeStore()

    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// - Parameter defaults: injecté par les tests pour ne pas toucher aux
    ///   vrais réglages.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.theme = AppTheme(storedValue: defaults.string(forKey: Self.storageKey))
    }
}
