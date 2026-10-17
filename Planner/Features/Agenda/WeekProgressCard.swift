//
//  WeekProgressCard.swift
//  Carte rose « CETTE SEMAINE — 3/9 » avec barre de progression
//  et l'étoile collée en autocollant.
//

import SwiftUI

/// Valeur simple, calculée par l'écran Agenda.
struct WeekProgress {
    let done: Int
    let total: Int

    /// 0…1, protégé contre la division par zéro.
    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    /// Petit message qui change selon l'avancement.
    var message: String {
        switch fraction {
        case 0 where total == 0: "Semaine libre"
        case 0:                  "C'est parti !"
        case ..<0.5:             "Bien lancé"
        case ..<1:               "Presque au bout !"
        default:                 "Semaine bouclée"
        }
    }
}

struct WeekProgressCard: View {
    let progress: WeekProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cette semaine")
                        .plannerLabelStyle(color: .white)
                    Text(progress.message)
                        .font(.title3.weight(.heavy))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(progress.done, format: .number)
                        .font(Theme.Fonts.display(52))
                        .contentTransition(.numericText())
                    Text("/\(progress.total)")
                        .font(Theme.Fonts.display(20))
                }
            }

            ProgressView(value: progress.fraction)
                .tint(.white)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(Theme.Colors.pink, in: .rect(cornerRadius: 24))
        .shadow(color: Theme.Colors.pink.opacity(0.35), radius: 16, y: 10)
        // L'étoile « autocollant », qui dépasse un peu de la carte.
        .overlay(alignment: .top) {
            StarLogo()
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(14))
                .offset(x: 50, y: -26)
                .accessibilityHidden(true)
        }
        .animation(.snappy, value: progress.done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cette semaine : \(progress.done) tâches faites sur \(progress.total)")
    }
}

#Preview {
    WeekProgressCard(progress: WeekProgress(done: 3, total: 9))
        .padding(40)
        .background(Theme.Colors.background)
}
