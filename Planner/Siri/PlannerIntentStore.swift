//
//  PlannerIntentStore.swift
//  Accès à la base pour Siri et les Raccourcis.
//
//  Pourquoi un acteur séparé et pas le ModelContext des vues ?
//  Un intent peut s'exécuter alors que l'app n'a aucune interface affichée
//  (Siri réveille le processus à froid), et `perform()` ne tourne PAS sur le
//  main actor. `@ModelActor` donne à cette couche son propre ModelContext,
//  isolé, utilisable depuis n'importe quel thread.
//
//  Les méthodes renvoient directement des AppEntity (des structs Sendable) :
//  les objets SwiftData, eux, ne doivent jamais franchir la frontière
//  d'isolation de l'acteur.
//

import Foundation
import SwiftData

@ModelActor
actor PlannerIntentStore {

    // MARK: - Cours

    func courses(ids: [UUID]) throws -> [CourseEntity] {
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { ids.contains($0.uuid) },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map(CourseEntity.init)
    }

    func allCourses() throws -> [CourseEntity] {
        let descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map(CourseEntity.init)
    }

    func courses(matching text: String) throws -> [CourseEntity] {
        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.name.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map(CourseEntity.init)
    }

    // MARK: - Éléments

    func items(ids: [UUID]) throws -> [PlannerItemEntity] {
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { ids.contains($0.uuid) },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(PlannerItemEntity.init)
    }

    func items(matching text: String) throws -> [PlannerItemEntity] {
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(PlannerItemEntity.init)
    }

    /// Ce que le sélecteur de Raccourcis propose par défaut : les tâches
    /// encore à faire, les plus proches d'abord. Volontairement borné.
    func pendingTasks(limit: Int = 20) throws -> [PlannerItemEntity] {
        let taskKind = ItemKind.task.rawValue
        var descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { $0.kindRaw == taskKind && !$0.isDone },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(PlannerItemEntity.init)
    }

    /// Les éléments d'une fenêtre de dates, bornes incluses côté début.
    func items(from start: Date, before end: Date, pendingOnly: Bool) throws -> [PlannerItemEntity] {
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { item in
                item.date >= start && item.date < end && (!pendingOnly || !item.isDone)
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(PlannerItemEntity.init)
    }

    // MARK: - Écriture

    func addItem(
        title: String,
        kind: ItemKind,
        date: Date,
        courseID: UUID?,
        isImportant: Bool = false
    ) throws -> PlannerItemEntity {
        let course = try courseID.flatMap { id in
            try modelContext.fetch(
                FetchDescriptor<Course>(predicate: #Predicate { $0.uuid == id })
            ).first
        }
        let item = PlannerItem(title: title, kind: kind, date: date, course: course)
        // Même règle que l'éditeur : seules les tâches peuvent être importantes.
        item.isImportant = kind == .task && isImportant
        modelContext.insert(item)
        try modelContext.save()
        return PlannerItemEntity(item)
    }

    /// Coche ou décoche un élément. Renvoie nil si l'élément n'existe plus
    /// (raccourci enregistré il y a longtemps sur une tâche supprimée depuis).
    func setDone(_ isDone: Bool, itemID: UUID) throws -> PlannerItemEntity? {
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.uuid == itemID })
        guard let item = try modelContext.fetch(descriptor).first else { return nil }
        item.isDone = isDone
        try modelContext.save()
        return PlannerItemEntity(item)
    }

    // MARK: - Apple Intelligence (schémas .reminders)
    //
    //  Les mêmes données vues comme des « rappels » : seules les tâches en
    //  sont (un événement ne se coche pas), et un cours devient une « liste ».

    func taskReminders(ids: [UUID]) throws -> [TaskReminderEntity] {
        let taskKind = ItemKind.task.rawValue
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { ids.contains($0.uuid) && $0.kindRaw == taskKind },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(TaskReminderEntity.init)
    }

    func taskReminders(matching text: String) throws -> [TaskReminderEntity] {
        let taskKind = ItemKind.task.rawValue
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { $0.kindRaw == taskKind && $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(TaskReminderEntity.init)
    }

    /// Toutes les tâches, pour (ré)alimenter l'index Spotlight.
    func allTaskReminders() throws -> [TaskReminderEntity] {
        let taskKind = ItemKind.task.rawValue
        let descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { $0.kindRaw == taskKind },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map(TaskReminderEntity.init)
    }

    func pendingTaskReminders(limit: Int = 20) throws -> [TaskReminderEntity] {
        let taskKind = ItemKind.task.rawValue
        var descriptor = FetchDescriptor<PlannerItem>(
            predicate: #Predicate { $0.kindRaw == taskKind && !$0.isDone },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(TaskReminderEntity.init)
    }

    /// Les cours vus comme des listes, plus la liste « Sans cours » quand
    /// elle est demandée (elle n'existe pas en base).
    func courseLists(ids: [UUID]) throws -> [CourseListEntity] {
        let lists = try modelContext.fetch(FetchDescriptor<Course>(
            predicate: #Predicate { ids.contains($0.uuid) },
            sortBy: [SortDescriptor(\.name)]
        )).map(CourseListEntity.init)
        return ids.contains(CourseListEntity.noCourseID) ? lists + [.noCourse] : lists
    }

    func courseLists(matching text: String) throws -> [CourseListEntity] {
        try modelContext.fetch(FetchDescriptor<Course>(
            predicate: #Predicate { $0.name.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.name)]
        )).map(CourseListEntity.init)
    }

    func allCourseLists() throws -> [CourseListEntity] {
        let lists = try modelContext.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\.name)]))
            .map(CourseListEntity.init)
        return lists + [.noCourse]
    }

    /// Crée une tâche. `listID` nil ou « Sans cours » = aucun cours.
    func addTask(
        title: String,
        details: String,
        date: Date,
        isAllDay: Bool,
        listID: UUID?,
        isImportant: Bool = false
    ) throws -> TaskReminderEntity {
        let item = PlannerItem(title: title, kind: .task, date: date, isAllDay: isAllDay,
                               course: try course(forListID: listID), details: details)
        item.isImportant = isImportant
        modelContext.insert(item)
        try modelContext.save()
        return TaskReminderEntity(item)
    }

    /// Ce qu'une mise à jour veut changer. nil = ne pas toucher.
    struct TaskChanges: Sendable {
        var title: String?
        var details: String?
        var date: Date?
        var isAllDay: Bool?
        var isDone: Bool?
        var listID: UUID?
        /// « Important » côté app, « signalé » (drapeau) côté Siri.
        var isImportant: Bool?
    }

    /// Applique les changements demandés. Renvoie nil si la tâche n'existe plus.
    func updateTask(id: UUID, _ changes: TaskChanges) throws -> TaskReminderEntity? {
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.uuid == id })
        guard let item = try modelContext.fetch(descriptor).first else { return nil }

        if let title = changes.title { item.title = title }
        if let details = changes.details { item.details = details }
        if let date = changes.date { item.date = date }
        if let isAllDay = changes.isAllDay { item.isAllDay = isAllDay }
        if let isDone = changes.isDone { item.isDone = isDone }
        if let listID = changes.listID { item.course = try course(forListID: listID) }
        if let isImportant = changes.isImportant { item.isImportant = isImportant }

        try modelContext.save()
        return TaskReminderEntity(item)
    }

    /// Supprime des éléments ; renvoie combien l'ont réellement été.
    @discardableResult
    func deleteItems(ids: [UUID]) throws -> Int {
        let items = try modelContext.fetch(FetchDescriptor<PlannerItem>(
            predicate: #Predicate { ids.contains($0.uuid) }
        ))
        for item in items { modelContext.delete(item) }
        try modelContext.save()
        return items.count
    }

    /// nil et « Sans cours » donnent tous deux « pas de cours ». Un cours
    /// introuvable aussi : mieux vaut créer la tâche que d'échouer.
    private func course(forListID listID: UUID?) throws -> Course? {
        guard let listID, listID != CourseListEntity.noCourseID else { return nil }
        return try modelContext.fetch(
            FetchDescriptor<Course>(predicate: #Predicate { $0.uuid == listID })
        ).first
    }
}
