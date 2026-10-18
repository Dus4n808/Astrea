//
//  AddItemButton.swift
//  Bouton « + » de la barre d'outils, réutilisé par plusieurs écrans.
//
//  - clic simple        → nouvelle tâche (le cas le plus fréquent)
//  - appui long / flèche → menu Tâche / Événement / Vacances
//  - ⌘N sur Mac et iPad avec clavier
//

import SwiftUI

struct AddItemButton: View {
    @Environment(AppState.self) private var appState

    /// Jour pré-rempli dans l'éditeur (ex. le jour sélectionné).
    var date: Date = .now

    var body: some View {
        Menu {
            ForEach(ItemKind.allCases) { kind in
                Button(kind.title, systemImage: kind.systemImage) {
                    appState.openEditor(kind: kind, on: date)
                }
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
        } primaryAction: {
            appState.openEditor(kind: .task, on: date)
        }
        .keyboardShortcut("n", modifiers: .command)
    }
}
