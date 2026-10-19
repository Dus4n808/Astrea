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
                    ThemedSegmentedPicker(options: ItemKind.allCases, selection: $draft.kind) { $0.title }
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
            // `prompt` coloré : sans lui, le texte d'aide est quasi
            // invisible sur le fond clair du Mac.
            TextField("Titre", text: $draft.title,
                      prompt: Text("Titre").foregroundStyle(Theme.Colors.inkSecondary.opacity(0.6)),
                      axis: .vertical)
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
                    EditorDateField(dayLabel, selection: $draft.date)
                }

                if draft.kind == .holiday {
                    EditorRow("Au") {
                        EditorDateField("Au", selection: $draft.endDate, from: draft.date)
                    }
                } else {
                    // Heure facultative : sans heure, l'élément est simplement
                    // prévu ce jour-là.
                    EditorRow("Heure") {
                        if draft.isAllDay {
                            Button {
                                draft.addTime()
                            } label: {
                                EditorCapsule(text: "Ajouter une heure", systemImage: "plus",
                                              color: Theme.Colors.accentDeep)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: Theme.Spacing.s) {
                                EditorTimeField(selection: $draft.date)
                                Button("Retirer l'heure", systemImage: "xmark") {
                                    draft.removeTime()
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.Colors.inkSecondary)
                            }
                        }
                    }
                }
            }
            // Les contrôles système (sélecteur de date iOS) prennent la
            // couleur de l'app plutôt que le bleu par défaut.
            .tint(Theme.Colors.accent)
        }
    }

    private var detailsSection: some View {
        EditorCard("Détails") {
            TextField("Détails", text: $draft.details,
                      prompt: Text("Pages à lire, consignes…").foregroundStyle(Theme.Colors.inkSecondary),
                      axis: .vertical)
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
                .foregroundStyle(Theme.Colors.danger)
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

/// Choix d'un jour : capsule « 📅 lundi 19 octobre » qui ouvre le
/// MiniMonthPicker (aux couleurs du thème) dans un popover, sur Mac comme
/// sur iPhone.
private struct EditorDateField: View {
    let label: String
    @Binding var selection: Date
    let minimum: Date?

    init(_ label: String, selection: Binding<Date>, from minimum: Date? = nil) {
        self.label = label
        self._selection = selection
        self.minimum = minimum
    }

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            // Sans l'année : on planifie un semestre, elle n'apporte rien.
            EditorCapsule(text: selection.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.planner)),
                          systemImage: "calendar")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(selection.formatted(date: .long, time: .omitted))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            // Calendrier maison sur toutes les plateformes : le DatePicker du
            // système garde sa propre couleur (bleu sur Mac, accent système
            // sur iOS). Choisir un jour referme le popover, comme un menu.
            MiniMonthPicker(selection: $selection, minimum: minimum) {
                isPresented = false
            }
            .presentationBackground(Theme.Colors.surface)
            // Sur iPhone, un popover devient sinon une feuille plein écran.
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Choix d'une heure : capsule « 🕑 14:30 » qui ouvre le MiniTimePicker.
/// Même rendu sur Mac et iPhone (popover, y compris sur écran compact).
private struct EditorTimeField: View {
    @Binding var selection: Date
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            EditorCapsule(text: selection.timeText, systemImage: "clock")
                .monospacedDigit()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Heure")
        .accessibilityValue(selection.timeText)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            MiniTimePicker(selection: $selection)
                .presentationBackground(Theme.Colors.surface)
                // Sur iPhone, un popover devient sinon une feuille plein écran.
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Capsule teintée des champs de la carte « Quand » (date, heure, ajout).
private struct EditorCapsule: View {
    let text: String
    let systemImage: String
    var color: Color? = nil

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color ?? Theme.Colors.ink)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 6)
            .background(Theme.Colors.tint, in: .capsule)
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
