//
//  AppState.swift
//  État global de navigation, partagé par toutes les vues via l'environnement.
//
//  Pourquoi un objet global ?
//  Plusieurs endroits doivent pouvoir ouvrir l'éditeur (bouton +, menu
//  contextuel d'un jour, tap sur une pastille…). Plutôt que de faire
//  remonter des callbacks à travers 5 vues, chaque vue appelle simplement
//  `appState.openEditor(...)` et RootView affiche la feuille.
//
//  Règle : ici on ne met QUE de la navigation (quelle section, quelle
//  feuille ouverte). Les données vivent dans SwiftData, pas ici.
//

import Foundation
import Observation

@Observable
final class AppState {
    /// Instance unique de l'app.
    ///
    /// Un singleton ici parce qu'un App Intent (« Ouvre l'agenda ») doit
    /// pouvoir pousser une navigation sans passer par la hiérarchie de vues :
    /// Siri peut réveiller le processus avant qu'aucune vue n'existe.
    static let shared = AppState()

    /// Section actuellement affichée.
    var section: AppSection = .calendar

    /// Feuille d'édition ouverte (nil = aucune).
    var editorRequest: EditorRequest?

    /// Jour pré-rempli quand on ajoute un élément depuis la tab bar.
    /// Les écrans qui ont une notion de « jour courant » (le calendrier)
    /// le tiennent à jour ; ailleurs c'est aujourd'hui.
    var focusedDate: Date = .now

    /// Ouvre l'éditeur pour créer un nouvel élément.
    func openEditor(kind: ItemKind = .task, on date: Date = .now) {
        editorRequest = EditorRequest(mode: .create(kind: kind, date: date))
    }

    /// Ouvre l'éditeur sur un élément existant.
    func openEditor(for item: PlannerItem) {
        editorRequest = EditorRequest(mode: .edit(item))
    }

    /// Fiche de consultation ouverte (nil = aucune). Voir ItemDetailView.
    var detailItem: PlannerItem?

    /// Ouvre la fiche d'un élément existant (tap sur une tâche).
    /// La modification se fait ensuite via le bouton « Modifier » de la fiche.
    func openDetail(for item: PlannerItem) {
        detailItem = item
    }
}
