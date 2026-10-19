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
            // Sans minimum, la colonne de détail peut être réduite à presque
            // rien en tirant le séparateur sur Mac.
            .navigationSplitViewColumnWidth(min: 360, ideal: 900)
        }
    }

    // MARK: - Sidebar

    /// Pas de `List(selection:)` : sa surbrillance suit la couleur d'accent du
    /// système (bleu par défaut sur Mac) et ignore `.tint`. Les lignes sont
    /// donc dessinées ici, aux couleurs du thème.
    private var sidebar: some View {
        List {
            BrandHeader()
                .listRowSeparator(.hidden)
                .padding(.bottom, Theme.Spacing.m)

            ForEach(AppSection.main) { section in
                sidebarRow(section)
            }

            Section {
                ForEach(courses) { course in
                    CourseChip(name: course.name, color: course.color.color)
                        .lineLimit(1)
                }
            } header: {
                Text("Mes cours")
                    .plannerLabelStyle()
            }
        }
        // Réglages reste toujours visible en bas, même si la liste défile.
        .safeAreaInset(edge: .bottom) {
            SidebarRow(section: .settings, isSelected: appState.section == .settings) {
                appState.section = .settings
            }
            .padding(Theme.Spacing.s)
        }
    }

    private func sidebarRow(_ section: AppSection) -> some View {
        SidebarRow(section: section, isSelected: appState.section == section) {
            appState.section = section
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 1, leading: Theme.Spacing.s, bottom: 1, trailing: Theme.Spacing.s))
    }
}

/// Une ligne de navigation : icône + titre, fond teinté quand elle est active.
private struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Pas de `Label` : dans une sidebar macOS, son icône est recolorée
            // avec l'accent du système (bleu), quel que soit le style donné.
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: section.systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 20)
                Text(section.title)
                    .foregroundStyle(isSelected ? Theme.Colors.accentDeep : Theme.Colors.ink)
            }
                .font(.body.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Theme.Colors.tint : .clear,
                            in: .rect(cornerRadius: Theme.Radius.pill + 2))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.snappy, value: isSelected)
    }
}

/// Logo + nom de l'app, en haut de la sidebar.
private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            StarLogo()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                // « astrea » en encre + point rose, comme dans la maquette.
                Text("astrea\(Text(".").foregroundStyle(Theme.Colors.accent))")
                    .foregroundStyle(Theme.Colors.ink)
                    .font(Theme.Fonts.display(28))
                    .tracking(-1)
                Text("Semestre d'automne")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            // La sidebar descend à 220 pt : sans ça, le sous-titre est coupé.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}
