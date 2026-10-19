//
//  CourseChip.swift
//  Carré de couleur + nom du cours. Équivalent du composant Figma « Class Chip ».
//

import SwiftUI

struct CourseChip: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.ink)
                .lineLimit(1)
        }
    }
}

/// Version « bouton » pour choisir un cours (éditeur iOS).
/// Sélectionnée : fond de la couleur du cours + coche blanche.
struct SelectableCourseChip: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 10, height: 10)
                }
                Text(name)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.Colors.onCourse : Theme.Colors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Theme.Colors.background, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading) {
        CourseChip(name: "méthodes qualitatives A", color: CourseColor.blue.color)
        SelectableCourseChip(name: "transition écologique", color: CourseColor.green.color, isSelected: true) {}
        SelectableCourseChip(name: "altro", color: CourseColor.teal.color, isSelected: false) {}
    }
    .padding()
}
