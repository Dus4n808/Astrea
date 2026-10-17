//
//  PlannerIntentStoreTests.swift
//  La couche de données que Siri et les Raccourcis utilisent.
//
//  On teste le store plutôt que `perform()` : c'est lui qui contient la
//  logique (recherche, création, cochage), et il se teste sans passer par le
//  registre global de dépendances d'App Intents.
//

import Foundation
import SwiftData
import Testing

@testable import Planner

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
}

/// Un store neuf, en mémoire, isolé pour chaque test.
private func makeStore() throws -> PlannerIntentStore {
    // `cloudKitDatabase: .none` explicite : sans ça la configuration tente
    // iCloud (l'app hôte a l'entitlement) et le test dépend du réseau.
    let configuration = ModelConfiguration(schema: PlannerStore.schema,
                                           isStoredInMemoryOnly: true,
                                           cloudKitDatabase: .none)
    let container = try ModelContainer(for: PlannerStore.schema, configurations: configuration)
    return PlannerIntentStore(modelContainer: container)
}

@Suite("PlannerIntentStore")
struct PlannerIntentStoreTests {

    // MARK: Création

    @Test("Ajouter une tâche la rend immédiatement retrouvable")
    func addTask() async throws {
        let store = try makeStore()
        let created = try await store.addItem(title: "lire le chapitre 3",
                                              kind: .task,
                                              date: day(2026, 10, 20),
                                              courseID: nil)

        #expect(created.title == "lire le chapitre 3")
        #expect(created.kind == .task)
        #expect(created.isDone == false)
        #expect(created.courseName == nil)

        let found = try await store.items(ids: [created.id])
        #expect(found.count == 1)
        #expect(found.first?.id == created.id)
    }

    @Test("Une tâche peut être rattachée à un cours")
    func addTaskWithCourse() async throws {
        let store = try makeStore()
        let course = try await store.insertCourseForTesting(name: "méthodes mixtes")

        let created = try await store.addItem(title: "texte",
                                              kind: .task,
                                              date: day(2026, 10, 20),
                                              courseID: course.id)

        #expect(created.courseName == "méthodes mixtes")
    }

    @Test("Un cours inconnu ne fait pas échouer la création")
    func addTaskWithUnknownCourse() async throws {
        // Scénario réel : un raccourci enregistré sur un cours supprimé depuis.
        // Mieux vaut une tâche sans cours qu'une erreur face à l'utilisateur.
        let store = try makeStore()
        let created = try await store.addItem(title: "orpheline",
                                              kind: .task,
                                              date: day(2026, 10, 20),
                                              courseID: UUID())

        #expect(created.courseName == nil)
    }

    // MARK: Cochage

    @Test("Cocher puis décocher une tâche")
    func toggleDone() async throws {
        let store = try makeStore()
        let created = try await store.addItem(title: "rendre cycle 1", kind: .task,
                                              date: day(2026, 10, 26), courseID: nil)

        let checked = try await store.setDone(true, itemID: created.id)
        #expect(checked?.isDone == true)

        let unchecked = try await store.setDone(false, itemID: created.id)
        #expect(unchecked?.isDone == false)
    }

    @Test("Cocher une tâche disparue renvoie nil plutôt que de planter")
    func setDoneOnMissingItem() async throws {
        let store = try makeStore()
        let result = try await store.setDone(true, itemID: UUID())
        #expect(result == nil)
    }

    // MARK: Recherche

    @Test("La recherche par titre ignore la casse et les accents")
    func searchIsForgiving() async throws {
        let store = try makeStore()
        _ = try await store.addItem(title: "Présentation orale", kind: .event,
                                    date: day(2026, 10, 30), courseID: nil)

        #expect(try await store.items(matching: "presentation").count == 1)
        #expect(try await store.items(matching: "ORALE").count == 1)
        #expect(try await store.items(matching: "examen").isEmpty)
    }

    @Test("Les suggestions ne proposent que des tâches non faites")
    func suggestionsArePendingTasksOnly() async throws {
        let store = try makeStore()
        let pending = try await store.addItem(title: "à faire", kind: .task,
                                              date: day(2026, 10, 20), courseID: nil)
        let finished = try await store.addItem(title: "déjà faite", kind: .task,
                                               date: day(2026, 10, 21), courseID: nil)
        _ = try await store.setDone(true, itemID: finished.id)
        _ = try await store.addItem(title: "un cours", kind: .event,
                                    date: day(2026, 10, 22), courseID: nil)

        let suggestions = try await store.pendingTasks()
        #expect(suggestions.map(\.id) == [pending.id])
    }

