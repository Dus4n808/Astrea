//
//  AnimatedStar3D.swift
//  L'étoile en 3D (3D/Star_WeekComplete.usdz) qui rebondit en boucle.
//
//  Utilisée en grand dans l'onboarding et en petit quand la semaine est
//  bouclée. Le fond est transparent : l'étoile se pose directement sur le
//  fond de l'écran, comme le logo 2D.
//

import SwiftUI
import RealityKit

struct AnimatedStar3D: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// En boucle (onboarding) ou un seul rebond (semaine bouclée).
    var repeats = true

    @State private var didFail = false

    var body: some View {
        if didFail {
            // Modèle introuvable ou illisible : on garde l'étoile 2D.
            StarLogo()
        } else {
            // La zone de rendu déborde au-dessus du cadre (elle est transparente) :
            // au sommet du saut, la pointe de l'étoile n'est plus coupée.
            // L'étoile, elle, garde la même taille et la même place.
            GeometryReader { proxy in
                let room = proxy.size.height * Self.topRoom
                realityView(aspect: proxy.size.height / max(proxy.size.width, 1))
                    .frame(width: proxy.size.width, height: proxy.size.height + room)
                    .offset(y: -room)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Hauteur ajoutée au-dessus du cadre, en fraction de sa hauteur.
    private static let topRoom: CGFloat = 0.35

    private func realityView(aspect: CGFloat) -> some View {
        RealityView { content in
            #if os(iOS)
            // Sans ça, l'iPhone ouvrirait la caméra (mode AR).
            content.camera = .virtual
            #endif
            guard let star = await StarModel.instance() else {
                didFail = true
                return
            }
            content.add(Self.framed(star))
            content.add(Self.camera(aspect: aspect))
            if !reduceMotion, let animation = star.availableAnimations.first {
                // Joué une seule fois, l'étoile finit dans sa pose de repos.
                star.playAnimation(repeats ? animation.repeat() : animation)
            }
        } update: { content in
            // Le cadre peut changer de proportions (rotation, fenêtre Mac).
            content.entities.first { $0.name == Self.cameraName }?
                .position = Self.cameraPosition(aspect: aspect)
        } placeholder: {
            // Pendant le chargement : rien, plutôt que le spinner gris par défaut.
            Color.clear
        }
    }

    /// Centre l'étoile sur l'origine et la ramène à une taille d'environ 1 m,
    /// quelle que soit l'échelle utilisée dans Blender.
    ///
    /// Les bornes sont mesurées au repos, mais le rebond (étirement depuis la
    /// base + saut) monte jusqu'à ~35 % plus haut : l'étoile est donc
    /// descendue un peu pour que tout le mouvement tienne dans le cadre.
    private static func framed(_ star: Entity) -> Entity {
        let bounds = star.visualBounds(relativeTo: nil)
        let largest = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard largest > 0 else { return star }
        let scale = 1 / largest
        let holder = Entity()
        star.position = -bounds.center - [0, 0.1 * largest, 0]
        holder.addChild(star)
        holder.scale = SIMD3(repeating: scale)
        return holder
    }

    private static let cameraName = "AnimatedStar3D.camera"
    private static let cameraDistance: Float = 2.3
    private static let fieldOfView: Float = 40

    /// Caméra de face, assez reculée pour que tout le rebond tienne dans le cadre.
    /// Le champ de vision est horizontal : la largeur seule fixe la taille de
    /// l'étoile, la marge du haut ne la rapetisse donc pas.
    private static func camera(aspect: CGFloat) -> Entity {
        let camera = Entity()
        camera.name = cameraName
        var lens = PerspectiveCameraComponent(fieldOfViewInDegrees: fieldOfView)
        lens.fieldOfViewOrientation = .horizontal
        camera.components.set(lens)
        camera.position = cameraPosition(aspect: aspect)
        return camera
    }

    /// La zone agrandie vers le haut a son centre plus haut que celui du cadre :
    /// la caméra monte d'autant pour que l'étoile reste centrée dans le cadre.
    private static func cameraPosition(aspect: CGFloat) -> SIMD3<Float> {
        let visibleWidth = 2 * cameraDistance * tan(fieldOfView / 2 * .pi / 180)
        let lift = Float(topRoom * aspect / 2) * visibleWidth
        return [0, lift, cameraDistance]
    }
}

/// Le modèle de l'étoile, lu une seule fois.
///
/// Sans ce cache, chaque apparition relisait et décodait le .usdz (≈ 800 Ko) :
/// c'est ce qui faisait accrocher l'écran au moment où l'étoile arrive
/// (bascule du filtre de l'agenda, retour sur la liste…). Chaque étoile
/// affichée est un clone : il partage les maillages et les animations du
/// modèle, et se crée presque instantanément.
@MainActor
enum StarModel {
    /// Nom du fichier .usdz dans le bundle.
    private static let name = "Star_WeekComplete"

    private static var loading: Task<Entity?, Never>?

    /// Une étoile prête à poser dans une scène (nil si le modèle est illisible).
    static func instance() async -> Entity? {
        let task = loading ?? Task { try? await Entity(named: name) }
        loading = task
        guard let model = await task.value else {
            // Échec : on retentera à la prochaine apparition.
            loading = nil
            return nil
        }
        return model.clone(recursive: true)
    }

    /// Lance la lecture en avance, pour que la première étoile s'affiche sans
    /// attente ni à-coup.
    static func preload() {
        Task { _ = await instance() }
    }
}

#Preview {
    AnimatedStar3D()
        .frame(width: 220, height: 220)
        .background(Theme.Colors.background)
}
