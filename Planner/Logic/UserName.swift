//
//  UserName.swift
//  Règles du prénom saisi à l'onboarding, réutilisé partout dans l'app
//  (« Salut Léa », etc.).
//
//  Pourquoi des règles ?
//  Le prénom s'affiche dans des titres en gros caractères : un nom de
//  80 caractères ou bourré d'emojis casserait la mise en page. On garde donc :
//  - 2 à 20 caractères,
//  - des lettres (accents et autres alphabets acceptés),
//  - des séparateurs simples entre les lettres : espace, tiret, apostrophe
//    (« Jean-Luc », « D'Artagnan », « Anne Marie »).
//

import Foundation

nonisolated enum UserName {
    static let minLength = 2
    static let maxLength = 20

    /// Clé de stockage (UserDefaults / @AppStorage).
    static let storageKey = "userName"

    /// Séparateurs autorisés entre deux lettres.
    private static let separators: Set<Character> = [" ", "-", "'", "’"]

    enum ValidationError: Error, Equatable {
        case tooShort

        var message: String {
            switch self {
            case .tooShort: "Au moins \(UserName.minLength) lettres"
            }
        }
    }

    /// Nettoie la saisie en direct, frappe par frappe :
    /// retire les caractères interdits (emojis, chiffres, symboles…),
    /// empêche deux séparateurs d'affilée et coupe à `maxLength`.
    static func sanitize(_ input: String) -> String {
        var result = ""
        for character in input {
            if isLetter(character) {
                result.append(character)
            } else if separators.contains(character) {
                // Pas de séparateur en tête ni deux à la suite.
                guard let last = result.last, !separators.contains(last) else { continue }
                result.append(character == "’" ? "'" : character)
            }
        }
        return String(result.prefix(maxLength))
    }

    /// Vérifie la saisie finale, avant de l'enregistrer.
    /// La longueur max et les caractères interdits sont déjà réglés par
    /// `normalized` : il ne reste qu'à vérifier qu'il y a assez de lettres.
    static func validate(_ input: String) -> ValidationError? {
        normalized(input).count < minLength ? .tooShort : nil
    }

    /// Forme enregistrée : espaces de bord retirés, séparateur final supprimé.
    static func normalized(_ input: String) -> String {
        var name = sanitize(input).trimmingCharacters(in: .whitespaces)
        while let last = name.last, separators.contains(last) {
            name.removeLast()
        }
        return name
    }

    /// Une lettre = tous ses scalaires sont des lettres ou des marques
    /// diacritiques (é, ñ, 李…). Les emojis et chiffres sont refusés.
    private static func isLetter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(CharacterSet.letters.contains)
    }
}
