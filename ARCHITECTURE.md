# Planner — Architecture

App SwiftUI multiplateforme (iPhone, iPad, Mac) avec SwiftData, synchronisée
entre appareils via CloudKit. Une cible app + une cible de tests ; un seul code :
les différences de plateforme sont gérées par la taille d'écran (sidebar vs
tab bar) et quelques `#if os(macOS)`.

## Les dossiers

Chaque dossier répond à une question : « je cherche quoi ? ». On descend du
plus global (l'app, la navigation) vers le plus précis (un écran, un modèle).

```
Planner/
├── App/            Démarrage de l'app
│   ├── Planner.swift          @main, branche la base de données et Siri
│   ├── AppState.swift         section affichée + feuille d'édition ouverte
│   └── AppSection.swift       liste des sections (Calendrier, Agenda…)
│
├── MainView/       La vue principale et la navigation
│   ├── RootView.swift         LA vue racine : choisit la coque et présente l'éditeur
│   ├── TabShell.swift         coque iPhone (tab bar + le « + »)
│   ├── SidebarShell.swift     coque iPad / Mac (sidebar + contenu)
│   └── AddItemButton.swift    le « + » de la barre d'outils
│
├── Screens/        Un dossier par écran
│   ├── Calendar/              vue mois (grille, en-tête, jour sélectionné)
│   ├── Agenda/                liste par jour + progression de la semaine
│   ├── Courses/               liste des cours + feuille de création
│   ├── ItemEditor/            feuille créer / modifier un élément
│   └── ComingSoon/            écran temporaire (Années, Réglages)
│
├── Design/         À quoi l'app ressemble
│   ├── Theme.swift            couleurs, polices, espacements (= variables Figma)
│   ├── CourseColor+Color.swift
│   └── Components/            StarLogo, EventPill, CourseChip, ItemRow, FlowLayout
│
├── Models/         Les données
│   ├── PlannerItem, ChecklistItem, Course, CourseColor, ItemKind   (SwiftData)
│   ├── PlannerItem+Display.swift  couleur et sous-titre d'un élément
│   └── Database/              création de la base (iCloud + repli local) + exemples
│
├── Logic/          Les calculs, sans aucune interface
│   ├── MonthGrid.swift        les 42 cases d'un mois
│   ├── ItemIndex.swift        les éléments rangés par jour
│   └── Calendar+Planner.swift, Date+Formatting.swift
│
└── Siri/           Siri, Apple Intelligence et Raccourcis
    ├── PlannerIntents.swift      actions à phrases fixes (« Ajoute une tâche dans Planner »)
    ├── PlannerShortcuts.swift    les phrases
    ├── AppleIntelligence.swift   schémas `.reminders` : Siri en langage naturel
    ├── PlannerSpotlight.swift    index Spotlight (là où Siri cherche les tâches)
    ├── PlannerDonations.swift    ce qu'on fait dans l'app, signalé à Siri
    └── PlannerEntities.swift, PlannerIntentStore.swift

PlannerTests/       tests unitaires (Swift Testing)
```

## Règles de dépendance

```
MainView ──► Screens ──► Design ──► (rien)
                 │
                 └─────► Models, Logic ──► (rien)
App ──► MainView, Siri
```

- **Logic** ne connaît pas SwiftUI : on peut le tester avec de simples tests unitaires.
- **Design** ne connaît pas les modèles : un composant reçoit du texte et
  des couleurs, jamais un `PlannerItem`. On peut donc le réutiliser partout.
- **Screens** assemble les deux. Un écran n'importe jamais un autre écran ;
  ce qui doit être partagé remonte dans `Design/Components` ou `Logic`.

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
6. **Apple Intelligence** passe par deux portes :
   - les intents à *schéma* (`AppleIntelligence.swift`) : une tâche y est un
     « rappel », un cours une « liste ». Siri les remplit à partir de phrases
     libres. Elles sont `isAssistantOnly` (cachées dans Raccourcis) pour ne
     pas doubler les intents classiques ;
   - l'index Spotlight, que Siri consulte pour retrouver « ma tâche X ».
     Réindexé au lancement, en arrière-plan, et après chaque écriture Siri.

## Contraintes à ne pas casser

- **Modèles compatibles CloudKit** : tout attribut a une valeur par défaut ou
  est optionnel, toute relation « à plusieurs » est optionnelle et possède un
  inverse, aucun `@Attribute(.unique)`. Une violation fait retomber l'app en
  base locale *sans rien afficher* — `CloudKitSchemaTests` monte la garde.
- **`uuid` est un contrat** : c'est l'identifiant que Siri enregistre dans les
  raccourcis de l'utilisateur. Il ne change jamais pour un élément donné.
- **Valeurs brutes des enums exposés à Siri** (`ItemKind`, `AppSection`) :
  on peut en ajouter, jamais renommer — les raccourcis déjà créés les rejouent.
- **Schémas Apple Intelligence** : leur forme est imposée et vérifiée au
  build. On ne renomme ni ne retire une propriété d'un type `@AppIntent(schema:)`
  / `@AppEntity(schema:)`. `CourseListEntity.noCourseID` est un contrat comme `uuid`.
- **Types purs en `nonisolated`** : l'app compile avec l'isolation main actor
  par défaut. Tout ce qu'un intent doit pouvoir appeler (`Calendar.planner`,
  `Theme`, les modèles, `MonthGrid`) est explicitement `nonisolated`.

## Recettes

| Je veux…                         | Où ?                                                     |
|----------------------------------|----------------------------------------------------------|
| changer une couleur de l'app     | `Design/Theme.swift`                                     |
| changer l'allure des cartes      | `plannerCard()` dans `Design/Theme.swift`                |
| ajouter une couleur de cours     | `Models/CourseColor.swift` + `Design/CourseColor+Color.swift` |
| ajouter une section              | `App/AppSection.swift` puis `SectionScreen` dans `MainView/RootView.swift` |
| ajouter un champ à une tâche     | `Models/PlannerItem.swift`, puis `ItemDraft.swift` et `ItemEditorView.swift` |
| ajouter un modèle SwiftData      | le créer dans `Models/` + l'ajouter à `PlannerStore.schema` |
| ajouter une action Siri          | `Siri/PlannerIntents.swift` + une phrase dans `PlannerShortcuts.swift` |
| ajouter un schéma Apple Intelligence | `Siri/AppleIntelligence.swift` ; dans Xcode, taper `reminders_` propose les modèles |

## Prochaines étapes prévues

- **Pondérations** : catégories de notes par cours (« Grade Weight Category »).
- **Années / semestres** : regrouper les cours par période.
- Mode sombre (couleurs adaptatives dans `Theme`).
- Écran Réglages, avec l'état de la synchronisation (`PlannerStore.isSyncing`).