    @Test("Les suggestions respectent leur limite")
    func suggestionsAreBounded() async throws {
        let store = try makeStore()
        for index in 0..<30 {
            _ = try await store.addItem(title: "tâche \(index)", kind: .task,
                                        date: day(2026, 10, 20), courseID: nil)
        }
        #expect(try await store.pendingTasks(limit: 5).count == 5)
    }

    // MARK: Fenêtre de dates

    @Test("La fenêtre inclut son début et exclut sa fin")
    func dateWindowBounds() async throws {
        let store = try makeStore()
        _ = try await store.addItem(title: "début", kind: .task, date: day(2026, 10, 20), courseID: nil)
        _ = try await store.addItem(title: "milieu", kind: .task, date: day(2026, 10, 22), courseID: nil)
        _ = try await store.addItem(title: "fin exclue", kind: .task, date: day(2026, 10, 25), courseID: nil)
        _ = try await store.addItem(title: "avant", kind: .task, date: day(2026, 10, 19), courseID: nil)

        let window = try await store.items(from: day(2026, 10, 20),
                                           before: day(2026, 10, 25),
                                           pendingOnly: true)
        #expect(window.map(\.title) == ["début", "milieu"])
    }

    @Test("pendingOnly: false ramène aussi les tâches cochées")
    func dateWindowIncludesDone() async throws {
        let store = try makeStore()
        let finished = try await store.addItem(title: "faite", kind: .task,
                                               date: day(2026, 10, 21), courseID: nil)
        _ = try await store.setDone(true, itemID: finished.id)

        let pending = try await store.items(from: day(2026, 10, 20),
                                            before: day(2026, 10, 25),
                                            pendingOnly: true)
        let everything = try await store.items(from: day(2026, 10, 20),
                                               before: day(2026, 10, 25),
                                               pendingOnly: false)
        #expect(pending.isEmpty)
        #expect(everything.count == 1)
    }

    @Test("Les résultats sont triés par date")
    func resultsAreSortedByDate() async throws {
        let store = try makeStore()
        _ = try await store.addItem(title: "tard", kind: .task, date: day(2026, 10, 24), courseID: nil)
        _ = try await store.addItem(title: "tôt", kind: .task, date: day(2026, 10, 21), courseID: nil)

        let window = try await store.items(from: day(2026, 10, 20),
                                           before: day(2026, 10, 25),
                                           pendingOnly: true)
        #expect(window.map(\.title) == ["tôt", "tard"])
    }

    // MARK: Cours

    @Test("Les cours remontent triés par nom")
    func coursesAreSortedByName() async throws {
        let store = try makeStore()
        _ = try await store.insertCourseForTesting(name: "sociétés multiculturelles")
        _ = try await store.insertCourseForTesting(name: "méthodes mixtes")

        let names = try await store.allCourses().map(\.name)
        #expect(names == ["méthodes mixtes", "sociétés multiculturelles"])
    }

    @Test("La recherche de cours fonctionne sur un fragment de nom")
    func courseSearch() async throws {
        let store = try makeStore()
        _ = try await store.insertCourseForTesting(name: "méthodes qualitatives A")
        _ = try await store.insertCourseForTesting(name: "transition écologique")

        #expect(try await store.courses(matching: "méthodes").count == 1)
        #expect(try await store.courses(matching: "e").count == 2)
        #expect(try await store.courses(matching: "chimie").isEmpty)
    }

    @Test("Un identifiant de cours inconnu ne ramène rien")
    func unknownCourseID() async throws {
        let store = try makeStore()
        _ = try await store.insertCourseForTesting(name: "altro")
        #expect(try await store.courses(ids: [UUID()]).isEmpty)
    }
}

// MARK: - Aide aux tests

extension PlannerIntentStore {
    /// Insère un cours. L'app n'a pas (encore) d'intent pour créer un cours :
    /// ce raccourci existe uniquement pour monter des scénarios de test.
    func insertCourseForTesting(name: String) throws -> CourseEntity {
        let course = Course(name: name, color: .blue)
        modelContext.insert(course)
        try modelContext.save()
        return CourseEntity(course)
    }
}
