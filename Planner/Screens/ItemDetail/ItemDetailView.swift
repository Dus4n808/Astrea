//
//  ItemDetailView.swift
//  Fiche de consultation d'un élément existant (tap sur une tâche).
//
//  On ne modifie pas directement : on consulte d'abord. Seuls les gestes
//  « du quotidien » sont possibles ici (cocher la tâche, cocher une ligne de
//  checklist). Pour tout le reste, le bouton « Modifier » ouvre l'éditeur
//  habituel (ItemEditorView) par-dessus la fiche.
//
//  Structure :
//  - Barre du haut : Fermer / Modifier
//  - En-tête : type, titre, trait de la couleur du cours
//  - Statut (tâches uniquement)
//  - Quand / Cours
//  - Détails
//  - Checklist (tâches uniquement)
//
//  Ce n'est pas une feuille (`sheet`) mais une carte posée sur un voile
//  sombre (voir `ItemDetailOverlay`) : une feuille système ne se ferme pas
//  quand on touche à côté, alors qu'ici un tap hors de la carte suffit.
//

import SwiftUI
import SwiftData

/// Voile + carte de la fiche, à poser en `overlay` sur toute l'app.
/// Toucher le voile (hors de la carte) ou appuyer sur Échap ferme la fiche.
struct ItemDetailOverlay: View {
    let item: PlannerItem
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Fermer la fiche")
                .accessibilityAddTraits(.isButton)
                .transition(.opacity)

            ItemDetailView(item: item, onClose: onClose)
                .padding(Theme.Spacing.l)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }
}

struct ItemDetailView: View {
    @Bindable var item: PlannerItem
    let onClose: () -> Void

    /// Éditeur ouvert par-dessus la fiche.
    @State private var editorRequest: EditorRequest?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // La carte épouse son contenu ; elle ne défile que si celui-ci
            // dépasse la hauteur de l'écran.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
        }
        // Même largeur de lecture que l'éditeur.
        .frame(maxWidth: 560)
        .background(Theme.Colors.background, in: .rect(cornerRadius: Theme.Radius.card + 8))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        .tint(Theme.Colors.accent)
        .sheet(item: $editorRequest, onDismiss: closeIfDeleted) { request in
            ItemEditorView(request: request)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header
            if item.kind.isCheckable { statusButton }
            whenSection
            if let course = item.course { courseSection(course) }
            if !item.details.isEmpty { detailsSection }
            if item.kind == .task && !item.sortedChecklist.isEmpty { checklistSection }
        }
        .padding([.horizontal, .bottom], Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(item.kind.title, systemImage: item.kind.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(item.displayColor)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 6)
                .background(item.displayColor.opacity(0.14), in: .capsule)

            Text(item.title)
                .font(Theme.Fonts.display(30))
                .tracking(-0.8)
                .foregroundStyle(item.isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                .strikethrough(item.isDone)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            // Trait épais, comme sous le titre de l'éditeur, mais de la
            // couleur de l'élément : c'est son « identité » visuelle.
            Rectangle()
                .fill(item.displayColor)
                .frame(height: 3)
        }
    }

    /// Gros bouton « Marquer comme terminée » / « Terminée ».
    private var statusButton: some View {
        Button {
            withAnimation(.snappy) { item.isDone.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                Text(item.isDone ? "Terminée" : "Marquer comme terminée")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(item.isDone ? Theme.Colors.onAccent : Theme.Colors.ink)
            .padding(Theme.Spacing.l)
            .background(item.isDone ? Theme.Colors.accent : Theme.Colors.surface,
                        in: .rect(cornerRadius: Theme.Radius.card))
            .shadow(color: Theme.Colors.accentDeep.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: item.isDone) { _, newValue in newValue }
    }

    private var whenSection: some View {
        EditorCard("Quand") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if item.kind == .holiday, let endDate = item.endDate {
                    DetailRow(systemImage: "calendar", label: "Du", value: Self.longDay(item.date))
                    DetailRow(systemImage: "calendar", label: "Au", value: Self.longDay(endDate))
                } else {
                    DetailRow(systemImage: "calendar", label: item.date.relativeDayTitle,
                              value: Self.longDay(item.date))
                    DetailRow(systemImage: "clock", label: "Heure",
                              value: item.isAllDay ? "Toute la journée" : item.date.timeText)
                }
            }
        }
    }

    private func courseSection(_ course: Course) -> some View {
        EditorCard("Cours") {
            CourseChip(name: course.name, color: course.color.color)
        }
    }

    private var detailsSection: some View {
        EditorCard("Détails") {
            Text(item.details)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var checklistSection: some View {
        let lines = item.sortedChecklist
        let doneCount = lines.filter(\.isDone).count
        return EditorCard("Checklist · \(doneCount)/\(lines.count)") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    HStack(spacing: Theme.Spacing.s) {
                        CheckCircle(isOn: line.isDone) {
                            withAnimation(.snappy) { line.isDone.toggle() }
                        }
                        Text(line.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(line.isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                            .strikethrough(line.isDone)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Barre d'outils

    private var topBar: some View {
        HStack {
            Button("Fermer", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.Colors.ink)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.surface, in: .circle)
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                editorRequest = EditorRequest(mode: .edit(item))
            } label: {
                Label("Modifier", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding([.horizontal, .top], Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Aides

    /// L'éditeur a pu supprimer l'élément : la fiche n'a alors plus de sens.
    private func closeIfDeleted() {
        if item.isDeleted || item.modelContext == nil { onClose() }
    }

    /// « lundi 19 octobre » (sans l'année, comme dans l'éditeur).
    private static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.planner))
    }
}

/// Ligne d'information : icône dans un carré teinté, label, valeur.
private struct DetailRow: View {
    let systemImage: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.accentDeep)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.tint, in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .plannerLabelStyle()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = PlannerStore.preview
    let item = (try? container.mainContext.fetch(FetchDescriptor<PlannerItem>()))?.first
        ?? PlannerItem(title: "lectures", date: .now, details: "Chapitres 3 et 4.")
    return ItemDetailOverlay(item: item) {}
        .modelContainer(container)
}
