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
        // Calculés une seule fois par mise à jour : chacun parcourt tous les
        // éléments, et ils servent chacun à deux endroits.
        let weekProgress = self.weekProgress
        let (groups, celebratesWeek) = Self.celebrating(self.groups, weekComplete: filter == .todo && weekProgress.isComplete)

        ScrollView {
            // Paresseuse : avec le filtre « Fait » ou « Tout », la liste grandit
            // tout le semestre ; seuls les jours visibles sont construits.
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
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
                    if celebratesWeek {
                        EmptyStateView(title: "Semaine bouclée !",
                                       message: "Tout est fait pour cette semaine. Voici la suite.",
                                       celebrates: true)
                    }
                    ForEach(groups) { group in
                        // Une seule vue par jour (le filet éventuel est dedans) :
                        // la pile paresseuse n'a pas à évaluer chaque jour pour
                        // savoir combien de lignes il produit.
                        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                            if let title = group.separatorTitle {
                                WeekSeparator(title: title)
                            }
                            AgendaDayGroup(day: group.day, items: group.items)
                        }
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
        // L'étoile 3D de la semaine bouclée peut surgir à tout moment (dernière
        // tâche cochée) : son modèle est lu d'avance pour qu'elle arrive sans à-coup.
        .task { StarModel.preload() }
    }

    // MARK: - Données dérivées

    /// Éléments filtrés, regroupés par jour et triés.
    ///
    /// La carte de progression ne compte que la semaine en cours : un filet
    /// marque donc l'endroit où la liste entre dans cette semaine (après des
    /// tâches en retard) et ceux où elle en sort (« Semaine prochaine »,
    /// puis « Plus tard »).
    private var groups: [AgendaDay] {
        let calendar = Calendar.planner
        let weekStart = calendar.startOfWeek(for: .now)
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let laterStart = calendar.date(byAdding: .weekOfYear, value: 2, to: weekStart) ?? nextWeekStart
        let visible = items.filter { filter.includes($0, from: weekStart) }

        func period(of day: Date) -> AgendaPeriod {
            switch day {
            case ..<weekStart:     .past
            case ..<nextWeekStart: .thisWeek
            case ..<laterStart:    .nextWeek
            default:               .later
            }
        }

        // « Fait » : un historique, la dernière tâche terminée en haut.
        // Regroupé par jour de complétion, sans filets de semaine.
        if filter == .done {
            let byDay = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.doneSortDate) }
            return byDay.keys.sorted(by: >).map { day in
                let items = (byDay[day] ?? []).sorted { $0.doneSortDate > $1.doneSortDate }
                return AgendaDay(day: day, items: items, period: period(of: day))
            }
        }

        let byDay = Dictionary(grouping: visible) { calendar.startOfDay(for: $0.date) }
        var previous: AgendaPeriod?
        return byDay.keys.sorted().map { day in
            let period = period(of: day)
            // Pas de filet tout en haut : seulement au changement de période.
            let title = (previous != nil && previous != period) ? period.separatorTitle : nil
            previous = period
            return AgendaDay(day: day, items: Self.importantFirst(byDay[day] ?? []),
                             period: period, separatorTitle: title)
        }
    }

    /// Semaine bouclée mais des éléments prévus ensuite : on fête quand même
    /// (la liste n'est pas vide), puis la suite arrive sous un filet, y
    /// compris tout en haut, pour dire de quelle semaine il s'agit.
    static func celebrating(_ groups: [AgendaDay], weekComplete: Bool) -> (groups: [AgendaDay], celebrates: Bool) {
        guard weekComplete, !groups.isEmpty, !hasPendingTasksBeforeNextWeek(groups) else {
            return (groups, false)
        }
        var groups = groups
        if groups[0].separatorTitle == nil {
            groups[0].separatorTitle = groups[0].period.separatorTitle
        }
        return (groups, true)
    }

    /// Reste-t-il une tâche à cocher avant la semaine prochaine (en retard ou
    /// cette semaine) ? Les évènements ne se cochent pas : ils n'empêchent
    /// pas de fêter la semaine.
    static func hasPendingTasksBeforeNextWeek(_ groups: [AgendaDay]) -> Bool {
        groups.contains { group in
            (group.period == .past || group.period == .thisWeek)
                && group.items.contains { $0.kind == .task && !$0.isDone }
        }
    }

    /// Les tâches importantes pas encore faites passent en tête du jour ;
    /// le reste garde l'ordre chronologique de la requête (tri stable).
    static func importantFirst(_ items: [PlannerItem]) -> [PlannerItem] {
        let highlighted = items.filter { $0.isImportant && !$0.isDone }
        guard !highlighted.isEmpty else { return items }
        return highlighted + items.filter { !($0.isImportant && !$0.isDone) }
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
    let period: AgendaPeriod
    /// Filet à afficher juste avant ce jour (changement de semaine), ou nil.
    var separatorTitle: String? = nil
    var id: Date { day }
}

/// Position d'un jour par rapport à la semaine en cours.
enum AgendaPeriod {
    case past, thisWeek, nextWeek, later

    var separatorTitle: String {
        switch self {
        case .past:     "En retard"
        case .thisWeek: "Cette semaine"
        case .nextWeek: "Semaine prochaine"
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

