//
//  UserNameTests.swift
//  Les règles du prénom saisi à l'onboarding.
//
//  Le prénom s'affiche en gros dans l'app : s'il laisse passer des emojis
//  ou dépasse la longueur max, la mise en page casse.
//

import Testing

@testable import Planner

@Suite("UserName")
struct UserNameTests {

    @Test("Les prénoms courants passent tels quels",
          arguments: ["Léa", "Jean-Luc", "D'Artagnan", "Anne Marie", "Zoë", "李华"])
    func validNames(name: String) {
        #expect(UserName.sanitize(name) == name)
        #expect(UserName.validate(name) == nil)
    }

    @Test("Emojis, chiffres et symboles sont retirés")
    func stripsForbiddenCharacters() {
        #expect(UserName.sanitize("Léa🌸42!") == "Léa")
        #expect(UserName.sanitize("<script>") == "script")
    }

    @Test("Pas de séparateur en tête ni deux d'affilée")
    func collapsesSeparators() {
        #expect(UserName.sanitize("  -Jean--Luc") == "Jean-Luc")
        #expect(UserName.sanitize("Anne   Marie") == "Anne Marie")
    }

    @Test("L'apostrophe typographique devient droite")
    func normalizesApostrophe() {
        #expect(UserName.sanitize("D’Artagnan") == "D'Artagnan")
    }

    @Test("La saisie est coupée à la longueur max")
    func truncates() {
        let long = String(repeating: "a", count: 50)
        #expect(UserName.sanitize(long).count == UserName.maxLength)
    }

    @Test("Le séparateur final est retiré à l'enregistrement")
    func normalizedTrimsTrailingSeparator() {
        #expect(UserName.normalized("Jean- ") == "Jean")
    }

    @Test("Trop court est refusé", arguments: ["", "a", "🌸🌸", "a-"])
    func tooShort(name: String) {
        #expect(UserName.validate(name) == .tooShort)
    }
}
