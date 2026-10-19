//
//  DayCell.swift
//  Une case (un jour) de la grille du mois.
//
//  Interactions :
//  - tap sur la case          → sélectionne le jour
//  - tap sur une pastille     → ouvre l'élément dans l'éditeur
//  - survol (Mac/iPad)        → bouton « + » qui propose Tâche / Événement / Vacances
//  - clic droit / appui long  → même menu (menu contextuel)
//  - glisser une pastille     → la déposer sur un autre jour la déplace (Mac)
//
//  La taille du numéro et le nombre de pastilles affichées viennent de
//  `CalendarLayout` : ils suivent la hauteur réelle de la case, pour que rien
//  ne déborde quand la fenêtre rétrécit.
//

import CoreTransferable
import SwiftData
import SwiftUI

struct DayCell: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    let day: GridDay
    let items: [PlannerItem]
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
    let isLastColumn: Bool
    let layout: CalendarLayout
    let onSelect: () -> Void

    @State private var isHovered = false
    /// Une pastille est glissée au-dessus de cette case.
    @State private var isDropTargeted = false
    /// Panneau « Tâche / Événement / Vacances » du bouton « + » ouvert.
    @State private var isAddPickerPresented = false

    private var style: CalendarStyle { layout.style }

    /// Côté du carré du numéro en compact (= diamètre du rond de sélection).
    private static let compactNumberSize: CGFloat = 24

    /// Le jour du jour a déjà sa case rose pleine : pas de rond en plus.
    private var showsSelectionCircle: Bool { isSelected && !isToday && style == .compact }

    /// Au-delà, on affiche « +N » à côté du numéro pour ne pas déborder de la case.
    private var maxVisibleItems: Int { layout.maxVisibleItems(cellHeight: cellHeight) }

    /// Hauteur réelle de la case, mesurée (nil avant la première mesure).
    @State private var cellHeight: CGFloat?

    var body: some View {
        content
            .padding(.horizontal, style == .regular ? Theme.Spacing.s : 6)
            .padding(.vertical, style == .regular ? layout.cellVerticalPadding : 4)
            // `minHeight: 0` : la case prend la hauteur de sa ligne, jamais
            // celle de son contenu. Avec le `clipped`, un contenu trop haut
            // est coupé au lieu de faire déborder la case (rose) sur ses voisines.
            .frame(maxWidth: .infinity,
                   minHeight: style == .regular ? 0 : nil,
                   maxHeight: style == .regular ? .infinity : nil,
                   alignment: .topLeading)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cellHeight = $0 }
            // Alignées en haut : sinon une case vide centre son numéro et il
            // n'est plus sur la même ligne que celui d'une case avec des barres.
            .frame(height: style == .compact ? layout.compactWeekHeight : nil, alignment: .top)
            .background { background }
            .overlay(alignment: .bottom) { gridLine(horizontal: true) }
            .overlay(alignment: .trailing) { if !isLastColumn { gridLine(horizontal: false) } }
            .overlay { dropHighlight }
            .contentShape(.rect)
            .onTapGesture(perform: onSelect)
            .onHover { isHovered = $0 }
            .contextMenu { addMenuItems }
            #if os(macOS)
            .dropDestination(for: ItemDragPayload.self) { payloads, _ in
                moveDroppedItems(payloads)
            } isTargeted: { isDropTargeted = $0 }
            #endif
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: style == .regular ? CalendarLayout.pillSpacing : 3) {
            dateRow

            switch style {
            case .regular: pills
            case .compact: bars
            }
        }
    }

    /// Le numéro du jour (+ « AUJOURD'HUI » ou « oct. » le 1er du mois).
    private var dateRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if isToday && style == .regular {
                Text(day.date.dayNumber, format: .number)
                    .font(Theme.Fonts.display(layout.dayNumberSize))
                    .tracking(-layout.dayNumberSize * 0.055)
                    .lineLimit(1)
                    .fixedSize()
                Text("Aujourd'hui")
                    .plannerLabelStyle(color: Theme.Colors.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(day.date.dayNumber, format: .number)
                    .font(.system(size: 15, weight: isToday ? .black : .bold))
                    .opacity(day.isInMonth ? 1 : 0.3)
                    .foregroundStyle(showsSelectionCircle ? Theme.Colors.accentDeep : (isToday ? Theme.Colors.onAccent : Theme.Colors.ink))
                    // En compact, le numéro occupe un carré fixe qui contient
                    // le rond de sélection : le rond fait partie de la mise en
                    // page et ne déborde plus sur les barres en dessous.
                    // (Même carré pour tous les jours, pour qu'ils restent alignés.)
                    .frame(width: style == .compact ? Self.compactNumberSize : nil,
                           height: style == .compact ? Self.compactNumberSize : nil)
                    .background {
                        if showsSelectionCircle {
                            Circle()
                                .fill(Theme.Colors.accent.opacity(0.2))
                        }
                    }
                if day.date.dayNumber == 1 && style == .regular {
                    Text(day.date.formatted(.dateTime.month(.abbreviated).locale(.planner)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Éléments qui ne tiennent pas : compteur sur la ligne du numéro,
            // pour laisser toute la hauteur aux pastilles.
            if style == .regular && hiddenItemCount > 0 {
                Text("+\(hiddenItemCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isToday ? Theme.Colors.onAccent : Theme.Colors.inkSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel("\(hiddenItemCount) autres")
            }

            // Bouton « + » visible au survol (Mac, iPad avec trackpad). Il reste
            // affiché tant que son panneau est ouvert : le popover a besoin de
            // son point d'ancrage, et la souris a quitté la case entre-temps.
            if (isHovered || isAddPickerPresented) && style == .regular {
                Button {
                    isAddPickerPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.onAccent)
                        .frame(width: 22, height: 22)
                        .background(isToday ? Theme.Colors.onAccent : Theme.Colors.accent, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter")
                .fixedSize()
                .popover(isPresented: $isAddPickerPresented, arrowEdge: .bottom) {
                    ItemKindPicker { kind in
                        isAddPickerPresented = false
                        appState.openEditor(kind: kind, on: day.date)
                    }
                    .presentationBackground(Theme.Colors.surface)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
        .foregroundStyle(isToday ? Theme.Colors.onAccent : Theme.Colors.ink)
    }

    /// Mode large : pastilles cliquables (le « +N » est sur la ligne du numéro).
    private var pills: some View {
        ForEach(items.prefix(maxVisibleItems)) { item in
            pill(for: item)
        }
    }

    private var hiddenItemCount: Int { max(0, items.count - maxVisibleItems) }

    /// Une pastille : clic → éditeur. Sur Mac, elle se glisse aussi vers un
    /// autre jour. Pas les vacances : elles couvrent plusieurs cases, et
    /// savoir laquelle on « tient » rendrait le geste ambigu.
    @ViewBuilder
    private func pill(for item: PlannerItem) -> some View {
        let button = Button {
            appState.openEditor(for: item)
        } label: {
            EventPill(title: item.title, color: item.displayColor, isDone: item.isDone)
        }
        .buttonStyle(.plain)

        #if os(macOS)
        if item.kind != .holiday {
            button.draggable(ItemDragPayload(id: item.uuid)) {
                EventPill(title: item.title, color: item.displayColor, isDone: item.isDone)
                    .frame(width: 160)
            }
        } else {
            button
        }
        #else
        button
        #endif
    }

    /// Mode compact : petites barres de couleur (une par élément).
    private var bars: some View {
        ForEach(items.prefix(maxVisibleItems)) { item in
            Capsule()
                .fill(item.displayColor)
                .frame(height: 4)
                .opacity(item.isDone ? 0.4 : 1)
        }
    }

    // MARK: - Fond et bordures

    @ViewBuilder
    private var background: some View {
        if isToday {
            RoundedRectangle(cornerRadius: style == .regular ? Theme.Radius.cell : 12)
                .fill(Theme.Colors.accent)
                .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 12, y: 6)
        } else if isHovered {
            RoundedRectangle(cornerRadius: Theme.Radius.cell)
                .fill(Theme.Colors.surface)
        } else if isWeekend && style == .regular {
            Theme.Colors.tint.opacity(0.35)
        }
    }

    /// Cadre rose pendant qu'une pastille survole la case : montre où elle
    /// atterrira. Sur la case du jour (déjà rose), le cadre passe en blanc.
    @ViewBuilder
    private var dropHighlight: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: Theme.Radius.cell)
                .fill(Theme.Colors.accent.opacity(isToday ? 0 : 0.08))
                .strokeBorder(isToday ? Theme.Colors.onAccent : Theme.Colors.accent, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }

    /// Fin trait rose entre les cases (pas sous la case du jour, qui est arrondie).
    @ViewBuilder
    private func gridLine(horizontal: Bool) -> some View {
        if !isToday {
            Rectangle()
                .fill(Theme.Colors.gridLine)
                .frame(width: horizontal ? nil : 1, height: horizontal ? 1 : nil)
        }
    }

    // MARK: - Menu « Ajouter »

    @ViewBuilder
    private var addMenuItems: some View {
        ForEach(ItemKind.allCases) { kind in
            Button(kind.title, systemImage: kind.systemImage) {
                appState.openEditor(kind: kind, on: day.date)
            }
        }
    }

    private var accessibilityText: String {
        let count = items.count
        let suffix = count == 0 ? "rien de prévu" : (count == 1 ? "1 élément" : "\(count) éléments")
        return "\(day.date.shortDayText), \(suffix)"
    }

    // MARK: - Glisser-déposer

    /// Déplace sur ce jour les éléments déposés. L'élément vient d'une autre
    /// case : on le retrouve en base par son identifiant stable.
    private func moveDroppedItems(_ payloads: [ItemDragPayload]) -> Bool {
        let ids = payloads.map(\.id)
        let descriptor = FetchDescriptor<PlannerItem>(predicate: #Predicate { ids.contains($0.uuid) })
        guard let dropped = try? context.fetch(descriptor), !dropped.isEmpty else { return false }

        withAnimation(.snappy) {
            for item in dropped where item.kind != .holiday {
                item.move(to: day.date)
            }
        }
        return true
    }
}

/// Ce qui voyage pendant le glisser : l'identifiant stable de l'élément.
///
/// En texte (`ProxyRepresentation`) pour ne pas avoir à déclarer un type de
/// contenu dans Info.plist, et limité à l'app (`ownProcess`) : déposer une
/// pastille dans Notes ne colle pas un UUID, et un texte venu d'ailleurs
/// n'est jamais pris pour un élément.
nonisolated private struct ItemDragPayload: Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.id.uuidString) { text in
            guard let id = UUID(uuidString: text) else { throw CocoaError(.coderInvalidValue) }
            return ItemDragPayload(id: id)
        }
        .visibility(.ownProcess)
    }
}

// Mise en page compacte (iPhone) : un jour sélectionné avec trois barres,
// pour vérifier que le rond ne touche pas les barres, à côté d'un jour vide.
#Preview("Compact — jour sélectionné") {
    let calendar = Calendar.planner
    let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21))!
    let items = ["lecture", "exposé", "cours"].map { PlannerItem(title: $0, date: day) }
    let layout = CalendarLayout(size: CGSize(width: 390, height: 800))
    HStack(spacing: 0) {
        DayCell(day: GridDay(date: day, isInMonth: true), items: items, isToday: false,
                isSelected: true, isWeekend: false, isLastColumn: false, layout: layout, onSelect: {})
        DayCell(day: GridDay(date: calendar.date(byAdding: .day, value: 1, to: day)!, isInMonth: true),
                items: [], isToday: false, isSelected: false, isWeekend: false, isLastColumn: true,
                layout: layout, onSelect: {})
    }
    .frame(width: 110)
    .padding()
    .background(Theme.Colors.background)
    .environment(AppState())
}
