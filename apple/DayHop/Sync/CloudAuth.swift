import Foundation

struct CloudIdentity: Codable, Equatable, Identifiable {
    var id: String
    var provider: String
}

struct CloudSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: UUID
    var email: String
    var identities: [CloudIdentity]
}

enum CloudAuthError: Error, Equatable {
    case notConfigured
    case offline
    case cancelled
    case unverified
    case confirmationSent
    case invalid
    case password
    case alreadyLinked
    case useExisting
    case generic
    case differentHousehold
}

enum CloudAuth {
    static func signInWithPassword(config: CloudConfig, email: String, password: String) async -> Result<CloudSession, CloudAuthError> {
        guard config.isConfigured, let base = config.url else { return .failure(.notConfigured) }
        let body: [String: String] = ["email": email, "password": password]
        let token = await post(base.appendingPathComponent("auth/v1/token"), query: "grant_type=password", config: config, body: body, bearer: nil)
        if case let .success(session) = token { return .success(session) }
        if case let .failure(error) = token, error == .password || error == .invalid {
            let signup = await post(base.appendingPathComponent("auth/v1/signup"), query: nil, config: config, body: body, bearer: nil)
            if case .failure(.useExisting) = signup { return .failure(.password) }
            return signup
        }
        return token
    }

    static func signInWithIDToken(config: CloudConfig, provider: String, idToken: String, nonce: String, linking: Bool) async -> Result<CloudSession, CloudAuthError> {
        guard config.isConfigured, let base = config.url else { return .failure(.notConfigured) }
        var body: [String: Any] = ["provider": provider, "id_token": idToken, "nonce": nonce]
        if linking { body["link_identity"] = true }
        let current = linking ? KeychainStore.get("cloud-session").flatMap(decodeSession) : nil
        return await post(base.appendingPathComponent("auth/v1/token"), query: "grant_type=id_token", config: config, json: body, bearer: current?.accessToken)
    }

    static func refresh(config: CloudConfig, session: CloudSession) async -> Result<CloudSession, CloudAuthError> {
        guard config.isConfigured, let base = config.url else { return .failure(.notConfigured) }
        return await post(base.appendingPathComponent("auth/v1/token"), query: "grant_type=refresh_token", config: config, json: ["refresh_token": session.refreshToken], bearer: nil)
    }

    static func unlink(config: CloudConfig, session: CloudSession, identityID: String) async -> Result<CloudSession, CloudAuthError> {
        guard CloudRules.canUnlink(identityCount: session.identities.count) else { return .failure(.invalid) }
        guard config.isConfigured, let base = config.url else { return .failure(.notConfigured) }
        var request = URLRequest(url: base.appendingPathComponent("auth/v1/user/identities/\(identityID)"))
        request.httpMethod = "DELETE"
        authorize(&request, config: config, bearer: session.accessToken)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return .failure(.generic) }
        } catch {
            return .failure(.offline)
        }
        return await currentUser(config: config, session: session)
    }

    static func currentUser(config: CloudConfig, session: CloudSession) async -> Result<CloudSession, CloudAuthError> {
        guard let base = config.url else { return .failure(.notConfigured) }
        var request = URLRequest(url: base.appendingPathComponent("auth/v1/user"))
        authorize(&request, config: config, bearer: session.accessToken)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return .failure(.generic) }
            guard let user = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .failure(.generic) }
            var next = session
            next.email = (user["email"] as? String) ?? session.email
            next.identities = identities(from: user)
            return .success(next)
        } catch {
            return .failure(.offline)
        }
    }

    static func signOut(config: CloudConfig, session: CloudSession) async {
        guard let base = config.url else { return }
        var request = URLRequest(url: base.appendingPathComponent("auth/v1/logout"))
        request.httpMethod = "POST"
        authorize(&request, config: config, bearer: session.accessToken)
        _ = try? await URLSession.shared.data(for: request)
    }

    private static func post(_ url: URL, query: String?, config: CloudConfig, body: [String: String], bearer: String?) async -> Result<CloudSession, CloudAuthError> {
        await post(url, query: query, config: config, json: body, bearer: bearer)
    }

    private static func post(_ url: URL, query: String?, config: CloudConfig, json: [String: Any], bearer: String?) async -> Result<CloudSession, CloudAuthError> {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let query { components?.query = query }
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        authorize(&request, config: config, bearer: bearer)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.generic) }
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if !(200..<300).contains(http.statusCode) {
                return .failure(mapError(object))
            }
            let payload = flattened(object)
            if payload["access_token"] == nil {
                return .failure(.confirmationSent)
            }
            guard let session = session(from: payload) else { return .failure(.generic) }
            return .success(session)
        } catch {
            return .failure(.offline)
        }
    }

    private static func authorize(_ request: inout URLRequest, config: CloudConfig, bearer: String?) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer ?? config.anonKey)", forHTTPHeaderField: "Authorization")
    }

    private static func mapError(_ object: [String: Any]) -> CloudAuthError {
        let code = ((object["error_code"] as? String) ?? (object["error"] as? String) ?? "").lowercased()
        switch code {
        case "invalid_credentials", "invalid_grant": return .password
        case "email_exists", "user_already_exists": return .useExisting
        case "identity_already_exists": return .alreadyLinked
        case "email_not_confirmed": return .confirmationSent
        case "validation_failed", "weak_password": return .invalid
        default: return .generic
        }
    }

    private static func flattened(_ object: [String: Any]) -> [String: Any] {
        guard object["access_token"] == nil, let nested = object["session"] as? [String: Any] else { return object }
        var merged = nested
        if merged["user"] == nil { merged["user"] = object["user"] ?? object }
        return merged
    }

    private static func session(from object: [String: Any]) -> CloudSession? {
        guard let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any],
              let id = (user["id"] as? String).flatMap(UUID.init) else { return nil }
        let expires = Date().addingTimeInterval(TimeInterval(object["expires_in"] as? Int ?? 3600))
        return CloudSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expires,
            userID: id,
            email: user["email"] as? String ?? "",
            identities: identities(from: user)
        )
    }

    private static func identities(from user: [String: Any]) -> [CloudIdentity] {
        let rows = user["identities"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let provider = row["provider"] as? String else { return nil }
            let id = (row["identity_id"] as? String) ?? (row["id"] as? String) ?? provider
            return CloudIdentity(id: id, provider: provider)
        }
    }

    static func decodeSession(_ raw: String) -> CloudSession? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CloudSession.self, from: data)
    }

    static func encode(_ session: CloudSession) -> String? {
        guard let data = try? JSONEncoder().encode(session) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
