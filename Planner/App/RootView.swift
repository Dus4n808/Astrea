//
//  RootView.swift
//  Vue racine : choisit la « coque » de navigation selon l'appareil.
//
//  - iPhone (largeur compacte)      → TabShell     (tab bar en bas)
//  - iPad (largeur régulière) / Mac → SidebarShell (sidebar à gauche)
//
//  Elle possède aussi l'AppState et présente la feuille d'édition,
//  pour que n'importe quelle vue puisse l'ouvrir.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var appState = AppState.shared

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        shell
            .environment(appState)
            .tint(Theme.Colors.pink)
            // La DA est pensée en clair (fond rose). Le mode sombre viendra
            // plus tard, quand Theme aura des couleurs adaptatives.
            .preferredColorScheme(.light)
            // La feuille d'édition est gérée à un seul endroit.
            .sheet(item: $appState.editorRequest) { request in
                ItemEditorView(request: request)
            }
    }

    @ViewBuilder
    private var shell: some View {
        #if os(iOS)
        if sizeClass == .compact {
            TabShell()
        } else {
            SidebarShell()
        }
        #else
        SidebarShell()
        #endif
    }
}

/// Fait le lien entre une section et son écran.
/// C'est le seul endroit à modifier quand on ajoute une section.
struct SectionScreen: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .calendar: CalendarScreen()
        case .agenda:   AgendaScreen()
        case .courses:  CoursesScreen()
        case .years:    ComingSoonScreen(section: section)
        case .settings: ComingSoonScreen(section: section)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PlannerStore.preview)
}
