import AuthenticationServices
import Foundation
import UIKit

struct ProviderCredential {
    var idToken: String
    var rawNonce: String
    var appleUserID: String?
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func once(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}

enum ProviderSignIn {
    @MainActor
    static func apple() async -> Result<ProviderCredential, CloudAuthError> {
        await AppleSignInCoordinator().start()
    }

    @MainActor
    static func google(clientID: String, reversedClientID: String) async -> Result<ProviderCredential, CloudAuthError> {
        await GoogleSignInCoordinator(clientID: clientID, reversedClientID: reversedClientID).start()
    }

    static func appleCredentialRevoked(_ userID: String) async -> Bool {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state == .revoked)
            }
        }
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<Result<ProviderCredential, CloudAuthError>, Never>?
    private var controller: ASAuthorizationController?
    private var rawNonce = ""

    func start() async -> Result<ProviderCredential, CloudAuthError> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            rawNonce = CloudRules.nonce()
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email]
            request.nonce = CloudRules.sha256Hex(rawNonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            finish(.failure(.generic))
            return
        }
        finish(.success(ProviderCredential(idToken: token, rawNonce: rawNonce, appleUserID: credential.user)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let code = (error as? ASAuthorizationError)?.code
        finish(.failure(code == .canceled ? .cancelled : .generic))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        keyWindow()
    }

    private func finish(_ result: Result<ProviderCredential, CloudAuthError>) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

@MainActor
private final class GoogleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    let clientID: String
    let reversedClientID: String

    init(clientID: String, reversedClientID: String) {
        self.clientID = clientID
        self.reversedClientID = reversedClientID
    }

    func start() async -> Result<ProviderCredential, CloudAuthError> {
        let rawNonce = CloudRules.nonce()
        let verifier = CloudRules.nonce()
        let challenge = CloudRules.codeChallenge(verifier)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "\(reversedClientID):/oauth2callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email"),
            URLQueryItem(name: "nonce", value: CloudRules.sha256Hex(rawNonce)),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let url = components?.url else { return .failure(.generic) }
        let gate = ResumeGate()
        let client = clientID
        let redirect = "\(reversedClientID):/oauth2callback"
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: reversedClientID) { callback, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    gate.once { continuation.resume(returning: .failure(.cancelled)) }
                    return
                }
                guard let callback, let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                    gate.once { continuation.resume(returning: .failure(.generic)) }
                    return
                }
                gate.once {
                    Task {
                        let exchanged = await Self.exchange(code: code, verifier: verifier, clientID: client, redirect: redirect, rawNonce: rawNonce)
                        continuation.resume(returning: exchanged)
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                gate.once { continuation.resume(returning: .failure(.generic)) }
            }
        }
    }

    private var session: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        keyWindow()
    }

    private static func exchange(code: String, verifier: String, clientID: String, redirect: String, rawNonce: String) async -> Result<ProviderCredential, CloudAuthError> {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirect,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]
        request.httpBody = fields.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = object["id_token"] as? String else { return .failure(.generic) }
            guard CloudRules.googleEmailVerified(idToken) else { return .failure(.unverified) }
            return .success(ProviderCredential(idToken: idToken, rawNonce: rawNonce, appleUserID: nil))
        } catch {
            return .failure(.offline)
        }
    }
}

private func keyWindow() -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
}
