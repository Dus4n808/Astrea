//
//  AppSection.swift
//  Les grandes sections de l'app (onglets sur iPhone, sidebar sur Mac/iPad).
//
//  Pour ajouter une section : ajoute un `case`, donne-lui un titre et une
//  icône SF Symbol, puis branche son écran dans `SectionScreen` (RootView.swift).
//

import AppIntents
import Foundation

nonisolated enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case calendar
    case agenda
    case courses
    case years
    case settings

    var id: String { rawValue }

    /// Texte affiché dans la sidebar et la tab bar.
    var title: String {
        switch self {
        case .calendar: "Calendrier"
        case .agenda:   "Agenda"
        case .courses:  "Cours"
        case .years:    "Années"
        case .settings: "Réglages"
        }
    }

    /// Nom du SF Symbol associé.
    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .agenda:   "list.bullet"
        case .courses:  "book.closed"
        case .years:    "square.grid.2x2"
        case .settings: "gearshape"
        }
    }

    /// Sections affichées dans la navigation principale.
    /// Réglages est à part : en bas de la sidebar sur Mac/iPad.
    static let main: [AppSection] = [.calendar, .agenda, .courses, .years]

    /// Sur iPhone la tab bar est limitée : on garde l'essentiel.
    /// Le bouton « + » n'est pas une section, il est géré à part dans TabShell.
    static let phoneTabs: [AppSection] = [.calendar, .agenda, .courses]
}
// MARK: - Siri et Raccourcis

//  Les valeurs brutes ("calendar", "agenda"…) sont enregistrées telles quelles
//  dans les raccourcis de l'utilisateur : ne jamais les renommer.
extension AppSection: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Section")

    static var caseDisplayRepresentations: [AppSection: DisplayRepresentation] {
        [
            .calendar: "Calendrier",
            .agenda:   "Agenda",
            .courses:  "Cours",
            .years:    "Années",
            .settings: "Réglages",
        ]
    }
}

