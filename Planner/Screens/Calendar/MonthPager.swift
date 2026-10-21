//
//  MonthPager.swift
//  Défilement horizontal page par page entre les mois.
//
//  Un mois = une page large comme l'écran. Le défilement s'arrête
//  toujours pile sur un mois (`.paging`), et `scrollPosition` tient
//  `CalendarState.displayedMonth` à jour pendant le glissement : l'en-tête
//  (le gros numéro, le nom du mois) suit donc le doigt.
//
//  Les flèches de la barre d'outils écrivent dans le même état, donc elles
//  font défiler la grille au lieu de la remplacer d'un coup.
//

import SwiftUI

struct MonthPager: View {
    let index: ItemIndex
    let state: CalendarState
    let layout: CalendarLayout

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(state.months, id: \.self) { month in
                    MonthGridView(grid: state.grid(for: month),
                                  index: index,
                                  state: state,
                                  layout: layout)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: Bindable(state).scrolledMonth)
        // Toutes les grilles font 6 semaines : la hauteur ne saute pas d'un
        // mois à l'autre, donc rien à figer ici.
    }
}
