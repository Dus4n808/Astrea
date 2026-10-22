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
//  - Rappel (sauf vacances)
//  - Priorité « Important » (tâches uniquement)
//  - Détails
//  - Checklist (tâches uniquement)
//  - Supprimer (en modification)
//
//  Chaque bloc est sa propre vue et ne reçoit que les champs du brouillon
//  qu'il modifie : taper une lettre dans le titre ne redessine pas la
//  checklist ni la liste des cours.
//
//  Toute la logique d'enregistrement est dans ItemDraft : cette vue ne fait
//  qu'afficher et modifier le brouillon.
//

import SwiftUI
import SwiftData

struct ItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let request: EditorRequest
    @State private var draft: ItemDraft
    @State private var isConfirmingDelete = false
    @FocusState private var isTitleFocused: Bool
    /// Saisie en cours dans les détails : Entrée y fait un retour à la ligne
    /// au lieu de valider (voir le bouton Valider).
    @FocusState private var isDetailsFocused: Bool
    /// Ligne de checklist en cours de saisie : Entrée y passe à la ligne
    /// suivante au lieu de valider.
    @FocusState private var focusedChecklistLine: UUID?

    /// Entrée est prise par le champ actif (retour à la ligne, élément suivant).
    private var returnKeyIsBusy: Bool {
        isDetailsFocused || focusedChecklistLine != nil
    }

    /// En modification : l'élément tel que la base le voit en ce moment.
    /// S'il disparaît (supprimé sur un autre appareil puis reçu via iCloud,
    /// ou par Siri), la feuille se ferme au lieu d'enregistrer dans le vide.
    @Query private var originalMatches: [PlannerItem]

    init(request: EditorRequest) {
        self.request = request
        let draft = ItemDraft(request: request)
        _draft = State(initialValue: draft)
        if let id = draft.originalID {
            _originalMatches = Query(filter: #Predicate<PlannerItem> { $0.uuid == id })
        } else {
            _originalMatches = Query(filter: #Predicate<PlannerItem> { _ in false })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        ThemedSegmentedPicker(options: ItemKind.allCases, selection: $draft.kind) { $0.title }
                        EditorTitleField(title: $draft.title, isFocused: $isTitleFocused)
                        if draft.kind != .holiday { EditorCourseSection(selection: $draft.course) }
                        EditorDateSection(kind: draft.kind, date: $draft.date,
                                          endDate: $draft.endDate, isAllDay: $draft.isAllDay,
                                          reveal: { await revealDateSection(with: proxy) })
                            .id(EditorDateSection.scrollID)
                        if draft.kind != .holiday {
                            EditorReminderSection(reminder: $draft.reminder, isAllDay: draft.isAllDay,
                                                  isImportant: draft.kind == .task && draft.isImportant)
                        }
                        if draft.kind == .task { EditorImportantSection(isImportant: $draft.isImportant) }
                        EditorDetailsSection(details: $draft.details, isFocused: $isDetailsFocused)
                        if draft.kind == .task { EditorChecklistSection(lines: $draft.checklist, focusedLine: $focusedChecklistLine) }
                        if request.isEditing { deleteButton }
                    }
                    .padding(Theme.Spacing.xl)
                    // La feuille peut être large (Mac, iPad) : au-delà, les lignes
                    // deviennent trop longues à lire, on centre plutôt.
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
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
            // Ajouter ou retirer l'heure change les rappels possibles :
            // « 10 min avant » n'a pas de sens pour une journée entière.
            .onChange(of: draft.isAllDay) { _, isAllDay in
                draft.reminder = draft.reminder.adapted(isAllDay: isAllDay)
            }
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
        .onChange(of: originalMatches.isEmpty) { _, isGone in
            if isGone && request.isEditing { dismiss() }
        }
        .confirmationDialog("Supprimer « \(draft.trimmedTitle) » ?",
                            isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                draft.delete(in: context)
                dismiss()
            }
        }
    }

    /// Avant d'ouvrir le calendrier ou l'heure (iPhone) : clavier ouvert et
    /// feuille défilée vers le bas, la carte « Quand » se retrouve collée en
    /// haut de l'écran et le calendrier n'a plus la place de s'afficher.
    /// On range le clavier et on remonte la carte en haut de la zone visible,
    /// en même temps ; le sélecteur s'ouvre ensuite dessous, en entier.
    private func revealDateSection(with proxy: ScrollViewProxy) async {
        #if os(iOS)
        let keyboardWasUp = isTitleFocused || isDetailsFocused || focusedChecklistLine != nil
        let start = ContinuousClock.now
        isTitleFocused = false
        isDetailsFocused = false
        focusedChecklistLine = nil
        await withCheckedContinuation { continuation in
            withAnimation(.snappy(duration: 0.3)) {
                proxy.scrollTo(EditorDateSection.scrollID, anchor: .top)
            } completion: {
                continuation.resume()
            }
        }
        // Le popover se place d'après l'écran final : on attend que le
        // clavier ait fini de descendre.
        if keyboardWasUp {
            try? await Task.sleep(until: start + .milliseconds(320))
        }
        #endif
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
                // Échap ferme la feuille (sur Mac, rien ne le fait sinon).
                .keyboardShortcut(.cancelAction)
                #if os(macOS)
                // Sur Mac, la barre d'une feuille applique son propre verre
                // teinté (translucide, couleur système) : on impose un bouton
                // neutre plein, en retrait derrière Valider.
                // En toutes lettres et en grand : en icône seule, seul le
                // petit « × » réagissait au clic, et un clic à côté était perdu.
                .labelStyle(.titleOnly)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .foregroundStyle(Theme.Colors.ink)
                #else
                .tint(Theme.Colors.ink)
                #endif
        }
        #if os(macOS)
        .sharedBackgroundVisibility(.hidden)
        #endif
        ToolbarItem(placement: .confirmationAction) {
            Button("Valider", systemImage: "checkmark") {
                draft.save(in: context)
                // Une tâche créée à la main apprend à Siri nos habitudes.
                if !request.isEditing && draft.kind == .task {
                    PlannerDonations.taskCreated(title: draft.trimmedTitle,
                                                 date: draft.date,
                                                 course: draft.course,
                                                 isImportant: draft.isImportant)
                }
                dismiss()
            }
            .disabled(!draft.canSave)
            #if os(macOS)
            // Entrée valide, sauf dans les détails (retour à la ligne) et la
            // checklist (élément suivant) : là, ⌘Entrée prend le relais. Il
            // faut retirer le raccourci (et pas seulement le doubler) car sur
            // Mac la fenêtre traite les raccourcis avant le champ de texte.
            .keyboardShortcut(returnKeyIsBusy ? KeyboardShortcut(.return, modifiers: .command)
                                              : .defaultAction)
            #else
            .keyboardShortcut(.return, modifiers: .command)
            #endif
            #if os(macOS)
            // Bouton plein et opaque à la couleur du thème (et non le verre
            // translucide par défaut de la barre). Même gabarit qu'Annuler.
            .labelStyle(.titleOnly)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            #endif
            // Le bouton plein de la barre d'outils ignore la teinte de la
            // feuille : il faut la lui donner directement.
            .tint(Theme.Colors.accent)
        }
        #if os(macOS)
        .sharedBackgroundVisibility(.hidden)
        #endif
    }
}

