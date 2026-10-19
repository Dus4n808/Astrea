//
//  AppleIntelligence.swift
//  Le planner tel que Siri (Apple Intelligence) le comprend.
//
//  Pourquoi un fichier à part ? Les intents de PlannerIntents.swift marchent
//  avec des phrases fixes (« Ajoute une tâche dans Planner »). Ici on adopte
//  les *schémas* du domaine `.reminders` d'Apple : une forme imposée par le
//  système, que Siri sait remplir à partir d'une demande en langage naturel
//  (« rappelle-moi de lire le chapitre 3 pour vendredi en méthodes mixtes »).
//
//  Correspondance planner → schéma :
//    tâche  → rappel  (`.reminders.reminder`)
//    cours  → liste   (`.reminders.list`) ; « Sans cours » est une liste virtuelle
//    détails → note,  échéance → dueDate,  faite → isCompleted
//
//  Les intents d'ici sont `isAssistantOnly` : invisibles dans l'app
//  Raccourcis, où les anciennes intents restent la référence. C'est la
//  migration recommandée par Apple — modifier les anciennes aurait cassé
//  les raccourcis déjà enregistrés (leurs paramètres n'ont pas les noms
//  imposés par le schéma).
//
//  La forme de chaque type est vérifiée à la compilation par Xcode :
//  une propriété requise manquante ou mal typée = erreur de build. Le schéma
//  impose donc aussi des champs que le planner ne connaît pas (lieu, section,
//  récurrence, drapeau…). Règle suivie :
//  - sans conséquence (drapeau, tags, images) → accepté et ignoré ;
//  - liens → ajoutés aux détails ;
//  - ce qui changerait le sens de la tâche (récurrence, rappel par lieu) →
//    refusé avec un message clair, plutôt qu'une tâche silencieusement fausse.
//

import AppIntents
import CoreSpotlight
import Foundation
import GeoToolbox

// MARK: - Type de liste

@AppEnum(schema: .reminders.listType)
enum CourseListType: String {
    case standard

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "Cours",
    ]
}

// MARK: - Cours vu comme une liste

@AppEntity(schema: .reminders.list)
struct CourseListEntity {
    static let defaultQuery = CourseListEntityQuery()

    /// L'uuid du cours, ou `noCourseID` pour la liste « Sans cours ».
    let id: UUID

