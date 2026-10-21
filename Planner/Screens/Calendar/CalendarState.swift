//
//  CalendarState.swift
//  État de l'écran Calendrier : quel mois est affiché, quel jour est sélectionné.
//
//  Séparé de la vue pour que la logique de navigation soit lisible et
//  testable sans interface.
//
//  Les mois navigables sont une liste finie (`months`) calculée une fois à
//  l'ouverture : c'est elle qui alimente le défilement horizontal page par
//  page. Une liste plutôt qu'un calcul à la volée, parce que le défilement a
//  besoin d'identités stables pour savoir sur quelle page il s'arrête.
//

import Foundation
import Observation

@Observable
final class CalendarState {
    /// Nombre de mois navigables de part et d'autre du mois d'ouverture
    /// (5 ans en arrière, 5 ans en avant : largement au-delà d'un cursus).
    static let monthRadius = 60

    /// Premier jour du mois affiché. Toujours une valeur présente dans `months`.
    var displayedMonth: Date
    /// Jour sélectionné (00:00). Sur iPhone, ses tâches s'affichent sous la grille.
    var selectedDay: Date

    /// Tous les mois atteignables au swipe, du plus ancien au plus récent.
    let months: [Date]

    private let calendar: Calendar

    init(today: Date = .now, calendar: Calendar = .planner) {
        self.calendar = calendar
        let start = calendar.startOfMonth(for: today)
        self.displayedMonth = start
        self.selectedDay = calendar.startOfDay(for: today)
        self.months = (-Self.monthRadius...Self.monthRadius).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: start)
        }
    }

    /// `displayedMonth` vu par le défilement horizontal (`scrollPosition`),
    /// qui travaille avec un optionnel. Le nil n'arrive qu'au tout premier
    /// affichage : on l'ignore.
    var scrolledMonth: Date? {
        get { displayedMonth }
        set { if let newValue { displayedMonth = newValue } }
    }

    /// La grille de 42 jours du mois affiché.
    var grid: MonthGrid { grid(for: displayedMonth) }

    /// La grille d'un mois quelconque (utilisée par le défilement horizontal).
    func grid(for month: Date) -> MonthGrid {
        MonthGrid(month: month, calendar: calendar)
    }

    /// Mois précédent (-1) ou suivant (+1).
    func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        show(month)
    }

    /// Revient au mois courant et sélectionne aujourd'hui.
    func goToToday(_ today: Date = .now) {
        selectedDay = calendar.startOfDay(for: today)
        show(today)
    }

    /// Sélectionne un jour ; s'il est dans un autre mois, on y va.
    func select(_ day: Date) {
        selectedDay = calendar.startOfDay(for: day)
        if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            show(day)
        }
    }

    /// Affiche le mois contenant `date`, s'il fait partie de la plage navigable.
    /// On retrouve la valeur exacte dans `months` plutôt que d'en recalculer
    /// une : le défilement compare les dates par identité, pas par mois.
    func show(_ date: Date) {
        guard let match = months.first(where: {
            calendar.isDate($0, equalTo: date, toGranularity: .month)
        }) else { return }
        displayedMonth = match
    }

    func isToday(_ day: Date) -> Bool { calendar.isDateInToday(day) }
    func isSelected(_ day: Date) -> Bool { calendar.isDate(day, inSameDayAs: selectedDay) }
}
