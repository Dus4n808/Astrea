# Planner — Architecture

App SwiftUI multiplateforme (iPhone, iPad, Mac) avec SwiftData, synchronisée
entre appareils via CloudKit. Une cible app + une cible de tests ; un seul code :
les différences de plateforme sont gérées par la taille d'écran (sidebar vs
tab bar) et quelques `#if os(macOS)`.

## Les 4 dossiers

```
Planner/
├── App/            Démarrage + navigation globale
│   ├── Planner.swift          @main, branche la base de données
│   ├── RootView.swift         choisit TabShell (iPhone) ou SidebarShell (Mac/iPad)
│   ├── AppState.swift         section affichée + feuille d'édition ouverte
│   ├── AppSection.swift       liste des sections (Calendrier, Agenda…)
│   └── Shells/                les deux « coques » de navigation
│
├── Core/           Le cœur, sans aucune interface
│   ├── Models/                Course, PlannerItem, ChecklistItem (SwiftData)
│   ├── Persistence/           création de la base (iCloud + repli local) + exemples
│   └── Calendar/              calculs de dates (grille du mois, index par jour)
│
├── DesignSystem/   Les briques visuelles réutilisables
│   ├── Theme.swift            couleurs, polices, espacements (= variables Figma)
│   └── Components/            StarLogo, EventPill, CourseChip, ItemRow, FlowLayout
│
└── Features/       Un dossier par fonctionnalité
    ├── Calendar/              vue mois
    ├── Agenda/                liste par jour + progression de la semaine
    ├── Editor/                feuille créer / modifier un élément
    ├── Courses/               gestion des cours
    ├── Intents/               Siri et Raccourcis (entités, actions, phrases)
    ├── ComingSoon/            écran temporaire (Années, Réglages)
    └── Shared/                petits morceaux utilisés par plusieurs features

PlannerTests/       tests unitaires (Swift Testing)
```

## Règles de dépendance

```
Features ──► DesignSystem ──► (rien)
   │
   └──────► Core ──► (rien)
App ──► Features
```

- **Core** ne connaît pas SwiftUI : on peut le tester avec de simples tests unitaires.
- **DesignSystem** ne connaît pas les modèles : un composant reçoit du texte et
  des couleurs, jamais un `PlannerItem`. On peut donc le réutiliser partout.
- **Features** assemble les deux. Une feature n'importe jamais une autre feature
  (sauf `Features/Shared`).

## Comment les données circulent

1. SwiftData stocke tout (`PlannerStore.shared`).
2. Les écrans lisent avec `@Query` → ils se mettent à jour automatiquement.
3. Pour **ouvrir l'éditeur**, une vue appelle `appState.openEditor(...)`.
   `RootView` voit la demande et présente `ItemEditorView`.
4. L'éditeur travaille sur une **copie** (`ItemDraft`) et n'écrit dans la base
   qu'au clic sur Valider. Annuler ne laisse donc aucune trace.
5. **Siri et les Raccourcis** n'utilisent pas ce chemin : `perform()` peut
   tourner sans aucune vue à l'écran et hors du main actor. Ils passent par
   `PlannerIntentStore`, un `@ModelActor` avec son propre contexte, enregistré
   comme dépendance dans `Planner.init()`.

## Contraintes à ne pas casser

- **Modèles compatibles CloudKit** : tout attribut a une valeur par défaut ou
  est optionnel, toute relation « à plusieurs » est optionnelle et possède un
  inverse, aucun `@Attribute(.unique)`. Une violation fait retomber l'app en
  base locale *sans rien afficher* — `CloudKitSchemaTests` monte la garde.
- **`uuid` est un contrat** : c'est l'identifiant que Siri enregistre dans les
  raccourcis de l'utilisateur. Il ne change jamais pour un élément donné.
- **Valeurs brutes des enums exposés à Siri** (`ItemKind`, `AppSection`) :
  on peut en ajouter, jamais renommer — les raccourcis déjà créés les rejouent.
- **Types purs en `nonisolated`** : l'app compile avec l'isolation main actor
  par défaut. Tout ce qu'un intent doit pouvoir appeler (`Calendar.planner`,
  `Theme`, les modèles, `MonthGrid`) est explicitement `nonisolated`.

## Recettes

| Je veux…                         | Où ?                                                     |
|----------------------------------|----------------------------------------------------------|
| changer une couleur de l'app     | `DesignSystem/Theme.swift`                               |
| ajouter une couleur de cours     | `Core/Models/CourseColor.swift` + `CourseColor+Color.swift` |
| ajouter une section              | `AppSection.swift` puis `SectionScreen` dans `RootView.swift` |
| ajouter un champ à une tâche     | `PlannerItem.swift`, puis `ItemDraft.swift` et `ItemEditorView.swift` |
| ajouter un modèle SwiftData      | le créer dans `Core/Models/` + l'ajouter à `PlannerStore.schema` |
| ajouter une action Siri          | `Features/Intents/PlannerIntents.swift` + une phrase dans `PlannerShortcuts.swift` |

## Prochaines étapes prévues

- **Pondérations** : catégories de notes par cours (« Grade Weight Category »).
- **Années / semestres** : regrouper les cours par période.
- Mode sombre (couleurs adaptatives dans `Theme`).
- Écran Réglages, avec l'état de la synchronisation (`PlannerStore.isSyncing`).
