//
//  ReminderPlannerTests.swift
//  Le calcul des rappels : quand ils partent, lesquels, avec quels messages.
//
//  Tout est testé sur ReminderPlanner (logique pure) : pas besoin
//  d'autorisation de notifications ni d'appareil.
//

import Foundation
import Testing

@testable import Planner

private let calendar = Calendar.planner

private func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// « Maintenant » fixe pour tous les tests : lundi 19 octobre 2026, 7:00.
private let now = time(2026, 10, 19, 7)

private func source(
    _ title: String = "lecture",
    kind: ItemKind = .task,
    date: Date,
    isAllDay: Bool = false,
    isDone: Bool = false,
    isImportant: Bool = false,
    reminder: ReminderOption,
    id: UUID = UUID()
) -> ReminderSource {
    ReminderSource(id: id, title: title, kind: kind, date: date, isAllDay: isAllDay,
                   isDone: isDone, isImportant: isImportant, reminder: reminder, courseName: nil)
}

private func plan(_ sources: [ReminderSource], settings: NotificationSettings = .init()) -> [PlannedReminder] {
    ReminderPlanner.plan(for: sources, settings: settings, now: now, calendar: calendar)
}

@Suite("Choix de rappel")
struct ReminderOptionTests {

    @Test("Avec une heure : 5, 10, 15 min ou la veille")
    func timedChoices() {
        #expect(ReminderOption.choices(isAllDay: false)
                == [.none, .fiveMinutes, .tenMinutes, .fifteenMinutes, .dayBefore])
    }

    @Test("Sans heure : le jour même ou la veille")
    func allDayChoices() {
        #expect(ReminderOption.choices(isAllDay: true) == [.none, .sameDay, .dayBefore])
    }

    @Test("Retirer l'heure transforme « x min avant » en « le jour même »")
    func adaptsWhenTimeRemoved() {
        #expect(ReminderOption.tenMinutes.adapted(isAllDay: true) == .sameDay)
        #expect(ReminderOption.dayBefore.adapted(isAllDay: true) == .dayBefore)
    }

    @Test("Ajouter une heure transforme « le jour même » en « 15 min avant »")
    func adaptsWhenTimeAdded() {
        #expect(ReminderOption.sameDay.adapted(isAllDay: false) == .fifteenMinutes)
        #expect(ReminderOption.fiveMinutes.adapted(isAllDay: false) == .fiveMinutes)
    }

    // Valeurs enregistrées en base et synchronisées : les renommer ferait
    // perdre leur rappel aux tâches existantes.
    @Test("Les valeurs brutes enregistrées n'ont pas changé")
    func rawValuesAreStable() {
        #expect(ReminderOption.none.rawValue == "")
        #expect(ReminderOption.fiveMinutes.rawValue == "5m")
        #expect(ReminderOption.tenMinutes.rawValue == "10m")
        #expect(ReminderOption.fifteenMinutes.rawValue == "15m")
        #expect(ReminderOption.sameDay.rawValue == "day0")
        #expect(ReminderOption.dayBefore.rawValue == "day1")
    }

    @Test("Une valeur inconnue (version plus récente sur un autre appareil) vaut « aucun »")
    func unknownRawIsNone() {
        let item = PlannerItem(title: "x", date: .now)
        item.reminderRaw = "2h-futur"
        #expect(item.reminder == .none)
    }
}

@Suite("Moment des rappels")
struct ReminderFireDateTests {

    @Test("10 min avant une tâche à 14:30 → 14:20")
    func minutesBefore() throws {
        let reminder = try #require(plan([source(date: time(2026, 10, 19, 14, 30), reminder: .tenMinutes)]).first)
        #expect(reminder.fireDate == time(2026, 10, 19, 14, 20))
    }

    @Test("La veille d'une tâche à heure précise : même heure, un jour plus tôt")
    func dayBeforeTimed() throws {
        let reminder = try #require(plan([source(date: time(2026, 10, 21, 9), reminder: .dayBefore)]).first)
        #expect(reminder.fireDate == time(2026, 10, 20, 9))
    }

    @Test("Sans heure, le jour même : à l'heure des Réglages")
    func sameDayUsesSettingsTime() throws {
        let settings = NotificationSettings(dayTime: 7 * 60 + 30)
        let reminder = try #require(plan([source(date: time(2026, 10, 20), isAllDay: true, reminder: .sameDay)],
                                         settings: settings).first)
        #expect(reminder.fireDate == time(2026, 10, 20, 7, 30))
    }

    @Test("Sans heure, la veille : la veille à l'heure des Réglages")
    func dayBeforeAllDay() throws {
        let reminder = try #require(plan([source(date: time(2026, 10, 22), isAllDay: true, reminder: .dayBefore)]).first)
        #expect(reminder.fireDate == time(2026, 10, 21, 8))
    }

    @Test("Un rappel déjà passé n'est pas programmé")
    func pastIsSkipped() {
        // 15 min avant 7:10, c'était 6:55 : trop tard.
        #expect(plan([source(date: time(2026, 10, 19, 7, 10), reminder: .fifteenMinutes)]).isEmpty)
    }
}

