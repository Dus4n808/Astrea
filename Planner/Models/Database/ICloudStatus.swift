//
//  ICloudStatus.swift
//  État du compte iCloud, pour dire à l'utilisateur si ses données se
//  synchronisent vraiment.
//
//  Pourquoi ne pas se fier au conteneur SwiftData : il se crée sans erreur
//  même sans compte iCloud. CloudKit échoue ensuite en arrière-plan, sans
//  rien remonter à l'app. Seul `CKContainer.accountStatus()` dit la vérité.
//
//  Ce n'est qu'une information : sans iCloud l'app marche normalement en
//  local, et SwiftData se met à synchroniser tout seul dès que l'utilisateur
//  se connecte.
//

import CloudKit
import Observation
import OSLog

@Observable
final class ICloudStatus {
    enum State: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        /// Le conteneur CloudKit n'a pas pu être créé : base locale (voir PlannerStore).
        case localOnly
        case unknown
    }

    static let shared = ICloudStatus()

    private(set) var state: State = .checking

    @ObservationIgnored private let log = Logger(subsystem: "Planner", category: "iCloud")

    /// Vérifie l'état tout de suite, puis à chaque connexion, déconnexion ou
    /// changement de compte. À lancer depuis `.task` : s'arrête avec la vue.
    func monitor() async {
        await refresh()
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            await refresh()
        }
    }

    func refresh() async {
        guard PlannerStore.usesCloudKit else {
            state = .localOnly
            return
        }
        do {
            let status = try await CKContainer(identifier: PlannerStore.containerIdentifier).accountStatus()
            state = State(status)
        } catch {
            log.warning("État du compte iCloud illisible : \(error.localizedDescription)")
            state = .unknown
        }
    }
}

extension ICloudStatus.State {
    init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        case .couldNotDetermine: self = .unknown
        @unknown default: self = .unknown
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .checking: "Vérification d'iCloud…"
        case .available: "iCloud activé"
        case .noAccount: "iCloud non connecté"
        case .restricted: "iCloud restreint"
        case .temporarilyUnavailable: "iCloud momentanément indisponible"
        case .localOnly: "Sur cet appareil uniquement"
        case .unknown: "État d'iCloud inconnu"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .checking:
            ""
        case .available:
            "Tes cours et tâches suivent ton compte iCloud sur tous tes appareils."
        case .noAccount:
            "Tes données restent sur cet appareil. Connecte-toi à iCloud dans les Réglages pour les retrouver sur tes autres appareils."
        case .restricted:
            "iCloud est limité sur cet appareil (contrôle parental ou gestion). Tes données restent sur cet appareil."
        case .temporarilyUnavailable:
            "Vérifie ton compte iCloud dans les Réglages. La synchronisation reprendra toute seule."
        case .localOnly:
            "La synchronisation iCloud n'a pas pu démarrer. Tes données restent sur cet appareil."
        case .unknown:
            "Impossible de vérifier ton compte iCloud pour le moment."
        }
    }

    var symbolName: String {
        switch self {
        case .checking: "icloud"
        case .available: "checkmark.icloud"
        case .temporarilyUnavailable, .unknown: "exclamationmark.icloud"
        case .noAccount, .restricted, .localOnly: "icloud.slash"
        }
    }
}
