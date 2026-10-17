//
//  ComingSoonScreen.swift
//  Écran temporaire pour les sections pas encore développées
//  (Années, Réglages). À remplacer feature par feature.
//

import SwiftUI

struct ComingSoonScreen: View {
    let section: AppSection

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            StarLogo()
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(-8))
            Text(section.title)
                .font(Theme.Fonts.display(34))
                .tracking(-1)
                .foregroundStyle(Theme.Colors.ink)
            Text("Bientôt disponible")
                .plannerLabelStyle(color: Theme.Colors.pink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationTitle(section.title)
    }
}

#Preview {
    ComingSoonScreen(section: .years)
}
