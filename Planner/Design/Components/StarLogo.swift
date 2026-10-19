//
//  StarLogo.swift
//  La mascotte « étoile », dessinée en code (même tracé que dans Figma).
//
//  Avantage d'un dessin vectoriel en code plutôt qu'une image :
//  net à toutes les tailles, aucun fichier à gérer, et on pourra l'animer
//  (clin d'œil quand on termine une tâche, par exemple).
//
//  Tout est dessiné dans un carré de 100×100 « unités », puis mis à
//  l'échelle de la taille réelle de la vue.
//

import SwiftUI

struct StarLogo: View {
    var body: some View {
        Canvas { context, size in
            // Facteur d'échelle : 100 unités → taille réelle (on garde un carré).
            let side = min(size.width, size.height)
            let scale = side / 100
            context.scaleBy(x: scale, y: scale)

            let star = StarShape.path
            let ink = Theme.Colors.ink

            // 1. Contour épais aux angles arrondis (= le trait noir).
            context.stroke(star, with: .color(ink),
                           style: StrokeStyle(lineWidth: 11, lineJoin: .round))

            // 2. Remplissage jaune en dégradé + trait jaune pour arrondir les pointes.
            let gradient = Gradient(colors: [Color(hex: 0xFFDB5C), Color(hex: 0xFFC93C), Color(hex: 0xF7B32B)])
            let shading = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: CGPoint(x: 20, y: 12), endPoint: CGPoint(x: 80, y: 92))
            context.fill(star, with: shading)
            context.stroke(star, with: .color(Color(hex: 0xFFC93C)),
                           style: StrokeStyle(lineWidth: 5.5, lineJoin: .round))

            // 3. Reflets blancs.
            let shine = StrokeStyle(lineWidth: 3, lineCap: .round)
            context.stroke(line(from: (48.5, 20.5), to: (44.5, 31)), with: .color(.white.opacity(0.75)), style: shine)
            context.stroke(line(from: (15, 44), to: (28, 42.6)), with: .color(.white.opacity(0.75)), style: shine)

            // 4. Yeux + petits reflets.
            for x in [43.0, 57.0] {
                context.fill(Path(ellipseIn: CGRect(x: x - 4, y: 52 - 5.6, width: 8, height: 11.2)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: x - 1.1 - 1.5, y: 49.6 - 1.5, width: 3, height: 3)), with: .color(.white))
            }

            // 5. Joues roses.
            for x in [35.5, 64.5] {
                context.fill(Path(ellipseIn: CGRect(x: x - 5, y: 61 - 3.2, width: 10, height: 6.4)),
                             with: .color(Color(hex: 0xFF7FA6)))
            }

            // 6. Sourire.
            var smile = Path()
            smile.move(to: CGPoint(x: 45.5, y: 61.5))
            smile.addQuadCurve(to: CGPoint(x: 54.5, y: 61.5), control: CGPoint(x: 50, y: 65.8))
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Logo Astrea")
    }

    private func line(from a: (Double, Double), to b: (Double, Double)) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: a.0, y: a.1))
        path.addLine(to: CGPoint(x: b.0, y: b.1))
        return path
    }
}

/// Le contour de l'étoile à 5 branches, dans un carré 100×100.
private enum StarShape {
    static let path: Path = {
        let center = CGPoint(x: 50, y: 55)
        let outerRadius = 45.0   // pointes
        let innerRadius = 22.0   // creux entre les pointes (plus grand = étoile plus « dodue »)

        var path = Path()
        // 10 points en alternant pointe / creux, en partant du haut.
        for index in 0..<10 {
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }()
}

#Preview {
    StarLogo()
        .frame(width: 160)
        .padding()
        .background(Theme.Colors.background)
}
