//
//  ReminderScheduler.swift
//  Fait correspondre les notifications programmées avec les rappels voulus.
//
//  Chaque appareil programme ses propres notifications, à partir des données
//  synchronisées : une tâche créée, déplacée, cochée ou supprimée sur l'iPhone
//  met à jour les rappels du Mac dès que le changement arrive par iCloud
//  (voir ReminderSyncModifier, qui relance `sync` à chaque changement).
//
//  On ne touche qu'à nos propres demandes (préfixe `reminder.`), et on ne
//  reprogramme que ce qui a changé.
//

import Foundation
import Observation
import UserNotifications

@Observable
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// Ce que le système autorise, pour l'afficher dans les Réglages.
    enum Authorization: Equatable {
        /// Pas encore vérifié.
        case unknown
        /// Jamais demandé : la demande viendra au premier rappel choisi.
        case notDetermined
        case allowed
        /// Refusé dans les réglages du système : seul l'utilisateur peut rouvrir.
        case denied
    }

    private(set) var authorization: Authorization = .unknown

    @ObservationIgnored private var center: UNUserNotificationCenter { .current() }

    // MARK: - Autorisation

    func refreshAuthorization() async {
        let status = await center.notificationSettings().authorizationStatus
        authorization = switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .allowed
        @unknown default: .denied
        }
    }

    /// Demande l'autorisation si elle n'a jamais été demandée. À appeler au
    /// moment où la personne choisit un rappel (c'est là que la question a
    /// du sens, recommandation d'Apple), pas au lancement de l'app.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorization()
        if authorization == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorization()
        }
        return authorization == .allowed
    }

    // MARK: - Synchronisation

    /// Remplace les rappels en attente par ceux qui découlent des données.
    func sync(_ sources: [ReminderSource], settings: NotificationSettings, userName: String) async {
        await refreshAuthorization()
        let wanted = authorization == .allowed
            ? ReminderPlanner.plan(for: sources, settings: settings, userName: userName)
            : []

        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(ReminderPlanner.identifierPrefix) }
        let pendingByID = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })

        // 1. Ce qui n'est plus voulu : tâche cochée, supprimée (ici ou sur un
        //    autre appareil), rappel retiré, notifications coupées…
        let wantedIDs = Set(wanted.map(\.identifier))
        let stale = pendingByID.keys.filter { !wantedIDs.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stale))
        }

        // 2. Ce qui est nouveau ou a changé. Même identifiant = remplacement.
        for reminder in wanted where !Self.matches(pendingByID[reminder.identifier], reminder) {
            try? await center.add(Self.request(for: reminder))
        }
    }

    /// Une notification d'essai, quelques secondes après, depuis les Réglages.
    func sendTest(userName: String) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = userName.isEmpty ? "Coucou !" : "Coucou \(userName) !"
        content.body = "Les rappels d'Astrea sont prêts. On s'occupe de ne rien oublier ✨"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
    }

    // MARK: - Demandes

    private static let calendar = Calendar.planner

    private static func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.subtitle = reminder.subtitle
        content.body = reminder.body
        content.sound = .default
        // Regroupés ensemble dans le centre de notifications.
        content.threadIdentifier = "astrea.reminders"
        // Toucher la notification ouvre la fiche de l'élément.
        content.userInfo = [NotificationDelegate.itemIDKey: reminder.itemID.uuidString]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components(of: reminder.fireDate),
                                                    repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    private static func components(of date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    /// La demande en attente est-elle déjà exactement celle voulue ?
    private static func matches(_ request: UNNotificationRequest?, _ reminder: PlannedReminder) -> Bool {
        guard let request,
              let trigger = request.trigger as? UNCalendarNotificationTrigger
        else { return false }
        let content = request.content
        return trigger.dateComponents == components(of: reminder.fireDate)
            && content.title == reminder.title
            && content.subtitle == reminder.subtitle
            && content.body == reminder.body
    }
}
