//
//  Date+Formatting.swift
//  Formats de date réutilisés dans l'interface.
//  Un seul endroit à modifier si on veut changer l'affichage d'une date.
//

import Foundation

// Pur calcul de texte : utilisable aussi depuis un App Intent, qui ne
// tourne pas sur le main actor.
nonisolated extension Date {
    /// « octobre »
    var monthName: String {
        formatted(.dateTime.month(.wide).locale(.planner))
    }

    /// « 2026 »
    var yearText: String {
        formatted(.dateTime.year().locale(.planner))
    }

    /// « lun. 26 oct. »
    var shortDayText: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(.planner))
    }

    /// « 14:30 »
    var timeText: String {
        formatted(.dateTime.hour().minute().locale(.planner))
    }

    /// Numéro du jour dans le mois : 1…31
    var dayNumber: Int {
        Calendar.planner.component(.day, from: self)
    }

    /// Numéro du mois : 1…12
    var monthNumber: Int {
        Calendar.planner.component(.month, from: self)
    }

    /// Numéro de semaine ISO (1…53)
    var weekNumber: Int {
        Calendar.planner.component(.weekOfYear, from: self)
    }

    /// « Aujourd'hui », « Demain », « Hier », sinon « lun. 26 oct. »
    var relativeDayTitle: String {
        let calendar = Calendar.planner
        if calendar.isDateInToday(self) { return "Aujourd'hui" }
        if calendar.isDateInTomorrow(self) { return "Demain" }
        if calendar.isDateInYesterday(self) { return "Hier" }
        return shortDayText
    }
}
