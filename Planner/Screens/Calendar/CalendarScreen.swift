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
//  Découpage en deux vues, pour la performance :
//  - `CalendarScreen` ne fait que lire la base et construire l'index des
//    jours (coûteux : il parcourt et trie tous les éléments) ;
//  - `CalendarContent` porte tout ce qui change souvent (taille de la
//    fenêtre, jour sélectionné, mois affiché pendant le swipe).
//  Ainsi, redimensionner la fenêtre ou changer de mois ne reconstruit pas
//  l'index : seul un changement des éléments le fait.
//

import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Query(sort: \PlannerItem.date) private var items: [PlannerItem]

    var body: some View {
        // `ItemIndex` lit la date, la fin, le type, etc. de chaque élément :
        // cette vue est donc recalculée (et l'index reconstruit) dès qu'un
        // de ces champs change, et seulement dans ce cas.
        CalendarContent(items: items, index: ItemIndex(items: items))
    }
}

private struct CalendarContent: View {
    @Environment(AppState.self) private var appState
    @State private var state = CalendarState()
    @State private var viewportSize: CGSize = .zero
    /// Hauteur visible de la page en mise en page large (sans les barres).
    @State private var pageHeight: CGFloat?

    let items: [PlannerItem]
    let index: ItemIndex

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var prefersCompact: Bool { sizeClass == .compact }
    #else
    private let prefersCompact = false
    #endif

    var body: some View {
        let layout = CalendarLayout(size: viewportSize, prefersCompact: prefersCompact)

        Group {
            switch layout.style {
            case .compact: compactLayout(layout: layout)
            case .regular: regularLayout(layout: layout)
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

    private func regularLayout(layout: CalendarLayout) -> some View {
        // Toujours un ScrollView, même quand tout tient : basculer entre
        // « ScrollView » et « pas de ScrollView » recréait la grille (et son
        // défilement horizontal) chaque fois que la fenêtre passait le seuil.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CalendarMonthHeader(state: state, items: items, layout: layout)
                    .padding(.bottom, Theme.Spacing.l)

                WeekdayHeader(layout: layout)

                MonthPager(index: index, state: state, layout: layout)
                    // Hauteur imposée uniquement quand la fenêtre est trop courte,
                    // sinon la grille remplit la place disponible.
                    .frame(height: layout.gridHeight)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, Theme.Spacing.l)
            // Quand tout tient, la page fait exactement la hauteur visible :
            // la grille s'étire pour la remplir, comme hors d'un ScrollView.
            .frame(height: layout.scrollsVertically ? nil : pageHeight)
        }
        // Fenêtre trop courte pour 6 semaines lisibles : on fait défiler
        // plutôt que d'écraser les cases jusqu'à couper les pastilles.
        .scrollDisabled(!layout.scrollsVertically)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
        } action: { _, height in
            pageHeight = height
        }
    }

    private func compactLayout(layout: CalendarLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                CalendarMonthHeader(state: state, items: items, layout: layout)

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
}

/// L'en-tête du mois, dans sa propre vue : c'est lui qui lit le mois affiché.
/// Pendant le swipe, ce mois change à chaque page ; seul l'en-tête est alors
/// recalculé, pas tout l'écran.
private struct CalendarMonthHeader: View {
    let state: CalendarState
    let items: [PlannerItem]
    let layout: CalendarLayout

    var body: some View {
        MonthHeader(month: state.displayedMonth,
                    weekNumber: state.selectedDay.weekNumber,
                    upcomingCount: upcomingDeadlines,
                    layout: layout)
    }

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
