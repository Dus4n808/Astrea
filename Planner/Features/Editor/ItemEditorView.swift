//
//  ItemEditorView.swift
//  Feuille « Nouvelle tâche » / « Modifier » (même vue pour les deux).
//
//  Structure :
//  - Type (Tâche / Événement / Vacances)
//  - Titre
//  - Cours (sauf vacances)
//  - Date, heure, date de fin (vacances)
//  - Détails
//  - Checklist (tâches uniquement)
//  - Supprimer (en modification)
//
//  Toute la logique d'enregistrement est dans ItemDraft : cette vue ne fait
//  qu'afficher et modifier le brouillon.
//

import SwiftUI
import SwiftData

struct ItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Course.name) private var courses: [Course]

    let request: EditorRequest
    @State private var draft: ItemDraft
    @State private var isConfirmingDelete = false
    @FocusState private var isTitleFocused: Bool

    init(request: EditorRequest) {
        self.request = request
        _draft = State(initialValue: ItemDraft(request: request))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    kindPicker
                    titleField
                    if draft.kind != .holiday { courseSection }
                    dateSection
                    detailsSection
                    if draft.kind == .task { checklistSection }
                    if request.isEditing { deleteButton }
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.surface)
            .navigationTitle(request.isEditing ? "Modifier" : draft.kind.newItemTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .animation(.snappy, value: draft.kind)
            .animation(.snappy, value: draft.isAllDay)
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
        #endif
        .onAppear {
            // Création : le clavier s'ouvre directement sur le titre.
            if !request.isEditing { isTitleFocused = true }
        }
        .confirmationDialog("Supprimer « \(draft.trimmedTitle) » ?",
                            isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                draft.delete(in: context)
                dismiss()
            }
        }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker("Type", selection: $draft.kind) {
            ForEach(ItemKind.allCases) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TextField("Titre", text: $draft.title, axis: .vertical)
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .submitLabel(.done)
            // Trait épais sous le titre (style Swiss de la maquette).
            Rectangle()
                .fill(Theme.Colors.ink)
                .frame(height: 2)
        }
    }

    private var courseSection: some View {
        EditorField("Cours") {
            if courses.isEmpty {
                Text("Aucun cours. Ajoute-les dans l'onglet Cours.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            } else {
                FlowLayout(spacing: Theme.Spacing.s, lineSpacing: Theme.Spacing.s) {
                    ForEach(courses) { course in
                        SelectableCourseChip(
                            name: course.name,
                            color: course.color.color,
                            isSelected: draft.course == course
                        ) {
                            // Re-cliquer sur le cours sélectionné le désélectionne.
                            draft.course = (draft.course == course) ? nil : course
                        }
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        EditorField("Quand") {
            VStack(spacing: Theme.Spacing.m) {
                DatePicker(draft.kind == .holiday ? "Du" : "Date",
                           selection: $draft.date, displayedComponents: .date)

                if draft.kind == .holiday {
                    DatePicker("Au", selection: $draft.endDate, in: draft.date..., displayedComponents: .date)
                } else {
                    Toggle(draft.kind == .task ? "Fin de journée" : "Toute la journée",
                           isOn: $draft.isAllDay)
                    if !draft.isAllDay {
                        DatePicker("Heure", selection: $draft.date, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .tint(Theme.Colors.pink)
        }
    }

    private var detailsSection: some View {
        EditorField("Détails") {
            TextField("Pages à lire, consignes…", text: $draft.details, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
        }
    }

    private var checklistSection: some View {
        EditorField("Checklist") {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach($draft.checklist) { $line in
                    HStack {
                        CheckCircle(isOn: line.isDone) { line.isDone.toggle() }
                        TextField("Élément", text: $line.title)
                            .textFieldStyle(.plain)
                            .strikethrough(line.isDone)
                        Button("Retirer", systemImage: "xmark") {
                            draft.checklist.removeAll { $0.id == line.id }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
                Button("Ajouter un élément", systemImage: "plus") {
                    draft.checklist.append(.init(title: ""))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.pink)
                .fontWeight(.semibold)
            }
        }
    }

    private var deleteButton: some View {
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Annuler", systemImage: "xmark") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Valider", systemImage: "checkmark") {
                draft.save(in: context)
                dismiss()
            }
            .disabled(!draft.canSave)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

// MARK: - Champ avec label

/// Label en petites capitales + contenu dans un bloc rose pâle.
private struct EditorField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label).plannerLabelStyle()
            content
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.background, in: .rect(cornerRadius: 12))
        }
    }
}

#Preview {
    ItemEditorView(request: EditorRequest(mode: .create(kind: .task, date: .now)))
        .modelContainer(PlannerStore.preview)
}
