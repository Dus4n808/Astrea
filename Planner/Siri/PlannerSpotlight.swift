//
//  PlannerSpotlight.swift
//  Tient l'index Spotlight à jour avec les tâches.
//
//  Pourquoi c'est important pour Siri : Apple Intelligence retrouve « ma
//  tâche de lecture » en cherchant dans l'index Spotlight de l'app. Une
//  tâche non indexée existe pour l'app, mais pas pour Siri.
//
//  Quand on indexe :
//  - après chaque écriture faite par Siri (intents d'AppleIntelligence.swift) ;
//  - au lancement et quand l'app passe en arrière-plan (RootView), pour
//    rattraper tout ce qui a été modifié dans l'interface.
//
//  Un échec d'indexation n'est jamais bloquant : la tâche est en base, seule
//  la recherche Siri / Spotlight sera en retard jusqu'à la prochaine passe.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

nonisolated enum PlannerSpotlight {

    static func index(_ tasks: [TaskReminderEntity]) async {
        try? await CSSearchableIndex.default().indexAppEntities(tasks)
    }

    static func remove(_ ids: [UUID]) async {
        try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: ids,
                                                                 ofType: TaskReminderEntity.self)
    }

    /// Repart de zéro : efface puis réindexe toutes les tâches. Sans
    /// l'effacement, une tâche supprimée dans l'app resterait trouvable.
    static func reindexAll(container: ModelContainer = PlannerStore.shared) async {
        let store = PlannerIntentStore(modelContainer: container)
        guard let tasks = try? await store.allTaskReminders() else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: TaskReminderEntity.self)
        try? await index.indexAppEntities(tasks)
    }
}
