//
//  EditorRequest.swift
//  « Demande d'ouverture » de l'éditeur : créer un nouvel élément ou en
//  modifier un existant. C'est cet objet que `AppState` stocke et que
//  `RootView` utilise pour présenter la feuille.
//

import Foundation

struct EditorRequest: Identifiable {
    enum Mode {
        case create(kind: ItemKind, date: Date)
        case edit(PlannerItem)
    }

    /// Nouvel identifiant à chaque demande : SwiftUI recrée la feuille proprement.
    let id = UUID()
    let mode: Mode

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
}
