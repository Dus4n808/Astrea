//
//  CoursesScreen.swift
//  Liste des cours : ajouter, renommer, changer la couleur, supprimer.
//

import SwiftUI
import SwiftData

struct CoursesScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Course.name) private var courses: [Course]

    /// Cours ouvert dans l'éditeur. `.new` = création.
    @State private var editing: CourseEditorTarget?

    var body: some View {
        List {
            ForEach(courses) { course in
                Button {
                    editing = .existing(course)
                } label: {
                    CourseRow(course: course)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .overlay {
            if courses.isEmpty {
                EmptyStateView(title: "Aucun cours",
                               message: "Ajoute tes cours pour colorer ton calendrier.")
            }
        }
        .navigationTitle("Cours")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nouveau cours", systemImage: "plus") { editing = .new }
            }
        }
        .sheet(item: $editing) { target in
            CourseEditorView(target: target)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(courses[index]) }
    }
}

/// Une ligne de la liste : le cours et ses tâches restantes.
///
/// Vue à part : le compteur parcourt les éléments du cours. Cocher une
/// tâche ne recalcule ainsi que la ligne de son cours, pas toute la liste.
private struct CourseRow: View {
    let course: Course

    var body: some View {
        HStack {
            CourseChip(name: course.name, color: course.color.color)
            Spacer()
            Text(pendingCountText)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .contentShape(.rect)
    }

    /// « 3 à faire » (tâches non terminées de ce cours).
    private var pendingCountText: String {
        let pending = course.allItems.filter { $0.kind == .task && !$0.isDone }.count
        return pending == 0 ? "" : "\(pending) à faire"
    }
}

#Preview {
    NavigationStack {
        CoursesScreen()
    }
    .modelContainer(PlannerStore.preview)
}
