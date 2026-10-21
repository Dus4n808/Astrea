//
//  ReminderSyncModifier.swift
//  Relance la programmation des rappels dès que quelque chose change.
//
//  Observe :
//  - les éléments qui ont un rappel (création, modification, cochage,
//    suppression — y compris ce qui arrive d'un autre appareil par iCloud,
//    ou de Siri) ;
//  - les réglages de notifications et le prénom (il apparaît dans certains
//    messages) ;
//  - le retour dans l'app : l'autorisation a pu changer dans les réglages
//    du système, et des rappels lointains peuvent maintenant entrer dans la
//    limite des 64 notifications en attente.
//
//  `.task(id:)` annule le passage précédent quand une nouvelle valeur
//  arrive : la petite attente regroupe une rafale de changements (frappe
//  dans un titre, réception iCloud de plusieurs tâches) en un seul passage.
//

import SwiftData
import SwiftUI

struct ReminderSyncModifier: ViewModifier {
    @Query(filter: #Predicate<PlannerItem> { $0.reminderRaw != "" })
    private var itemsWithReminder: [PlannerItem]

    @AppStorage(NotificationSettings.enabledKey) private var isEnabled = true
    @AppStorage(NotificationSettings.dayTimeKey) private var dayTime = NotificationSettings.defaultDayTime
    @AppStorage(NotificationSettings.importantOnlyKey) private var importantOnly = false
    @AppStorage(UserName.storageKey) private var userName = ""
    @Environment(\.scenePhase) private var scenePhase

    // Lit les modèles SwiftData de la vue : main actor obligatoire.
    @MainActor
    func body(content: Content) -> some View {
        let key = SyncKey(
            sources: itemsWithReminder.map(ReminderSource.init),
            settings: NotificationSettings(isEnabled: isEnabled, dayTime: dayTime, importantOnly: importantOnly),
            userName: userName,
            isActive: scenePhase == .active
        )
        content.task(id: key) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await ReminderScheduler.shared.sync(key.sources, settings: key.settings, userName: key.userName)
        }
    }

    private struct SyncKey: Equatable {
        let sources: [ReminderSource]
        let settings: NotificationSettings
        let userName: String
        let isActive: Bool
    }
}

extension View {
    /// Tient les notifications de rappel à jour (à poser une fois, sur la racine).
    func syncsReminders() -> some View {
        modifier(ReminderSyncModifier())
    }
}
