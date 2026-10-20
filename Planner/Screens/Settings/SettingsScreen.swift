//
//  SettingsScreen.swift
//  Réglages : prénom, thème de couleurs, état de la synchronisation iCloud.
//
//  Le prénom suit les mêmes règles qu'à l'onboarding (UserName) et
//  s'enregistre dès qu'il est valide : pas de bouton « Enregistrer ».
//  Le thème s'applique tout de suite à toute l'app (ThemeStore).
//

import SwiftUI

struct SettingsScreen: View {
    @AppStorage(UserName.storageKey) private var savedName = ""
    @State private var nameDraft = ""

    private var themeStore: ThemeStore { .shared }
    private var nameError: UserName.ValidationError? { UserName.validate(nameDraft) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                nameSection
                themeSection
                syncSection
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Réglages")
        .onAppear { nameDraft = savedName }
    }

    // MARK: - Prénom

    private var nameSection: some View {
        EditorCard("Ton prénom") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField("Ton prénom", text: $nameDraft,
                          prompt: Text("Ton prénom").foregroundStyle(Theme.Colors.inkSecondary))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .textContentType(.givenName)
                    #endif
                    .onChange(of: nameDraft) { _, newValue in
                        let clean = UserName.sanitize(newValue)
                        if clean != newValue {
                            nameDraft = clean
                        } else if UserName.validate(clean) == nil {
                            // Valide : on l'enregistre tout de suite. Invalide
                            // (trop court) : on garde l'ancien prénom, jamais vide.
                            savedName = UserName.normalized(clean)
                        }
                    }

                HStack {
                    // Tant que c'est invalide, l'ancien prénom reste enregistré.
                    if let nameError {
                        Text(nameError.message)
                    }
                    Spacer()
                    Text("\(nameDraft.count)/\(UserName.maxLength)")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
    }

    // MARK: - Thème

    private var themeSection: some View {
        EditorCard("Thème") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.m)],
                      spacing: Theme.Spacing.m) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeSwatch(theme: theme, isSelected: themeStore.theme == theme) {
                        withAnimation(.snappy) { themeStore.theme = theme }
                    }
                }
            }
        }
    }

    // MARK: - iCloud

    private var syncSection: some View {
        let state = ICloudStatus.shared.state
        return EditorCard("Synchronisation") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.ink)
                    if state != .checking {
                        Text(state.message)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            } icon: {
                Image(systemName: state.symbolName)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        // Vérifié à l'ouverture des réglages, puis à chaque changement de
        // compte tant que l'écran reste affiché.
        .task { await ICloudStatus.shared.monitor() }
    }
}

/// Aperçu d'un thème : son fond, une carte et sa couleur d'accent.
private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let palette = theme.palette
        Button(action: action) {
            VStack(spacing: Theme.Spacing.s) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: Theme.Radius.cell)
                        .fill(palette.background)
                    // Mini carte + pastille d'accent : l'allure de l'app en petit.
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(palette.accent).frame(width: 28, height: 6)
                        Capsule().fill(palette.gridLine).frame(width: 40, height: 6)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(palette.surface, in: .rect(cornerRadius: 8))
                    .padding(8)
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(palette.onAccent)
                            }
                        }
                        .padding(4)
                }
                .frame(height: 72)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.cell)
                        .strokeBorder(isSelected ? palette.accent : palette.gridLine,
                                      lineWidth: isSelected ? 2.5 : 1)
                }

                Text(theme.name)
                    .font(.caption.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thème \(theme.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
