//
//  AppleIntelligenceTests.swift
//  La traduction planner ↔ schéma `.reminders` utilisée par Siri.
//
//  Le compilateur vérifie déjà la FORME des types (le validateur de schémas
//  d'Xcode). Ici on vérifie le SENS : qu'une échéance sans heure devient
//  « fin de journée », qu'une tâche sans cours atterrit dans « Sans cours »,
//  qu'une mise à jour ne touche que ce qu'on lui demande, etc.
//

import Foundation
import SwiftData
import Testing

@testable import Planner

private func makeStore() throws -> PlannerIntentStore {
    let configuration = ModelConfiguration(schema: PlannerStore.schema,
                                           isStoredInMemoryOnly: true,
                                           cloudKitDatabase: .none)
    let container = try ModelContainer(for: PlannerStore.schema, configurations: configuration)
    return PlannerIntentStore(modelContainer: container)
}

@Suite("Échéance Siri")
struct TaskDueDateTests {

    @Test("Une échéance sans heure devient « fin de journée »")
    func dayOnlyIsAllDay() {
        let due = TaskDueDate(components: DateComponents(year: 2026, month: 10, day: 23))
        #expect(due.isAllDay)
        #expect(due.date == Calendar.planner.date(from: DateComponents(year: 2026, month: 10, day: 23)))
    }

    @Test("Une échéance avec heure garde l'heure")
    func timedKeepsHour() {
        let due = TaskDueDate(components: DateComponents(year: 2026, month: 10, day: 23, hour: 14, minute: 30))
        #expect(!due.isAllDay)
        #expect(Calendar.planner.component(.hour, from: due.date) == 14)
        #expect(Calendar.planner.component(.minute, from: due.date) == 30)
    }

    @Test("Sans échéance : aujourd'hui, fin de journée")
    func missingIsToday() {
        let due = TaskDueDate(components: nil)
        #expect(due.isAllDay)
        #expect(due.date == Calendar.planner.startOfDay(for: .now))
    }

    @Test("Aller-retour : une tâche « fin de journée » ne renvoie pas d'heure à Siri")
    func roundTripOmitsHourWhenAllDay() throws {
        let date = try #require(Calendar.planner.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
        #expect(TaskDueDate.components(of: date, isAllDay: true).hour == nil)
        #expect(TaskDueDate.components(of: date, isAllDay: false).hour == 9)
    }
}

@Suite("Note Siri")
struct TaskNoteTests {

    @Test("Note et liens sont réunis dans les détails, un par ligne")
    func mergesNoteAndLinks() throws {
        let url = try #require(URL(string: "https://moodle.example/cours"))
        #expect(TaskNote.details(note: AttributedString("pages 12 à 40"), urls: [url])
                == "pages 12 à 40\nhttps://moodle.example/cours")
    }

    @Test("Rien du tout = nil, pour qu'une mise à jour ne vide pas les détails")
    func emptyIsNil() {
        #expect(TaskNote.details(note: nil, urls: []) == nil)
        #expect(TaskNote.details(note: AttributedString("   "), urls: []) == nil)
    }
}

@Suite("Store côté Apple Intelligence")
struct AppleIntelligenceStoreTests {

    @Test("Une tâche sans cours appartient à la liste « Sans cours »")
    func taskWithoutCourseIsInNoCourseList() async throws {
        let store = try makeStore()
        let created = try await store.addTask(title: "lire", details: "", date: .now,
                                              isAllDay: true, listID: nil)
        #expect(created.list.id == CourseListEntity.noCourseID)
    }

    @Test("Choisir « Sans cours » ne rattache à aucun cours")
    func noCourseListMeansNoCourse() async throws {
        let store = try makeStore()
        let created = try await store.addTask(title: "lire", details: "", date: .now,
                                              isAllDay: true, listID: CourseListEntity.noCourseID)
        #expect(try await store.items(ids: [created.id]).first?.courseName == nil)
    }

    @Test("Une tâche peut être créée directement dans un cours")
    func addToCourse() async throws {
        let store = try makeStore()
        let course = try await store.insertCourseForTesting(name: "méthodes mixtes")
        let created = try await store.addTask(title: "texte", details: "", date: .now,
                                              isAllDay: true, listID: course.id)
        #expect(created.list.id == course.id)
        #expect(created.list.name == "méthodes mixtes")
    }

    @Test("La liste « Sans cours » est proposée et retrouvable par son identifiant")
    func noCourseListIsResolvable() async throws {
        let store = try makeStore()
        #expect(try await store.allCourseLists().contains { $0.id == CourseListEntity.noCourseID })
        #expect(try await store.courseLists(ids: [CourseListEntity.noCourseID]).count == 1)
    }

    @Test("Seules les tâches sont des rappels, pas les événements")
    func onlyTasksAreReminders() async throws {
        let store = try makeStore()
        let event = try await store.addItem(title: "colloque", kind: .event, date: .now, courseID: nil)
        #expect(try await store.taskReminders(ids: [event.id]).isEmpty)
        #expect(try await store.allTaskReminders().isEmpty)
    }

    @Test("Une mise à jour ne touche que ce qu'on lui donne")
    func updateIsPartial() async throws {
        let store = try makeStore()
        let created = try await store.addTask(title: "lire", details: "chapitre 3", date: .now,
                                              isAllDay: true, listID: nil)

        var changes = PlannerIntentStore.TaskChanges()
        changes.isDone = true
        let updated = try #require(try await store.updateTask(id: created.id, changes))

        #expect(updated.isCompleted)
        #expect(updated.title == "lire")
        #expect(updated.note.map { String($0.characters) } == "chapitre 3")
    }

    @Test("Mettre à jour une tâche disparue renvoie nil")
    func updateMissing() async throws {
        let store = try makeStore()
        #expect(try await store.updateTask(id: UUID(), .init(isDone: true)) == nil)
    }

    @Test("Supprimer retire les tâches et compte ce qui a été supprimé")
    func deleteItems() async throws {
        let store = try makeStore()
        let a = try await store.addTask(title: "a", details: "", date: .now, isAllDay: true, listID: nil)
        let b = try await store.addTask(title: "b", details: "", date: .now, isAllDay: true, listID: nil)

        #expect(try await store.deleteItems(ids: [a.id, UUID()]) == 1)
        #expect(try await store.allTaskReminders().map(\.id) == [b.id])
    }
}