// MARK: - Sections

/// Gros titre souligné, sans cadre.
private struct EditorTitleField: View {
    @Binding var title: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // `prompt` coloré : sans lui, le texte d'aide est quasi
            // invisible sur le fond clair du Mac.
            TextField("Titre", text: $title,
                      prompt: Text("Titre").foregroundStyle(Theme.Colors.inkSecondary.opacity(0.6)),
                      axis: .vertical)
                .font(Theme.Fonts.display(30))
                .tracking(-0.8)
                .foregroundStyle(Theme.Colors.ink)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .submitLabel(.done)
            // Trait épais sous le titre (détail Swiss de la maquette). Il passe
            // au rose pendant la saisie : c'est le seul repère de focus, le
            // champ n'ayant volontairement pas de cadre.
            Rectangle()
                .fill(isFocused.wrappedValue ? Theme.Colors.accent : Theme.Colors.ink)
                .frame(height: 3)
                .animation(.snappy, value: isFocused.wrappedValue)
        }
    }
}

/// Choix du cours : une chip par cours, re-cliquer désélectionne.
/// La liste des cours est lue ici : l'éditeur n'en dépend pas ailleurs.
private struct EditorCourseSection: View {
    @Query(sort: \Course.name) private var courses: [Course]
    @Binding var selection: Course?

