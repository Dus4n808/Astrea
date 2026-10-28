//
//  MonthGridView.swift
//  La grille 7 × 6 du mois. Elle ne fait que placer les cases :
//  le contenu de chaque case est dans DayCell.swift,
//  et les mesures (hauteur de semaine, tailles) dans CalendarLayout.swift.
//

import SwiftUI

struct MonthGridView: View {
    let grid: MonthGrid
    let index: ItemIndex
    let state: CalendarState
    let layout: CalendarLayout

    var body: some View {
        VStack(spacing: 0) {
            ForEach(grid.weeks, id: \.first?.id) { week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                        DayCell(
                            day: day,
                            // Les tâches faites quittent la grille : on les
                            // retrouve dans l'Agenda, section « Fait ».
                            items: index.items(on: day.date).filter { !$0.isDone },
                            isToday: state.isToday(day.date),
                            isSelected: state.isSelected(day.date),
                            isWeekend: column >= 5,
                            isLastColumn: column == MonthGrid.daysPerWeek - 1,
                            layout: layout,
                            onSelect: { state.select(day.date) }
                        )
                    }
                }
                // En mode large, les 6 semaines se partagent la hauteur dispo,
                // sans jamais descendre sous une hauteur lisible.
                .frame(minHeight: layout.isRegular ? CalendarLayout.minimumWeekHeight : nil,
                       maxHeight: layout.isRegular ? .infinity : nil)
            }
        }
    }
}
