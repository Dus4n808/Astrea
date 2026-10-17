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

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du cours", text: $name)

                Section("Couleur") {
                    ColorPalettePicker(selection: $color)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Nouveau cours" : "Modifier le cours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider", systemImage: "checkmark", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
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

/// Rangée de pastilles rondes pour choisir une couleur de la palette.
private struct ColorPalettePicker: View {
    @Binding var selection: CourseColor

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(CourseColor.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.displayName)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
