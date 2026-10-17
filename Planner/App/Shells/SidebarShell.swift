//
//  SidebarShell.swift
//  Navigation Mac et iPad : sidebar à gauche + contenu à droite.
//
//  La sidebar contient :
//  1. le logo,
//  2. les sections principales,
//  3. la liste « Mes cours » (lecture seule pour l'instant),
//  4. Réglages, collé en bas.
//

import SwiftUI
import SwiftData

struct SidebarShell: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Course.name) private var courses: [Course]

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            NavigationStack {
                SectionScreen(section: appState.section)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: selection) {
            BrandHeader()
                .listRowSeparator(.hidden)
                .padding(.bottom, Theme.Spacing.m)

            ForEach(AppSection.main) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }

            Section("Mes cours") {
                ForEach(courses) { course in
                    CourseChip(name: course.name, color: course.color.color)
                }
            }
        }
        // Réglages reste toujours visible en bas, même si la liste défile.
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.section = .settings
            } label: {
                Label(AppSection.settings.title, systemImage: AppSection.settings.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    /// `List(selection:)` attend un optionnel ; on convertit vers AppState.
    private var selection: Binding<AppSection?> {
        Binding(
            get: { appState.section },
            set: { newValue in
                if let newValue { appState.section = newValue }
            }
        )
    }
}

/// Logo + nom de l'app, en haut de la sidebar.
private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            StarLogo()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                // « planner » en encre + point rose, comme dans la maquette.
                Text("planner\(Text(".").foregroundStyle(Theme.Colors.pink))")
                    .foregroundStyle(Theme.Colors.ink)
                    .font(Theme.Fonts.display(28))
                    .tracking(-1)
                Text("Semestre d'automne")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
    }
}
