//
//  PlannerShortcuts.swift
//  Les phrases que Siri reconnaît sans que l'utilisateur configure quoi que ce soit.
//
//  Deux contraintes du système :
//  - chaque phrase DOIT contenir \(.applicationName), sinon l'index la rejette
//    silencieusement et la phrase ne marche jamais ;
//  - 10 raccourcis maximum par app, vérifié à la compilation.
//
//  Une phrase publiée est un contrat : on peut en ajouter, mais renommer ou
//  supprimer une phrase déjà livrée casse les habitudes vocales des gens.
//

import AppIntents

struct PlannerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Ajoute une tâche dans \(.applicationName)",
                "Nouvelle tâche dans \(.applicationName)",
                "Add a task to \(.applicationName)",
            ],
            shortTitle: "Ajouter une tâche",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: UpcomingTasksIntent(),
            phrases: [
                "Qu'est-ce que j'ai à faire dans \(.applicationName)",
                "Mes tâches à venir dans \(.applicationName)",
                "What's due in \(.applicationName)",
            ],
            shortTitle: "Tâches à venir",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: SetTaskDoneIntent(),
            phrases: [
                "Marque une tâche comme faite dans \(.applicationName)",
                "Coche une tâche dans \(.applicationName)",
            ],
            shortTitle: "Cocher une tâche",
            systemImageName: "checkmark.circle"
        )

        // `section` est un AppEnum : la phrase se décline automatiquement en
        // « ouvre le calendrier / l'agenda / les cours… ».
        AppShortcut(
            intent: OpenPlannerIntent(),
            phrases: [
                "Ouvre \(\.$section) dans \(.applicationName)",
                "Ouvre \(.applicationName)",
            ],
            shortTitle: "Ouvrir Astrea",
            systemImageName: "calendar"
        )
    }
}
