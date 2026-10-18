//
//  CalendarHeader.swift
//  En-tête « Swiss » du mois + ligne des jours de la semaine.
//
//   10  Octobre                         ● 4 échéances d'ici le 31
//       2026 • Semaine 42
//   LUN   MAR   MER   JEU   VEN   SAM   DIM
//   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//  Les tailles viennent de `CalendarLayout` : le gros numéro maigrit avec la
//  fenêtre, et la pastille d'échéances s'efface quand la place manque.
//

import SwiftUI

struct MonthHeader: View {
    let month: Date
    let weekNumber: Int
    let upcomingCount: Int
    let layout: CalendarLayout

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.l) {
            // Le numéro du mois en très grand : la signature visuelle de l'app.
            Text(month.monthNumber, format: .number)
                .font(Theme.Fonts.display(layout.monthNumberSize))
                .tracking(layout.monthNumberTracking)
                .foregroundStyle(Theme.Colors.accent)
                .contentTransition(.numericText())
                .lineLimit(1)
                .fixedSize()

            VStack(alignment: .leading, spacing: 6) {
                Text(month.monthName.capitalized(with: .planner))
                    .font(Theme.Fonts.display(layout.monthNameSize))
                    .tracking(layout.monthNameTracking)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: Theme.Spacing.s) {
                    Text(month.yearText)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.ink)
                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 5, height: 5)
                    Text("Semaine \(weekNumber)")
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(.bottom, layout.isRegular ? 18 : 10)

            Spacer(minLength: 0)

            if layout.showsDeadlineBadge && upcomingCount > 0 {
                DeadlineBadge(count: upcomingCount)
                    .padding(.bottom, 22)
            }
        }
        // VoiceOver lit « octobre 2026 » au lieu de « 10, Octobre, 2026… ».
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(month.monthName) \(month.yearText)")
    }
}

/// Pastille « ● 4 échéances ce mois-ci ».
private struct DeadlineBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 7, height: 7)
            Text(count == 1 ? "1 échéance ce mois-ci" : "\(count) échéances ce mois-ci")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.accentDeep)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 6)
        .background(Theme.Colors.tint, in: .capsule)
        .fixedSize()
    }
}

/// Ligne « LUN MAR … DIM » + trait noir épais (détail Swiss de la maquette).
struct WeekdayHeader: View {
    let layout: CalendarLayout

    var body: some View {
        let calendar = Calendar.planner
        let names = layout.isRegular ? calendar.weekdayShortNames : calendar.weekdayInitials

        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 0) {
                ForEach(Array(names.enumerated()), id: \.offset) { position, name in
                    Text(name)
                        // Samedi et dimanche en rose.
                        .plannerLabelStyle(color: position >= 5 ? Theme.Colors.accent : Theme.Colors.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, layout.isRegular ? 10 : 6)
                }
            }
            Rectangle()
                .fill(Theme.Colors.ink)
                .frame(height: 2)
        }
        .accessibilityHidden(true)
    }
}
