//
//  CalendarLogicTests.swift
//  Le calcul de la grille et la navigation entre les mois.
//
//  C'est la partie de l'app la plus facile à casser sans s'en rendre compte :
//  un décalage d'un jour ne se voit pas à l'œil sur une seule capture d'écran.
//

import Foundation
import Testing

@testable import Planner

// MARK: - Outils communs

/// Un jour précis du calendrier de l'app, pour des tests lisibles.
private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    let components = DateComponents(year: year, month: month, day: dayOfMonth)
    return Calendar.planner.date(from: components)!
}

// MARK: - Calendrier de l'app

@Suite("Calendar.planner")
struct PlannerCalendarTests {

    @Test("La semaine commence le lundi")
    func weekStartsOnMonday() {
        #expect(Calendar.planner.firstWeekday == 2)
        #expect(Calendar.planner.weekdayInitials.first == "L")
        #expect(Calendar.planner.weekdayShortNames.first == "LUN")
        #expect(Calendar.planner.weekdayShortNames.last == "DIM")
    }

    @Test("Les noms de jours sont au nombre de sept, sans point")
    func weekdayNames() {
        #expect(Calendar.planner.weekdayShortNames.count == 7)
        #expect(Calendar.planner.weekdayShortNames.allSatisfy { !$0.contains(".") })
    }

    @Test("startOfMonth ramène au 1er à minuit")
    func startOfMonth() {
        let middle = day(2026, 10, 17)
        #expect(Calendar.planner.startOfMonth(for: middle) == day(2026, 10, 1))
    }

    @Test("startOfWeek ramène au lundi précédent")
    func startOfWeek() {
        // Le 17 octobre 2026 est un samedi : le lundi de sa semaine est le 12.
        #expect(Calendar.planner.startOfWeek(for: day(2026, 10, 17)) == day(2026, 10, 12))
        // Un lundi reste sur lui-même.
        #expect(Calendar.planner.startOfWeek(for: day(2026, 10, 12)) == day(2026, 10, 12))
    }
}

// MARK: - Grille du mois

@Suite("MonthGrid")
struct MonthGridTests {

    @Test("Toujours 42 cases, soit 6 semaines de 7 jours")
    func alwaysSixWeeks() {
        // La hauteur constante de la grille en dépend : si un mois produisait
        // 35 cases, l'interface sauterait d'un mois à l'autre.
        for month in 1...12 {
            let grid = MonthGrid(month: day(2026, month, 1))
            #expect(grid.days.count == 42, "mois \(month)")
            #expect(grid.weeks.count == 6, "mois \(month)")
            #expect(grid.weeks.allSatisfy { $0.count == 7 }, "mois \(month)")
        }
    }

    @Test("La grille démarre au lundi de la semaine du 1er")
    func startsOnMondayBeforeFirst() {
        // Octobre 2026 : le 1er est un jeudi, la grille commence le 28 septembre.
        let grid = MonthGrid(month: day(2026, 10, 1))
        #expect(grid.days.first?.date == day(2026, 9, 28))
        #expect(grid.days.first?.isInMonth == false)
    }

    @Test("isInMonth distingue le mois affiché de ses voisins")
    func flagsNeighbouringMonths() {
        let grid = MonthGrid(month: day(2026, 10, 1))
        let inMonth = grid.days.filter(\.isInMonth)

        #expect(inMonth.count == 31)                        // octobre
        #expect(inMonth.first?.date == day(2026, 10, 1))
        #expect(inMonth.last?.date == day(2026, 10, 31))
    }

    @Test("Les jours se suivent sans trou ni doublon")
    func daysAreContiguous() {
        let grid = MonthGrid(month: day(2026, 10, 1))
        let dates = grid.days.map(\.date)

        #expect(Set(dates).count == dates.count)
        for (previous, next) in zip(dates, dates.dropFirst()) {
            let gap = Calendar.planner.dateComponents([.day], from: previous, to: next).day
            #expect(gap == 1)
        }
    }

    @Test("Un mois de février bissextile reste cohérent")
    func leapFebruary() {
        let grid = MonthGrid(month: day(2028, 2, 1))
        #expect(grid.days.filter(\.isInMonth).count == 29)
    }