    var name: String
    var type: CourseListType

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
        self.type = .standard
    }

    init(_ course: Course) {
        self.init(id: course.uuid, name: course.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    // MARK: Liste « Sans cours »

    /// Le schéma veut qu'un rappel appartienne TOUJOURS à une liste, alors
    /// qu'une tâche peut n'avoir aucun cours. On expose donc une liste
    /// virtuelle, qui n'existe pas en base. Cet identifiant est un contrat :
    /// Siri peut l'avoir mémorisé, il ne doit jamais changer.
    static let noCourseID = UUID(uuidString: "5E1C0A55-0000-4000-8000-000000000000")!

    static var noCourse: CourseListEntity {
        CourseListEntity(id: noCourseID, name: "Sans cours")
    }
}

struct CourseListEntityQuery: EntityStringQuery {
    @Dependency private var store: PlannerIntentStore

    func entities(for identifiers: [UUID]) async throws -> [CourseListEntity] {
        try await store.courseLists(ids: identifiers)
    }

    func entities(matching string: String) async throws -> [CourseListEntity] {
        try await store.courseLists(matching: string)
    }

    func suggestedEntities() async throws -> [CourseListEntity] {
        try await store.allCourseLists()
    }
}

// MARK: - Tâche vue comme un rappel

@AppEntity(schema: .reminders.reminder)
struct TaskReminderEntity: IndexedEntity {
    static let defaultQuery = TaskReminderEntityQuery()

    /// Le même `PlannerItem.uuid` que PlannerItemEntity : stable, jamais réattribué.
    let id: UUID

    var title: String
    var note: AttributedString?
    var dueDate: DateComponents?
    var isCompleted: Bool
    var creationDate: Date?
    var list: CourseListEntity

    // Exigés par le schéma, sans équivalent dans le planner : toujours vides.
    var tags: Set<String>
    var urls: [URL]
    var recurrence: Calendar.RecurrenceRule?
    var isFlagged: Bool?
    var completionDate: Date?
    var locationTrigger: LocationTriggerEntity?

    init(_ item: PlannerItem) {
        self.id = item.uuid
        self.title = item.title
        self.note = item.details.isEmpty ? nil : AttributedString(item.details)
        self.dueDate = TaskDueDate.components(of: item.date, isAllDay: item.isAllDay)
        self.isCompleted = item.isDone
        self.creationDate = item.createdAt
        self.list = item.course.map(CourseListEntity.init) ?? .noCourse
        self.tags = []
        self.urls = []
        self.recurrence = nil
        self.isFlagged = nil
        self.completionDate = nil
        self.locationTrigger = nil
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(list.name)")
    }
}

struct TaskReminderEntityQuery: EntityStringQuery, IndexedEntityQuery {
    @Dependency private var store: PlannerIntentStore

    func entities(for identifiers: [UUID]) async throws -> [TaskReminderEntity] {
        try await store.taskReminders(ids: identifiers)
    }

    func entities(matching string: String) async throws -> [TaskReminderEntity] {
        try await store.taskReminders(matching: string)
    }

    func suggestedEntities() async throws -> [TaskReminderEntity] {
        try await store.pendingTaskReminders()
    }

    // Le système peut demander de reconstruire l'index Spotlight (index perdu,
    // mise à jour du système…). On redonne simplement les tâches demandées.

    func reindexEntities(for identifiers: [UUID], indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(entities(for: identifiers))
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(store.allTaskReminders())
    }
}

// MARK: - Créer une tâche

@AppIntent(schema: .reminders.createReminder)
struct CreateTaskReminderIntent {
    static let isAssistantOnly = true

    var title: String
    var list: CourseListEntity?
    var note: AttributedString?
    var dueDate: DateComponents?
    var urls: [URL]

    // Exigés par le schéma, sans équivalent dans le planner.
    var isFlagged: Bool?
    var images: [IntentFile]
    var tags: Set<String>
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerEntity?
    var section: CourseSectionEntity?

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some ReturnsValue<TaskReminderEntity> {
        // Toute la validation avant l'écriture : perform() peut être relancé.
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw PlannerIntentError.emptyTitle }
        guard recurrence == nil else { throw PlannerIntentError.recurrenceUnsupported }
        guard locationTrigger == nil else { throw PlannerIntentError.locationUnsupported }

        // Sans échéance : aujourd'hui, en fin de journée (comme dans l'app).
        let due = TaskDueDate(components: dueDate)
        let created = try await store.addTask(title: cleanTitle,
                                              details: TaskNote.details(note: note, urls: urls) ?? "",
                                              date: due.date,
                                              isAllDay: due.isAllDay,
                                              listID: list?.id)
        await PlannerSpotlight.index([created])
        return .result(value: created)
    }
}

// MARK: - Modifier / cocher une tâche

@AppIntent(schema: .reminders.updateReminder)
struct UpdateTaskReminderIntent {
    static let isAssistantOnly = true

    var target: TaskReminderEntity
    var title: String?
    var note: AttributedString?
    var dueDate: DateComponents?
    var isCompleted: Bool?
    var list: CourseListEntity?
    var urls: [URL]?

    // Exigés par le schéma, sans équivalent dans le planner.
    var tags: Set<String>?
    var isFlagged: Bool?
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerEntity?

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some ReturnsValue<TaskReminderEntity> {
        guard recurrence == nil else { throw PlannerIntentError.recurrenceUnsupported }
        guard locationTrigger == nil else { throw PlannerIntentError.locationUnsupported }

        var changes = PlannerIntentStore.TaskChanges()
        if let title {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw PlannerIntentError.emptyTitle }
            changes.title = cleanTitle
        }
        changes.details = TaskNote.details(note: note, urls: urls ?? [])
        if let dueDate {
            let due = TaskDueDate(components: dueDate)
            changes.date = due.date
            changes.isAllDay = due.isAllDay
        }
        changes.isDone = isCompleted
        changes.listID = list?.id

