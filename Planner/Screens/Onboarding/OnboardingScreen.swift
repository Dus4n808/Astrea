//
//  OnboardingScreen.swift
//  Premier écran, affiché tant que l'utilisateur n'a pas donné son prénom.
//
//  Le but est que ce soit accueillant et un peu joueur :
//  - l'étoile flotte et se balance, entourée d'étincelles qui scintillent ;
//  - le titre répond pendant la saisie (« Salut, Léa ! ») ;
//  - valider fait faire une pirouette à l'étoile avant d'entrer dans l'app.
//
//  Le prénom est nettoyé en direct (voir UserName) puis enregistré dans
//  @AppStorage : RootView bascule alors automatiquement sur l'app.
//

import SwiftUI

struct OnboardingScreen: View {
    @AppStorage(UserName.storageKey) private var savedName = ""
    @State private var draft = ""
    @State private var isCelebrating = false
    @FocusState private var isFieldFocused: Bool

    private var error: UserName.ValidationError? { UserName.validate(draft) }
    private var cleanName: String { UserName.normalized(draft) }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            FloatingStar(isCelebrating: isCelebrating)
                .frame(width: 130, height: 130)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.s) {
                Text("Coucou !")
                    .plannerLabelStyle(color: Theme.Colors.accent)
                greeting
                    .font(Theme.Fonts.display(34))
                    .tracking(-1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.ink)
                    .contentTransition(.interpolate)
                    .animation(.snappy, value: cleanName)
                Text("Astrea range tes cours, tes devoirs et tes vacances.\nOn commence par ton prénom ?")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    // Sinon la deuxième ligne est coupée en « … ».
                    .fixedSize(horizontal: false, vertical: true)
            }

            nameField
                .padding(.top, Theme.Spacing.s)

            // Bouton dessiné plutôt que `.borderedProminent` : désactivé, celui
            // du Mac devient presque invisible sur le fond clair.
            Button(action: save) {
                Label("C'est parti", systemImage: "arrow.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.m)
                    .background(Theme.Colors.accent, in: .capsule)
                    .shadow(color: Theme.Colors.accent.opacity(error == nil ? 0.35 : 0), radius: 10, y: 5)
                    .opacity(error == nil ? 1 : 0.45)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(error != nil || isCelebrating)
            .keyboardShortcut(.defaultAction)
            .animation(.snappy, value: error == nil)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .tint(Theme.Colors.accent)
        .onAppear { isFieldFocused = true }
    }

    /// « Bienvenue » tant que rien n'est tapé, puis « Salut, Léa ! »
    /// avec le prénom dans la couleur du thème.
    private var greeting: Text {
        if error == nil {
            Text("Salut, \(Text(cleanName).foregroundStyle(Theme.Colors.accent)) !")
        } else {
            Text("Bienvenue")
        }
    }

    private var nameField: some View {
        VStack(spacing: Theme.Spacing.xs) {
            TextField("Ton prénom", text: $draft,
                      prompt: Text("Ton prénom").foregroundStyle(Theme.Colors.inkSecondary))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.ink)
                // Aligné à gauche : sur Mac, le texte d'aide ignore le centrage
                // et ne serait pas aligné avec la saisie.
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.words)
                .textContentType(.givenName)
                #endif
                .submitLabel(.go)
                .focused($isFieldFocused)
                .onSubmit(save)
                // Nettoyage frappe par frappe : caractères interdits retirés,
                // longueur coupée à UserName.maxLength.
                .onChange(of: draft) { _, newValue in
                    let clean = UserName.sanitize(newValue)
                    if clean != newValue { draft = clean }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .background(Theme.Colors.surface, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(isFieldFocused ? Theme.Colors.accent : Theme.Colors.gridLine,
                                           lineWidth: 2)
                }
                .animation(.snappy, value: isFieldFocused)

            HStack {
                // Le message n'apparaît qu'une fois la saisie commencée.
                if let error, !draft.isEmpty {
                    Text(error.message)
                }
                Spacer()
                Text("\(draft.count)/\(UserName.maxLength)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.inkSecondary)
            .padding(.horizontal, Theme.Spacing.m)
        }
        // Un prénom fait 20 caractères au plus : inutile de prendre tout l'écran.
        .frame(maxWidth: 280)
    }

    private func save() {
        guard error == nil, !isCelebrating else { return }
        let name = cleanName
        isCelebrating = true
        // La pirouette de l'étoile se voit avant que l'app ne remplace l'écran.
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.snappy) { savedName = name }
        }
    }
}

// MARK: - Étoile animée

/// L'étoile du logo qui flotte, se balance, et tourne sur elle-même pour fêter
/// la validation. Des étincelles scintillent autour.
private struct FloatingStar: View {
    let isCelebrating: Bool

    /// Étincelles : position autour de l'étoile (en fraction du cadre) et taille.
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.08, 0.20, 18), (0.90, 0.12, 14), (0.95, 0.70, 20), (0.05, 0.80, 12), (0.55, 0.0, 10),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Self.sparkles.indices, id: \.self) { index in
                    let sparkle = Self.sparkles[index]
                    Image(systemName: "sparkle")
                        .font(.system(size: sparkle.size, weight: .bold))
                        .foregroundStyle(index.isMultiple(of: 2) ? Theme.Colors.accent : Theme.Colors.gridLine)
                        .symbolEffect(.breathe, options: .repeat(.continuous).speed(0.6 + Double(index) * 0.15))
                        .position(x: proxy.size.width * sparkle.x, y: proxy.size.height * sparkle.y)
                }

                StarLogo()
                    .frame(width: proxy.size.width * 0.66)
                    .phaseAnimator([false, true]) { star, isUp in
                        star
                            .offset(y: isUp ? -8 : 4)
                            .rotationEffect(.degrees(isUp ? 6 : -8))
                    } animation: { _ in
                        .easeInOut(duration: 1.6)
                    }
                    .rotationEffect(.degrees(isCelebrating ? 360 : 0))
                    .scaleEffect(isCelebrating ? 1.15 : 1)
                    .animation(.spring(duration: 0.6, bounce: 0.4), value: isCelebrating)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }
}

/// « C'est parti → » : l'icône après le texte.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            configuration.title
            configuration.icon
        }
    }
}

#Preview {
    OnboardingScreen()
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
