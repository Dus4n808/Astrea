//
//  ReminderOption.swift
//  Quand prévenir la personne avant un élément.
//
//  Les choix dépendent de l'heure :
//  - élément à heure précise → 5, 10 ou 15 min avant, ou la veille à la même heure ;
//  - élément sans heure      → le jour même ou la veille, à l'heure choisie
//                              dans les Réglages (NotificationSettings.dayTime).
//
//  Les valeurs brutes sont enregistrées dans la base et synchronisées par
//  iCloud : ne jamais les renommer (un autre appareil, ou une ancienne
//  version de l'app, ne les reconnaîtrait plus). On ajoute, on ne renomme pas.
//

import Foundation

nonisolated enum ReminderOption: String, CaseIterable, Identifiable, Sendable {
    /// Pas de rappel. Chaîne vide : c'est aussi la valeur par défaut en base.
    case none = ""
    case fiveMinutes = "5m"
    case tenMinutes = "10m"
    case fifteenMinutes = "15m"
    /// Sans heure uniquement : le jour même, à l'heure des Réglages.
    case sameDay = "day0"
    /// La veille : à la même heure (élément à heure précise) ou à l'heure
    /// des Réglages (élément sans heure).
    case dayBefore = "day1"

    var id: String { rawValue }

    /// Les choix proposés dans l'éditeur, dans l'ordre d'affichage.
    static func choices(isAllDay: Bool) -> [ReminderOption] {
        isAllDay
            ? [.none, .sameDay, .dayBefore]
            : [.none, .fiveMinutes, .tenMinutes, .fifteenMinutes, .dayBefore]
    }

    /// Ce choix a-t-il un sens pour un élément avec / sans heure ?
    func isAvailable(isAllDay: Bool) -> Bool {
        Self.choices(isAllDay: isAllDay).contains(self)
    }

    /// Le choix le plus proche quand on ajoute ou retire l'heure, pour ne
    /// jamais garder un rappel impossible (« 10 min avant » une journée).
    func adapted(isAllDay: Bool) -> ReminderOption {
        guard !isAvailable(isAllDay: isAllDay) else { return self }
        // Heure retirée : « x min avant » devient « le jour même ».
        // Heure ajoutée : « le jour même » devient « 15 min avant ».
        return isAllDay ? .sameDay : .fifteenMinutes
    }

    /// Libellé court des pastilles de l'éditeur.
    var title: String {
        switch self {
        case .none:           "Aucun"
        case .fiveMinutes:    "5 min avant"
        case .tenMinutes:     "10 min avant"
        case .fifteenMinutes: "15 min avant"
        case .sameDay:        "Le jour même"
        case .dayBefore:      "La veille"
        }
    }

    /// Avance sur l'heure de l'élément, pour les rappels « x min avant ».
    var minutesBefore: Int? {
        switch self {
        case .fiveMinutes:    5
        case .tenMinutes:     10
        case .fifteenMinutes: 15
        default:              nil
        }
    }
}

extension PlannerItem {
    /// Rappel choisi pour cet élément. Une valeur inconnue (écrite par une
    /// version plus récente de l'app, sur un autre appareil) vaut « aucun ».
    var reminder: ReminderOption {
        get { ReminderOption(rawValue: reminderRaw) ?? .none }
        set { reminderRaw = newValue.rawValue }
    }
}
