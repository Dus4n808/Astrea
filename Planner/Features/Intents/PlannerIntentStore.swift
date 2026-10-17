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
        courseID: UUID?
    ) throws -> PlannerItemEntity {
        let course = try courseID.flatMap { id in
            try modelContext.fetch(
                FetchDescriptor<Course>(predicate: #Predicate { $0.uuid == id })
            ).first
        }
        let item = PlannerItem(title: title, kind: kind, date: date, course: course)
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
}
