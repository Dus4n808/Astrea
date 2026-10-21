//
//  SecurityAndSyncTests.swift
//  Les garde-fous qui ne se voient pas à l'écran :
//  - Siri ne doit rien lire ni écrire sur un appareil verrouillé ;
//  - les règles de suppression gardent la base (et donc iCloud) cohérente ;
//  - les identifiants mémorisés par Siri ne changent jamais ;
//  - l'état iCloud affiché dit la vérité.
//

import AppIntents
import CloudKit
import Foundation
import SwiftData
import Testing

@testable import Planner

private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: PlannerStore.schema,
                                           isStoredInMemoryOnly: true,
                                           cloudKitDatabase: .none)
    return try ModelContainer(for: PlannerStore.schema, configurations: configuration)
}

// MARK: - Sécurité Siri

@Suite("Sécurité des intents")
struct IntentSecurityTests {

    /// Par défaut un intent tourne appareil verrouillé : n'importe qui tenant
    /// le téléphone pourrait lire, cocher ou supprimer des tâches via Siri.
    @Test("Toute intent qui lit ou modifie les données exige le déverrouillage")
    func dataIntentsRequireAuthentication() {
        let policies: [String: IntentAuthenticationPolicy] = [
            "AddTaskIntent": AddTaskIntent.authenticationPolicy,
            "SetTaskDoneIntent": SetTaskDoneIntent.authenticationPolicy,
            "UpcomingTasksIntent": UpcomingTasksIntent.authenticationPolicy,
            "CreateTaskReminderIntent": CreateTaskReminderIntent.authenticationPolicy,
            "UpdateTaskReminderIntent": UpdateTaskReminderIntent.authenticationPolicy,
            "DeleteTaskRemindersIntent": DeleteTaskRemindersIntent.authenticationPolicy,
        ]
        for (name, policy) in policies {
            #expect(policy == .requiresAuthentication, "\(name) tourne sans déverrouillage")
        }
    }

    @Test("Chaque erreur Siri a un message lisible", arguments: [
        PlannerIntentError.emptyTitle, .itemNotFound, .invalidRange,
        .recurrenceUnsupported, .locationUnsupported,
    ])
    func errorsHaveMessages(error: PlannerIntentError) {
        #expect(!String(localized: error.localizedStringResource).isEmpty)
    }
}

// MARK: - Contrats Siri

@Suite("Contrats Siri")
struct SiriContractTests {

    @Test("L'identifiant de la liste « Sans cours » ne change jamais")
    func noCourseIDIsStable() {
        // Siri a pu le mémoriser : le changer casserait ses demandes.
        #expect(CourseListEntity.noCourseID.uuidString == "5E1C0A55-0000-4000-8000-000000000000")
    }

    @Test("Siri et l'app voient la même tâche sous le même identifiant")
    func entitiesShareTheItemUUID() {
        let item = PlannerItem(title: "lecture", date: .now)
        #expect(PlannerItemEntity(item).id == item.uuid)
        #expect(TaskReminderEntity(item).id == item.uuid)
    }

    @Test("Déplacer une tâche vers « Sans cours » la détache de son cours")
    func moveToNoCourseList() async throws {
        let container = try makeContainer()
        let store = PlannerIntentStore(modelContainer: container)
        let course = Course(name: "méthodes mixtes", color: .blue)
        let context = ModelContext(container)
        context.insert(course)
        try context.save()

        let task = try await store.addTask(title: "texte", details: "", date: .now,
                                           isAllDay: true, listID: course.uuid)
        #expect(task.list.id == course.uuid)

        let moved = try #require(try await store.updateTask(
            id: task.id, .init(listID: CourseListEntity.noCourseID)))
        #expect(moved.list.id == CourseListEntity.noCourseID)
    }

    @Test("Une mise à jour avec un titre ne vide pas les détails")
    func updateTitleKeepsDetails() async throws {
        let store = PlannerIntentStore(modelContainer: try makeContainer())
        let task = try await store.addTask(title: "texte", details: "p. 12", date: .now,
                                           isAllDay: true, listID: nil)
        // Ce que fait UpdateTaskReminderIntent sans note ni lien.
        let details = TaskNote.details(note: nil, urls: [])
        let updated = try #require(try await store.updateTask(
            id: task.id, .init(title: "texte relu", details: details)))
        #expect(updated.title == "texte relu")
        #expect(updated.note.map { String($0.characters) } == "p. 12")
    }
}

// MARK: - Intégrité des données

@Suite("Règles de suppression")
@MainActor
struct DeleteRuleTests {

    @Test("Supprimer un cours garde ses tâches, simplement sans cours")
    func deletingCourseKeepsItems() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = Course(name: "méthodes mixtes", color: .blue)
        let item = PlannerItem(title: "lecture", date: .now, course: course)
        context.insert(course)
        context.insert(item)
        try context.save()

        context.delete(course)
        try context.save()

        let items = try context.fetch(FetchDescriptor<PlannerItem>())
        #expect(items.map(\.title) == ["lecture"])
        #expect(items.first?.course == nil)
    }

    @Test("Supprimer une tâche par Siri supprime aussi sa checklist")
    func siriDeleteCascadesChecklist() async throws {
        let container = try makeContainer()
        let item = PlannerItem(title: "réviser", date: .now)
        item.checklist = [ChecklistItem(title: "chapitre 1", order: 0),
                          ChecklistItem(title: "chapitre 2", order: 1)]
        container.mainContext.insert(item)
        try container.mainContext.save()

        let store = PlannerIntentStore(modelContainer: container)
        #expect(try await store.deleteItems(ids: [item.uuid]) == 1)

        let fresh = ModelContext(container)
        #expect(try fresh.fetchCount(FetchDescriptor<PlannerItem>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<ChecklistItem>()) == 0)
    }
}

// MARK: - État iCloud

@Suite("État iCloud")
@MainActor
struct ICloudStatusTests {

    @Test("Chaque statut CloudKit donne le bon état", arguments: [
        (CKAccountStatus.available, ICloudStatus.State.available),
        (.noAccount, .noAccount),
        (.restricted, .restricted),
        (.temporarilyUnavailable, .temporarilyUnavailable),
        (.couldNotDetermine, .unknown),
    ])
    func mapsAccountStatus(status: CKAccountStatus, expected: ICloudStatus.State) {
        #expect(ICloudStatus.State(status) == expected)
    }

    @Test("Seul « iCloud activé » affiche l'icône validée", arguments: [
        ICloudStatus.State.checking, .available, .noAccount, .restricted,
        .temporarilyUnavailable, .localOnly, .unknown,
    ])
    func onlyAvailableLooksSynced(state: ICloudStatus.State) {
        #expect((state.symbolName == "checkmark.icloud") == (state == .available))
    }

    @Test("Tout état autre que la vérification explique la situation", arguments: [
        ICloudStatus.State.available, .noAccount, .restricted,
        .temporarilyUnavailable, .localOnly, .unknown,
    ])
    func statesHaveMessages(state: ICloudStatus.State) {
        #expect(!String(localized: state.message).isEmpty)
    }
}
