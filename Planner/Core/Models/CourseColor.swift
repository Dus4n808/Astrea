//
//  CourseColor.swift
//  Palette fermée des couleurs de cours.
//
//  Pourquoi une palette fermée plutôt qu'une couleur libre ?
//  - toutes les couleurs sont choisies pour être lisibles sur le fond rose,
//  - on stocke un simple texte ("blue") en base, stable dans le temps.
//
//  La conversion vers une vraie `Color` SwiftUI est dans
//  DesignSystem/CourseColor+Color.swift (le modèle ne connaît pas SwiftUI).
//

import Foundation

nonisolated enum CourseColor: String, Codable, CaseIterable, Identifiable {
    case blue, graphite, orange, violet, red, green, teal, pink

    var id: String { rawValue }
}
