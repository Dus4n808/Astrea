//
//  ItemDraftTests.swift
//  Ce que l'éditeur écrit vraiment en base quand on appuie sur « Valider ».
//
//  C'est le seul chemin d'écriture de l'interface : chaque règle métier
//  (vacances sans cours, événements jamais importants, checklist réservée
//  aux tâches…) y est appliquée. Un oubli ici = une donnée incohérente,
//  synchronisée ensuite sur tous les appareils.
//

import Foundation
import SwiftData
import Testing

@testable import Planner

private func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: day,
                                               hour: hour, minute: minute))!
}

@MainActor
private func allItems(in context: ModelContext) throws -> [PlannerItem] {
    try context.fetch(FetchDescriptor<PlannerItem>())
}

private func createDraft(_ kind: ItemKind = .task) -> ItemDraft {
    ItemDraft(request: EditorRequest(mode: .create(kind: kind, date: time(2026, 10, 19))))
}

@Suite("Brouillon de l'éditeur")
@MainActor
struct ItemDraftTests {
    /// Une base neuve, en mémoire, sans iCloud, recréée pour chaque test.
    /// Le conteneur doit rester en vie : un `mainContext` dont le conteneur
    /// a été libéré fait planter SwiftData à la première écriture.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(schema: PlannerStore.schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        container = try ModelContainer(for: PlannerStore.schema, configurations: configuration)
    }

    // MARK: Validation

    @Test("Un titre vide ou fait d'espaces ne peut pas être validé", arguments: ["", "   ", "\n\t"])
    func blankTitleCannotBeSaved(title: String) {
        var draft = createDraft()
        draft.title = title
        #expect(!draft.canSave)
    }

    // MARK: Création

    @Test("Créer insère un seul élément, titre et détails nettoyés")
    func createInsertsCleanItem() throws {
        var draft = createDraft()
        draft.title = "  lire chapitre 3  "
        draft.details = "\n p. 40 à 52 \n"
        draft.save(in: context)

        let items = try allItems(in: context)
        #expect(items.count == 1)
        #expect(items.first?.title == "lire chapitre 3")
        #expect(items.first?.details == "p. 40 à 52")
    }

    @Test("Des vacances n'ont ni cours, ni rappel, ni importance, mais gardent leur fin")
    func holidayRules() throws {
        let course = Course(name: "méthodes mixtes", color: .blue)
        context.insert(course)

        var draft = createDraft(.holiday)
        draft.title = "semaine intercalaire"
        draft.course = course
        draft.isImportant = true
        draft.reminder = .dayBefore
        draft.endDate = time(2026, 10, 23)
        draft.save(in: context)

        let item = try #require(try allItems(in: context).first)
        #expect(item.course == nil)
        #expect(item.reminder == ReminderOption.none)
        #expect(!item.isImportant)
        #expect(item.endDate == time(2026, 10, 23))
    }

    @Test("Seules les vacances durent plusieurs jours", arguments: [ItemKind.task, .event])
    func onlyHolidaysHaveEndDate(kind: ItemKind) throws {
        var draft = createDraft(kind)
        draft.title = "x"
        draft.endDate = time(2026, 10, 25)
        draft.save(in: context)

        #expect(try #require(try allItems(in: context).first).endDate == nil)
    }

    @Test("Une fin avant le début est ignorée, même pour des vacances")
    func holidayEndBeforeStartIsDropped() throws {
        var draft = createDraft(.holiday)
        draft.title = "x"
        draft.endDate = time(2026, 10, 1)
        draft.save(in: context)

        #expect(try #require(try allItems(in: context).first).endDate == nil)
    }

    @Test("Un événement n'est jamais important")
    func eventsAreNeverImportant() throws {
        var draft = createDraft(.event)
        draft.title = "présentation orale"
        draft.isImportant = true
        draft.save(in: context)

        #expect(try #require(try allItems(in: context).first).isImportant == false)
    }

    @Test("Un rappel « x min avant » devient « le jour même » sur un élément sans heure")
    func reminderAdaptsToAllDay() throws {
        var draft = createDraft()
        draft.title = "x"
        draft.reminder = .tenMinutes
        draft.removeTime()
        draft.save(in: context)

        #expect(try #require(try allItems(in: context).first).reminder == .sameDay)
    }

    // MARK: Checklist

    @Test("La checklist garde son ordre et laisse tomber les lignes vides")
    func checklistOrderAndBlankLines() throws {
        var draft = createDraft()
        draft.title = "réviser"
        draft.checklist = [
            .init(title: "chapitre 1", isDone: true),
            .init(title: "   "),
            .init(title: "chapitre 2"),
        ]
        draft.save(in: context)

        let item = try #require(try allItems(in: context).first)
        #expect(item.sortedChecklist.map(\.title) == ["chapitre 1", "chapitre 2"])
        #expect(item.sortedChecklist.map(\.order) == [0, 1])
        #expect(item.sortedChecklist.map(\.isDone) == [true, false])
    }

    @Test("Passer une tâche en événement efface sa checklist, sans lignes orphelines")
    func changingKindClearsChecklist() throws {
        var draft = createDraft()
        draft.title = "réviser"
        draft.checklist = [.init(title: "chapitre 1"), .init(title: "chapitre 2")]
        draft.save(in: context)
        try context.save()

        let item = try #require(try allItems(in: context).first)
        var edit = ItemDraft(request: EditorRequest(mode: .edit(item)))
        edit.kind = .event
        edit.save(in: context)
        try context.save()

        #expect(item.sortedChecklist.isEmpty)
        // Les anciennes lignes sont vraiment supprimées, pas seulement détachées :
        // sinon elles resteraient synchronisées dans iCloud pour rien.
        #expect(try context.fetchCount(FetchDescriptor<ChecklistItem>()) == 0)
    }

    // MARK: Modification

    @Test("Modifier met à jour l'élément existant, sans en créer un deuxième")
    func editDoesNotDuplicate() throws {
        let item = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        context.insert(item)
        let uuid = item.uuid

        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.title = "lecture chapitre 4"
        draft.save(in: context)

        let items = try allItems(in: context)
        #expect(items.count == 1)
        #expect(items.first?.title == "lecture chapitre 4")
        // L'identifiant que Siri a mémorisé ne change pas.
        #expect(items.first?.uuid == uuid)
    }

    @Test("Annuler (ne pas enregistrer) laisse l'élément intact")
    func unsavedDraftChangesNothing() throws {
        let item = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        item.isImportant = true
        context.insert(item)

        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.title = "autre chose"
        draft.isImportant = false
        draft.kind = .event

        #expect(item.title == "lecture")
        #expect(item.isImportant)
        #expect(item.kind == .task)
    }

    @Test("Le brouillon reprend fidèlement l'élément à modifier")
    func editDraftMirrorsItem() {
        let course = Course(name: "méthodes mixtes", color: .violet)
        let item = PlannerItem(title: "texte", date: time(2026, 10, 19, 14, 30), isAllDay: false,
                               course: course, details: "p. 12")
        item.isImportant = true
        item.reminder = .fifteenMinutes

        let draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        #expect(draft.title == "texte")
        #expect(draft.date == time(2026, 10, 19, 14, 30))
        #expect(!draft.isAllDay)
        #expect(draft.course === course)
        #expect(draft.details == "p. 12")
        #expect(draft.isImportant)
        #expect(draft.reminder == .fifteenMinutes)
        #expect(draft.originalID == item.uuid)
    }

    // MARK: Suppression pendant l'édition

    @Test("Un élément supprimé ailleurs pendant l'édition n'est pas recréé")
    func deletedElsewhereIsNotResurrected() throws {
        let item = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        context.insert(item)
        try context.save()

        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.title = "modifié trop tard"

        // Suppression arrivée entre-temps (autre appareil via iCloud, Siri…).
        context.delete(item)
        try context.save()

        #expect(draft.originalIsGone)
        draft.save(in: context)
        draft.delete(in: context)
        try context.save()
        #expect(try allItems(in: context).isEmpty)
    }

    @Test("Supprimer depuis l'éditeur retire l'élément et sa checklist")
    func deleteRemovesItemAndChecklist() throws {
        var create = createDraft()
        create.title = "réviser"
        create.checklist = [.init(title: "chapitre 1")]
        create.save(in: context)
        try context.save()

        let item = try #require(try allItems(in: context).first)
        ItemDraft(request: EditorRequest(mode: .edit(item))).delete(in: context)
        try context.save()

        #expect(try allItems(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<ChecklistItem>()) == 0)
    }

    @Test("Un brouillon de création n'a rien à supprimer")
    func createDraftDeleteIsNoOp() throws {
        context.insert(PlannerItem(title: "autre", date: .now))
        createDraft().delete(in: context)
        #expect(try allItems(in: context).count == 1)
        #expect(!createDraft().originalIsGone)
    }
}
