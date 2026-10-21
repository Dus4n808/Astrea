//
//  NotificationDelegate.swift
//  Ce qui se passe quand un rappel arrive, ou quand on le touche.
//
//  - App ouverte : la notification s'affiche quand même (sinon le système
//    la garde silencieusement, et on la raterait en pleine révision).
//  - Toucher la notification : l'app s'ouvre sur la fiche de l'élément.
//
//  Le délégué doit être en place avant la fin du lancement (voir Planner.swift),
//  sinon toucher une notification qui a lancé l'app ne mène nulle part.
//

import Foundation
import SwiftData
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Clé de `userInfo` qui porte l'uuid de l'élément.
    nonisolated static let itemIDKey = "itemID"

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Lu ici : `userInfo` ne peut pas franchir le saut vers le main actor.
        let rawID = response.notification.request.content.userInfo[Self.itemIDKey] as? String
        guard let rawID, let itemID = UUID(uuidString: rawID) else { return }
        await openItem(itemID)
    }

    /// Ouvre la fiche de l'élément, s'il existe encore (il a pu être
    /// supprimé sur un autre appareil depuis la programmation du rappel).
    private func openItem(_ itemID: UUID) {
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { $0.uuid == itemID })
        guard let item = try? PlannerStore.shared.mainContext.fetch(descriptor).first else { return }
        AppState.shared.openDetail(for: item)
    }
}
