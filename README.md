# ⭐ Astrea

> Une app de planning de cours faite avec amour, pour une seule utilisatrice :
> ma copine.

*🇬🇧 [English below](#-english)*

## L'histoire

Ma copine organisait ses cours, ses devoirs et ses examens avec une app de
planning… qui ne marchait pas vraiment. Entre les bugs et la synchro
capricieuse, l'outil donnait plus de travail qu'il n'en faisait gagner.

Moi, je suis développeur. Alors au lieu de chercher une autre app, j'ai passé
beaucoup trop de soirées à lui en coder une.
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

Pour l'instant, Astrea n'est disponible qu'en TestFlight. La prochaine étape,
c'est une sortie sur l'App Store.

---

Fait avec ❤️, du café et un assistant IA, pour qu'elle ait enfin une app
qui fonctionne.

---

## 🇬🇧 English

> A class planner app made with love, for a single user: my girlfriend.

### The story

My girlfriend was organizing her classes, homework and exams with a planner
app… that didn't really work. Between the bugs and the flaky sync, it made
more work than it saved.

I'm a developer. So instead of looking for another app, I spent way too many
evenings coding her one. It runs on iPhone, iPad and Mac, syncs through
iCloud, and you can talk to it with Siri. Perfectly proportionate.

So Astrea is:

- 📅 **a monthly calendar**, with little colored dots for each class;
- 📝 **a day-by-day agenda**, with a "This week" card that cheers her on
  ("C'est parti !", "Presque au bout !") and a 3D star that spins when the
  week is done ✨;
- 🎨 **classes**, each with its own color;
- ✅ **tasks** to check off, **events**, and **holidays**
  (the most important item type);
- ☁️ **iCloud sync**: add it on the Mac, find it on the iPhone;
- 🗣️ **Siri and Apple Intelligence**: "Hey Siri, what do I have to do in
  Astrea?". It answers, even if the answer isn't always welcome.

### Built with a lot (a lot) of AI 🤖

I won't lie: this project was built in pair with AI, mainly with
[Claude Code](https://claude.com/claude-code). The architecture, the SwiftUI,
the CloudKit schema headaches, the Siri intents, the tests: AI wrote a good
chunk of the code. I made the calls, reviewed, tested and broke things.

It was also a great way to learn SwiftUI, SwiftData and App Intents without
spending six months on it. And to ship before she finished her semester.

### Under the hood

| What | With |
|---|---|
| UI | SwiftUI, a single codebase for iPhone, iPad and Mac |
| Data | SwiftData |
| Sync | CloudKit (with a local fallback when iCloud acts up) |
| Siri | App Intents, App Shortcuts, Apple Intelligence schemas, Spotlight |
| Tests | Swift Testing |
| Design | Figma mockups → tokens in `Design/Theme.swift` |

Details on how the code is organized are in
[`ARCHITECTURE.md`](ARCHITECTURE.md).

### Running the project

1. Open `Planner.xcodeproj` in Xcode.
2. Change the signing team and bundle ID (otherwise they're mine 😉),
   as well as the iCloud container in `Planner.entitlements`.
3. ⌘R.

The app targets iOS 27 and macOS 27.

### What's next

For now, Astrea is only available on TestFlight. The next step is an
App Store release.

---

Made with ❤️, coffee and an AI assistant, so she finally has an app that
works.
