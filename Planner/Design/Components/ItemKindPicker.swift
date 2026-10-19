//
//  ItemKindPicker.swift
//  Petit panneau « Tâche / Événement / Vacances » à mettre dans un popover.
//
//  Remplace un `Menu` système à cet endroit : sur Mac, un menu est dessiné
//  par AppKit (surbrillance à l'accent du système, bleu par défaut) et ne
//  peut pas prendre les couleurs du thème.
//

import SwiftUI

struct ItemKindPicker: View {
    let onPick: (ItemKind) -> Void

    @State private var hovered: ItemKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Ajouter")
                .plannerLabelStyle()
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xs)

            ForEach(ItemKind.allCases) { kind in
                Button {
                    onPick(kind)
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: kind.systemImage)
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(width: 20)
                        Text(kind.title)
                            .foregroundStyle(Theme.Colors.ink)
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 7)
                    .background(hovered == kind ? Theme.Colors.tint : .clear,
                                in: .rect(cornerRadius: Theme.Radius.pill + 2))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? kind : (hovered == kind ? nil : hovered) }
            }
        }
        .padding(Theme.Spacing.s)
        .frame(width: 180)
    }
}

#Preview {
    ItemKindPicker { _ in }
        .background(Theme.Colors.surface)
}
