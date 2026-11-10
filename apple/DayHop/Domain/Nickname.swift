import Foundation

enum NicknameIssue: Equatable {
    case length
    case forbidden
    case charset
}

enum Nicknames {
    static func normalize(_ input: String) -> String {
        let composed = input.precomposedStringWithCanonicalMapping
        let trimmed = composed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func issue(_ input: String) -> NicknameIssue? {
        let value = normalize(input)
        if !Limits.nicknameLength.contains(value.count) { return .length }
        if containsForbidden(value) { return .forbidden }
        let allowed = value.unicodeScalars.allSatisfy { scalar in
            scalar == " " || scalar == "'" || scalar == "-" || CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        }
        return allowed ? nil : .charset
    }

    static func containsForbidden(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            scalar.value <= 0x1F || scalar.value == 0x7F || (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
        }
    }
}
