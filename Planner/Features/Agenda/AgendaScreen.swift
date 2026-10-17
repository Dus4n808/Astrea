//
//  AgendaScreen.swift
//  Liste des éléments regroupés par jour, avec un filtre À faire / Fait / Tout.
//
//  ┌──────────────────────────────┐
//  │ CETTE SEMAINE         3 /9   │  ← WeekProgressCard
//  └──────────────────────────────┘
//  [ À faire | Fait | Tout ]       ← filtre
//  18   lecture          ○
//  DIM  lectures         ○         ← AgendaDayGroup
//

import SwiftUI
import SwiftData

struct AgendaScreen: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \PlannerItem.date) private var items: [PlannerItem]
    @State private var filter: AgendaFilter = .todo

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                WeekProgressCard(progress: weekProgress)

                Picker("Filtre", selection: $filter) {
                    ForEach(AgendaFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if groups.isEmpty {
                    ContentUnavailableView(filter.emptyTitle, systemImage: "checkmark.circle",
                                           description: Text(filter.emptyMessage))
                } else {
                    ForEach(groups) { group in
                        AgendaDayGroup(day: group.day, items: group.items)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 720) // lisible sur Mac/iPad : pas de lignes de 1500 pt
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Agenda")
        .toolbar {
            // Sur iPhone le « + » vit dans la tab bar : inutile de le doubler ici.
            if !isCompact {
                ToolbarItem(placement: .primaryAction) { AddItemButton() }
            }
        }
        .animation(.snappy, value: filter)
    }

    // MARK: - Données dérivées

    /// Éléments filtrés, regroupés par jour et triés.
    private var groups: [AgendaDay] {
        let calendar = Calendar.planner
        let weekStart = calendar.startOfWeek(for: .now)
        let visible = items.filter { filter.includes($0, from: weekStart) }
        let byDay = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted().map { AgendaDay(day: $0, items: byDay[$0] ?? []) }
    }

    /// Tâches de la semaine en cours : combien sont faites sur le total.
    private var weekProgress: WeekProgress {
        let calendar = Calendar.planner
        let weekTasks = items.filter {
            $0.kind == .task && calendar.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear)
        }
        return WeekProgress(done: weekTasks.filter(\.isDone).count, total: weekTasks.count)
    }
}

/// Un jour de l'agenda et ses éléments.
struct AgendaDay: Identifiable {
    let day: Date
    let items: [PlannerItem]
    var id: Date { day }
}

// MARK: - Filtre

enum AgendaFilter: String, CaseIterable, Identifiable {
    case todo, done, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: "À faire"
        case .done: "Fait"
        case .all:  "Tout"
        }
    }

    var emptyTitle: String {
        switch self {
        case .todo: "Tout est fait !"
        case .done: "Rien de terminé"
        case .all:  "Agenda vide"
        }
    }

    var emptyMessage: String {
        switch self {
        case .todo: "Aucune tâche en attente. Profite."
        case .done: "Coche une tâche pour la retrouver ici."
        case .all:  "Ajoute ta première tâche avec le bouton +."
        }
    }

    /// Règle de filtrage.
    /// - À faire : tout ce qui n'est pas fait à partir de cette semaine,
    ///             + les tâches en retard des semaines passées.
    /// - Fait    : uniquement les tâches cochées.
    /// - Tout    : tout à partir de cette semaine.
    func includes(_ item: PlannerItem, from weekStart: Date) -> Bool {
        switch self {
        case .todo: !item.isDone && (item.date >= weekStart || item.kind == .task)
        case .done: item.isDone
        case .all:  item.date >= weekStart
        }
    }
}

#Preview {
    NavigationStack {
        AgendaScreen()
    }
    .environment(AppState())
    .modelContainer(PlannerStore.preview)
}