    @Test("N'importe quelle date du mois donne la même grille")
    func normalizesToStartOfMonth() {
        let fromFirst = MonthGrid(month: day(2026, 10, 1)).days
        let fromMiddle = MonthGrid(month: day(2026, 10, 23)).days
        #expect(fromFirst == fromMiddle)
    }
}

// MARK: - État de l'écran calendrier

@MainActor
@Suite("CalendarState")
struct CalendarStateTests {

    @Test("S'ouvre sur le mois et le jour d'aujourd'hui")
    func opensOnToday() {
        let today = day(2026, 10, 17)
        let state = CalendarState(today: today)

        #expect(state.displayedMonth == day(2026, 10, 1))
        #expect(state.selectedDay == today)
    }

    @Test("La plage navigable est centrée sur le mois d'ouverture")
    func navigableRange() {
        let state = CalendarState(today: day(2026, 10, 17))
        let radius = CalendarState.monthRadius

        #expect(state.months.count == radius * 2 + 1)
        #expect(state.months.first == day(2026 - 5, 10, 1))
        #expect(state.months.last == day(2026 + 5, 10, 1))
        #expect(state.months.contains(state.displayedMonth))
    }

    @Test("moveMonth avance et recule d'un mois")
    func moveMonth() {
        let state = CalendarState(today: day(2026, 10, 17))

        state.moveMonth(by: 1)
        #expect(state.displayedMonth == day(2026, 11, 1))

        state.moveMonth(by: -2)
        #expect(state.displayedMonth == day(2026, 9, 1))
    }

    @Test("moveMonth franchit correctement le changement d'année")
    func moveMonthAcrossYear() {
        let state = CalendarState(today: day(2026, 12, 15))
        state.moveMonth(by: 1)
        #expect(state.displayedMonth == day(2027, 1, 1))
    }

    @Test("Le mois affiché reste une valeur de la liste navigable")
    func displayedMonthStaysInList() {
        // Le défilement horizontal compare les mois par identité : une date
        // « équivalente » mais pas identique ferait sauter la page.
        let state = CalendarState(today: day(2026, 10, 17))
        state.moveMonth(by: 3)
        #expect(state.months.contains(state.displayedMonth))
    }

    @Test("moveMonth au-delà de la plage ne bouge pas")
    func moveMonthBeyondRangeIsIgnored() {
        let state = CalendarState(today: day(2026, 10, 17))
        state.moveMonth(by: CalendarState.monthRadius + 1)
        #expect(state.displayedMonth == day(2026, 10, 1))
    }

    @Test("Sélectionner un jour d'un autre mois change le mois affiché")
    func selectingAcrossMonthsFollows() {
        let state = CalendarState(today: day(2026, 10, 17))
        state.select(day(2026, 11, 3))

        #expect(state.selectedDay == day(2026, 11, 3))
        #expect(state.displayedMonth == day(2026, 11, 1))
    }

    @Test("Sélectionner un jour du mois affiché ne le fait pas bouger")
    func selectingInsideMonthKeepsMonth() {
        let state = CalendarState(today: day(2026, 10, 17))
        state.select(day(2026, 10, 2))

        #expect(state.selectedDay == day(2026, 10, 2))
        #expect(state.displayedMonth == day(2026, 10, 1))
    }

    @Test("goToToday revient au mois et au jour courants")
    func goToToday() {
        let state = CalendarState(today: day(2026, 10, 17))
        state.moveMonth(by: 4)
        state.goToToday(day(2026, 10, 17))

        #expect(state.displayedMonth == day(2026, 10, 1))
        #expect(state.selectedDay == day(2026, 10, 17))
    }

    @Test("isSelected ignore l'heure")
    func isSelectedIgnoresTime() {
        let state = CalendarState(today: day(2026, 10, 17))
        let sameDayLater = Calendar.planner.date(byAdding: .hour, value: 18, to: day(2026, 10, 17))!

        #expect(state.isSelected(sameDayLater))
        #expect(!state.isSelected(day(2026, 10, 18)))
    }
}
