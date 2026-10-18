//
//  PlannerStore.swift
//  Création de la base de données SwiftData.
//
//  - `shared`  : la vraie base, enregistrée sur l'appareil et synchronisée
//                avec iCloud (base privée CloudKit) quand c'est possible.
//  - `preview` : une base en mémoire remplie d'exemples, pour les #Preview.
//
//  Pour ajouter un nouveau modèle : l'ajouter dans `schema` ci-dessous.
//
//  Contraintes CloudKit (à respecter dans tout nouveau modèle, sinon la
//  synchronisation s'éteint silencieusement) :
//  - chaque attribut a une valeur par défaut, ou est optionnel ;
//  - chaque relation est optionnelle ou a une valeur par défaut, et possède
//    une relation inverse ;
//  - pas de `@Attribute(.unique)` : CloudKit ne sait pas l'appliquer.
//

import Foundation
import OSLog
import SwiftData

nonisolated enum PlannerStore {
    /// Tous les modèles persistés par l'app.
    static let schema = Schema([
        Course.self,
        PlannerItem.self,
        ChecklistItem.self,
    ])

    private static let log = Logger(subsystem: "Planner", category: "Persistence")

    /// Base principale de l'app, synchronisée entre les appareils du compte iCloud.
    ///
    /// Pas de données d'exemple ici, même en DEBUG : la base peut être vide au
    /// lancement simplement parce que la première synchronisation n'est pas
    /// encore descendue. Semer à ce moment-là dupliquerait les exemples sur
    /// chaque appareil. Les exemples restent dans `preview`.
    static let shared: ModelContainer = makeSharedContainer()

    /// Base en mémoire pour les aperçus Xcode (jamais enregistrée, jamais synchronisée).
    /// `mainContext` est isolé au main actor, et les aperçus s'y construisent.
    @MainActor
    static let preview: ModelContainer = {
        let container = makeLocalContainer(inMemory: true)
        SampleData.insertIfEmpty(into: container.mainContext)
        return container
    }()

    /// Vrai si la base tourne effectivement avec iCloud.
    /// Utile pour afficher « Synchronisé » dans les réglages, plus tard.
    private(set) nonisolated(unsafe) static var isSyncing = false

    // MARK: - Construction

    /// iCloud d'abord, local ensuite.
    ///
    /// Le repli n'est pas de la prudence excessive : la création du conteneur
    /// CloudKit échoue dès que l'app n'est pas provisionnée pour iCloud
    /// (identifiant de bundle de développement, build non signée, conteneur
    /// pas encore créé sur le portail). Planter au lancement dans ces cas-là
    /// rendrait l'app inutilisable alors qu'elle fonctionne très bien en local.
    private static func makeSharedContainer() -> ModelContainer {
        let cloudConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            let container = try ModelContainer(for: schema, configurations: cloudConfiguration)
            isSyncing = true
            return container
        } catch {
            log.warning("""
                Synchronisation iCloud indisponible, la base reste locale. \
                Vérifie que l'app a bien un identifiant de bundle réel et un \
                conteneur iCloud provisionné. Détail : \(error.localizedDescription)
                """)
            return makeLocalContainer(inMemory: false)
        }
    }

    private static func makeLocalContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Sans base de données l'app ne peut rien faire : on arrête avec
            // un message clair plutôt que de continuer dans un état cassé.
            fatalError("Impossible de créer la base SwiftData : \(error)")
        }
    }
}
