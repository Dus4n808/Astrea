//
//  Calendar+Planner.swift
//  Calendrier et langue utilisés partout dans l'app.
//
//  Centraliser ces réglages évite des bugs subtils : si une vue utilisait
//  `Calendar.current` (semaine qui commence le dimanche aux US) et une autre
//  un calendrier suisse (lundi), les grilles ne seraient pas alignées.
//

import Foundation

nonisolated extension Locale {
    /// Langue de l'interface (dates en français : « lun. 26 oct. »).
    static let planner = Locale(identifier: "fr_CH")
}

nonisolated extension Calendar {
    /// Calendrier grégorien, semaine du lundi au dimanche.
    static let planner: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .planner
        calendar.timeZone = .current
        calendar.firstWeekday = 2          // 1 = dimanche, 2 = lundi
        calendar.minimumDaysInFirstWeek = 4 // norme ISO 8601 pour les n° de semaine
        return calendar
    }()

    /// Premier jour du mois contenant `date`, à 00:00.
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    /// Premier jour (lundi) de la semaine contenant `date`, à 00:00.
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }

    /// Initiales des jours, dans l'ordre de la semaine : ["L", "M", "M", …].
    var weekdayInitials: [String] {
        rotatedFromFirstWeekday(veryShortStandaloneWeekdaySymbols)
    }

    /// Abréviations en majuscules : ["LUN", "MAR", …].
    var weekdayShortNames: [String] {
        rotatedFromFirstWeekday(shortStandaloneWeekdaySymbols)
            .map { $0.replacingOccurrences(of: ".", with: "").uppercased() }
    }

    /// Les symboles Apple commencent toujours par dimanche : on les décale
    /// pour commencer par `firstWeekday`.
    private func rotatedFromFirstWeekday(_ symbols: [String]) -> [String] {
        let shift = firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
