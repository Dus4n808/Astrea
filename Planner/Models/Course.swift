//
//  Course.swift
//  Un cours du semestre (ex. « méthodes qualitatives A »).
//

import Foundation
import SwiftData

@Model
nonisolated final class Course {
    /// Identifiant stable, identique sur tous les appareils (voir PlannerItem.uuid).
    var uuid: UUID = UUID()

    var name: String = ""

    /// Couleur stockée en texte (voir CourseColor). Utilise plutôt `color`.
    var colorRaw: String = CourseColor.blue.rawValue

    var createdAt: Date = Date.now

    /// Les éléments liés à ce cours.
    /// `.nullify` : si on supprime le cours, ses tâches restent mais sans cours.
    /// Optionnelle : CloudKit l'exige pour toute relation « à plusieurs ».
    @Relationship(deleteRule: .nullify, inverse: \PlannerItem.course)
    var items: [PlannerItem]? = []

    /// Les éléments du cours, jamais nil côté appelant.
    var allItems: [PlannerItem] { items ?? [] }

    init(name: String, color: CourseColor) {
        self.name = name
        self.colorRaw = color.rawValue
    }

    /// Accès typé à la couleur. Si la valeur en base est inconnue, on retombe sur bleu.
    var color: CourseColor {
        get { CourseColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }
}
