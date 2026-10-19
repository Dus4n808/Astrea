//
//  PlannerTests.swift
//  Contrats du modèle et de l'intégration Siri.
//
//  Beaucoup de ces vérifications protègent contre des plantages à l'exécution
//  qui ne se voient pas à la compilation : un AppEnum auquel il manque un
//  libellé plante au moment où Siri l'affiche, pas avant.
//

import AppIntents
import Foundation
import SwiftData
import Testing

@testable import Planner

// MARK: - Modèle

@Suite("Modèle")
struct ModelTests {

    @Test("kind est bien relu depuis sa valeur stockée")
    func kindRoundTrip() {
        for kind in ItemKind.allCases {
            let item = PlannerItem(title: "x", kind: kind, date: .now)
            #expect(item.kind == kind)
            #expect(item.kindRaw == kind.rawValue)
        }
    }

    @Test("Une valeur de type inconnue retombe sur « tâche »")
    func unknownKindFallsBack() {
        // Scénario réel : une version future ajoute un type, puis l'utilisateur
        // rouvre l'app avec une ancienne version synchronisée via iCloud.
        let item = PlannerItem(title: "x", date: .now)
        item.kindRaw = "quelque-chose-de-futur"
        #expect(item.kind == .task)
    }

    @Test("Une couleur de cours inconnue retombe sur bleu")
    func unknownColorFallsBack() {
        let course = Course(name: "x", color: .orange)
        course.colorRaw = "fuchsia-neon"
        #expect(course.color == .blue)
    }

    @Test("Les couleurs déjà enregistrées gardent leur valeur brute")
    func courseColorRawValuesAreStable() {
        // Valeurs stockées dans les cours existants : les renommer les ferait
        // tous retomber sur bleu.
        let legacy = ["blue", "graphite", "orange", "violet", "red", "green", "teal", "pink"]
        for raw in legacy { #expect(CourseColor(rawValue: raw) != nil, "\(raw)") }
    }

    @Test("L'ordre de proposition contient chaque couleur une seule fois")
    func suggestionOrderCoversPalette() {
        #expect(CourseColor.suggestionOrder.count == CourseColor.allCases.count)
        #expect(Set(CourseColor.suggestionOrder) == Set(CourseColor.allCases))
    }

    @Test("Un nouveau cours reçoit une couleur encore libre")
    func suggestedColorIsFree() {
        #expect(CourseColor.suggested(avoiding: []) == .blue)
        #expect(CourseColor.suggested(avoiding: [.blue]) == .orange)
        // 20 cours sur 20 couleurs : toutes différentes.
        var used: [CourseColor] = []
        for _ in CourseColor.allCases { used.append(CourseColor.suggested(avoiding: used)) }
        #expect(Set(used).count == CourseColor.allCases.count)
        // Palette pleine : on repart sur la moins utilisée.
        #expect(CourseColor.suggested(avoiding: used) == .blue)
    }

    @Test("Chaque élément reçoit un identifiant stable distinct")
    func uuidsAreUnique() {
        // Cet identifiant est la clé que Siri enregistre dans les raccourcis.
        let uuids = (0..<50).map { _ in PlannerItem(title: "x", date: .now).uuid }
        #expect(Set(uuids).count == 50)
    }

    @Test("La checklist est triée par position, pas par ordre d'insertion")
    func checklistIsSorted() {
        // SwiftData ne garantit pas l'ordre d'un tableau de relation.
        let item = PlannerItem(title: "devoir", date: .now)
        item.checklist = [
            ChecklistItem(title: "troisième", order: 2),
            ChecklistItem(title: "premier", order: 0),
            ChecklistItem(title: "deuxième", order: 1),
        ]
        #expect(item.sortedChecklist.map(\.title) == ["premier", "deuxième", "troisième"])
    }

    @Test("Seules les tâches sont cochables")
    func onlyTasksAreCheckable() {
        #expect(ItemKind.task.isCheckable)
        #expect(!ItemKind.event.isCheckable)
        #expect(!ItemKind.holiday.isCheckable)
    }
}

// MARK: - Compatibilité CloudKit

@Suite("Schéma CloudKit")
struct CloudKitSchemaTests {

    @Test("Le schéma satisfait les règles de CloudKit")
    func schemaIsCloudKitCompatible() throws {
        // Un modèle qui viole les règles CloudKit (attribut sans valeur par
        // défaut, relation « à plusieurs » non optionnelle, relation sans
        // inverse) fait silencieusement retomber l'app en base locale : la
        // synchronisation ne marche plus et rien ne le signale à l'écran.
        let configuration = ModelConfiguration(schema: PlannerStore.schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .automatic)
        _ = try ModelContainer(for: PlannerStore.schema, configurations: configuration)
    }
}

// MARK: - Types exposés à Siri

@Suite("Métadonnées App Intents")
struct AppIntentsMetadataTests {

    @Test("Chaque type d'élément a un libellé pour Siri")
    func itemKindHasEveryCase() {
        // Un cas manquant ici est un fatalError au moment où Siri l'affiche.
        for kind in ItemKind.allCases {
            #expect(ItemKind.caseDisplayRepresentations[kind] != nil, "\(kind)")
        }
    }

    @Test("Chaque section a un libellé pour Siri")
    func appSectionHasEveryCase() {
        for section in AppSection.allCases {
            #expect(AppSection.caseDisplayRepresentations[section] != nil, "\(section)")
        }
    }

    @Test("Les valeurs brutes exposées à Siri n'ont pas changé")
    func rawValuesAreStable() {
        // Ces chaînes sont enregistrées dans les raccourcis des utilisateurs.
        // Les renommer casse silencieusement les raccourcis déjà créés.
        #expect(ItemKind.task.rawValue == "task")
        #expect(ItemKind.event.rawValue == "event")
        #expect(ItemKind.holiday.rawValue == "holiday")

        #expect(AppSection.calendar.rawValue == "calendar")
        #expect(AppSection.agenda.rawValue == "agenda")
        #expect(AppSection.courses.rawValue == "courses")
        #expect(AppSection.settings.rawValue == "settings")
    }

    @Test("Le nombre de raccourcis respecte la limite du système")
    func shortcutCountWithinLimit() {
        // Dépasser 10 fait échouer la compilation, mais le message vient de
        // l'extracteur de métadonnées : autant le voir ici d'abord.
        #expect(PlannerShortcuts.appShortcuts.count <= 10)
    }

    // Le contenu des phrases n'est pas lisible à l'exécution (`AppShortcut`
    // n'expose pas `phrases`). La règle « chaque phrase contient
    // \(.applicationName) » est vérifiée par Xcode, qui émet un avertissement
    // de compilation si elle n'est pas respectée.
}
