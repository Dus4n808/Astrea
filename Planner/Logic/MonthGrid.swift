//
//  MonthGrid.swift
//  Calcule les jours affichés dans la grille d'un mois.
//
//  C'est de la logique pure (aucune vue, aucune base de données) :
//  facile à tester avec des tests unitaires.
//
//  Exemple pour octobre 2026 (le 1er est un jeudi) :
//
//      LUN MAR MER JEU VEN SAM DIM
//      28  29  30  1   2   3   4     ← 28-30 = fin de septembre (isInMonth = false)
//      5   6   7   8   9   10  11
//      …
//      2   3   4   5   6   7   8     ← début de novembre (isInMonth = false)
//
//  On affiche toujours 6 semaines (42 cases) pour que la grille garde la même
//  hauteur d'un mois à l'autre : l'interface ne « saute » pas en naviguant.
//

import Foundation

/// Une case de la grille.
nonisolated struct GridDay: Identifiable, Hashable {
    /// Le jour à 00:00.
    let date: Date
    /// false pour les jours du mois précédent/suivant (affichés en grisé).
    let isInMonth: Bool

    var id: Date { date }
}

nonisolated struct MonthGrid {
    static let weekCount = 6
    static let daysPerWeek = 7

    /// N'importe quelle date du mois affiché.
    let month: Date
    let calendar: Calendar

    init(month: Date, calendar: Calendar = .planner) {
        self.month = calendar.startOfMonth(for: month)
        self.calendar = calendar
    }

    /// Les 42 cases, de haut en bas et de gauche à droite.
    var days: [GridDay] {
        // 1. Lundi de la semaine qui contient le 1er du mois.
        let firstVisibleDay = calendar.startOfWeek(for: month)
        let currentMonth = calendar.component(.month, from: month)

        // 2. On avance jour par jour 42 fois.
        return (0..<(Self.weekCount * Self.daysPerWeek)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstVisibleDay) else {
                return nil
            }
            let isInMonth = calendar.component(.month, from: date) == currentMonth
            return GridDay(date: date, isInMonth: isInMonth)
        }
    }

    /// Les cases regroupées par semaine (6 tableaux de 7 jours).
    var weeks: [[GridDay]] {
        let all = days
        return stride(from: 0, to: all.count, by: Self.daysPerWeek).map {
            Array(all[$0..<min($0 + Self.daysPerWeek, all.count)])
        }
    }
}
