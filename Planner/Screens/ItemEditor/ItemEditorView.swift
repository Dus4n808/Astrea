//
//  ItemEditorView.swift
//  Feuille « Nouvelle tâche » / « Modifier » (même vue pour les deux).
//
//  Mise en page : fond rose pâle + cartes blanches, exactement comme le reste
//  de l'app. Chaque bloc = un label en petites capitales posé au-dessus d'une
//  carte (`plannerCard`). Aucun contrôle système brut : le choix du type et le
//  bouton Supprimer sont habillés aux couleurs du thème.
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
                    KindSelector(selection: $draft.kind)
                    titleField
                    if draft.kind != .holiday { courseSection }
                    dateSection
                    detailsSection
                    if draft.kind == .task { checklistSection }
                    if request.isEditing { deleteButton }
                }
                .padding(Theme.Spacing.xl)
                // La feuille peut être large (Mac, iPad) : au-delà, les lignes
                // deviennent trop longues à lire, on centre plutôt.
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.Colors.background)
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle(request.isEditing ? "Modifier" : draft.kind.newItemTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .animation(.snappy, value: draft.kind)
            .animation(.snappy, value: draft.isAllDay)
        }
        // Toute la feuille (curseur, contrôles) prend la couleur du thème.
        .tint(Theme.Colors.accent)
        // Sinon la feuille garde le fond système derrière la barre de titre.
        .presentationBackground(Theme.Colors.background)
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

    private var titleField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TextField("Titre", text: $draft.title, axis: .vertical)
                .font(Theme.Fonts.display(30))
                .tracking(-0.8)
                .foregroundStyle(Theme.Colors.ink)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .submitLabel(.done)
            // Trait épais sous le titre (détail Swiss de la maquette). Il passe
            // au rose pendant la saisie : c'est le seul repère de focus, le
            // champ n'ayant volontairement pas de cadre.
            Rectangle()
                .fill(isTitleFocused ? Theme.Colors.accent : Theme.Colors.ink)
                .frame(height: 3)
                .animation(.snappy, value: isTitleFocused)
        }
    }

    private var courseSection: some View {
        EditorCard("Cours") {
            if courses.isEmpty {
                Text("Aucun cours. Ajoute-les dans la section Cours.")
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
        EditorCard("Quand") {
            VStack(spacing: 0) {
                let dayLabel = draft.kind == .holiday ? "Du" : "Date"
                EditorRow(dayLabel, showsSeparator: false) {
                    DatePicker(dayLabel, selection: $draft.date, displayedComponents: .date)
                }

                if draft.kind == .holiday {
                    EditorRow("Au") {
                        DatePicker("Au", selection: $draft.endDate,
                                   in: draft.date..., displayedComponents: .date)
                    }
                } else {
                    let allDayLabel = draft.kind == .task ? "Fin de journée" : "Toute la journée"
                    EditorRow(allDayLabel) {
                        Toggle(allDayLabel, isOn: $draft.isAllDay)
                            .toggleStyle(.switch)
                    }
                    if !draft.isAllDay {
                        EditorRow("Heure") {
                            DatePicker("Heure", selection: $draft.date,
                                       displayedComponents: .hourAndMinute)
                        }
                    }
                }
            }
            // Les contrôles système (bascule, sélecteur de date) prennent la
            // couleur de l'app plutôt que le bleu par défaut.
            .tint(Theme.Colors.accent)
        }
    }

    private var detailsSection: some View {
        EditorCard("Détails") {
            TextField("Pages à lire, consignes…", text: $draft.details, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.ink)
        }
    }

    private var checklistSection: some View {
        EditorCard("Checklist") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach($draft.checklist) { $line in
                    HStack(spacing: Theme.Spacing.s) {
                        CheckCircle(isOn: line.isDone) { line.isDone.toggle() }
                        TextField("Élément", text: $line.title)
                            .textFieldStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(line.isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                            .strikethrough(line.isDone)
                        Button("Retirer", systemImage: "xmark") {
                            draft.checklist.removeAll { $0.id == line.id }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }

                Button("Ajouter un élément", systemImage: "plus") {
                    draft.checklist.append(.init(title: ""))
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.top, draft.checklist.isEmpty ? 0 : Theme.Spacing.s)
            }
        }
    }

    private var deleteButton: some View {
        Button {
            isConfirmingDelete = true
        } label: {
            Label("Supprimer", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .plannerCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Annuler", systemImage: "xmark") { dismiss() }
                .tint(Theme.Colors.ink)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Valider", systemImage: "checkmark") {
                draft.save(in: context)
                // Une tâche créée à la main apprend à Siri nos habitudes.
                if !request.isEditing && draft.kind == .task {
                    PlannerDonations.taskCreated(title: draft.trimmedTitle,
                                                 date: draft.date,
                                                 course: draft.course)
                }
                dismiss()
            }
            .disabled(!draft.canSave)
            .keyboardShortcut(.return, modifiers: .command)
            // Le bouton plein de la barre d'outils ignore la teinte de la
            // feuille : il faut la lui donner directement.
            .tint(Theme.Colors.accent)
        }
    }
}

// MARK: - Briques de la feuille

/// Choix du type, à la place du `Picker` segmenté du système : celui-ci est
/// gris et ignore complètement le thème de l'app.
private struct KindSelector: View {
    @Binding var selection: ItemKind

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(ItemKind.allCases) { kind in
                let isSelected = kind == selection
                Button {
                    selection = kind
                } label: {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? .white : Theme.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Theme.Colors.accent : Theme.Colors.surface,
                                    in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.snappy, value: selection)
    }
}

/// Label en petites capitales + contenu dans une carte blanche.
/// C'est le bloc de base de la feuille ; il reprend la carte des lignes
/// d'agenda pour que l'éditeur ait le même grain que les listes.
/// Aussi utilisé par la feuille des cours (CourseEditorView).
struct EditorCard<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label)
                .plannerLabelStyle()
                .padding(.leading, Theme.Spacing.xs)
            content
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .plannerCard()
        }
    }
}

/// Une ligne de réglage dans une carte : label à gauche, contrôle à droite,
/// séparée de la précédente par un filet rose clair.
///
/// Le label est dessiné ici et masqué sur le contrôle (`labelsHidden`), sinon
/// macOS centre le couple label + contrôle et iOS l'étale : les deux ne
/// s'alignaient pas pareil. Le contrôle garde quand même son vrai label pour
/// VoiceOver, et le texte visible devient décoratif.
private struct EditorRow<Content: View>: View {
    let label: String
    let showsSeparator: Bool
    let content: Content

    init(_ label: String, showsSeparator: Bool = true, @ViewBuilder content: () -> Content) {
        self.label = label
        self.showsSeparator = showsSeparator
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSeparator {
                Rectangle()
                    .fill(Theme.Colors.gridLine)
                    .frame(height: 1)
                    .padding(.vertical, Theme.Spacing.s)
            }
            HStack(spacing: Theme.Spacing.m) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                content.labelsHidden()
            }
        }
    }
}

#Preview("Création") {
    ItemEditorView(request: EditorRequest(mode: .create(kind: .task, date: .now)))
        .modelContainer(PlannerStore.preview)
}

// Variante utile : pas de cours, et deux dates au lieu d'une.
#Preview("Vacances") {
    ItemEditorView(request: EditorRequest(mode: .create(kind: .holiday, date: .now)))
        .modelContainer(PlannerStore.preview)
}
