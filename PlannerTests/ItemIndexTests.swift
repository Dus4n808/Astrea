//
//  ItemIndexTests.swift
//  Le regroupement des éléments par jour, et l'ordre d'affichage.
//
//  ItemIndex est l'optimisation qui évite 42 filtrages par rendu de grille :
//  si elle se trompe, des éléments disparaissent silencieusement de cases.
//

import Foundation
import Testing

@testable import Planner

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
}

private func time(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour))!
}

@Suite("ItemIndex")
struct ItemIndexTests {

    @Test("Un élément se retrouve sur son jour")
    func findsItemOnItsDay() {
        let task = PlannerItem(title: "lecture", date: day(2026, 10, 18))
        let index = ItemIndex(items: [task])

        #expect(index.items(on: day(2026, 10, 18)).count == 1)
        #expect(index.items(on: day(2026, 10, 19)).isEmpty)
    }

    @Test("La recherche par jour ignore l'heure")
    func lookupIgnoresTime() {
        let event = PlannerItem(title: "présentation", kind: .event,
                                date: time(2026, 10, 18, 14), isAllDay: false)
        let index = ItemIndex(items: [event])

        #expect(index.items(on: time(2026, 10, 18, 23)).count == 1)
    }

    @Test("Une période couvre tous ses jours, bornes incluses")
    func spansEveryDay() {
        let holiday = PlannerItem(title: "semaine intercalaire", kind: .holiday,
                                  date: day(2026, 11, 2), endDate: day(2026, 11, 6))
        let index = ItemIndex(items: [holiday])

        for dayOfMonth in 2...6 {
            #expect(index.items(on: day(2026, 11, dayOfMonth)).count == 1, "jour \(dayOfMonth)")
        }
        #expect(index.items(on: day(2026, 11, 1)).isEmpty)
        #expect(index.items(on: day(2026, 11, 7)).isEmpty)
    }

    @Test("Une date de fin aberrante ne boucle pas indéfiniment")
    func clampsAbsurdSpans() {
        // Garde-fou : une erreur de saisie (fin en 2030) ne doit pas remplir
        // des milliers de jours au moment du rendu.
        let broken = PlannerItem(title: "erreur", kind: .holiday,
                                 date: day(2026, 1, 1), endDate: day(2030, 1, 1))
        let index = ItemIndex(items: [broken])

        #expect(index.items(on: day(2026, 1, 1)).count == 1)
        #expect(index.items(on: day(2030, 1, 1)).isEmpty)
    }

    @Test("Une date de fin antérieure au début ne garde que le premier jour")
    func endBeforeStart() {
        let odd = PlannerItem(title: "incohérent", kind: .holiday,
                              date: day(2026, 10, 10), endDate: day(2026, 10, 5))
        let index = ItemIndex(items: [odd])

        #expect(index.items(on: day(2026, 10, 10)).isEmpty)
        #expect(index.items(on: day(2026, 10, 5)).isEmpty)
    }

    @Test("Dans une journée : vacances, puis heures fixes, puis fin de journée")
    func displayOrderWithinADay() {
        let target = day(2026, 10, 19)
        let allDayTask = PlannerItem(title: "lecture", date: target)
        let timedEvent = PlannerItem(title: "cours", kind: .event,
                                     date: time(2026, 10, 19, 10), isAllDay: false)
        let holiday = PlannerItem(title: "congé", kind: .holiday, date: target)

        let index = ItemIndex(items: [allDayTask, timedEvent, holiday])
        let titles = index.items(on: target).map(\.title)

        #expect(titles == ["congé", "cours", "lecture"])
    }

    @Test("Deux éléments à heure fixe sont triés par heure")
    func timedItemsSortedByHour() {
        let late = PlannerItem(title: "tard", kind: .event, date: time(2026, 10, 19, 16), isAllDay: false)
        let early = PlannerItem(title: "tôt", kind: .event, date: time(2026, 10, 19, 8), isAllDay: false)

        let index = ItemIndex(items: [late, early])
        #expect(index.items(on: day(2026, 10, 19)).map(\.title) == ["tôt", "tard"])
    }

    @Test("Un jour vide renvoie une liste vide, pas nil")
    func emptyDay() {
        let index = ItemIndex(items: [])
        #expect(index.items(on: day(2026, 10, 19)).isEmpty)
    }
}

// MARK: - Filtre de l'agenda

@Suite("AgendaFilter")
struct AgendaFilterTests {

    private let weekStart = day(2026, 10, 12)

    @Test("« À faire » garde ce qui n'est pas coché à partir de cette semaine")
    func todoKeepsPending() {
        let pending = PlannerItem(title: "à faire", date: day(2026, 10, 14))
        #expect(AgendaFilter.todo.includes(pending, from: weekStart))
    }

    @Test("« À faire » garde les tâches en retard des semaines passées")
    func todoKeepsOverdueTasks() {
        // Une tâche oubliée ne doit pas disparaître parce que sa date est passée.
        let overdue = PlannerItem(title: "oubliée", date: day(2026, 9, 30))
        #expect(AgendaFilter.todo.includes(overdue, from: weekStart))
    }

    @Test("« À faire » laisse tomber les événements passés")
    func todoDropsPastEvents() {
        // Un cours de la semaine dernière n'est pas « à faire » : il a eu lieu.
        let pastEvent = PlannerItem(title: "cours passé", kind: .event, date: day(2026, 9, 30))
        #expect(!AgendaFilter.todo.includes(pastEvent, from: weekStart))
    }

    @Test("« À faire » exclut ce qui est coché")
    func todoExcludesDone() {
        let done = PlannerItem(title: "finie", date: day(2026, 10, 14))
        done.isDone = true
        #expect(!AgendaFilter.todo.includes(done, from: weekStart))
    }

    @Test("« Fait » ne garde que ce qui est coché, même en dehors de la semaine")
    func doneKeepsOnlyChecked() {
        let oldDone = PlannerItem(title: "vieille", date: day(2026, 8, 1))
        oldDone.isDone = true
        let pending = PlannerItem(title: "en cours", date: day(2026, 10, 14))

        #expect(AgendaFilter.done.includes(oldDone, from: weekStart))
        #expect(!AgendaFilter.done.includes(pending, from: weekStart))
    }

    @Test("« Tout » part du début de la semaine")
    func allStartsAtWeekStart() {
        let thisWeek = PlannerItem(title: "cette semaine", date: day(2026, 10, 14))
        let lastWeek = PlannerItem(title: "semaine passée", date: day(2026, 10, 5))

        #expect(AgendaFilter.all.includes(thisWeek, from: weekStart))
        #expect(!AgendaFilter.all.includes(lastWeek, from: weekStart))
    }
}
