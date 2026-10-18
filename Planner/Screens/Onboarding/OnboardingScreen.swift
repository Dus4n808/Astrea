//
//  OnboardingScreen.swift
//  Premier écran, affiché tant que l'utilisateur n'a pas donné son prénom.
//
//  Même mise en page que ComingSoonScreen (étoile + gros titre + label).
//  Les couleurs propres à l'onboarding viendront plus tard.
//
//  Le prénom est nettoyé en direct (voir UserName) puis enregistré dans
//  @AppStorage : RootView bascule alors automatiquement sur l'app.
//

import SwiftUI

struct OnboardingScreen: View {
    @AppStorage(UserName.storageKey) private var savedName = ""
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    private var error: UserName.ValidationError? { UserName.validate(draft) }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            StarLogo()
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            Text("Bienvenue")
                .font(Theme.Fonts.display(34))
                .tracking(-1)
                .foregroundStyle(Theme.Colors.ink)
            Text("Comment tu t'appelles ?")
                .plannerLabelStyle(color: Theme.Colors.accent)

            nameField
                .padding(.top, Theme.Spacing.s)

            Button(action: save) {
                Text("C'est parti")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.m)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(error != nil)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .tint(Theme.Colors.accent)
        .onAppear { isFieldFocused = true }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            TextField("Ton prénom", text: $draft)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
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
                .padding(Theme.Spacing.l)
                .plannerCard()

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
            .padding(.horizontal, Theme.Spacing.s)
        }
    }

    private func save() {
        guard error == nil else { return }
        withAnimation(.snappy) {
            savedName = UserName.normalized(draft)
        }
    }
}

#Preview {
    OnboardingScreen()
        .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
