# ⭐ Astrea

> Une app de planning de cours faite avec amour, pour une seule utilisatrice :
> ma copine.

## L'histoire

Ma copine jonglait entre ses cours, ses devoirs, ses examens et ses vacances.
Il y avait des post-its partout et des captures d'écran d'emploi du temps
perdues dans la pellicule. Elle me répétait souvent « attends, c'est pour quand
déjà ? ».

Moi, je suis développeur. Alors au lieu de lui offrir un agenda papier
à 12 €, j'ai passé beaucoup trop de soirées à lui coder une app.
Elle est sur iPhone, iPad et Mac, synchronisée via iCloud, et on peut lui
parler avec Siri. C'est tout à fait proportionné.

Astrea, c'est donc :

- 📅 **un calendrier** du mois, avec des petites pastilles de couleur par cours ;
- 📝 **un agenda** jour par jour, avec une carte « Cette semaine » qui l'encourage
  (« C'est parti ! », « Presque au bout ! ») et une étoile 3D qui
  tourne quand la semaine est bouclée ✨ ;
- 🎨 **des cours** avec chacun leur couleur ;
- ✅ **des tâches** à cocher, des **événements**, et des **vacances**
  (le type d'élément le plus important) ;
- ☁️ **une synchro iCloud** : ajouté sur le Mac, retrouvé sur l'iPhone ;
- 🗣️ **Siri et Apple Intelligence** : « Dis Siri, qu'est-ce que j'ai à faire
  dans Astrea ? ». Ça répond, même si la réponse ne plaît pas toujours.

## Fait avec beaucoup (beaucoup) d'IA 🤖

Je ne vais pas mentir : ce projet a été construit en binôme avec l'IA,
principalement avec [Claude Code](https://claude.com/claude-code).
L'architecture, le SwiftUI, les galères de schéma CloudKit, les intents Siri,
les tests : l'IA a écrit une bonne partie du code. Moi, j'ai décidé,
relu, testé et cassé des trucs.

C'était aussi un super moyen d'apprendre SwiftUI, SwiftData et App Intents
sans y passer six mois. Et de livrer avant qu'elle n'ait fini son semestre.

## Sous le capot

| Quoi | Avec |
|---|---|
| Interface | SwiftUI, une seule base de code pour iPhone, iPad et Mac |
| Données | SwiftData |
| Synchro | CloudKit (avec repli en local si iCloud boude) |
| Siri | App Intents, App Shortcuts, schémas Apple Intelligence, Spotlight |
| Tests | Swift Testing |
| Design | maquettes Figma → tokens dans `Design/Theme.swift` |

Le détail de l'organisation du code se trouve dans
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Lancer le projet

1. Ouvrir `Planner.xcodeproj` dans Xcode.
2. Changer l'équipe de signature et le bundle ID (sinon c'est les miens 😉),
   ainsi que le conteneur iCloud dans `Planner.entitlements`.
3. ⌘R.

L'app cible iOS 27 et macOS 27.

## La suite

- Les pondérations des notes par cours
- Le regroupement par années et semestres
- Un mode sombre, pour réviser à 2 h du matin sans se brûler les yeux

---

Fait avec ❤️, du café et un assistant IA, pour la personne la plus organisée
que je connaisse (maintenant).
