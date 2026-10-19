//
//  PlannerItem+Display.swift
//  Informations d'affichage dérivées d'un élément, partagées par plusieurs
//  features (Calendrier, Agenda). Garder ça ici évite que chaque écran
//  recalcule la couleur ou le sous-titre à sa façon.
//

import SwiftUI

nonisolated extension PlannerItem {
    /// Couleur d'affichage : celle du cours, sinon une couleur par type.
    /// Main actor : une tâche sans cours prend l'accent du thème actif.
    @MainActor
    var displayColor: Color {
        if let course { return course.color.color }
        switch kind {
        case .task:    return Theme.Colors.accent
        case .event:   return CourseColor.graphite.color
        case .holiday: return CourseColor.teal.color
        }
    }

    /// Ligne secondaire : « méthodes mixtes · 14:30 », ou juste
    /// « méthodes mixtes » quand l'élément n'a pas d'heure.
    var subtitle: String {
        let label = course?.name ?? kind.title
        return isAllDay ? label : "\(label) · \(date.timeText)"
    }
}
