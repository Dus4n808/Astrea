//
//  CourseEditorView.swift
//  Petite feuille pour créer ou modifier un cours (nom + couleur).
//

import SwiftUI
import SwiftData

/// Ce qu'on édite : un nouveau cours ou un cours existant.
enum CourseEditorTarget: Identifiable {
    case new
    case existing(Course)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let course): "\(course.persistentModelID)"
        }
    }
}

struct CourseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]

    let target: CourseEditorTarget
    @State private var name: String
    @State private var color: CourseColor

    init(target: CourseEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _name = State(initialValue: "")
            _color = State(initialValue: .blue)
        case .existing(let course):
            _name = State(initialValue: course.name)
            _color = State(initialValue: course.color)
        }
    }

    @FocusState private var isNameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Couleurs déjà portées par les autres cours (pas celui qu'on modifie).
    private var otherCoursesColors: [CourseColor] {
        courses.filter { course in
            if case .existing(let edited) = target { return course != edited }
            return true
        }
        .map(\.color)
    }

    var body: some View {
        NavigationStack {
            // Même grain que la feuille des tâches (ItemEditorView) : fond rose
            // pâle, gros titre souligné, puis des cartes blanches labellisées.
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    nameField
                    EditorCard("Couleur") {
                        ColorPalettePicker(selection: $color,
                                           usedColors: Set(otherCoursesColors))
                    }
                    EditorCard("Aperçu") {
                        CourseChip(name: trimmedName.isEmpty ? "Nom du cours" : trimmedName,
                                   color: color.color)
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.Colors.background)
            .navigationTitle(isNew ? "Nouveau cours" : "Modifier le cours")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark") { dismiss() }
                        .tint(Theme.Colors.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider", systemImage: "checkmark", action: save)
                        .disabled(trimmedName.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                        // Le bouton plein de la barre d'outils ignore la teinte
                        // de la feuille : il faut la lui donner directement.
                        .tint(Theme.Colors.accent)
                }
            }
        }
        // Une feuille n'hérite pas toujours du `.tint` de RootView.
        .tint(Theme.Colors.accent)
        .presentationBackground(Theme.Colors.background)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 360)
        #endif
        .onAppear {
            guard isNew else { return }
            isNameFocused = true
            // Nouveau cours : on propose d'office une couleur encore libre,
            // pour que 15-20 cours restent distincts sans effort.
            color = CourseColor.suggested(avoiding: otherCoursesColors)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TextField("Nom du cours", text: $name)
                .font(Theme.Fonts.display(30))
                .tracking(-0.8)
                .foregroundStyle(Theme.Colors.ink)
                .textFieldStyle(.plain)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { if !trimmedName.isEmpty { save() } }
            // Trait épais sous le titre, rose pendant la saisie (comme l'éditeur de tâches).
            Rectangle()
                .fill(isNameFocused ? Theme.Colors.accent : Theme.Colors.ink)
                .frame(height: 3)
                .animation(.snappy, value: isNameFocused)
        }
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func save() {
        switch target {
        case .new:
            context.insert(Course(name: trimmedName, color: color))
        case .existing(let course):
            course.name = trimmedName
            course.color = color
        }
        dismiss()
    }
}

/// Grille de pastilles rondes pour choisir une couleur de la palette.
///
/// 5 colonnes fixes : avec 20 couleurs, ça donne 4 lignes pleines, une
/// famille de teintes par ligne (voir l'ordre dans CourseColor). Une grille
/// régulière reste lisible là où une rangée qui passe à la ligne au hasard
/// mélangerait les familles.
private struct ColorPalettePicker: View {
    @Binding var selection: CourseColor
    /// Couleurs déjà prises par un autre cours : marquées d'un petit point,
    /// mais toujours sélectionnables (deux cours peuvent partager une couleur).
    let usedColors: Set<CourseColor>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                ForEach(CourseColor.allCases) { option in
                    swatch(option)
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                Text(selection.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Spacer(minLength: 0)
                if !usedColors.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(Theme.Colors.inkSecondary)
                            .frame(width: 4, height: 4)
                        Text("déjà utilisée")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
        .animation(.snappy, value: selection)
    }

    private func swatch(_ option: CourseColor) -> some View {
        let isSelected = option == selection
        let isUsed = usedColors.contains(option)
        return Button {
            selection = option
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(option.color)
                    .frame(width: 34, height: 34)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Theme.Colors.onCourse)
                        }
                    }
                    // Anneau de la couleur autour de la pastille choisie.
                    .padding(3)
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? option.color : .clear, lineWidth: 2)
                    }
                // Le point garde sa place même invisible : la grille ne saute pas.
                Circle()
                    .fill(Theme.Colors.inkSecondary)
                    .frame(width: 4, height: 4)
                    .opacity(isUsed && !isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityValue(isUsed ? "Déjà utilisée" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Nouveau cours") {
    CourseEditorView(target: .new)
        .modelContainer(PlannerStore.preview)
}
