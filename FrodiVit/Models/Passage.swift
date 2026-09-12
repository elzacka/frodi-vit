import Foundation
import SwiftData

/// Et utdrag av et dokument, med vektoren gjenfinningen sammenligner mot.
///
/// Dokumentet deles opp ved import, og hvert stykke får sin vektor da. Et
/// spørsmål koster dermed én vektor, ikke én per avsnitt i alt du har lastet
/// opp.
///
/// Teksten er forseglet som dokumentet den kommer fra. Vektoren er det ikke:
/// 768 tall fra en modell er ikke en tekst du kan lese tilbake, og å låse opp
/// hvert av dem for hvert spørsmål ville kostet mer enn det vernet.
@Model
final class Passage {
    /// Plassen i dokumentet. Utvalget sorteres etter den, så modellen leser
    /// utdragene i den rekkefølgen de sto.
    var index: Int = 0

    var sealedText: Data = Data()

    /// Antall tegn i klartekst, så utvalget kan telle mot budsjettet uten å
    /// låse opp noe.
    var characterCount: Int = 0

    /// `Float32` etter hverandre, i enhetens byterekkefølge.
    var vector: Data = Data()

    var document: Document?

    init(index: Int, text: String, vector: [Float]) throws {
        self.index = index
        self.sealedText = try Vault.seal(text)
        self.characterCount = text.count
        self.vector = vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    func text() throws -> String {
        guard !sealedText.isEmpty else { return "" }
        return try Vault.openText(sealedText)
    }

    var floats: [Float] {
        vector.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
