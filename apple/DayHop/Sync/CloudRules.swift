import CryptoKit
import Foundation

enum HouseholdJoin: Equatable {
    case uploadLocal
    case useRemote
    case alreadySynced
    case refuseMerge
}

enum CloudRules {
    static func join(localRemoteID: UUID?, serverHouseholdID: UUID?, localHasContent: Bool) -> HouseholdJoin {
        switch (localRemoteID, serverHouseholdID) {
        case (nil, nil):
            return localHasContent ? .uploadLocal : .uploadLocal
        case (nil, .some):
            return localHasContent ? .refuseMerge : .useRemote
        case (.some, nil):
            return .uploadLocal
        case let (local?, server?) where local == server:
            return .alreadySynced
        default:
            return .refuseMerge
        }
    }

    static func canUnlink(identityCount: Int) -> Bool {
        identityCount > 1
    }

    static func retryDelay(attempt: Int) -> TimeInterval {
        let step = max(0, attempt - 1)
        return min(300, 2 * pow(2, Double(step)))
    }

    static func googleEmailVerified(_ jwt: String) -> Bool {
        guard let payload = jwtPayload(jwt) else { return false }
        if let verified = payload["email_verified"] as? Bool { return verified }
        if let verified = payload["email_verified"] as? String { return verified == "true" }
        return false
    }

    static func nonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func codeChallenge(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func jwtPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var text = String(parts[1])
        text = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - text.count % 4) % 4
        text += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: text) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

struct CloudConfig: Equatable {
    var url: URL?
    var anonKey: String
    var googleClientID: String
    var googleReversedClientID: String

    var isConfigured: Bool {
        guard let url, url.scheme == "https", !anonKey.isEmpty else { return false }
        return true
    }

    var googleReady: Bool {
        isConfigured && !googleClientID.isEmpty && !googleReversedClientID.isEmpty
    }

    static func load(bundle: Bundle = .main) -> CloudConfig {
        guard let url = bundle.url(forResource: "supabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return CloudConfig(url: nil, anonKey: "", googleClientID: "", googleReversedClientID: "")
        }
        let rawURL = (json["url"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return CloudConfig(
            url: URL(string: rawURL),
            anonKey: (json["anonKey"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            googleClientID: (json["googleClientID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            googleReversedClientID: (json["googleReversedClientID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
