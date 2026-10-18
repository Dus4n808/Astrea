//
//  ItemKind.swift
//  Les trois types d'éléments qu'on peut ajouter au calendrier.
//

import Foundation

nonisolated enum ItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Quelque chose à faire (lire, rendre un travail…). Peut être cochée.
    case task
    /// Un rendez-vous ou un cours ponctuel.
    case event
    /// Une période sans cours (vacances, semaine intercalaire). Peut durer plusieurs jours.
    case holiday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:    "Tâche"
        case .event:   "Événement"
        case .holiday: "Vacances"
        }
    }

    /// Titre de l'éditeur en création (accords en français).
    var newItemTitle: String {
        switch self {
        case .task:    "Nouvelle tâche"
        case .event:   "Nouvel événement"
        case .holiday: "Nouvelles vacances"
        }
    }

    var systemImage: String {
        switch self {
        case .task:    "checkmark.square"
        case .event:   "calendar"
        case .holiday: "sun.max"
        }
    }

    /// Seules les tâches ont une case à cocher.
    var isCheckable: Bool { self == .task }
}
