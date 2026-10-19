//
//  ItemRow.swift
//  Carte d'une tâche dans une liste (Agenda, liste du jour sur iPhone).
//
//  [ barre couleur ]  Titre                    ( ○ )
//                     Sous-titre
//                     Détails (s'il y en a, 2 lignes max)
//

import SwiftUI

struct ItemRow: View {
    let title: String
    let subtitle: String
    let color: Color
    let isDone: Bool
    /// Notes de l'élément ; rien n'est affiché si c'est vide.
    var details: String = ""
    /// nil = pas de case à cocher (événements, vacances).
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // La barre suit la hauteur de la carte (détails compris).
            Capsule()
                .fill(color)
                .frame(width: 4)
                .frame(minHeight: 34, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                    .strikethrough(isDone)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.inkSecondary)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.ink.opacity(0.75))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onToggle {
                CheckCircle(isOn: isDone, action: onToggle)
            }
        }
        .padding(.leading, Theme.Spacing.m)
        .padding(.trailing, 14)
        .padding(.vertical, Theme.Spacing.m)
        .plannerCard()
    }
}

extension View {
    /// Balayer vers la gauche pour supprimer (balayage complet = suppression
    /// directe). Le conteneur défilant doit porter `swipeActionsContainer()`,
    /// sinon le geste n'a aucun effet hors d'une `List`.
    func deleteOnSwipe(perform delete: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Supprimer", systemImage: "trash", role: .destructive, action: delete)
                .tint(Theme.Colors.danger)
        }
    }
}

/// Case à cocher ronde, rose quand elle est cochée.
struct CheckCircle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.Colors.gridLine, lineWidth: 2)
                    .opacity(isOn ? 0 : 1)
                Circle()
                    .fill(Theme.Colors.accent)
                    .opacity(isOn ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.Colors.onAccent)
                    .opacity(isOn ? 1 : 0)
            }
            .frame(width: 24, height: 24)
            // Zone de tap confortable (44 pt recommandés par Apple).
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: isOn) { _, newValue in newValue }
        .accessibilityLabel(isOn ? "Terminée" : "À faire")
    }
}

#Preview {
    VStack {
        ItemRow(title: "lectures", subtitle: "méthodes qualitatives A",
                color: CourseColor.blue.color, isDone: false,
                details: "Chapitres 3 et 4, prendre des notes sur la méthode.", onToggle: {})
        ItemRow(title: "texte", subtitle: "sociétés multiculturelles · 14:30",
                color: CourseColor.violet.color, isDone: true, onToggle: {})
    }
    .padding()
    .background(Theme.Colors.background)
}