        guard let updated = try await store.updateTask(id: target.id, changes) else {
            throw PlannerIntentError.itemNotFound
        }
        await PlannerSpotlight.index([updated])
        return .result(value: updated)
    }
}

// MARK: - Supprimer des tâches

@AppIntent(schema: .reminders.deleteReminders)
struct DeleteTaskRemindersIntent: DeleteIntent {
    static let isAssistantOnly = true

    var entities: [TaskReminderEntity]

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some IntentResult {
        // Irréversible : on demande d'abord. Si la personne refuse, l'appel
        // lève une erreur qui interrompt perform() avant toute suppression.
        let dialog: IntentDialog = entities.count == 1
            ? "Supprimer « \(entities[0].title) » d'Astrea ?"
            : "Supprimer ces \(entities.count) tâches d'Astrea ?"
        try await requestConfirmation(dialog: dialog)

        let ids = entities.map(\.id)
        try await store.deleteItems(ids: ids)
        await PlannerSpotlight.remove(ids)
        return .result()
    }
}

// MARK: - Types imposés par le schéma, non gérés par le planner
//
//  Le schéma d'un rappel référence un rappel par lieu et une section de
//  liste. Le planner n'a ni l'un ni l'autre : ces types existent pour que la
//  forme soit complète, et leurs requêtes ne renvoient jamais rien — Siri
//  ne peut donc pas en proposer.

@AppEnum(schema: .reminders.locationTriggerEvent)
enum LocationTriggerEvent: String {
    case arrive
    case depart

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .arrive: "En arrivant",
        .depart: "En partant",
    ]
}

@AppEntity(schema: .reminders.locationTrigger)
struct LocationTriggerEntity {
    static let defaultQuery = LocationTriggerEntityQuery()

    let id: UUID
    var place: GeoToolbox.PlaceDescriptor
    var event: LocationTriggerEvent

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Rappel par lieu")
    }
}

struct LocationTriggerEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [LocationTriggerEntity] { [] }
    func entities(matching string: String) async throws -> [LocationTriggerEntity] { [] }
}

@AppEntity(schema: .reminders.section)
struct CourseSectionEntity {
    static let defaultQuery = CourseSectionEntityQuery()

    let id: UUID
    var name: String
    var list: CourseListEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CourseSectionEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [CourseSectionEntity] { [] }
    func entities(matching string: String) async throws -> [CourseSectionEntity] { [] }
}

// MARK: - Note

/// Le planner n'a qu'un champ « Détails » : la note et les liens donnés à
/// Siri y sont réunis, un lien par ligne.
nonisolated enum TaskNote {
    /// nil quand il n'y a rien du tout (en mise à jour : « ne pas toucher »).
    static func details(note: AttributedString?, urls: [URL]) -> String? {
        let text = note.map { String($0.characters) }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lines = (text.isEmpty ? [] : [text]) + urls.map(\.absoluteString)
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// MARK: - Échéance

/// Traduit l'échéance du schéma (des `DateComponents`, éventuellement sans
/// heure) vers le modèle du planner (une date + « fin de journée »), et inversement.
nonisolated struct TaskDueDate {
    let date: Date
    let isAllDay: Bool

    /// Pas d'heure dans la demande (« pour vendredi ») = fin de journée.
    init(components: DateComponents?, calendar: Calendar = .planner) {
        guard let components, let resolved = calendar.date(from: components) else {
            date = calendar.startOfDay(for: .now)
            isAllDay = true
            return
        }
        isAllDay = components.hour == nil
        date = isAllDay ? calendar.startOfDay(for: resolved) : resolved
    }

    static func components(of date: Date, isAllDay: Bool, calendar: Calendar = .planner) -> DateComponents {
        calendar.dateComponents(isAllDay ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute],
                                from: date)
    }
}
