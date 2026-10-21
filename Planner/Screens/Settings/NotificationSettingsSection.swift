//
//  NotificationSettingsSection.swift
//  Réglages des rappels : les recevoir ou non, à quelle heure pour les
//  tâches sans heure, seulement pour les importantes, et un essai.
//
//  Propres à cet appareil (voir NotificationSettings). Chaque changement
//  reprogramme aussitôt les rappels (ReminderSyncModifier observe ces clés).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct NotificationSettingsSection: View {
    @AppStorage(NotificationSettings.enabledKey) private var isEnabled = true
    @AppStorage(NotificationSettings.dayTimeKey) private var dayTime = NotificationSettings.defaultDayTime
    @AppStorage(NotificationSettings.importantOnlyKey) private var importantOnly = false
    @AppStorage(UserName.storageKey) private var userName = ""
    @Environment(\.openURL) private var openURL

    @State private var isPickingTime = false
    @State private var testSent = false

    private var scheduler: ReminderScheduler { .shared }

    var body: some View {
        EditorCard("Notifications") {
            VStack(alignment: .leading, spacing: 0) {
                if scheduler.authorization == .denied {
                    deniedBanner
                        .padding(.bottom, Theme.Spacing.m)
                }

                SettingsToggleRow(title: "Recevoir les rappels",
                                  subtitle: "Sur cet appareil, pour les éléments qui ont un rappel.",
                                  systemImage: "bell.badge",
                                  isOn: $isEnabled)

                if isEnabled {
                    SettingsSeparator()
                    dayTimeRow
                    SettingsSeparator()
                    SettingsToggleRow(title: "Seulement les importantes",
                                      subtitle: "Les autres tâches restent silencieuses.",
                                      systemImage: "star",
                                      isOn: $importantOnly)
                    SettingsSeparator()
                    testRow
                }
            }
            .animation(.snappy, value: isEnabled)
            .animation(.snappy, value: scheduler.authorization)
        }
        .task { await scheduler.refreshAuthorization() }
        .onChange(of: isEnabled) { _, enabled in
            // Rallumer les rappels : on demande la permission si besoin.
            if enabled { Task { await scheduler.requestAuthorizationIfNeeded() } }
        }
    }

    // MARK: - Lignes

    /// L'heure des rappels « le jour même » / « la veille » des éléments sans heure.
    private var dayTimeRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            SettingsIcon(systemImage: "clock")
            VStack(alignment: .leading, spacing: 2) {
                Text("Tâches sans heure")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Text("L'heure de leurs rappels, chaque jour.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            Spacer(minLength: Theme.Spacing.s)
            Button {
                isPickingTime.toggle()
            } label: {
                Text(NotificationSettings(dayTime: dayTime).dayTimeText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.tint, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Heure des rappels des tâches sans heure")
            .accessibilityValue(NotificationSettings(dayTime: dayTime).dayTimeText)
            .popover(isPresented: $isPickingTime, arrowEdge: .bottom) {
                // Le même sélecteur d'heure que l'éditeur, aux couleurs du thème.
                MiniTimePicker(selection: dayTimeAsDate)
                    .presentationBackground(Theme.Colors.surface)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    /// Essai : une notification arrive dans 3 secondes.
    private var testRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            SettingsIcon(systemImage: "paperplane")
            VStack(alignment: .leading, spacing: 2) {
                Text("Faire un essai")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Text(testSent ? "C'est parti, regarde dans 3 secondes !" : "Pour voir à quoi ressemble un rappel.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: Theme.Spacing.s)
            Button {
                Task {
                    await scheduler.sendTest(userName: userName)
                    withAnimation(.snappy) { testSent = scheduler.authorization == .allowed }
                }
            } label: {
                Text("Essayer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.accent, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    /// Refusé dans les réglages du système : l'app ne peut plus rien
    /// demander, seul l'utilisateur peut rouvrir. On le dit, avec le chemin.
    private var deniedBanner: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(Theme.Colors.accentDeep)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Les notifications sont refusées pour Astrea sur cet appareil. Aucun rappel ne pourra arriver.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Ouvrir les réglages") {
                    if let url = Self.systemSettingsURL { openURL(url) }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.Colors.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.tint, in: .rect(cornerRadius: Theme.Radius.cell))
    }

    // MARK: - Aides

    /// Les minutes enregistrées, vues comme une date d'aujourd'hui pour le
    /// MiniTimePicker (seules l'heure et les minutes comptent).
    private var dayTimeAsDate: Binding<Date> {
        let calendar = Calendar.planner
        return Binding {
            calendar.date(bySettingHour: dayTime / 60, minute: dayTime % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            dayTime = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
        }
    }

    private static var systemSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #endif
    }
}

// MARK: - Briques

/// Icône dans un carré teinté, comme les lignes de la fiche d'un élément.
private struct SettingsIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Colors.accentDeep)
            .frame(width: 34, height: 34)
            .background(Theme.Colors.tint, in: .rect(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}

/// Interrupteur avec titre et explication, teinté du thème.
private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Theme.Spacing.m) {
                SettingsIcon(systemImage: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(ThemedSwitchStyle())
    }
}

/// Interrupteur maison, identique sur Mac et iPhone : le système dessine
/// une case à cocher sur Mac, ou un interrupteur éteint presque invisible
/// sur les cartes blanches. Ici : piste rose clair éteinte, accent allumée,
/// toujours calée à droite de la ligne.
private struct ThemedSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                configuration.label
                Spacer(minLength: Theme.Spacing.s)
                Capsule()
                    .fill(configuration.isOn ? Theme.Colors.accent : Theme.Colors.gridLine)
                    .frame(width: 46, height: 28)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Theme.Colors.surface)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .padding(3)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "Activé" : "Désactivé")
        .sensoryFeedback(.selection, trigger: configuration.isOn)
    }
}

/// Filet rose clair entre deux lignes, comme dans l'éditeur.
private struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.gridLine)
            .frame(height: 1)
            .padding(.vertical, Theme.Spacing.m)
    }
}

#Preview {
    ScrollView {
        NotificationSettingsSection()
            .padding()
    }
    .background(Theme.Colors.background)
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
