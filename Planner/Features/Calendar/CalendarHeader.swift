//
//  CalendarHeader.swift
//  En-tête « Swiss » du mois + ligne des jours de la semaine.
//
//   10  Octobre                         ● 4 échéances d'ici le 31
//       2026 • Semaine 42
//   LUN   MAR   MER   JEU   VEN   SAM   DIM
//   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//

import SwiftUI

struct MonthHeader: View {
    let month: Date
    let weekNumber: Int
    let upcomingCount: Int
    let style: CalendarStyle

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.l) {
            // Le numéro du mois en très grand : la signature visuelle de l'app.
            Text(month.monthNumber, format: .number)
                .font(Theme.Fonts.display(style == .regular ? 140 : 88))
                .tracking(-6)
                .foregroundStyle(Theme.Colors.pink)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 6) {
                Text(month.monthName.capitalized(with: .planner))
                    .font(Theme.Fonts.display(style == .regular ? 56 : 32))
                    .tracking(-2)
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: Theme.Spacing.s) {
                    Text(month.yearText)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.ink)
                    Circle()
                        .fill(Theme.Colors.pink)
                        .frame(width: 5, height: 5)
                    Text("Semaine \(weekNumber)")
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                .font(.subheadline)
            }
            .padding(.bottom, style == .regular ? 18 : 10)

            Spacer(minLength: 0)

            if style == .regular && upcomingCount > 0 {
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
                .fill(Theme.Colors.pink)
                .frame(width: 7, height: 7)
            Text(count == 1 ? "1 échéance ce mois-ci" : "\(count) échéances ce mois-ci")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.pinkDeep)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 6)
        .background(Theme.Colors.tint, in: .capsule)
    }
}

/// Ligne « LUN MAR … DIM » + trait noir épais (détail Swiss de la maquette).
struct WeekdayHeader: View {
    let style: CalendarStyle

    var body: some View {
        let calendar = Calendar.planner
        let names = style == .regular ? calendar.weekdayShortNames : calendar.weekdayInitials

        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 0) {
                ForEach(Array(names.enumerated()), id: \.offset) { position, name in
                    Text(name)
                        // Samedi et dimanche en rose.
                        .plannerLabelStyle(color: position >= 5 ? Theme.Colors.pink : Theme.Colors.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, style == .regular ? 10 : 6)
                }
            }
            Rectangle()
                .fill(Theme.Colors.ink)
                .frame(height: 2)
        }
        .accessibilityHidden(true)
    }
}
