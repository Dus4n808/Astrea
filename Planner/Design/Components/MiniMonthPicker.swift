//
//  MiniMonthPicker.swift
//  Petit calendrier pour choisir un jour, aux couleurs de l'app.
//
//  Remplace le `DatePicker` graphique de macOS, qui ignore la teinte (sélection
//  et cadre bleus), reste en anglais et a l'allure d'AppKit. Celui-ci réutilise
//  la logique de la grille du mois (MonthGrid) : semaine du lundi, français.
//
//  ┌──────────────────────────────┐
//  │ Octobre 2026        ‹  ●  ›  │
//  │ L  M  M  J  V  S  D          │
//  │ …  ⓳  …                      │  ← jour choisi : rond rose plein
//  └──────────────────────────────┘
//
//  Choisir un jour garde l'heure déjà réglée dans `selection`.
//

import SwiftUI

struct MiniMonthPicker: View {
    @Binding var selection: Date
    /// Premier jour autorisé (ex. fin des vacances ≥ début), ou nil.
    var minimum: Date? = nil
    /// Appelé après un choix de jour (pour refermer un popover, par exemple).
    var onPick: () -> Void = {}

    @State private var month: Date

    private let calendar = Calendar.planner
    private static let cellSize: CGFloat = 34

    init(selection: Binding<Date>, minimum: Date? = nil, onPick: @escaping () -> Void = {}) {
        self._selection = selection
        self.minimum = minimum
        self.onPick = onPick
        // On ouvre sur le mois du jour déjà choisi.
        self._month = State(initialValue: Calendar.planner.startOfMonth(for: selection.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            weekdayRow
            grid
        }
        .padding(Theme.Spacing.l)
        .frame(width: Self.cellSize * 7 + Theme.Spacing.l * 2)
        .animation(.snappy, value: month)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("\(month.monthName.capitalized(with: .planner)) \(Text(month.yearText).foregroundStyle(Theme.Colors.inkSecondary))")
                .font(Theme.Fonts.display(18))
                .tracking(-0.4)
                .foregroundStyle(Theme.Colors.ink)
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            navigationButton("Mois précédent", systemImage: "chevron.left") { shiftMonth(by: -1) }
            navigationButton("Aujourd'hui", systemImage: "circle.fill") {
                month = calendar.startOfMonth(for: .now)
            }
            .imageScale(.small)
            navigationButton("Mois suivant", systemImage: "chevron.right") { shiftMonth(by: 1) }
        }
    }

    private func navigationButton(_ title: String, systemImage: String,
                                  action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.Colors.accent)
            .frame(width: 24, height: 24)
            .contentShape(.circle)
    }

    // MARK: - Grille

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(calendar.weekdayInitials.enumerated()), id: \.offset) { position, initial in
                Text(initial)
                    .plannerLabelStyle(color: position >= 5 ? Theme.Colors.accent : Theme.Colors.inkSecondary)
                    .frame(width: Self.cellSize)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 2) {
            ForEach(MonthGrid(month: month, calendar: calendar).weeks, id: \.first?.id) { week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        dayButton(day)
                    }
                }
            }
        }
    }

    private func dayButton(_ day: GridDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day.date)
        let isAllowed = minimum.map { day.date >= calendar.startOfDay(for: $0) } ?? true

        return Button {
            pick(day.date)
        } label: {
            Text(day.date.dayNumber, format: .number)
                .font(.system(size: 13, weight: isSelected || isToday ? .heavy : .semibold))
                .foregroundStyle(isSelected ? Theme.Colors.onAccent
                                 : (isToday ? Theme.Colors.accent : Theme.Colors.ink))
                .opacity(day.isInMonth ? 1 : 0.3)
                .frame(width: Self.cellSize, height: Self.cellSize)
                .background {
                    if isSelected {
                        Circle().fill(Theme.Colors.accent)
                    } else if isToday {
                        Circle().strokeBorder(Theme.Colors.accent.opacity(0.4), lineWidth: 1.5)
                    }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!isAllowed)
        .opacity(isAllowed ? 1 : 0.35)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Actions

    private func shiftMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) {
            month = next
        }
    }

    /// Nouveau jour, même heure : `selection` porte aussi l'heure des
    /// éléments qui ne sont pas « toute la journée ».
    private func pick(_ day: Date) {
        let time = calendar.dateComponents([.hour, .minute], from: selection)
        selection = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                                  second: 0, of: day) ?? day
        // Un jour grisé du mois voisin fait aussi tourner la page.
        month = calendar.startOfMonth(for: day)
        onPick()
    }
}

#Preview {
    @Previewable @State var date = Date.now
    MiniMonthPicker(selection: $date)
        .background(Theme.Colors.surface)
}
