//
//  CalendarScreen.swift
//  Écran principal : la vue mois.
//
//  Deux mises en page selon la place disponible :
//  - large (Mac, iPad)  : grande grille avec des pastilles dans chaque case.
//  - compacte (iPhone)  : petite grille avec des barres de couleur,
//                          et la liste du jour sélectionné en dessous.
//
//  Cette vue ne fait qu'assembler : l'en-tête, la grille et la liste sont
//  chacune dans leur propre fichier.
//

import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(AppState.self) private var appState
    @State private var state = CalendarState()
    @Query(sort: \PlannerItem.date) private var items: [PlannerItem]

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        // Index reconstruit quand `items` change (SwiftData met à jour @Query).
        let index = ItemIndex(items: items)

        Group {
            if isCompact {
                compactLayout(index: index)
            } else {
                regularLayout(index: index)
            }
        }
        .background(Theme.Colors.background)
        .toolbar { toolbarContent }
        // Le « + » de la tab bar (iPhone) n'a pas accès à l'état du calendrier :
        // on lui transmet le jour sélectionné pour qu'il le pré-remplisse.
        .onAppear { appState.focusedDate = state.selectedDay }
        .onChange(of: state.selectedDay) { _, day in appState.focusedDate = day }
        .onDisappear { appState.focusedDate = .now }
    }

    // MARK: - Mises en page

    private func regularLayout(index: ItemIndex) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MonthHeader(month: state.displayedMonth,
                        weekNumber: state.selectedDay.weekNumber,
                        upcomingCount: upcomingDeadlines,
                        style: .regular)
                .padding(.bottom, Theme.Spacing.l)

            WeekdayHeader(style: .regular)

            MonthPager(index: index, state: state, style: .regular)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.l)
    }

    private func compactLayout(index: ItemIndex) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                MonthHeader(month: state.displayedMonth,
                            weekNumber: state.selectedDay.weekNumber,
                            upcomingCount: upcomingDeadlines,
                            style: .compact)

                VStack(spacing: 0) {
                    WeekdayHeader(style: .compact)
                    MonthPager(index: index, state: state, style: .compact)
                }

                DayAgendaList(day: state.selectedDay, items: index.items(on: state.selectedDay))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
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

        // Sur iPhone le « + » vit dans la tab bar : inutile de le doubler ici.
        if !isCompact {
            ToolbarItem(placement: .primaryAction) {
                AddItemButton(date: state.selectedDay)
            }
        }
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
