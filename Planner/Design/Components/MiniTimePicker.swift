//
//  MiniTimePicker.swift
//  Choix d'une heure, assorti au MiniMonthPicker.
//
//  ┌───────────────────────────┐
//  │          14:30            │  ← heure choisie, en gros
//  │ HEURE                     │
//  │ 07 08 09 10 11 12         │  ← 24 heures, en grille
//  │ …                         │
//  │ MINUTES                   │
//  │ 00 05 10 15 20 25 …       │  ← par pas de 5 minutes
//  └───────────────────────────┘
//
//  Une grille plutôt qu'une roue : tout est visible d'un coup d'œil et se
//  choisit en un clic, sur Mac comme sur iPhone. Changer l'heure garde le jour.
//

import SwiftUI

struct MiniTimePicker: View {
    @Binding var selection: Date

    private let calendar = Calendar.planner
    static let minuteStep = 5

    private var hour: Int { calendar.component(.hour, from: selection) }
    private var minute: Int { calendar.component(.minute, from: selection) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(selection.timeText)
                .font(Theme.Fonts.display(34))
                .tracking(-1)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.ink)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)

            Text("Heure").plannerLabelStyle()
            grid(values: Array(0..<24), columns: 6, selected: hour) { set(hour: $0) }

            Text("Minutes").plannerLabelStyle()
            grid(values: Array(stride(from: 0, to: 60, by: Self.minuteStep)), columns: 6,
                 selected: Self.roundedMinute(minute)) { set(minute: $0) }
        }
        .padding(Theme.Spacing.l)
        .frame(width: 6 * 40 + Theme.Spacing.l * 2)
        .animation(.snappy, value: selection)
    }

    private func grid(values: [Int], columns: Int, selected: Int,
                      action: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 4), count: columns),
                  spacing: 4) {
            ForEach(values, id: \.self) { value in
                let isSelected = value == selected
                Button {
                    action(value)
                } label: {
                    Text(value, format: .number.precision(.integerLength(2)))
                        .font(.system(size: 13, weight: isSelected ? .heavy : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Theme.Colors.onAccent : Theme.Colors.ink)
                        .frame(width: 36, height: 30)
                        .background(isSelected ? Theme.Colors.accent : Theme.Colors.tint.opacity(0.5),
                                    in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Calcul

    /// Minute affichée comme choisie : la plus proche sur la grille de 5.
    static func roundedMinute(_ minute: Int) -> Int {
        min(55, Int((Double(minute) / Double(minuteStep)).rounded()) * minuteStep)
    }

    private func set(hour newHour: Int) {
        selection = Self.date(selection, hour: newHour, minute: minute, calendar: calendar)
    }

    private func set(minute newMinute: Int) {
        selection = Self.date(selection, hour: hour, minute: newMinute, calendar: calendar)
    }

    /// Même jour, nouvelle heure.
    static func date(_ date: Date, hour: Int, minute: Int, calendar: Calendar = .planner) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}

#Preview {
    @Previewable @State var date = Date.now
    MiniTimePicker(selection: $date)
        .background(Theme.Colors.surface)
}
