//
//  PlannerItem+Move.swift
//  Déplacer un élément sur un autre jour (glisser-déposer dans le calendrier).
//

import Foundation

extension PlannerItem {
    /// Place l'élément sur `day` en gardant son heure.
    ///
    /// On décale d'un nombre de jours plutôt que de recopier la date cible :
    /// l'heure murale reste la même même si un changement d'heure (été/hiver)
    /// tombe entre les deux jours. Une date de fin éventuelle suit du même
    /// décalage, pour que la durée ne change pas.
    ///
    /// - Returns: `true` si l'élément a bougé (faux si c'est déjà le bon jour).
    @discardableResult
    func move(to day: Date, calendar: Calendar = .planner) -> Bool {
        let offset = calendar.dateComponents([.day],
                                             from: calendar.startOfDay(for: date),
                                             to: calendar.startOfDay(for: day)).day ?? 0
        guard offset != 0,
              let newDate = calendar.date(byAdding: .day, value: offset, to: date)
        else { return false }

        date = newDate
        if let endDate {
            self.endDate = calendar.date(byAdding: .day, value: offset, to: endDate)
        }
        return true
    }
}
