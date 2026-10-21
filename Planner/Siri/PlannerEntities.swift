//
//  PlannerEntities.swift
//  Les types du planner tels que Siri et les Raccourcis les voient.
//
//  Ce sont des copies (des structs), pas les objets SwiftData : le système
//  les conserve, les envoie sur un autre appareil, les relit des jours plus
//  tard. Seul `id` est vraiment persisté par le système ; tout le reste est
//  relu à la demande via la requête (`EntityQuery`).
//
//  C'est pour ça que `PlannerItem.uuid` ne doit jamais changer : c'est la clé
//  que Siri garde dans les raccourcis enregistrés.
//

import AppIntents
import Foundation

// MARK: - Cours

struct CourseEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cours")
    static let defaultQuery = CourseEntityQuery()

    let id: UUID

    @Property(title: "Nom")
    var name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ course: Course) {
        self.init(id: course.uuid, name: course.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CourseEntityQuery: EntityStringQuery {
    @Dependency private var store: PlannerIntentStore

    func entities(for identifiers: [UUID]) async throws -> [CourseEntity] {
        try await store.courses(ids: identifiers)
    }

    /// Recherche libre dans le sélecteur : rien n'est filtré par le système,
    /// c'est à nous de faire la correspondance.
    func entities(matching string: String) async throws -> [CourseEntity] {
        try await store.courses(matching: string)
    }

    func suggestedEntities() async throws -> [CourseEntity] {
        try await store.allCourses()
    }
}

// MARK: - Élément du planner

struct PlannerItemEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Élément d'Astrea")
    static let defaultQuery = PlannerItemEntityQuery()

    let id: UUID

    @Property(title: "Titre")
    var title: String

    @Property(title: "Date")
    var date: Date

    @Property(title: "Terminé")
    var isDone: Bool

    @Property(title: "Type")
    var kind: ItemKind

    @Property(title: "Cours")
    var courseName: String?

    @Property(title: "Important")
    var isImportant: Bool

    init(id: UUID, title: String, date: Date, isDone: Bool, kind: ItemKind, courseName: String?,
         isImportant: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.isDone = isDone
        self.kind = kind
        self.courseName = courseName
        self.isImportant = isImportant
    }

    init(_ item: PlannerItem) {
        self.init(id: item.uuid,
                  title: item.title,
                  date: item.date,
                  isDone: item.isDone,
                  kind: item.kind,
                  courseName: item.course?.name,
                  isImportant: item.isImportant)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: courseName.map { "\($0)" }
        )
    }
}

struct PlannerItemEntityQuery: EntityStringQuery {
    @Dependency private var store: PlannerIntentStore

    func entities(for identifiers: [UUID]) async throws -> [PlannerItemEntity] {
        try await store.items(ids: identifiers)
    }

    func entities(matching string: String) async throws -> [PlannerItemEntity] {
        try await store.items(matching: string)
    }

    /// Appelé à l'improviste pour remplir un sélecteur : on reste court.
    func suggestedEntities() async throws -> [PlannerItemEntity] {
        try await store.pendingTasks()
    }
}

// MARK: - Type d'élément

//  Les valeurs brutes ("task", "event", "holiday") sont enregistrées telles
//  quelles dans les raccourcis : ne jamais les renommer ni les réordonner.
extension ItemKind: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Type d'élément")

    static var caseDisplayRepresentations: [ItemKind: DisplayRepresentation] {
        [
            .task:    "Tâche",
            .event:   "Événement",
            .holiday: "Vacances",
        ]
    }
}
