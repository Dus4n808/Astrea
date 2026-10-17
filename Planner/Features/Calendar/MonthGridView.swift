//
//  MonthGridView.swift
//  La grille 7 × 6 du mois. Elle ne fait que placer les cases :
//  le contenu de chaque case est dans DayCell.swift.
//

import SwiftUI

/// Taille d'affichage du calendrier.
enum CalendarStyle {
    /// Mac / iPad : grandes cases avec pastilles.
    case regular
    /// iPhone : petites cases avec barres de couleur.
    case compact
}

struct MonthGridView: View {
    let grid: MonthGrid
    let index: ItemIndex
    let state: CalendarState
    let style: CalendarStyle

    var body: some View {
        VStack(spacing: 0) {
            ForEach(grid.weeks, id: \.first?.id) { week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { column, day in
                        DayCell(
                            day: day,
                            items: index.items(on: day.date),
                            isToday: state.isToday(day.date),
                            isSelected: state.isSelected(day.date),
                            isWeekend: column >= 5,
                            isLastColumn: column == MonthGrid.daysPerWeek - 1,
                            style: style,
                            onSelect: { state.select(day.date) }
                        )
                    }
                }
                // En mode large, les 6 semaines se partagent la hauteur dispo.
                .frame(maxHeight: style == .regular ? .infinity : nil)
            }
        }
    }
}
