//
//  DayAgendaList.swift
//  Sur iPhone : la liste des éléments du jour sélectionné, sous la grille.
//

import SwiftData
import SwiftUI

struct DayAgendaList: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    let day: Date
    let items: [PlannerItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // « Demain                    DIM. 18 OCT. »
            HStack(alignment: .firstTextBaseline) {
                Text(day.relativeDayTitle)
                    .font(Theme.Fonts.display(22))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Colors.ink)
                Spacer()
                Text(day.shortDayText)
                    .plannerLabelStyle(color: Theme.Colors.accent)
            }

            if items.isEmpty {
                EmptyDayView { appState.openEditor(on: day) }
            } else {
                // Même règle que l'agenda : les tâches importantes en tête.
                ForEach(AgendaScreen.importantFirst(items)) { item in
                    ItemRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        color: item.displayColor,
                        isDone: item.isDone,
                        details: item.details,
                        isImportant: item.isImportant,
                        onToggle: item.kind.isCheckable ? { toggle(item) } : nil
                    )
                    .contentShape(.rect)
                    .onTapGesture { appState.openDetail(for: item) }
                    // Le ScrollView de CalendarScreen porte swipeActionsContainer().
                    .deleteOnSwipe {
                        withAnimation(.snappy) { context.delete(item) }
                    }
                }
            }
        }
    }

    private func toggle(_ item: PlannerItem) {
        withAnimation(.snappy) { item.isDone.toggle() }
    }
}

/// Journée vide : un petit message sympa plutôt qu'un trou.
private struct EmptyDayView: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            StarLogo()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rien de prévu")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Text("Profite, ou ajoute une tâche.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            Spacer()
            Button("Ajouter", systemImage: "plus", action: onAdd)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}
