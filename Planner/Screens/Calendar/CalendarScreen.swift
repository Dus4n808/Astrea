//
//  CalendarScreen.swift
//  Écran principal : la vue mois.
//
//  Deux mises en page, choisies d'après la place réellement disponible
//  (voir CalendarLayout) et non d'après l'appareil :
//  - large    : grande grille avec des pastilles dans chaque case.
//  - compacte : petite grille avec des barres de couleur,
//               et la liste du jour sélectionné en dessous.
//
//  C'est ce qui rend l'écran utilisable sur Mac, où la fenêtre peut être
//  réduite jusqu'à la taille d'un iPhone.
//
//  Cette vue ne fait qu'assembler : l'en-tête, la grille et la liste sont
//  chacune dans leur propre fichier.
//

import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(AppState.self) private var appState
    @State private var state = CalendarState()
    @State private var viewportSize: CGSize = .zero
    @Query(sort: \PlannerItem.date) private var items: [PlannerItem]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var prefersCompact: Bool { sizeClass == .compact }
    #else
    private let prefersCompact = false
    #endif

    var body: some View {
        // Index reconstruit quand `items` change (SwiftData met à jour @Query).
        let index = ItemIndex(items: items)
        let layout = CalendarLayout(size: viewportSize, prefersCompact: prefersCompact)

        Group {
            switch layout.style {
            case .compact: compactLayout(index: index, layout: layout)
            case .regular: regularLayout(index: index, layout: layout)
            }
        }
        .background(Theme.Colors.background)
        // Sur Mac la fenêtre se redimensionne librement et il n'existe pas de
        // size class : c'est la taille mesurée qui décide de la mise en page.
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewportSize = newSize
        }
        .toolbar { toolbarContent }
        // Le « + » de la tab bar (iPhone) n'a pas accès à l'état du calendrier :
        // on lui transmet le jour sélectionné pour qu'il le pré-remplisse.
        .onAppear { appState.focusedDate = state.selectedDay }
        .onChange(of: state.selectedDay) { _, day in appState.focusedDate = day }
        .onDisappear { appState.focusedDate = .now }
    }

    // MARK: - Mises en page

    @ViewBuilder
    private func regularLayout(index: ItemIndex, layout: CalendarLayout) -> some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            MonthHeader(month: state.displayedMonth,
                        weekNumber: state.selectedDay.weekNumber,
                        upcomingCount: upcomingDeadlines,
                        layout: layout)
                .padding(.bottom, Theme.Spacing.l)

            WeekdayHeader(layout: layout)

            MonthPager(index: index, state: state, layout: layout)
                // Hauteur imposée uniquement quand la fenêtre est trop courte,
                // sinon la grille remplit la place disponible.
                .frame(height: layout.gridHeight)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, Theme.Spacing.l)

        // Fenêtre trop courte pour 6 semaines lisibles : on fait défiler
        // plutôt que d'écraser les cases jusqu'à couper les pastilles.
        if layout.scrollsVertically {
            ScrollView { content }
        } else {
            content
        }
    }

    private func compactLayout(index: ItemIndex, layout: CalendarLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                MonthHeader(month: state.displayedMonth,
                            weekNumber: state.selectedDay.weekNumber,
                            upcomingCount: upcomingDeadlines,
                            layout: layout)

                VStack(spacing: 0) {
                    WeekdayHeader(layout: layout)
                    MonthPager(index: index, state: state, layout: layout)
                        .frame(height: layout.compactWeekHeight * CGFloat(MonthGrid.weekCount))
                }

                DayAgendaList(day: state.selectedDay, items: index.items(on: state.selectedDay))
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.bottom, Theme.Spacing.xl)
            // Lisible quand la fenêtre du Mac est étroite mais pas minuscule.
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // Balayer une tâche de la liste du jour pour la supprimer.
        .swipeActionsContainer()
    }

    // MARK: - Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Mois précédent", systemImage: "chevron.left") {
                withAnimation(.snappy) { state.moveMonth(by: -1) }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Button("Aujourd'hui") {
                withAnimation(.snappy) { state.goToToday() }
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Mois suivant", systemImage: "chevron.right") {
                withAnimation(.snappy) { state.moveMonth(by: 1) }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }

        if showsAddButton {
            ToolbarItem(placement: .primaryAction) {
                AddItemButton(date: state.selectedDay)
            }
        }
    }

    /// Sur iPhone le « + » vit dans la tab bar : inutile de le doubler ici.
    /// Le critère est la présence de la tab bar, pas la largeur : une fenêtre
    /// Mac réduite passe en mise en page compacte mais garde sa barre d'outils.
    private var showsAddButton: Bool {
        !prefersCompact
    }

    // MARK: - Données dérivées

    /// Tâches non faites entre aujourd'hui et la fin du mois affiché
    /// (« 4 échéances d'ici le 31 » dans la maquette).
    private var upcomingDeadlines: Int {
        let calendar = Calendar.planner
        let today = calendar.startOfDay(for: .now)
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: state.displayedMonth) else { return 0 }
        return items.filter {
            $0.kind == .task && !$0.isDone && $0.date >= today && $0.date < endOfMonth
        }.count
    }
}

#Preview {
    NavigationStack {
        CalendarScreen()
    }
    .environment(AppState())
    .modelContainer(PlannerStore.preview)
}

// Les deux cas que la mise en page large ne couvre pas : fenêtre étroite
// (bascule en compact) et fenêtre basse (la grille défile).

#Preview("Mac — fenêtre réduite", traits: .fixedLayout(width: 700, height: 760)) {
    NavigationStack {
        CalendarScreen()
    }
    .environment(AppState())
    .modelContainer(PlannerStore.preview)
}

// Taille d'ouverture de la fenêtre Mac (voir Planner.swift) : cases larges
// avec pastilles.
#Preview("Mac — fenêtre d'ouverture", traits: .fixedLayout(width: 1280, height: 820)) {
    NavigationStack {
        CalendarScreen()
    }
    .environment(AppState())
    .modelContainer(PlannerStore.preview)
}

#Preview("Mac — fenêtre basse", traits: .fixedLayout(width: 1200, height: 520)) {
    NavigationStack {
        CalendarScreen()
    }
    .environment(AppState())
    .modelContainer(PlannerStore.preview)
}
