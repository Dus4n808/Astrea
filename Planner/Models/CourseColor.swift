//
//  CourseColor.swift
//  Palette fermée des couleurs de cours.
//
//  Pourquoi une palette fermée plutôt qu'une couleur libre ?
//  - toutes les couleurs sont choisies pour être lisibles sur le fond rose,
//  - on stocke un simple texte ("blue") en base, stable dans le temps.
//
//  20 couleurs pour couvrir une année chargée (15-20 cours) sans doublon.
//  L'ordre des cas est celui de la grille du sélecteur : 4 lignes de 5,
//  une famille par ligne (chauds, verts, bleus, violets + neutres).
//  Ne jamais renommer une valeur brute : elle est enregistrée dans les cours.
//
//  La conversion vers une vraie `Color` SwiftUI est dans
//  Design/CourseColor+Color.swift (le modèle ne connaît pas SwiftUI).
//

import Foundation

nonisolated enum CourseColor: String, Codable, CaseIterable, Identifiable {
    case raspberry, pink, red, orange, mustard
    case olive, lime, green, forest, teal
    case sky, cobalt, blue, lavender, violet
    case orchid, plum, cocoa, slate, graphite

    var id: String { rawValue }

    /// Ordre de proposition pour un nouveau cours : on alterne les familles
    /// pour que des cours créés à la suite soient bien différents à l'œil.
    static let suggestionOrder: [CourseColor] = [
        .blue, .orange, .green, .violet, .red, .teal, .pink, .mustard, .cobalt, .plum,
        .lime, .raspberry, .sky, .cocoa, .lavender, .forest, .orchid, .olive, .slate, .graphite,
    ]

    /// Première couleur encore libre ; si tout est pris, celle qui l'est le
    /// moins souvent (à égalité, l'ordre de proposition décide).
    static func suggested(avoiding used: [CourseColor]) -> CourseColor {
        let counts = Dictionary(used.map { ($0, 1) }, uniquingKeysWith: +)
        return suggestionOrder.min { counts[$0, default: 0] < counts[$1, default: 0] } ?? .blue
    }
}
