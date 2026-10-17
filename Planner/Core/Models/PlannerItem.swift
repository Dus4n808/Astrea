//
//  PlannerItem.swift
//  Un élément du calendrier : tâche, événement ou vacances.
//
//  On utilise UN seul modèle pour les trois types, avec un champ `kind`.
//  Raison : ils partagent presque tous leurs champs (titre, date, cours,
//  détails). Trois modèles séparés dupliqueraient tout le code d'affichage.
//

import Foundation
import SwiftData

@Model
nonisolated final class PlannerItem {
    /// Identifiant stable, identique sur tous les appareils.
    /// Les raccourcis Siri enregistrent cette valeur : elle ne doit jamais
    /// changer pour un élément donné (l'identifiant SwiftData interne, lui,
    /// diffère d'un appareil à l'autre).
    var uuid: UUID = UUID()

    var title: String = ""

    /// Type stocké en texte (voir ItemKind). Utilise plutôt `kind`.
    var kindRaw: String = ItemKind.task.rawValue

    /// Jour (et heure si `isAllDay == false`) de l'élément.
    var date: Date = Date.now

    /// true = « Fin de journée » / toute la journée, l'heure de `date` est ignorée.
    var isAllDay: Bool = true

    /// Dernier jour inclus, pour les éléments sur plusieurs jours (vacances).
    /// nil = un seul jour.
    var endDate: Date?

    var details: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date.now

    /// Cours associé (optionnel : des vacances n'ont pas de cours).
    var course: Course?

    /// Sous-tâches. `.cascade` : supprimées avec l'élément.
    /// Optionnelle parce que CloudKit l'exige pour toute relation « à
    /// plusieurs » ; côté code on passe par `sortedChecklist`.
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.parent)
    var checklist: [ChecklistItem]? = []

    init(
        title: String,
        kind: ItemKind = .task,
        date: Date,
        isAllDay: Bool = true,
        endDate: Date? = nil,
        course: Course? = nil,
        details: String = ""
    ) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.date = date
        self.isAllDay = isAllDay
        self.endDate = endDate
        self.course = course
        self.details = details
    }

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRaw) ?? .task }
        set { kindRaw = newValue.rawValue }
    }

    /// SwiftData ne garantit pas l'ordre d'un tableau de relation :
    /// on trie toujours via `order` avant d'afficher.
    var sortedChecklist: [ChecklistItem] {
        (checklist ?? []).sorted { $0.order < $1.order }
    }
}
