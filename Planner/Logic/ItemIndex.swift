//
//  ItemIndex.swift
//  Range les éléments par jour pour un affichage rapide.
//
//  Problème : la grille a 42 cases. Si chaque case filtrait tous les
//  éléments (`items.filter { … }`), on parcourrait la liste 42 fois.
//  Solution : on parcourt la liste UNE fois et on remplit un dictionnaire
//  [jour → éléments]. Chaque case fait ensuite une simple recherche.
//
//  Les éléments sur plusieurs jours (vacances avec `endDate`) sont ajoutés
//  à chaque jour qu'ils couvrent.
//

import Foundation

struct ItemIndex {
    private var itemsByDay: [Date: [PlannerItem]] = [:]
    private let calendar: Calendar

    /// Sécurité : une période ne peut pas couvrir plus de 60 jours
    /// (évite une boucle énorme si une date de fin est erronée).
    private static let maxSpanInDays = 60

    init(items: [PlannerItem], calendar: Calendar = .planner) {
        self.calendar = calendar

        for item in items {
            let start = calendar.startOfDay(for: item.date)
            let end = calendar.startOfDay(for: item.endDate ?? item.date)

            var day = start
            var count = 0
            while day <= end && count < Self.maxSpanInDays {
                itemsByDay[day, default: []].append(item)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                count += 1
            }
        }

        // Ordre d'affichage dans une journée : vacances d'abord,
        // puis les éléments à heure fixe, puis « fin de journée ».
        for (day, dayItems) in itemsByDay {
            itemsByDay[day] = dayItems.sorted(by: Self.displayOrder)
        }
    }

    /// Les éléments d'un jour donné (n'importe quelle heure de ce jour).
    func items(on date: Date) -> [PlannerItem] {
        itemsByDay[calendar.startOfDay(for: date)] ?? []
    }

    nonisolated private static func displayOrder(_ a: PlannerItem, _ b: PlannerItem) -> Bool {
        if (a.kind == .holiday) != (b.kind == .holiday) { return a.kind == .holiday }
        if a.isAllDay != b.isAllDay { return !a.isAllDay }
        if a.date != b.date { return a.date < b.date }
        return a.createdAt < b.createdAt
    }
}
