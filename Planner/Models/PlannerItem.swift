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

    /// true = pas d'heure : l'élément est prévu ce jour-là, l'heure de `date`
    /// est ignorée. (Nom conservé : le champ est déjà dans le schéma CloudKit.)
    var isAllDay: Bool = true

    /// Dernier jour inclus, pour les éléments sur plusieurs jours (vacances).
    /// nil = un seul jour.
    var endDate: Date?

    var details: String = ""

    /// Ne pas modifier directement : passer par `setDone(_:)`, qui tient
    /// `completedAt` à jour.
    var isDone: Bool = false

    /// Moment où la tâche a été cochée (nil = pas faite, ou cochée avant
    /// l'ajout de ce champ). Sert à l'onglet « Fait » : la dernière tâche
    /// terminée en haut. Optionnel : CloudKit l'accepte sans migration.
    var completedAt: Date?

    /// Tâche importante : mise en avant dans l'agenda (en tête du jour,
    /// carte soulignée). Valeur par défaut obligatoire pour CloudKit : les
    /// éléments déjà synchronisés la prennent sans migration.
    var isImportant: Bool = false

    /// Rappel avant l'élément (voir ReminderOption). Stocké en texte, vide =
    /// aucun rappel. Utilise plutôt `reminder`. Les notifications elles-mêmes
    /// sont programmées par chaque appareil à partir de ce champ
    /// (ReminderScheduler) : elles suivent donc les changements reçus d'iCloud.
    var reminderRaw: String = ""

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

    /// Coche ou décoche, en datant le moment où la tâche est faite.
    /// Ne fait rien si l'état ne change pas : recocher une tâche déjà faite
    /// ne doit pas la faire remonter dans l'onglet « Fait ».
    func setDone(_ done: Bool, at date: Date = .now) {
        guard done != isDone else { return }
        isDone = done
        completedAt = done ? date : nil
    }

    func toggleDone() { setDone(!isDone) }

    /// Date de tri de l'onglet « Fait ». Les tâches cochées avant l'ajout de
    /// `completedAt` n'ont pas de date de complétion : on prend leur date
    /// prévue, au plus près de la réalité.
    var doneSortDate: Date { completedAt ?? date }

    /// SwiftData ne garantit pas l'ordre d'un tableau de relation :
    /// on trie toujours via `order` avant d'afficher.
    var sortedChecklist: [ChecklistItem] {
        (checklist ?? []).sorted { $0.order < $1.order }
    }
}
