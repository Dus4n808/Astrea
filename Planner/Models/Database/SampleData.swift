//
//  SampleData.swift
//  Données d'exemple (reprises de ton planner actuel, octobre 2026).
//  Utilisées pour les aperçus Xcode et en mode DEBUG sur une base vide.
//

import Foundation
import SwiftData

enum SampleData {
    /// N'ajoute les exemples que si la base ne contient encore aucun cours.
    static func insertIfEmpty(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Course>())) ?? 0
        guard existing == 0 else { return }
        insert(into: context)
    }

    private static func insert(into context: ModelContext) {
        // MARK: Cours
        let qualitatives = Course(name: "méthodes qualitatives A", color: .blue)
        let mixtes       = Course(name: "méthodes mixtes", color: .graphite)
        let psycho       = Course(name: "psychologie clinique transculturelle", color: .orange)
        let societes     = Course(name: "sociétés multiculturelles", color: .violet)
        let diversite    = Course(name: "diversité religieuse et culturelle", color: .red)
        let transition   = Course(name: "transition écologique", color: .green)
        let altro        = Course(name: "altro", color: .teal)
        [qualitatives, mixtes, psycho, societes, diversite, transition, altro]
            .forEach { context.insert($0) }

        // MARK: Éléments
        /// Raccourci : un jour d'octobre/novembre 2026.
        func day(_ d: Int, month: Int = 10) -> Date {
            Calendar.planner.date(from: DateComponents(year: 2026, month: month, day: d)) ?? .now
        }

        let items: [PlannerItem] = [
            PlannerItem(title: "lecture", date: day(18), course: mixtes),
            PlannerItem(title: "lectures", date: day(18), course: qualitatives),
            PlannerItem(title: "lectures", date: day(19), course: psycho),
            PlannerItem(title: "chiamare x buono xa", date: day(19), course: altro),
            PlannerItem(title: "texte bleona", date: day(19), course: mixtes),
            PlannerItem(title: "appunti", date: day(21), course: diversite),
            PlannerItem(title: "texte", date: day(23), course: societes),
            PlannerItem(title: "lire lecture (avant cours)", date: day(26), course: qualitatives),
            PlannerItem(title: "rendre cycle 1", date: day(26), course: transition,
                        details: "Déposer sur Moodle avant minuit."),
            PlannerItem(title: "rendre évaluation 1", date: day(29), course: societes),
            PlannerItem(title: "présentation orale", kind: .event, date: day(30), course: societes),
            PlannerItem(title: "semaine intercalaire", kind: .holiday,
                        date: day(2, month: 11), endDate: day(6, month: 11)),
        ]
        items.forEach { context.insert($0) }

        // « texte » est déjà fait (barré dans l'ancienne app).
        items.first { $0.title == "texte" }?.isDone = true

        try? context.save()
    }
}
