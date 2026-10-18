//
//  PlannerIntents.swift
//  Les actions que Siri, Spotlight et l'app Raccourcis peuvent exécuter.
//
//  Trois règles qui ne sautent pas aux yeux :
//  1. `perform()` ne tourne pas sur le main actor : tout passe par
//     PlannerIntentStore (un acteur SwiftData) ou par un saut explicite.
//  2. `perform()` peut être relancé depuis le début (demande de valeur
//     manquante) : on résout tous les paramètres AVANT d'écrire en base.
//  3. Le nom des types et les phrases sont un contrat : un raccourci
//     enregistré par l'utilisateur les rejoue. On ajoute, on ne renomme pas.
//

import AppIntents
import Foundation

// MARK: - Ajouter une tâche

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Ajouter une tâche"
    static let description = IntentDescription(
        "Crée une tâche dans le planner, avec une échéance et un cours facultatifs.",
        categoryName: "Planner"
    )

    @Parameter(title: "Titre", requestValueDialog: "Quelle tâche veux-tu ajouter ?")
    var taskTitle: String

    @Parameter(title: "Échéance")
    var dueDate: Date?

    @Parameter(title: "Cours")
    var course: CourseEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Ajouter \(\.$taskTitle) au planner") {
            \.$dueDate
            \.$course
        }
    }

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some IntentResult & ReturnsValue<PlannerItemEntity> & ProvidesDialog {
        // Toute la résolution d'abord : après l'insertion, un redémarrage de
        // perform() recréerait la tâche une deuxième fois.
        let cleanTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw PlannerIntentError.emptyTitle }

        let day = Calendar.planner.startOfDay(for: dueDate ?? .now)
        let item = try await store.addItem(title: cleanTitle,
                                           kind: .task,
                                           date: day,
                                           courseID: course?.id)

        return .result(value: item, dialog: "« \(cleanTitle) » est ajoutée au \(Self.dayText(day)).")
    }

    private static func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.planner))
    }
}

// MARK: - Cocher / décocher une tâche

struct SetTaskDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Marquer une tâche comme faite"
    static let description = IntentDescription(
        "Coche ou décoche une tâche du planner.",
        categoryName: "Planner"
    )

    @Parameter(title: "Tâche", requestValueDialog: "Quelle tâche ?")
    var task: PlannerItemEntity

    @Parameter(title: "Faite", default: true,
               displayName: Bool.IntentDisplayName(true: "Faite", false: "À faire"))
    var isDone: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Marquer \(\.$task) comme \(\.$isDone)")
    }

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some IntentResult & ReturnsValue<PlannerItemEntity> & ProvidesDialog {
        guard let updated = try await store.setDone(isDone, itemID: task.id) else {
            throw PlannerIntentError.itemNotFound
        }
        let dialog: IntentDialog = isDone
            ? "« \(updated.title) » est cochée."
            : "« \(updated.title) » est remise à faire."
        return .result(value: updated, dialog: dialog)
    }
}

// MARK: - Consulter ce qui arrive

struct UpcomingTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Tâches à venir"
    static let description = IntentDescription(
        "Liste les tâches du planner encore à faire sur les prochains jours.",
        categoryName: "Planner"
    )

    @Parameter(title: "Nombre de jours", default: 7,
               inclusiveRange: (1, 90))
    var days: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Tâches des \(\.$days) prochains jours")
    }

    @Dependency private var store: PlannerIntentStore

    func perform() async throws -> some IntentResult & ReturnsValue<[PlannerItemEntity]> & ProvidesDialog {
        let calendar = Calendar.planner
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else {
            throw PlannerIntentError.invalidRange
        }

        let items = try await store.items(from: start, before: end, pendingOnly: true)
        return .result(value: items, dialog: Self.summary(count: items.count, days: days))
    }

    private static func summary(count: Int, days: Int) -> IntentDialog {
        switch count {
        case 0:  "Rien à faire d'ici là. Profite."
        case 1:  "Une seule chose à faire dans les \(days) prochains jours."
        default: "\(count) choses à faire dans les \(days) prochains jours."
        }
    }
}

// MARK: - Ouvrir une section

struct OpenPlannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir le planner"
    static let description = IntentDescription(
        "Ouvre le planner sur le calendrier ou sur l'agenda.",
        categoryName: "Planner"
    )

    /// L'interface EST le résultat de cette action : on passe au premier plan
    /// avant d'exécuter `perform()`.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Section", default: .calendar,
               requestDisambiguationDialog: "Quelle section veux-tu ouvrir ?")
    var section: AppSection

    static var parameterSummary: some ParameterSummary {
        Summary("Ouvrir \(\.$section)")
    }

    @Dependency private var navigation: AppState

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.section = section
        return .result()
    }
}

// MARK: - Erreurs

/// Conformer à `CustomLocalizedStringResourceConvertible` est ce qui fait
/// qu'une erreur s'affiche telle quelle dans Siri. Sans ça, l'utilisateur
/// n'a droit qu'à un « une erreur est survenue » générique.
nonisolated enum PlannerIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyTitle
    case itemNotFound
    case invalidRange
    case recurrenceUnsupported
    case locationUnsupported

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyTitle:            "Il faut un titre pour créer une tâche."
        case .itemNotFound:          "Cette tâche n'existe plus dans le planner."
        case .invalidRange:          "Cette période n'est pas valide."
        case .recurrenceUnsupported: "Le planner ne gère pas encore les tâches qui se répètent."
        case .locationUnsupported:   "Le planner ne gère pas les rappels liés à un lieu."
        }
    }
}
