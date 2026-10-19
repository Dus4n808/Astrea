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
    @AppStorage(UserName.storageKey) private var userName = ""

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if !userName.isEmpty {
                    Text("Salut \(userName)\(Text(" !").foregroundStyle(Theme.Colors.accent))")
                        .font(Theme.Fonts.display(28))
                        .tracking(-1)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                WeekProgressCard(progress: weekProgress)

                ThemedSegmentedPicker(options: AgendaFilter.allCases, selection: $filter) { $0.title }

                if groups.isEmpty {
                    // Prend toute la largeur : la pile parente est alignée à
                    // gauche, le message serait sinon collé au bord.
                    // Semaine bouclée : l'étoile 3D fête ça à la place de l'étoile fixe.
                    EmptyStateView(title: filter.emptyTitle, message: filter.emptyMessage,
                                   celebrates: filter == .todo && weekProgress.isComplete)
                } else {
                    ForEach(groups) { group in
                        if let title = group.separatorTitle {
                            WeekSeparator(title: title)
                        }
                        AgendaDayGroup(day: group.day, items: group.items)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 720) // lisible sur Mac/iPad : pas de lignes de 1500 pt
            .frame(maxWidth: .infinity)
        }
        // Balayer une tâche pour la supprimer.
        .swipeActionsContainer()
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
    ///
    /// La carte de progression ne compte que la semaine en cours : un filet
    /// marque donc l'endroit où la liste entre dans cette semaine (après des
    /// tâches en retard) et celui où elle en sort (« Plus tard »).
    private var groups: [AgendaDay] {
        let calendar = Calendar.planner
        let weekStart = calendar.startOfWeek(for: .now)
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let visible = items.filter { filter.includes($0, from: weekStart) }
        let byDay = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.date) }

        var previous: AgendaPeriod?
        return byDay.keys.sorted().map { day in
            let period: AgendaPeriod = day < weekStart ? .past
                : (day < nextWeekStart ? .thisWeek : .later)
            // Pas de filet tout en haut : seulement au changement de période.
            let title = (previous != nil && previous != period) ? period.separatorTitle : nil
            previous = period
            return AgendaDay(day: day, items: byDay[day] ?? [], separatorTitle: title)
        }
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
    /// Filet à afficher juste avant ce jour (changement de semaine), ou nil.
    var separatorTitle: String? = nil
    var id: Date { day }
}

/// Position d'un jour par rapport à la semaine en cours.
private enum AgendaPeriod {
    case past, thisWeek, later

    var separatorTitle: String {
        switch self {
        case .past:     "En retard"
        case .thisWeek: "Cette semaine"
        case .later:    "Plus tard"
        }
    }
}

/// Filet discret avec un petit label, entre la semaine en cours et le reste.
private struct WeekSeparator: View {
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(title)
                .plannerLabelStyle()
                .fixedSize()
            Rectangle()
                .fill(Theme.Colors.gridLine)
                .frame(height: 1)
        }
        .padding(.top, Theme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
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

