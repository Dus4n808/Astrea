//
//  ItemDraft.swift
//  Brouillon modifiable de l'éditeur.
//
//  Pourquoi un brouillon au lieu de modifier directement le PlannerItem ?
//  Parce que SwiftData enregistre les changements tout de suite. Si on
//  modifiait l'objet en direct, appuyer sur « Annuler » ne servirait à rien.
//  Ici on travaille sur une copie (`struct`) et on ne l'applique qu'au clic
//  sur « Valider ».
//

import Foundation
import SwiftData

struct ItemDraft {
    /// Une ligne de checklist dans le brouillon.
    struct ChecklistLine: Identifiable {
        let id = UUID()
        var title: String
        var isDone: Bool = false
    }

    var kind: ItemKind = .task
    var title: String = ""
    var date: Date = .now
    /// true = pas d'heure : l'élément est simplement prévu ce jour-là.
    /// (Nom hérité du modèle, où il est synchronisé avec iCloud.)
    var isAllDay: Bool = true
    var endDate: Date = .now
    var course: Course?
    var details: String = ""
    var checklist: [ChecklistLine] = []

    /// L'élément d'origine si on modifie, nil si on crée.
    private(set) var original: PlannerItem?

    // MARK: - Création du brouillon

    init(request: EditorRequest) {
        switch request.mode {
        case let .create(kind, date):
            self.kind = kind
            self.date = Self.defaultDate(for: date)
            self.endDate = self.date

        case let .edit(item):
            original = item
            kind = item.kind
            title = item.title
            date = item.date
            isAllDay = item.isAllDay
            endDate = item.endDate ?? item.date
            course = item.course
            details = item.details
            checklist = item.sortedChecklist.map { ChecklistLine(title: $0.title, isDone: $0.isDone) }
        }
    }

    /// Jour choisi + heure actuelle arrondie (utile si on ajoute une heure).
    private static func defaultDate(for day: Date) -> Date {
        let calendar = Calendar.planner
        let hour = calendar.component(.hour, from: .now)
        return calendar.date(bySettingHour: min(hour + 1, 23), minute: 0, second: 0, of: day) ?? day
    }

    // MARK: - Heure (facultative)

    /// Donne une heure à l'élément. S'il n'en avait jamais eu (minuit, cas
    /// d'un élément créé par Siri), on propose l'heure pleine qui suit.
    mutating func addTime(now: Date = .now) {
        let calendar = Calendar.planner
        let time = calendar.dateComponents([.hour, .minute], from: date)
        if time.hour == 0 && time.minute == 0 {
            let nextHour = min(calendar.component(.hour, from: now) + 1, 23)
            date = MiniTimePicker.date(date, hour: nextHour, minute: 0, calendar: calendar)
        }
        isAllDay = false
    }

    /// Retire l'heure : l'élément redevient « ce jour-là ».
    mutating func removeTime() {
        isAllDay = true
    }

    // MARK: - Validation

    /// Titre sans espaces superflus.
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Le bouton Valider n'est actif que si le brouillon est enregistrable.
    var canSave: Bool { !trimmedTitle.isEmpty }

    // MARK: - Enregistrement

    /// Applique le brouillon : crée un nouvel élément ou met à jour l'existant.
    func save(in context: ModelContext) {
        let item = original ?? PlannerItem(title: trimmedTitle, date: date)
        if original == nil { context.insert(item) }

        item.title = trimmedTitle
        item.kind = kind
        item.date = date
        item.isAllDay = isAllDay
        // Seules les vacances durent plusieurs jours.
        item.endDate = (kind == .holiday && endDate > date) ? endDate : nil
        // Des vacances ne sont pas liées à un cours.
        item.course = kind == .holiday ? nil : course
        item.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        replaceChecklist(of: item, in: context)
    }

    /// Remplace la checklist entière (plus simple et plus sûr que de
    /// comparer ligne par ligne ce qui a changé).
    private func replaceChecklist(of item: PlannerItem, in context: ModelContext) {
        for old in item.sortedChecklist { context.delete(old) }
        item.checklist = []

        guard kind == .task else { return }
        let lines = checklist.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        item.checklist = lines.enumerated().map { position, line in
            ChecklistItem(title: line.title, order: position, isDone: line.isDone)
        }
    }

    /// Supprime l'élément d'origine (mode édition uniquement).
    func delete(in context: ModelContext) {
        guard let original else { return }
        context.delete(original)
    }
}
