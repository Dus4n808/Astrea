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

import CoreData
import Foundation
import OSLog
import SwiftData

nonisolated enum PlannerStore {
    /// Tous les modèles persistés par l'app.
    private static let modelTypes: [any PersistentModel.Type] = [
        Course.self,
        PlannerItem.self,
        ChecklistItem.self,
    ]

    static let schema = Schema(modelTypes)

    /// Doit correspondre à `com.apple.developer.icloud-container-identifiers`
    /// dans Planner.entitlements.
    static let containerIdentifier = "iCloud.com.dusanfama.Planner"

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

    /// Vrai si la base a été créée avec CloudKit (faux = repli en local).
    /// Ne dit PAS que la synchronisation marche : sans compte iCloud le
    /// conteneur se crée quand même. Pour ça, voir ICloudStatus.
    private(set) nonisolated(unsafe) static var usesCloudKit = false

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
        #if DEBUG
        // Seulement sur demande : lent, et inutile tant que les modèles ne
        // changent pas. Après un changement de modèle, lancer une fois avec
        // l'argument `-InitCloudKitSchema` (Scheme > Run > Arguments).
        if ProcessInfo.processInfo.arguments.contains("-InitCloudKitSchema") {
            initializeCloudKitSchema(storeURL: cloudConfiguration.url)
        }
        #endif
        do {
            let container = try ModelContainer(for: schema, configurations: cloudConfiguration)
            usesCloudKit = true
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

    #if DEBUG
    /// Envoie le schéma complet (tous les modèles, tous les champs) dans
    /// l'environnement Development de CloudKit.
    ///
    /// Sans ça, CloudKit ne crée un type d'enregistrement que lorsqu'un premier
    /// objet de ce type est synchronisé : un modèle jamais utilisé en
    /// développement (ex. `ChecklistItem`) manque alors au moment de
    /// « Deploy Schema Changes », et la synchronisation casse en Production.
    ///
    /// SwiftData n'expose pas cette fonction : on passe par un conteneur
    /// Core Data temporaire sur le même fichier, retiré juste après.
    private static func initializeCloudKitSchema(storeURL: URL) {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else { return }
        autoreleasepool {
            let description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            description.shouldAddStoreAsynchronously = false

            let container = NSPersistentCloudKitContainer(name: "Planner", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError {
                log.warning("Schéma CloudKit non initialisé (chargement) : \(loadError.localizedDescription)")
                return
            }
            do {
                try container.initializeCloudKitSchema()
                log.info("Schéma CloudKit initialisé dans Development.")
            } catch {
                log.warning("Schéma CloudKit non initialisé : \(error.localizedDescription)")
            }
            // Le fichier doit être libéré avant que SwiftData l'ouvre à son tour.
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif

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
