//
//  Planner.swift
//  Point d'entrée de l'application (iOS, iPadOS et macOS).
//
//  Rôle de ce fichier : uniquement « brancher » les briques globales.
//  - la base de données SwiftData (PlannerStore)
//  - les dépendances des App Intents (Siri, Raccourcis)
//  - la vue racine (RootView)
//  Aucune logique métier ici : si tu cherches comment une feature marche,
//  va dans Features/<NomDeLaFeature>/.
//

import AppIntents
import SwiftUI
import SwiftData

@main
struct Planner: App {

    init() {
        // Les dépendances des intents s'enregistrent ici et nulle part
        // ailleurs : Siri peut lancer le processus sans aucune vue à l'écran,
        // et lire une dépendance non enregistrée est une erreur fatale.
        // Valeurs sorties de la closure : `add(dependency:)` prend une
        // autoclosure Sendable, qui ne peut pas lire d'état isolé au main actor.
        let intentStore = PlannerIntentStore(modelContainer: PlannerStore.shared)
        let navigation = AppState.shared
        AppDependencyManager.shared.add(dependency: intentStore)
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Une seule base pour toute l'app, partagée par toutes les fenêtres.
        .modelContainer(PlannerStore.shared)
        #if os(macOS)
        // Taille d'ouverture confortable pour la vue mois sur Mac.
        .defaultSize(width: 1280, height: 820)
        #endif
    }
}
