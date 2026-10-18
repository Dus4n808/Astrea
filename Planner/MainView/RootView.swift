//
//  RootView.swift
//  Vue racine : choisit la « coque » de navigation selon l'appareil.
//
//  - iPhone (largeur compacte)      → TabShell     (tab bar en bas)
//  - iPad (largeur régulière) / Mac → SidebarShell (sidebar à gauche)
//
//  Chaque écran s'adapte ensuite à la place qu'il reçoit : sur Mac, réduire
//  la fenêtre fait passer le calendrier en mise en page compacte
//  (voir CalendarLayout).
//
//  Elle possède aussi l'AppState et présente la feuille d'édition,
//  pour que n'importe quelle vue puisse l'ouvrir.
//
//  Au premier lancement (aucun prénom enregistré), elle affiche
//  OnboardingScreen à la place de la coque.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @State private var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Vide tant que l'onboarding n'est pas terminé.
    @AppStorage(UserName.storageKey) private var userName = ""

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        content
            #if os(macOS)
            // Plancher de redimensionnement : en dessous, la sidebar et le
            // contenu ne cohabitent plus utilement.
            .frame(minWidth: 680, minHeight: 480)
            #endif
            .environment(appState)
            .tint(Theme.Colors.accent)
            // La DA est pensée en clair (fond rose). Le mode sombre viendra
            // plus tard, quand Theme aura des couleurs adaptatives.
            .preferredColorScheme(.light)
            // La feuille d'édition est gérée à un seul endroit.
            .sheet(item: $appState.editorRequest) { request in
                ItemEditorView(request: request)
            }
            // Siri cherche les tâches dans l'index Spotlight : on le remet à
            // jour au lancement et en quittant l'app, pour rattraper tout ce
            // qui a été modifié dans l'interface (voir PlannerSpotlight).
            .task { await PlannerSpotlight.reindexAll() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    Task { await PlannerSpotlight.reindexAll() }
                }
            }
    }

    /// Onboarding au premier lancement, puis l'app.
    @ViewBuilder
    private var content: some View {
        if userName.isEmpty {
            OnboardingScreen()
                .transition(.opacity)
        } else {
            shell
                .transition(.opacity)
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
