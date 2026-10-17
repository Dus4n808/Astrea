//
//  ChecklistItem.swift
//  Une ligne de checklist à l'intérieur d'une tâche.
//

import Foundation
import SwiftData

@Model
nonisolated final class ChecklistItem {
    var title: String = ""
    var isDone: Bool = false

    /// Position dans la liste (0, 1, 2…). Voir PlannerItem.sortedChecklist.
    var order: Int = 0

    /// Tâche parente (la relation inverse est déclarée dans PlannerItem).
    var parent: PlannerItem?

    init(title: String, order: Int, isDone: Bool = false) {
        self.title = title
        self.order = order
        self.isDone = isDone
    }
}
