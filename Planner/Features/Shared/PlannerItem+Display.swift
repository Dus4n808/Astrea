//
//  PlannerItem+Display.swift
//  Informations d'affichage dérivées d'un élément, partagées par plusieurs
//  features (Calendrier, Agenda). Garder ça ici évite que chaque écran
//  recalcule la couleur ou le sous-titre à sa façon.
//

import SwiftUI

nonisolated extension PlannerItem {
    /// Couleur d'affichage : celle du cours, sinon une couleur par type.
    var displayColor: Color {
        if let course { return course.color.color }
        switch kind {
        case .task:    return Theme.Colors.pink
        case .event:   return CourseColor.graphite.color
        case .holiday: return CourseColor.teal.color
        }
    }

    /// Ligne secondaire : « méthodes mixtes · Fin de journée »
    var subtitle: String {
        let time = isAllDay ? "Fin de journée" : date.timeText
        if let course { return "\(course.name) · \(time)" }
        return "\(kind.title) · \(time)"
    }
}
