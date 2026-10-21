//
//  AgendaDayGroup.swift
//  Un bloc de l'agenda : gros numéro du jour à gauche, éléments à droite.
//

import SwiftData
import SwiftUI

struct AgendaDayGroup: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    let day: Date
    let items: [PlannerItem]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Colonne « 18 / DIM ».
            VStack(alignment: .leading, spacing: 0) {
                Text(day.dayNumber, format: .number)
                    .font(Theme.Fonts.display(40))
                    .tracking(-2)
                    .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.ink)
                Text(day.formatted(.dateTime.weekday(.abbreviated).locale(.planner)))
                    .plannerLabelStyle(color: Theme.Colors.accent)
            }
            .frame(width: 56, alignment: .leading)

            VStack(spacing: Theme.Spacing.s) {
                ForEach(items) { item in
                    ItemRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        color: item.displayColor,
                        isDone: item.isDone,
                        details: item.details,
                        onToggle: item.kind.isCheckable ? { toggle(item) } : nil
                    )
                    .contentShape(.rect)
                    .onTapGesture { appState.openDetail(for: item) }
                    // Le ScrollView d'AgendaScreen porte swipeActionsContainer().
                    .deleteOnSwipe {
                        withAnimation(.snappy) { context.delete(item) }
                    }
                }
            }
        }
    }

    private var isToday: Bool { Calendar.planner.isDateInToday(day) }

    private func toggle(_ item: PlannerItem) {
        withAnimation(.snappy) { item.isDone.toggle() }
    }
}
