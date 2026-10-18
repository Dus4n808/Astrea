//
//  EventPill.swift
//  Petite pastille colorée affichée dans une case du calendrier.
//  Équivalent du composant Figma « Event Pill » (états Default / Done).
//
//  Composant « bête » : il reçoit du texte et une couleur, il ne connaît
//  pas les modèles. On peut donc le réutiliser n'importe où.
//

import SwiftUI

struct EventPill: View {
    let title: String
    let color: Color
    var isDone: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            // Petit trait blanc à gauche (détail de la maquette).
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: 3, height: 10)

            Text(title)
                .font(Theme.Fonts.pill)
                .foregroundStyle(.white)
                .strikethrough(isDone)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: .rect(cornerRadius: Theme.Radius.pill))
        .opacity(isDone ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }
}

#Preview {
    VStack {
        EventPill(title: "lectures", color: CourseColor.blue.color)
        EventPill(title: "texte", color: CourseColor.violet.color, isDone: true)
    }
    .frame(width: 160)
    .padding()
}
