//
//  DayCell.swift
//  Une case (un jour) de la grille du mois.
//
//  Interactions :
//  - tap sur la case          → sélectionne le jour
//  - tap sur une pastille     → ouvre l'élément dans l'éditeur
//  - survol (Mac/iPad)        → bouton « + » qui propose Tâche / Événement / Vacances
//  - clic droit / appui long  → même menu (menu contextuel)
//

import SwiftUI

struct DayCell: View {
    @Environment(AppState.self) private var appState

    let day: GridDay
    let items: [PlannerItem]
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
    let isLastColumn: Bool
    let style: CalendarStyle
    let onSelect: () -> Void

    @State private var isHovered = false

    /// Au-delà, on affiche « +N » pour ne pas déborder de la case.
    private let maxVisibleItems = 3

    var body: some View {
        content
            .padding(style == .regular ? Theme.Spacing.s : 6)
            .frame(maxWidth: .infinity, maxHeight: style == .regular ? .infinity : nil, alignment: .topLeading)
            .frame(height: style == .compact ? 52 : nil)
            .background { background }
            .overlay(alignment: .bottom) { gridLine(horizontal: true) }
            .overlay(alignment: .trailing) { if !isLastColumn { gridLine(horizontal: false) } }
            .contentShape(.rect)
            .onTapGesture(perform: onSelect)
            .onHover { isHovered = $0 }
            .contextMenu { addMenuItems }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: style == .regular ? 4 : 3) {
            dateRow

            switch style {
            case .regular: pills
            case .compact: bars
            }
        }
    }

    /// Le numéro du jour (+ « AUJOURD'HUI » ou « oct. » le 1er du mois).
    private var dateRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if isToday && style == .regular {
                Text(day.date.dayNumber, format: .number)
                    .font(Theme.Fonts.display(36))
                    .tracking(-2)
                Text("Aujourd'hui")
                    .plannerLabelStyle(color: .white)
            } else {
                Text(day.date.dayNumber, format: .number)
                    .font(.system(size: 15, weight: isToday ? .black : .bold))
                    .opacity(day.isInMonth ? 1 : 0.3)
                if day.date.dayNumber == 1 && style == .regular {
                    Text(day.date.formatted(.dateTime.month(.abbreviated).locale(.planner)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.pink)
                }
            }

            Spacer(minLength: 0)

            // Bouton « + » visible au survol (Mac, iPad avec trackpad).
            if isHovered && style == .regular {
                Menu { addMenuItems } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.Colors.pink, in: .circle)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .foregroundStyle(isToday ? .white : Theme.Colors.ink)
    }

    /// Mode large : pastilles cliquables.
    private var pills: some View {
        Group {
            ForEach(items.prefix(maxVisibleItems)) { item in
                Button {
                    appState.openEditor(for: item)
                } label: {
                    EventPill(title: item.title, color: item.displayColor, isDone: item.isDone)
                }
                .buttonStyle(.plain)
            }
            if items.count > maxVisibleItems {
                Text("+\(items.count - maxVisibleItems) autres")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? .white : Theme.Colors.inkSecondary)
            }
        }
    }

    /// Mode compact : petites barres de couleur (une par élément).
    private var bars: some View {
        ForEach(items.prefix(maxVisibleItems)) { item in
            Capsule()
                .fill(item.displayColor)
                .frame(height: 4)
                .opacity(item.isDone ? 0.4 : 1)
        }
    }

    // MARK: - Fond et bordures

    @ViewBuilder
    private var background: some View {
        if isToday {
            RoundedRectangle(cornerRadius: style == .regular ? Theme.Radius.cell : 12)
                .fill(Theme.Colors.pink)
                .shadow(color: Theme.Colors.pink.opacity(0.35), radius: 12, y: 6)
        } else if isSelected && style == .compact {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.Colors.pink, lineWidth: 2)
        } else if isHovered {
            RoundedRectangle(cornerRadius: Theme.Radius.cell)
                .fill(Theme.Colors.surface)
        } else if isWeekend && style == .regular {
            Theme.Colors.tint.opacity(0.35)
        }
    }

    /// Fin trait rose entre les cases (pas sous la case du jour, qui est arrondie).
    @ViewBuilder
    private func gridLine(horizontal: Bool) -> some View {
        if !isToday {
            Rectangle()
                .fill(Theme.Colors.gridLine)
                .frame(width: horizontal ? nil : 1, height: horizontal ? 1 : nil)
        }
    }

    // MARK: - Menu « Ajouter »

    @ViewBuilder
    private var addMenuItems: some View {
        ForEach(ItemKind.allCases) { kind in
            Button(kind.title, systemImage: kind.systemImage) {
                appState.openEditor(kind: kind, on: day.date)
            }
        }
    }

    private var accessibilityText: String {
        let count = items.count
        let suffix = count == 0 ? "rien de prévu" : (count == 1 ? "1 élément" : "\(count) éléments")
        return "\(day.date.shortDayText), \(suffix)"
    }
}
