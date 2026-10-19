//
//  EmptyStateView.swift
//  « Rien ici » aux couleurs du thème : l'étoile, un titre, une phrase.
//
//  Remplace `ContentUnavailableView`, dont l'icône et les textes restent
//  dans les gris du système quel que soit le thème choisi.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    /// Remplace l'étoile fixe par l'étoile 3D animée (semaine bouclée).
    var celebrates = false

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            if celebrates {
                AnimatedStar3D(repeats: false)
                    // ~65 pt d'étoile visible, comme l'étoile fixe : le reste
                    // du cadre sert de marge au rebond.
                    .frame(width: 110, height: 110)
            } else {
                StarLogo()
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-8))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(Theme.Fonts.display(22))
                .tracking(-0.5)
                .foregroundStyle(Theme.Colors.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(title: "Tout est fait !", message: "Aucune tâche en attente. Profite.", celebrates: true)
        .background(Theme.Colors.background)
}
