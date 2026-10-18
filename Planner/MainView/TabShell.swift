//
//  TabShell.swift
//  Navigation iPhone : une tab bar (Liquid Glass sur iOS 26+).
//
//  Chaque onglet a sa propre NavigationStack, pour que la navigation
//  dans un onglet ne soit pas perdue quand on change d'onglet.
//
//  À droite, détaché des onglets, un bouton « + » ouvre l'éditeur. C'est un
//  Tab avec le rôle `prominent` : le système l'isole en bout de barre et gère
//  son placement (un bouton posé par-dessus viendrait chevaucher la pastille,
//  que le système centre).
//
//  Pourquoi la sélection `.add` est réellement stockée, et pas annulée
//  aussitôt : si le getter renvoyait toujours la section courante, la tab bar
//  jouait une transition vers « + » PUIS une transition retour, ce qui
//  retardait visiblement l'ouverture de la feuille. Ici le tap ouvre
//  l'éditeur immédiatement, l'onglet vide reste caché derrière, et on revient
//  à la section précédente à la fermeture.
//

import SwiftUI

struct TabShell: View {
    @Environment(AppState.self) private var appState
    @State private var selection: TabItem = .section(.calendar)

    var body: some View {
        TabView(selection: tabSelection) {
            ForEach(AppSection.phoneTabs) { section in
                Tab(section.title, systemImage: section.systemImage, value: TabItem.section(section)) {
                    NavigationStack {
                        SectionScreen(section: section)
                    }
                }
            }

            Tab("Ajouter une tâche", systemImage: "plus", value: TabItem.add, role: .prominent) {
                // Masqué par la feuille d'édition ; la couleur évite un flash
                // blanc si jamais il apparaît une fraction de seconde.
                Theme.Colors.background.ignoresSafeArea()
            }
        }
        .onAppear { selection = .section(appState.section) }
        // Une navigation venue d'ailleurs (Siri, Mac Catalyst…) doit bouger l'onglet.
        .onChange(of: appState.section) { _, section in
            if selection != .add { selection = .section(section) }
        }
        // Feuille refermée : on quitte l'onglet « + ».
        .onChange(of: appState.editorRequest == nil) { _, isClosed in
            if isClosed && selection == .add { selection = .section(appState.section) }
        }
    }

    /// Les deux natures d'élément de la tab bar : une section, ou l'action « + ».
    private enum TabItem: Hashable {
        case section(AppSection)
        case add
    }

    /// On passe par un Binding explicite pour déclencher l'ouverture de
    /// l'éditeur dans le même cycle que le tap, sans attendre un `onChange`.
    private var tabSelection: Binding<TabItem> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                switch newValue {
                case .section(let section): appState.section = section
                case .add:                  appState.openEditor(kind: .task, on: appState.focusedDate)
                }
            }
        )
    }
}
