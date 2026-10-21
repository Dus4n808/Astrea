//
//  NotificationSettings.swift
//  Les préférences de notifications, réglées dans l'écran Réglages.
//
//  Elles sont propres à chaque appareil (UserDefaults, pas iCloud) : on peut
//  vouloir être prévenu sur son iPhone mais pas sur son Mac. Le rappel
//  choisi pour une tâche, lui, est synchronisé avec la tâche.
//

import Foundation

nonisolated struct NotificationSettings: Equatable, Sendable {
    /// Interrupteur général : coupé, plus aucune notification sur cet appareil.
    var isEnabled: Bool = true
    /// Heure des rappels des éléments sans heure, en minutes depuis minuit.
    var dayTime: Int = NotificationSettings.defaultDayTime
    /// Ne prévenir que pour les tâches marquées « Important ».
    var importantOnly: Bool = false

    /// 8:00 : assez tôt pour s'organiser, assez tard pour ne pas réveiller.
    static let defaultDayTime = 8 * 60

    // Clés @AppStorage, partagées par les Réglages et le planificateur.
    static let enabledKey = "notifications.enabled"
    static let dayTimeKey = "notifications.dayTime"
    static let importantOnlyKey = "notifications.importantOnly"

    /// Les réglages tels qu'enregistrés (valeurs par défaut si jamais touchés).
    static func load(from defaults: UserDefaults = .standard) -> NotificationSettings {
        NotificationSettings(
            isEnabled: defaults.object(forKey: enabledKey) as? Bool ?? true,
            dayTime: defaults.object(forKey: dayTimeKey) as? Int ?? defaultDayTime,
            importantOnly: defaults.bool(forKey: importantOnlyKey)
        )
    }

    var dayTimeHour: Int { dayTime / 60 }
    var dayTimeMinute: Int { dayTime % 60 }

    /// « 08:00 », pour les textes des Réglages et de l'éditeur.
    var dayTimeText: String {
        String(format: "%02d:%02d", dayTimeHour, dayTimeMinute)
    }
}
