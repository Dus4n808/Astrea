//
//  ReminderPlanner.swift
//  Calcule quelles notifications programmer, et avec quels messages.
//
//  Logique pure, sans le système de notifications : à partir des éléments et
//  des réglages, on obtient la liste exacte des rappels à venir. Le
//  ReminderScheduler n'a plus qu'à faire correspondre ce que le système a en
//  attente avec cette liste. Testable sans autorisation ni appareil.
//
//  Pourquoi tout recalculer plutôt que programmer au fil de l'eau : une
//  tâche peut être modifiée, cochée ou supprimée sur un autre appareil, et
//  le changement arrive par iCloud sans passer par l'éditeur. Repartir des
//  données garantit qu'aucun rappel fantôme ne survit.
//

import Foundation

/// Ce dont le calcul a besoin d'un élément, figé (Sendable, hors SwiftData).
nonisolated struct ReminderSource: Equatable, Sendable {
    let id: UUID
    let title: String
    let kind: ItemKind
    let date: Date
    let isAllDay: Bool
    let isDone: Bool
    let isImportant: Bool
    let reminder: ReminderOption
    let courseName: String?
}

extension ReminderSource {
    init(_ item: PlannerItem) {
        self.init(id: item.uuid, title: item.title, kind: item.kind, date: item.date,
                  isAllDay: item.isAllDay, isDone: item.isDone, isImportant: item.isImportant,
                  reminder: item.reminder, courseName: item.course?.name)
    }
}

/// Une notification à programmer.
nonisolated struct PlannedReminder: Equatable, Sendable {
    /// Identifiant de la demande auprès du système : un seul rappel par
    /// élément, donc le reprogrammer remplace l'ancien au lieu de le doubler.
    let identifier: String
    let itemID: UUID
    let fireDate: Date
    let title: String
    let subtitle: String
    let body: String
}

nonisolated enum ReminderPlanner {
    /// Préfixe de nos demandes : le planificateur ne touche qu'à celles-ci.
    static let identifierPrefix = "reminder."

    /// iOS ne garde que 64 notifications en attente par app : au-delà, les
    /// plus lointaines sont ignorées sans bruit. On s'arrête avant, et les
    /// suivantes seront programmées aux prochains passages (lancement, retour
    /// dans l'app, chaque modification).
    static let maxPending = 60

    static func identifier(for itemID: UUID) -> String {
        identifierPrefix + itemID.uuidString
    }

    /// Les rappels à programmer, du plus proche au plus lointain.
    static func plan(
        for sources: [ReminderSource],
        settings: NotificationSettings,
        userName: String = "",
        now: Date = .now,
        calendar: Calendar = .planner
    ) -> [PlannedReminder] {
        guard settings.isEnabled else { return [] }

        let planned = sources.compactMap { source -> PlannedReminder? in
            guard source.reminder != .none,
                  source.kind != .holiday,
                  !source.isDone,
                  !settings.importantOnly || source.isImportant,
                  let fireDate = fireDate(for: source, settings: settings, calendar: calendar),
                  fireDate > now
            else { return nil }

            return PlannedReminder(
                identifier: identifier(for: source.id),
                itemID: source.id,
                fireDate: fireDate,
                title: source.isImportant ? "⭐ \(source.title)" : source.title,
                subtitle: source.courseName ?? "",
                body: ReminderMessages.body(for: source, userName: userName, calendar: calendar)
            )
        }
        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    /// Moment du rappel, ou nil si le choix n'a pas de sens pour l'élément.
    static func fireDate(
        for source: ReminderSource,
        settings: NotificationSettings,
        calendar: Calendar = .planner
    ) -> Date? {
        // Un choix devenu impossible (heure retirée sur un autre appareil
        // avec une ancienne version) est adapté plutôt qu'ignoré.
        let reminder = source.reminder.adapted(isAllDay: source.isAllDay)

        if source.isAllDay {
            let day = calendar.startOfDay(for: source.date)
            let target: Date?
            switch reminder {
            case .sameDay:   target = day
            case .dayBefore: target = calendar.date(byAdding: .day, value: -1, to: day)
            default:         target = nil
            }
            return target.flatMap {
                calendar.date(bySettingHour: settings.dayTimeHour, minute: settings.dayTimeMinute,
                              second: 0, of: $0)
            }
        }

        if let minutes = reminder.minutesBefore {
            return calendar.date(byAdding: .minute, value: -minutes, to: source.date)
        }
        if reminder == .dayBefore {
            return calendar.date(byAdding: .day, value: -1, to: source.date)
        }
        return nil
    }
}

// MARK: - Messages

/// Des messages courts et sympas, en tutoiement comme le reste de l'app.
/// Plusieurs variantes, choisies d'après l'identifiant de l'élément : chaque
/// tâche garde toujours la même (reprogrammer ne la change pas), mais deux
/// tâches n'ont pas forcément la même.
nonisolated enum ReminderMessages {

    static func body(for source: ReminderSource, userName: String, calendar: Calendar = .planner) -> String {
        let reminder = source.reminder.adapted(isAllDay: source.isAllDay)
        let name = userName.trimmingCharacters(in: .whitespaces)
        let variants: [String]

        if let minutes = reminder.minutesBefore {
            variants = [
                "C'est dans \(minutes) min. Tu gères !",
                "Plus que \(minutes) min, on y va ⏰",
                name.isEmpty ? "Dans \(minutes) min, c'est à toi ✨" : "\(name), c'est dans \(minutes) min. Go !",
            ]
        } else if reminder == .dayBefore && !source.isAllDay {
            let time = timeText(source.date, calendar: calendar)
            variants = [
                "C'est demain à \(time). Un peu d'avance, ça fait du bien.",
                "Demain \(time) : on prépare le terrain ce soir ?",
            ]
        } else if reminder == .dayBefore {
            variants = [
                "C'est pour demain ! Un petit coup d'avance ?",
                "Demain, c'est le grand jour 📅",
            ]
        } else {
            variants = [
                "C'est pour aujourd'hui. Tu vas tout déchirer 💪",
                "Au programme aujourd'hui. Une chose à la fois !",
                name.isEmpty ? "Aujourd'hui, c'est le moment 🌟" : "Allez \(name), c'est pour aujourd'hui 🌟",
            ]
        }

        let message = variants[variantIndex(for: source.id, count: variants.count)]
        return source.isImportant ? message + " Celle-là compte !" : message
    }

    /// Stable d'un lancement à l'autre (contrairement à `hashValue`).
    static func variantIndex(for id: UUID, count: Int) -> Int {
        Int(id.uuid.0) % max(count, 1)
    }

    /// « 14:30 », sans passer par les formateurs liés au main actor.
    private static func timeText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
