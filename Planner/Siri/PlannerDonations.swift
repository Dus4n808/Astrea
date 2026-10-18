//
//  PlannerDonations.swift
//  Signale à Siri ce que la personne fait dans l'app.
//
//  App Intents ne « voit » pas les actions faites dans l'interface : seules
//  les intents lancées par Siri ou Raccourcis sont données automatiquement.
//  Sans donation, Siri ne peut pas apprendre qu'on ajoute une lecture tous
//  les lundis, et les suggestions restent vides.
//
//  On donne l'intent « publique » (AddTaskIntent, celle qui a des phrases),
//  après l'enregistrement réussi — jamais avant.
//

import AppIntents
import Foundation

enum PlannerDonations {

    static func taskCreated(title: String, date: Date, course: Course?) {
        let intent = AddTaskIntent()
        intent.taskTitle = title
        intent.dueDate = date
        intent.course = course.map(CourseEntity.init)
        // Une donation ratée ne doit jamais gêner l'enregistrement.
        Task { try? await IntentDonationManager.shared.donate(intent: intent) }
    }
}
