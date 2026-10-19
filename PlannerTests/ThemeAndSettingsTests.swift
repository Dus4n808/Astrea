//
//  ThemeAndSettingsTests.swift
//  Thèmes de couleurs, heure facultative des éléments, navigation.
//

import Foundation
import Testing

@testable import Planner

/// UserDefaults jetable : les tests ne touchent jamais aux vrais réglages.
private func makeDefaults() -> UserDefaults {
    let name = "tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: day,
                                               hour: hour, minute: minute))!
}

// MARK: - Thèmes

@Suite("Thèmes")
@MainActor
struct ThemeTests {

    @Test("Rose est le thème par défaut")
    func roseIsDefault() {
        #expect(AppTheme.default == .rose)
        #expect(ThemeStore(defaults: makeDefaults()).theme == .rose)
    }

    @Test("Au moins 4 thèmes en plus du rose")
    func offersEnoughThemes() {
        #expect(AppTheme.allCases.count >= 5)
    }

    @Test("Chaque thème a un nom distinct")
    func namesAreDistinct() {
        let names = AppTheme.allCases.map(\.name)
        #expect(!names.contains(""))
        #expect(Set(names).count == names.count)
    }

    @Test("Les valeurs enregistrées n'ont pas changé")
    func rawValuesAreStable() {
        // Enregistrées dans les réglages : les renommer ferait perdre le choix.
        #expect(AppTheme.rose.rawValue == "rose")
        #expect(AppTheme.lavender.rawValue == "lavender")
        #expect(AppTheme.mint.rawValue == "mint")
        #expect(AppTheme.peach.rawValue == "peach")
        #expect(AppTheme.sky.rawValue == "sky")
    }

    @Test("Une valeur inconnue ou absente retombe sur le thème par défaut")
    func unknownValueFallsBack() {
        #expect(AppTheme(storedValue: nil) == .default)
        #expect(AppTheme(storedValue: "fluo") == .default)
        #expect(AppTheme(storedValue: "mint") == .mint)
    }

    @Test("Le choix est enregistré et relu au lancement suivant")
    func choiceIsPersisted() {
        let defaults = makeDefaults()
        let store = ThemeStore(defaults: defaults)
        store.theme = .lavender
        #expect(defaults.string(forKey: ThemeStore.storageKey) == "lavender")
        #expect(ThemeStore(defaults: defaults).theme == .lavender)
    }

    @Test("Chaque thème a sa propre couleur d'accent")
    func accentsAreDistinct() {
        let accents = AppTheme.allCases.map { "\($0.palette.accent)" }
        #expect(Set(accents).count == accents.count)
    }
}

// MARK: - Heure facultative

@Suite("Heure facultative")
@MainActor
struct OptionalTimeTests {

    @Test("Une nouvelle tâche n'a pas d'heure")
    func newTaskHasNoTime() {
        let draft = ItemDraft(request: EditorRequest(mode: .create(kind: .task, date: time(2026, 10, 19))))
        #expect(draft.isAllDay)
    }

    @Test("Ajouter une heure à une tâche sans heure propose l'heure pleine suivante")
    func addTimeFromMidnight() {
        let item = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.addTime(now: time(2026, 10, 19, 14, 20))
        #expect(!draft.isAllDay)
        #expect(draft.date == time(2026, 10, 19, 15))
    }

    @Test("Ajouter une heure garde une heure déjà réglée")
    func addTimeKeepsExistingTime() {
        let item = PlannerItem(title: "cours", kind: .event, date: time(2026, 10, 19, 9, 30))
        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.addTime(now: time(2026, 10, 19, 20))
        #expect(draft.date == time(2026, 10, 19, 9, 30))
    }

    @Test("Ajouter une heure tard le soir ne passe pas au lendemain")
    func addTimeLateEvening() {
        let item = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.addTime(now: time(2026, 10, 19, 23, 40))
        #expect(draft.date == time(2026, 10, 19, 23))
    }

    @Test("Retirer l'heure remet l'élément sur la journée")
    func removeTime() {
        let item = PlannerItem(title: "cours", kind: .event, date: time(2026, 10, 19, 9), isAllDay: false)
        var draft = ItemDraft(request: EditorRequest(mode: .edit(item)))
        draft.removeTime()
        #expect(draft.isAllDay)
    }

    @Test("Le sous-titre ne montre l'heure que si elle existe")
    func subtitleShowsTimeOnlyWhenSet() {
        let course = Course(name: "méthodes mixtes", color: .blue)
        let dayOnly = PlannerItem(title: "lecture", date: time(2026, 10, 19), course: course)
        #expect(dayOnly.subtitle == "méthodes mixtes")
        #expect(!dayOnly.subtitle.contains("journée"))

        let timed = PlannerItem(title: "cours", kind: .event, date: time(2026, 10, 19, 14, 30),
                                isAllDay: false, course: course)
        #expect(timed.subtitle == "méthodes mixtes · 14:30")
    }

    @Test("Sans cours, le sous-titre donne le type")
    func subtitleWithoutCourse() {
        let task = PlannerItem(title: "lecture", date: time(2026, 10, 19))
        #expect(task.subtitle == ItemKind.task.title)
    }
}

// MARK: - Sélecteur d'heure

@Suite("Sélecteur d'heure")
@MainActor
struct TimePickerTests {

    @Test("Changer l'heure garde le jour")
    func keepsDay() {
        let changed = MiniTimePicker.date(time(2026, 10, 19, 9), hour: 17, minute: 45)
        #expect(changed == time(2026, 10, 19, 17, 45))
    }

    @Test("La minute affichée est arrondie à la grille de 5", arguments: [
        (0, 0), (2, 0), (3, 5), (29, 30), (57, 55), (59, 55),
    ])
    func roundsMinute(minute: Int, expected: Int) {
        #expect(MiniTimePicker.roundedMinute(minute) == expected)
    }
}

// MARK: - Navigation

@Suite("Navigation")
struct NavigationTests {

    @Test("Réglages est accessible sur iPhone")
    func settingsReachableOnPhone() {
        #expect(AppSection.phoneTabs.contains(.settings))
    }

    @Test("Chaque section est atteignable sur Mac (sidebar + Réglages en bas)")
    func everySectionReachableOnMac() {
        for section in AppSection.allCases where section != .settings {
            #expect(AppSection.main.contains(section), "\(section)")
        }
    }
}
