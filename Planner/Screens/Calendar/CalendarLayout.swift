//
//  CalendarLayout.swift
//  Les mesures du calendrier, déduites de la place réellement disponible.
//
//  Pourquoi ce fichier existe : sur Mac il n'y a pas de size class. La fenêtre
//  peut faire 600 pt de large comme 2000, et `horizontalSizeClass` vaut
//  toujours « regular ». S'y fier gardait donc en permanence la mise en page
//  large, qui s'écrase dès qu'on réduit la fenêtre : gros numéro qui pousse le
//  nom du mois dehors, cases trop courtes, pastilles coupées.
//
//  Ici tout découle de la taille mesurée, sur toutes les plateformes.
//

import SwiftUI

/// Taille d'affichage du calendrier.
enum CalendarStyle: Equatable {
    /// Grandes cases avec pastilles (fenêtre large : Mac, iPad).
    case regular
    /// Petites cases avec barres de couleur (fenêtre étroite : iPhone, Mac réduit).
    case compact
}

struct CalendarLayout: Equatable {

    /// En dessous, les 7 colonnes sont trop étroites pour une pastille
    /// lisible : on bascule en mise en page compacte.
    static let minimumRegularWidth: CGFloat = 860

    /// Hauteur minimale d'une semaine en mode large. Si la fenêtre est plus
    /// courte que 6 semaines à cette hauteur, la grille défile au lieu de
    /// s'écraser.
    static let minimumWeekHeight: CGFloat = 88

    /// Largeur à partir de laquelle on s'autorise les grandes marges et la
    /// pastille « 4 échéances ».
    private static let comfortableWidth: CGFloat = 1040

    /// Largeur à laquelle la typographie atteint sa taille maximale.
    private static let maximalTypographyWidth: CGFloat = 1400

    /// Place disponible. `.zero` tant que la première mesure n'est pas arrivée.
    let size: CGSize
    let style: CalendarStyle

    /// - Parameter prefersCompact: ce que suggère la plateforme (la size class
    ///   sur iOS). Sert uniquement avant la première mesure, pour éviter un
    ///   changement de mise en page visible à l'ouverture.
    init(size: CGSize = .zero, prefersCompact: Bool = false) {
        self.size = size
        if size.width > 0 {
            self.style = size.width < Self.minimumRegularWidth ? .compact : .regular
        } else {
            self.style = prefersCompact ? .compact : .regular
        }
    }

    var isRegular: Bool { style == .regular }

    // MARK: - En-tête

    /// Le gros numéro du mois : la signature visuelle de l'app, mais il doit
    /// maigrir avec la fenêtre, sinon il chasse le nom du mois hors de l'écran.
    var monthNumberSize: CGFloat {
        isRegular ? interpolated(from: 92, to: 140) : 72
    }

    var monthNameSize: CGFloat {
        isRegular ? interpolated(from: 36, to: 56) : 28
    }

    /// Le crénage suit la taille, sinon les chiffres se chevauchent en petit.
    var monthNumberTracking: CGFloat { -monthNumberSize * 0.045 }
    var monthNameTracking: CGFloat { -monthNameSize * 0.036 }

    /// La pastille « 4 échéances » n'a pas la place quand la fenêtre est juste.
    var showsDeadlineBadge: Bool { isRegular && width >= Self.comfortableWidth }

    var horizontalPadding: CGFloat {
        width >= Self.comfortableWidth ? Theme.Spacing.xl : Theme.Spacing.l
    }

    // MARK: - Grille

    /// Hauteur réelle d'une semaine, une fois l'en-tête déduit.
    var weekHeight: CGFloat {
        guard isRegular else { return compactWeekHeight }
        let available = size.height - estimatedHeaderHeight
        return max(Self.minimumWeekHeight, available / CGFloat(MonthGrid.weekCount))
    }

    /// Hauteur d'une case en mode compact (grille fixe, liste du jour dessous).
    let compactWeekHeight: CGFloat = 52

    /// Fenêtre trop courte pour 6 semaines lisibles : on fait défiler.
    var scrollsVertically: Bool {
        guard isRegular, size.height > 0 else { return false }
        return size.height - estimatedHeaderHeight < minimumGridHeight
    }

    /// Hauteur imposée à la grille quand la fenêtre est trop courte ; `nil`
    /// quand la grille peut simplement remplir la place disponible.
    var gridHeight: CGFloat? { scrollsVertically ? minimumGridHeight : nil }

    /// Taille du numéro du jour dans une case : elle suit la hauteur de la
    /// case, sinon un « 18 » en 36 pt mange toute la place des pastilles.
    var dayNumberSize: CGFloat {
        isRegular ? min(36, max(20, weekHeight * 0.32)) : 15
    }

    /// Combien de pastilles tiennent dans une case avant le « +N autres ».
    var maxVisibleItems: Int {
        guard isRegular else { return 3 }
        let free = weekHeight - dayNumberSize - Theme.Spacing.s * 2
        return max(1, min(4, Int(free / 20)))
    }

    // MARK: - Détails

    private var width: CGFloat { size.width > 0 ? size.width : Self.minimumRegularWidth }

    private var minimumGridHeight: CGFloat {
        Self.minimumWeekHeight * CGFloat(MonthGrid.weekCount)
    }

    /// Estimation de ce que prennent l'en-tête du mois, la ligne des jours et
    /// les marges verticales. Une estimation suffit : elle ne sert qu'à
    /// décider si la grille doit défiler ou remplir la hauteur.
    private var estimatedHeaderHeight: CGFloat {
        let weekdayRow: CGFloat = 40
        return monthNumberSize + Theme.Spacing.l + weekdayRow + Theme.Spacing.l * 2
    }

    /// Valeur qui passe de `from` à `to` au fil de la largeur disponible.
    private func interpolated(from: CGFloat, to: CGFloat) -> CGFloat {
        let span = Self.maximalTypographyWidth - Self.minimumRegularWidth
        let progress = (width - Self.minimumRegularWidth) / span
        return from + (to - from) * min(max(progress, 0), 1)
    }
}