@Suite("Quels rappels partent")
struct ReminderSelectionTests {

    private let tomorrow = time(2026, 10, 20, 10)

    @Test("Rien pour une tâche cochée, sans rappel, ou des vacances")
    func skipsWhatShouldStaySilent() {
        #expect(plan([
            source(date: tomorrow, isDone: true, reminder: .tenMinutes),
            source(date: tomorrow, reminder: .none),
            source(kind: .holiday, date: tomorrow, isAllDay: true, reminder: .sameDay),
        ]).isEmpty)
    }

    @Test("Les événements ont aussi leurs rappels")
    func eventsAreReminded() {
        #expect(plan([source(kind: .event, date: tomorrow, reminder: .fiveMinutes)]).count == 1)
    }

    @Test("Notifications coupées : plus aucun rappel")
    func disabledMeansNothing() {
        #expect(plan([source(date: tomorrow, reminder: .tenMinutes)],
                     settings: NotificationSettings(isEnabled: false)).isEmpty)
    }

    @Test("« Seulement les importantes » laisse les autres silencieuses")
    func importantOnly() {
        let important = source("partiel", date: tomorrow, isImportant: true, reminder: .tenMinutes)
        let normal = source("lecture", date: tomorrow, reminder: .tenMinutes)
        let planned = plan([important, normal], settings: NotificationSettings(importantOnly: true))
        #expect(planned.map(\.itemID) == [important.id])
    }

    @Test("Du plus proche au plus lointain, sans dépasser la limite du système")
    func sortedAndCapped() {
        let sources = (1...80).map { day in
            source(date: calendar.date(byAdding: .day, value: 81 - day, to: tomorrow)!, reminder: .tenMinutes)
        }
        let planned = plan(sources)
        #expect(planned.count == ReminderPlanner.maxPending)
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
    }

    @Test("Un seul rappel par élément, au même identifiant à chaque calcul")
    func identifierIsStable() {
        let id = UUID()
        let first = plan([source(date: tomorrow, reminder: .tenMinutes, id: id)])
        let second = plan([source(date: tomorrow, reminder: .fifteenMinutes, id: id)])
        #expect(first.first?.identifier == second.first?.identifier)
        #expect(first.first?.identifier == ReminderPlanner.identifier(for: id))
    }
}

@Suite("Messages des rappels")
struct ReminderMessageTests {

    @Test("Une tâche importante a son étoile et un petit mot en plus")
    func importantStandsOut() throws {
        let reminder = try #require(plan([
            source("partiel", date: time(2026, 10, 20, 10), isImportant: true, reminder: .tenMinutes),
        ]).first)
        #expect(reminder.title == "⭐ partiel")
        #expect(reminder.body.hasSuffix("Celle-là compte !"))
    }

    @Test("Le message parle du bon délai")
    func mentionsTheDelay() throws {
        let reminder = try #require(plan([source(date: time(2026, 10, 20, 10), reminder: .fiveMinutes)]).first)
        #expect(reminder.body.contains("5 min"))
    }

    @Test("La veille d'une tâche à heure précise, le message donne l'heure")
    func dayBeforeGivesTime() throws {
        let reminder = try #require(plan([source(date: time(2026, 10, 21, 14, 30), reminder: .dayBefore)]).first)
        #expect(reminder.body.contains("14:30"))
    }

    @Test("Le message d'une tâche ne change pas d'un calcul à l'autre")
    func messageIsStable() {
        let item = source(date: time(2026, 10, 20, 10), reminder: .tenMinutes)
        #expect(plan([item]).first?.body == plan([item]).first?.body)
    }
}

@Suite("Réglages des notifications")
struct NotificationSettingsTests {

    @Test("Jamais réglés : activés, à 8:00, pour toutes les tâches")
    func defaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "notifications-tests-\(UUID())"))
        let settings = NotificationSettings.load(from: defaults)
        #expect(settings.isEnabled)
        #expect(settings.dayTime == 8 * 60)
        #expect(!settings.importantOnly)
        #expect(settings.dayTimeText == "08:00")
    }

    @Test("Relus tels qu'enregistrés")
    func roundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "notifications-tests-\(UUID())"))
        defaults.set(false, forKey: NotificationSettings.enabledKey)
        defaults.set(18 * 60 + 45, forKey: NotificationSettings.dayTimeKey)
        defaults.set(true, forKey: NotificationSettings.importantOnlyKey)
        let settings = NotificationSettings.load(from: defaults)
        #expect(settings == NotificationSettings(isEnabled: false, dayTime: 18 * 60 + 45, importantOnly: true))
        #expect(settings.dayTimeText == "18:45")
    }
}
