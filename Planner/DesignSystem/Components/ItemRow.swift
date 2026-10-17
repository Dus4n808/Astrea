//
//  ItemRow.swift
//  Carte d'une tâche dans une liste (Agenda, liste du jour sur iPhone).
//
//  [ barre couleur ]  Titre                    ( ○ )
//                     Sous-titre
//

import SwiftUI

struct ItemRow: View {
    let title: String
    let subtitle: String
    let color: Color
    let isDone: Bool
    /// nil = pas de case à cocher (événements, vacances).
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDone ? Theme.Colors.inkSecondary : Theme.Colors.ink)
                    .strikethrough(isDone)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onToggle {
                CheckCircle(isOn: isDone, action: onToggle)
            }
        }
        .padding(.leading, Theme.Spacing.m)
        .padding(.trailing, 14)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.Colors.pinkDeep.opacity(0.06), radius: 6, y: 2)
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
                    .fill(Theme.Colors.pink)
                    .opacity(isOn ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
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
        ItemRow(title: "lectures", subtitle: "méthodes qualitatives A · Fin de journée",
                color: CourseColor.blue.color, isDone: false, onToggle: {})
        ItemRow(title: "texte", subtitle: "sociétés multiculturelles · Fin de journée",
                color: CourseColor.violet.color, isDone: true, onToggle: {})
    }
    .padding()
    .background(Theme.Colors.background)
}
