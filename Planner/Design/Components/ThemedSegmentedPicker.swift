//
//  ThemedSegmentedPicker.swift
//  Choix exclusif entre quelques options (À faire / Fait / Tout,
//  Tâche / Événement / Vacances), aux couleurs du thème.
//
//  Remplace le `Picker` segmenté du système, qui reste gris et blanc quel
//  que soit le thème choisi.
//

import SwiftUI

struct ThemedSegmentedPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Theme.Colors.onAccent : Theme.Colors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Theme.Colors.accent : Theme.Colors.surface,
                                    in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.snappy, value: selection)
    }
}

#Preview {
    @Previewable @State var selection = "À faire"
    ThemedSegmentedPicker(options: ["À faire", "Fait", "Tout"], selection: $selection) { $0 }
        .padding()
        .background(Theme.Colors.background)
}
