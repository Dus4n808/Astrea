//
//  ItemMoveTests.swift
//  Déplacer un élément sur un autre jour (glisser-déposer du calendrier Mac).
//

import Foundation
import Testing

@testable import Planner

private func time(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    Calendar.planner.date(from: DateComponents(year: year, month: month, day: dayOfMonth,
                                               hour: hour, minute: minute))!
}

@Suite("Déplacement d'un élément")
struct ItemMoveTests {

    @Test("L'élément change de jour mais garde son heure")
    func keepsTimeOfDay() {
        let event = PlannerItem(title: "cours", kind: .event, date: time(2026, 10, 14, 14, 30), isAllDay: false)
        #expect(event.move(to: time(2026, 10, 16)))
        #expect(event.date == time(2026, 10, 16, 14, 30))
    }

    @Test("Vers un jour passé aussi")
    func movesBackward() {
        let task = PlannerItem(title: "lecture", date: time(2026, 10, 14, 9))
        task.move(to: time(2026, 10, 2, 22))
        #expect(task.date == time(2026, 10, 2, 9))
    }

    @Test("L'heure murale tient à travers le passage à l'heure d'hiver")
    func survivesDaylightSavingChange() {
        // Le passage à l'heure d'hiver tombe le 25 octobre 2026 en Europe.
        let event = PlannerItem(title: "séminaire", kind: .event, date: time(2026, 10, 23, 14), isAllDay: false)
        event.move(to: time(2026, 10, 27))
        #expect(Calendar.planner.component(.hour, from: event.date) == 14)
        #expect(Calendar.planner.isDate(event.date, inSameDayAs: time(2026, 10, 27)))
    }

    @Test("Une date de fin suit, la durée ne change pas")
    func shiftsEndDate() {
        let holiday = PlannerItem(title: "congé", kind: .holiday, date: time(2026, 10, 19),
                                  endDate: time(2026, 10, 23))
        holiday.move(to: time(2026, 10, 26))
        #expect(holiday.date == time(2026, 10, 26))
        #expect(holiday.endDate == time(2026, 10, 30))
    }

    @Test("Déposer sur le même jour ne change rien")
    func sameDayIsNoOp() {
        let original = time(2026, 10, 14, 9)
        let task = PlannerItem(title: "lecture", date: original)
        #expect(!task.move(to: time(2026, 10, 14, 18)))
        #expect(task.date == original)
    }
}