    var body: some View {
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
                            isSelected: selection == course
                        ) {
                            // Re-cliquer sur le cours sélectionné le désélectionne.
                            selection = (selection == course) ? nil : course
                        }
                    }
                }
            }
        }
    }
}

/// Carte « Quand » : jour (ou « Du / Au » pour des vacances) et heure facultative.
private struct EditorDateSection: View {
    let kind: ItemKind
    @Binding var date: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    /// Rend la carte entièrement visible avant d'ouvrir un sélecteur.
    let reveal: () async -> Void

    /// Repère de défilement de la carte (voir `revealDateSection`).
    static let scrollID = "EditorDateSection"

    var body: some View {
        EditorCard("Quand") {
            VStack(spacing: 0) {
                let dayLabel = kind == .holiday ? "Du" : "Date"
                EditorRow(dayLabel, showsSeparator: false) {
                    EditorDateField(dayLabel, selection: $date, reveal: reveal)
                }

                if kind == .holiday {
                    EditorRow("Au") {
                        EditorDateField("Au", selection: $endDate, from: date, reveal: reveal)
                    }
                } else {
                    // Heure facultative : sans heure, l'élément est simplement
                    // prévu ce jour-là.
                    EditorRow("Heure") {
                        if isAllDay {
                            Button {
                                // Même règle que `ItemDraft.addTime`.
                                date = ItemDraft.dateWithTime(date)
                                isAllDay = false
                            } label: {
                                EditorCapsule(text: "Ajouter une heure", systemImage: "plus",
                                              color: Theme.Colors.accentDeep)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: Theme.Spacing.s) {
                                EditorTimeField(selection: $date, reveal: reveal)
                                Button("Retirer l'heure", systemImage: "xmark") {
                                    isAllDay = true
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
}

/// Rappel avant l'élément : une pastille par choix, adaptés à l'heure.
/// Une phrase sous les pastilles dit ce qui va réellement se passer
/// (heure du rappel, ou pourquoi rien ne partira).
private struct EditorReminderSection: View {
    @Binding var reminder: ReminderOption
    let isAllDay: Bool
    let isImportant: Bool

    @AppStorage(NotificationSettings.enabledKey) private var notificationsEnabled = true
    @AppStorage(NotificationSettings.dayTimeKey) private var dayTime = NotificationSettings.defaultDayTime
    @AppStorage(NotificationSettings.importantOnlyKey) private var importantOnly = false
    private var scheduler: ReminderScheduler { .shared }

    var body: some View {
        EditorCard("Rappel") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                FlowLayout(spacing: Theme.Spacing.s, lineSpacing: Theme.Spacing.s) {
                    ForEach(ReminderOption.choices(isAllDay: isAllDay)) { option in
                        ReminderChip(option: option, isSelected: reminder == option) {
                            select(option)
                        }
                    }
                }
                if let hint {
                    Label(hint.text, systemImage: hint.systemImage)
                        .font(.caption)
                        .foregroundStyle(hint.isWarning ? Theme.Colors.accentDeep : Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: reminder)
        }
        .task { await scheduler.refreshAuthorization() }
    }

    private func select(_ option: ReminderOption) {
        reminder = option
        // Premier rappel choisi : c'est le bon moment pour demander la
        // permission (la personne comprend pourquoi).
        if option != .none {
            Task { await scheduler.requestAuthorizationIfNeeded() }
        }
    }

    private struct Hint {
        let text: String
        let systemImage: String
        var isWarning = false
    }

    /// Ce qui va se passer, dans l'ordre : d'abord ce qui empêche le rappel.
    private var hint: Hint? {
        guard reminder != .none else { return nil }
        if scheduler.authorization == .denied {
            return Hint(text: "Les notifications d'Astrea sont refusées dans les réglages de l'appareil.",
                        systemImage: "bell.slash", isWarning: true)
        }
        if !notificationsEnabled {
            return Hint(text: "Les notifications sont coupées dans les Réglages d'Astrea.",
                        systemImage: "bell.slash", isWarning: true)
        }
        if importantOnly && !isImportant {
            return Hint(text: "Les rappels ne partent que pour les tâches importantes (Réglages).",
                        systemImage: "star", isWarning: true)
        }
        if isAllDay {
            let time = NotificationSettings(dayTime: dayTime).dayTimeText
            let day = reminder == .dayBefore ? "La veille" : "Le jour même"
            return Hint(text: "\(day) à \(time). L'heure se change dans les Réglages.",
                        systemImage: "bell")
        }
        return nil
    }
}

/// Pastille d'un choix de rappel : pleine, à la couleur du thème, quand elle est choisie.
private struct ReminderChip: View {
    let option: ReminderOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: option == .none ? "bell.slash.fill" : "bell.fill")
                        .font(.caption.weight(.bold))
                }
                Text(option.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.Colors.onAccent : Theme.Colors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.Colors.accent : Theme.Colors.background, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rappel : \(option.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected) { _, newValue in newValue }
    }
}

/// Option « Important » : la tâche sera mise en avant dans l'agenda.
/// Toute la ligne est cliquable ; l'étoile se remplit quand c'est coché.
private struct EditorImportantSection: View {
    @Binding var isImportant: Bool

    var body: some View {
        EditorCard("Priorité") {
            Button {
                isImportant.toggle()
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: isImportant ? "star.fill" : "star")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isImportant ? Theme.Colors.accent : Theme.Colors.inkSecondary)
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Important")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.ink)
                        Text("Mise en avant dans l'agenda")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    // Même case que la checklist, purement visuelle ici :
                    // c'est le bouton entier qui bascule l'option.
                    CheckCircle(isOn: isImportant) { isImportant.toggle() }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Important")
            .accessibilityValue(isImportant ? "Activé" : "Désactivé")
            .accessibilityAddTraits(isImportant ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: isImportant)
        }
    }
}

/// Notes libres de l'élément.
private struct EditorDetailsSection: View {
    @Binding var details: String
    var isFocused: FocusState<Bool>.Binding

    private static let placeholder = "Pages à lire, consignes…"

    var body: some View {
        EditorCard("Détails") {
            #if os(macOS)
            // Sur Mac, un TextField multiligne valide avec Entrée (le retour
            // à la ligne demande ⌥Entrée) : un vrai éditeur de texte permet
            // d'aller à la ligne avec Entrée, comme partout ailleurs.
            TextEditor(text: $details)
                .scrollContentBackground(.hidden)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.ink)
                // Même hauteur que le champ iOS : 3 lignes, jusqu'à 8.
                .frame(minHeight: 54, maxHeight: 150)
                .focused(isFocused)
                .overlay(alignment: .topLeading) {
                    if details.isEmpty {
                        Text(Self.placeholder)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            // Aligné sur la marge interne du texte de l'éditeur.
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Détails")
            #else
            TextField("Détails", text: $details,
                      prompt: Text(Self.placeholder).foregroundStyle(Theme.Colors.inkSecondary),
                      axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.ink)
                .focused(isFocused)
            #endif
        }
    }
}

/// Sous-tâches : cocher, renommer, retirer, ajouter.
/// Entrée dans une ligne passe à la suivante (et en crée une au bout),
/// pour enchaîner la saisie au clavier sans toucher la souris.
private struct EditorChecklistSection: View {
    @Binding var lines: [ItemDraft.ChecklistLine]
    var focusedLine: FocusState<UUID?>.Binding

    var body: some View {
        EditorCard("Checklist") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach($lines) { $line in
                    HStack(spacing: Theme.Spacing.s) {
                        CheckCircle(isOn: line.isDone) { line.isDone.toggle() }
                        TextField("Élément", text: $line.title)
                            .textFieldStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(line.isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                            .strikethrough(line.isDone)
                            .focused(focusedLine, equals: line.id)
                            .submitLabel(.next)
                            .onSubmit { advance(from: line.id) }
                        Button("Retirer", systemImage: "xmark") {
                            lines.removeAll { $0.id == line.id }
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }

                Button("Ajouter un élément", systemImage: "plus") {
                    appendLine()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.top, lines.isEmpty ? 0 : Theme.Spacing.s)
            }
        }
    }

    /// Entrée dans une ligne :
    /// - une ligne suit → on y passe ;
    /// - dernière ligne remplie → on en crée une nouvelle, prête à taper ;
    /// - dernière ligne vide → on s'arrête (pas de lignes vides en série).
    private func advance(from id: UUID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < lines.count {
            focusedLine.wrappedValue = lines[index + 1].id
        } else if lines[index].title.trimmingCharacters(in: .whitespaces).isEmpty {
            focusedLine.wrappedValue = nil
        } else {
            appendLine()
        }
    }

    /// Ajoute une ligne vide et y place le curseur.
    private func appendLine() {
        let line = ItemDraft.ChecklistLine(title: "")
        lines.append(line)
        focusedLine.wrappedValue = line.id
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
    let reveal: () async -> Void

    init(_ label: String, selection: Binding<Date>, from minimum: Date? = nil,
         reveal: @escaping () async -> Void) {
        self.label = label
        self._selection = selection
        self.minimum = minimum
        self.reveal = reveal
    }

    @State private var isPresented = false

    var body: some View {
        Button {
            if isPresented {
                isPresented = false
            } else {
                Task {
                    await reveal()
                    isPresented = true
                }
            }
        } label: {
            // Sans l'année : on planifie un semestre, elle n'apporte rien.
            EditorCapsule(text: selection.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.planner)),
                          systemImage: "calendar")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(selection.formatted(date: .long, time: .omitted))
        .popover(isPresented: $isPresented, arrowEdge: editorPopoverArrowEdge) {
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
    let reveal: () async -> Void
    @State private var isPresented = false

    var body: some View {
        Button {
            if isPresented {
                isPresented = false
            } else {
                Task {
                    await reveal()
                    isPresented = true
                }
            }
        } label: {
            EditorCapsule(text: selection.timeText, systemImage: "clock")
                .monospacedDigit()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Heure")
        .accessibilityValue(selection.timeText)
        .popover(isPresented: $isPresented, arrowEdge: editorPopoverArrowEdge) {
            MiniTimePicker(selection: $selection)
                .presentationBackground(Theme.Colors.surface)
                // Sur iPhone, un popover devient sinon une feuille plein écran.
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Côté d'où sortent le calendrier et l'heure.
/// - Mac : au-dessus du champ, comme avant.
/// - iOS : le système choisit le côté où il y a de la place. Imposé « au-dessus »,
///   le calendrier était coupé dès que le champ se trouvait en haut de l'écran
///   (le bord de la flèche est respecté sur iOS depuis 18.1).
private var editorPopoverArrowEdge: Edge? {
    #if os(macOS)
    .bottom
    #else
    nil
    #endif
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
