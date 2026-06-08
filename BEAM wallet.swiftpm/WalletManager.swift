import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import Security
import UIKit

@MainActor
class WalletManager: ObservableObject {

    // MARK: - Published State — Wallet
    @Published var balance: Double = 0.0
    @Published var pendingBalance: Double = 0.0
    @Published var transactions: [Transaction] = []
    @Published var address: String = ""          // User UID — doubles as wallet ID
    @Published var errorMessage: String? = nil   // Balance / transfer errors (shown in WalletHomeView)
    @Published var isBusy: Bool = false
    /// Drives the SettingsView testnet toggle (preserved for future dynamic URL switching)
    @Published var isTestnet: Bool = true

    // MARK: - Published State — Auth
    @Published var isAuthenticated: Bool = false
    @Published var authError: String? = nil      // Auth-only errors (shown in SignInView)

    // MARK: - Private Auth State
    private(set) var authToken: String = ""
    private(set) var userUID: String = ""

    private var pollTimer: AnyCancellable?
    private let session = URLSession.shared
    private var googleAuthSession: ASWebAuthenticationSession?
    private let googleAuthPresenter = AuthSessionPresenter()
    private var passkeyAuthorizationSession: AuthorizationControllerSession?

    init() {
        restoreSessionFromKeychain()
    }

    // MARK: - Firebase Auth REST: Sign In (async)
    /// Primary async sign-in. Called directly from SignInView.
    func signIn(email: String, password: String) async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(AppConfig.firebaseApiKey)") else {
            authError = "Invalid authentication URL."
            return
        }

        do {
            let data = try await post(url: url, body: [
                "email": email,
                "password": password,
                "returnSecureToken": true
            ])
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["idToken"] as? String,
                  let localId = json["localId"] as? String else {
                authError = firebaseErrorMessage(from: data) ?? "Sign-in failed. Check your credentials."
                return
            }
            commitSession(token: idToken, uid: localId)
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Apple Sign-In
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8),
              !identityTokenString.isEmpty else {
            authError = "Apple did not return an identity token."
            return
        }

        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(AppConfig.firebaseApiKey)") else {
            authError = "Invalid Apple authentication URL."
            return
        }

        do {
            let postBody = Self.formURLEncoded([
                "id_token": identityTokenString,
                "providerId": "apple.com"
            ])
            let data = try await post(url: url, body: [
                "postBody": postBody,
                "requestUri": AppConfig.appleFirebaseRequestURI,
                "returnIdpCredential": true,
                "returnSecureToken": true
            ])

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["idToken"] as? String,
                  let localId = json["localId"] as? String else {
                authError = firebaseErrorMessage(from: data) ?? "Apple sign-in failed."
                return
            }

            commitSession(token: idToken, uid: localId)
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        authError = nil

        guard !AppConfig.googleOAuthClientID.isEmpty,
              !AppConfig.googleRedirectScheme.isEmpty else {
            authError = "Google sign-in is not configured. Add the iOS OAuth client ID and redirect scheme."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let authResult = try await requestGoogleAuthorizationCode()
            let googleIDToken = try await exchangeGoogleCodeForIDToken(
                code: authResult.code,
                codeVerifier: authResult.codeVerifier
            )
            let firebaseSession = try await signInToFirebaseWithGoogle(idToken: googleIDToken)
            commitSession(token: firebaseSession.idToken, uid: firebaseSession.localID)
        } catch GoogleAuthError.cancelled {
            authError = nil
        } catch let error as GoogleAuthError {
            authError = error.localizedDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Passkeys
    func registerPasskey() async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        do {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: AppConfig.passkeyRelyingPartyID
            )
            let userID = Self.randomBytes(byteCount: 32)
            let challenge = Self.randomBytes(byteCount: 32)
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: "BEAM Wallet",
                userID: userID
            )

            let authorization = try await performAuthorization(request)
            guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
                authError = "Passkey registration returned an invalid credential."
                return
            }

            let credentialID = credential.credentialID.base64URLEncodedString()
            KeychainStore.set(credentialID, for: .passkeyCredentialID)
            commitPasskeySession(credentialID: credentialID)
        } catch AuthorizationError.cancelled {
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    func authenticateWithPasskey() async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        do {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: AppConfig.passkeyRelyingPartyID
            )
            let request = provider.createCredentialAssertionRequest(challenge: Self.randomBytes(byteCount: 32))

            let authorization = try await performAuthorization(request)
            guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
                authError = "Passkey sign-in returned an invalid credential."
                return
            }

            let credentialID = credential.credentialID.base64URLEncodedString()
            KeychainStore.set(credentialID, for: .passkeyCredentialID)
            commitPasskeySession(credentialID: credentialID)
        } catch AuthorizationError.cancelled {
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Firebase Auth REST: Create Account (async)
    func createAccount(email: String, password: String) async {
        await createAccount(email: email, password: password, name: "")
    }

    /// Registers a new Firebase user, then optionally sets a display name.
    func createAccount(email: String, password: String, name: String) async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        guard let signUpURL = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(AppConfig.firebaseApiKey)") else {
            authError = "Invalid authentication URL."
            return
        }

        do {
            let data = try await post(url: signUpURL, body: [
                "email": email,
                "password": password,
                "returnSecureToken": true
            ])
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = json["idToken"] as? String,
                  let localId = json["localId"] as? String else {
                authError = firebaseErrorMessage(from: data) ?? "Account creation failed."
                return
            }

            // Optionally persist the display name
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty {
                await updateDisplayName(trimmedName, token: idToken)
            }

            commitSession(token: idToken, uid: localId)
        } catch {
            authError = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        authError = nil
        isBusy = true
        defer { isBusy = false }

        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(AppConfig.firebaseApiKey)") else {
            authError = "Invalid password reset URL."
            return
        }

        do {
            let data = try await post(url: url, body: [
                "requestType": "PASSWORD_RESET",
                "email": email
            ])

            if let error = firebaseErrorMessage(from: data) {
                authError = error
                return
            }

            authError = "Reset email sent!"
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Sign Out
    func signOut() {
        stopPolling()
        authToken = ""
        userUID = ""
        address = ""
        balance = 0.0
        pendingBalance = 0.0
        transactions = []
        isAuthenticated = false
        authError = nil
        errorMessage = nil
        KeychainStore.delete(.idToken)
        KeychainStore.delete(.userUID)
    }

    // MARK: - Legacy Callback Sign-In (preserved for backward compatibility)
    /// Wraps the async signIn so older call sites continue to compile unchanged.
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            await signIn(email: email, password: password)
            if self.isAuthenticated {
                completion(true, nil)
            } else {
                completion(false, self.authError ?? "Sign-in failed.")
            }
        }
    }

    // MARK: - Fetch Balance from /api/balance
    func fetchWalletData() {
        guard !authToken.isEmpty,
              let url = URL(string: "\(AppConfig.apiBaseURL)/api/balance") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.errorMessage = "Balance error: \(error.localizedDescription)"
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Invalid balance response from server."
                    return
                }
                if let serverError = json["error"] as? String {
                    self.errorMessage = serverError
                    return
                }
                self.balance = (json["balanceBeam"] as? Double) ?? 0.0
                self.pendingBalance = (json["pendingBeam"] as? Double) ?? 0.0
                self.errorMessage = nil
            }
        }.resume()
    }

    // MARK: - Allocate BEAM → POST /api/allocate
    /// Sends `amountBeam` from the current user to `destinationUID`.
    func allocateBeam(
        to destinationUID: String,
        amount: Double,
        memo: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard !authToken.isEmpty, !userUID.isEmpty else {
            completion(false, "Not signed in.")
            return
        }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/api/allocate") else {
            completion(false, "Invalid API URL.")
            return
        }

        isBusy = true

        var body: [String: Any] = [
            "sourceUid": userUID,
            "destinationUid": destinationUID,
            "amountBeam": amount
        ]
        if let memo { body["memo"] = memo }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBusy = false

                if let error { completion(false, error.localizedDescription); return }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(false, "Invalid server response."); return
                }
                if let serverError = json["error"] as? String {
                    completion(false, serverError); return
                }
                let localTx = Transaction(
                    hash: (json["transactionId"] as? String) ?? UUID().uuidString,
                    amount: amount,
                    type: .sent,
                    timestamp: Date(),
                    address: destinationUID,
                    confirmations: 6
                )
                self.transactions.insert(localTx, at: 0)
                self.fetchWalletData()
                completion(true, json["transactionId"] as? String)
            }
        }.resume()
    }

    // MARK: - Stripe Connect Cash Out
    func checkStripeConnectStatus(completion: @escaping (Bool, String?) -> Void) {
        guard !authToken.isEmpty,
              let url = URL(string: "\(AppConfig.apiBaseURL)/api/connect/status") else {
            completion(false, "Not signed in.")
            return
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        session.dataTask(with: req) { data, _, error in
            Task { @MainActor in
                if let error {
                    completion(false, error.localizedDescription)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(false, "Invalid Connect status response.")
                    return
                }
                if let serverError = json["error"] as? String {
                    completion(false, serverError)
                    return
                }
                completion((json["connected"] as? Bool) == true, nil)
            }
        }.resume()
    }

    func createStripeConnectOnboardingLink(completion: @escaping (URL?, String?) -> Void) {
        guard !authToken.isEmpty,
              let url = URL(string: "\(AppConfig.apiBaseURL)/api/connect/onboard") else {
            completion(nil, "Not signed in.")
            return
        }

        isBusy = true

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)

        session.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                self?.isBusy = false

                if let error {
                    completion(nil, error.localizedDescription)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil, "Invalid Connect onboarding response.")
                    return
                }
                if let serverError = json["error"] as? String {
                    completion(nil, serverError)
                    return
                }
                guard let urlString = json["url"] as? String,
                      let accountLinkURL = URL(string: urlString) else {
                    completion(nil, "Connect onboarding link was missing.")
                    return
                }
                completion(accountLinkURL, nil)
            }
        }.resume()
    }

    func redeemBeam(amount: Double, completion: @escaping (Bool, String?) -> Void) {
        guard !authToken.isEmpty,
              let url = URL(string: "\(AppConfig.apiBaseURL)/api/redeem") else {
            completion(false, "Not signed in.")
            return
        }

        isBusy = true

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "amountBeam": amount
        ])

        session.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBusy = false

                if let error {
                    completion(false, error.localizedDescription)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(false, "Invalid redemption response.")
                    return
                }
                if let serverError = json["error"] as? String {
                    completion(false, serverError)
                    return
                }
                if let newBalance = json["newBalance"] as? Double {
                    self.balance = newBalance
                }
                if let transferId = json["transferId"] as? String {
                    let localTx = Transaction(
                        hash: transferId,
                        amount: amount,
                        type: .sent,
                        timestamp: Date(),
                        address: "Stripe Connect",
                        confirmations: 1
                    )
                    self.transactions.insert(localTx, at: 0)
                    completion(true, "Transfer ID: \(transferId)")
                    return
                }
                completion(true, "Cash out submitted.")
            }
        }.resume()
    }

    // MARK: - Balance Polling (every 10 s while authenticated)
    private func startPolling() {
        stopPolling()
        pollTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchWalletData() }
    }

    func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Private Helpers

    /// Commits a successful auth session and kicks off wallet data fetch + polling.
    private func commitSession(token: String, uid: String) {
        authToken = token
        userUID = uid
        address = uid
        KeychainStore.set(token, for: .idToken)
        KeychainStore.set(uid, for: .userUID)
        isAuthenticated = true
        authError = nil
        fetchWalletData()
        startPolling()
    }

    private func commitPasskeySession(credentialID: String) {
        userUID = credentialID
        address = credentialID
        isAuthenticated = true
        authError = nil
    }

    private func restoreSessionFromKeychain() {
        guard let token = KeychainStore.string(for: .idToken),
              let uid = KeychainStore.string(for: .userUID),
              !token.isEmpty,
              !uid.isEmpty else { return }

        authToken = token
        userUID = uid
        address = uid
        isAuthenticated = true
        fetchWalletData()
        startPolling()
    }

    /// Updates the Firebase Auth display name (best-effort; failure is non-fatal).
    private func updateDisplayName(_ name: String, token: String) async {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:update?key=\(AppConfig.firebaseApiKey)") else { return }
        _ = try? await post(url: url, body: [
            "idToken": token,
            "displayName": name,
            "returnSecureToken": false
        ])
    }

    /// Generic JSON POST helper — throws on network errors, returns raw Data.
    private func post(url: URL, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        return data
    }

    private func requestGoogleAuthorizationCode() async throws -> GoogleAuthorizationResult {
        let state = Self.randomURLSafeString(byteCount: 32)
        let codeVerifier = Self.randomURLSafeString(byteCount: 64)
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        let redirectURI = "\(AppConfig.googleRedirectScheme):/oauth2redirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.googleOAuthClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let authURL = components?.url else {
            throw GoogleAuthError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.googleRedirectScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.googleAuthSession = nil

                    if let error = error as? ASWebAuthenticationSessionError,
                       error.code == .canceledLogin {
                        continuation.resume(throwing: GoogleAuthError.cancelled)
                        return
                    }

                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL,
                          let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                        continuation.resume(throwing: GoogleAuthError.missingCallback)
                        return
                    }

                    let items = callbackComponents.queryItems ?? []
                    if let returnedError = items.first(where: { $0.name == "error" })?.value {
                        continuation.resume(throwing: GoogleAuthError.oauth(returnedError))
                        return
                    }

                    guard items.first(where: { $0.name == "state" })?.value == state else {
                        continuation.resume(throwing: GoogleAuthError.stateMismatch)
                        return
                    }

                    guard let code = items.first(where: { $0.name == "code" })?.value,
                          !code.isEmpty else {
                        continuation.resume(throwing: GoogleAuthError.missingAuthorizationCode)
                        return
                    }

                    continuation.resume(returning: GoogleAuthorizationResult(
                        code: code,
                        codeVerifier: codeVerifier
                    ))
                }
            }

            authSession.presentationContextProvider = googleAuthPresenter
            authSession.prefersEphemeralWebBrowserSession = true
            googleAuthSession = authSession

            if !authSession.start() {
                googleAuthSession = nil
                continuation.resume(throwing: GoogleAuthError.couldNotStartSession)
            }
        }
    }

    private func exchangeGoogleCodeForIDToken(code: String, codeVerifier: String) async throws -> String {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GoogleAuthError.invalidURL
        }

        let body = [
            "client_id": AppConfig.googleOAuthClientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": "\(AppConfig.googleRedirectScheme):/oauth2redirect"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded(body).data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleAuthError.invalidTokenResponse
        }

        if let error = json["error"] as? String {
            throw GoogleAuthError.oauth(error)
        }

        guard let idToken = json["id_token"] as? String, !idToken.isEmpty else {
            throw GoogleAuthError.invalidTokenResponse
        }

        return idToken
    }

    private func signInToFirebaseWithGoogle(idToken: String) async throws -> FirebaseAuthSession {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(AppConfig.firebaseApiKey)") else {
            throw GoogleAuthError.invalidURL
        }

        let postBody = Self.formURLEncoded([
            "id_token": idToken,
            "providerId": "google.com"
        ])

        let data = try await post(url: url, body: [
            "postBody": postBody,
            "requestUri": AppConfig.googleFirebaseRequestURI,
            "returnIdpCredential": true,
            "returnSecureToken": true
        ])

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleAuthError.invalidFirebaseResponse
        }

        if let error = firebaseErrorMessage(from: data) {
            throw GoogleAuthError.oauth(error)
        }

        guard let firebaseIDToken = json["idToken"] as? String,
              let localID = json["localId"] as? String else {
            throw GoogleAuthError.invalidFirebaseResponse
        }

        return FirebaseAuthSession(idToken: firebaseIDToken, localID: localID)
    }

    /// Extracts and humanises Firebase Identity Toolkit error codes.
    private func firebaseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any],
              let message = err["message"] as? String else { return nil }
        switch message {
        case "EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS":
            return "No account found. Tap Create Account to register."
        case "INVALID_PASSWORD":
            return "Incorrect password. Please try again."
        case "INVALID_EMAIL":
            return "Enter a valid email address."
        case "USER_DISABLED":
            return "This account has been disabled."
        case "EMAIL_EXISTS":
            return "An account with this email already exists."
        case "TOO_MANY_ATTEMPTS_TRY_LATER":
            return "Too many attempts. Please wait a moment and try again."
        case _ where message.contains("WEAK_PASSWORD"):
            return "Password must be at least 6 characters."
        default:
            return message
        }
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        randomBytes(byteCount: byteCount).base64URLEncodedString()
    }

    private static func randomBytes(byteCount: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formURLEncoded(_ values: [String: String]) -> String {
        values
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .joined(separator: "&")
    }

    private func performAuthorization(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let session = AuthorizationControllerSession { [weak self] result in
                Task { @MainActor in
                    self?.passkeyAuthorizationSession = nil
                    switch result {
                    case .success(let authorization):
                        continuation.resume(returning: authorization)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            passkeyAuthorizationSession = session
            session.perform(request)
        }
    }
}

private enum KeychainKey: String {
    case idToken = "beam.firebase.idToken"
    case userUID = "beam.firebase.userUID"
    case passkeyCredentialID = "beam.passkey.credentialID"
}

private enum KeychainStore {
    static func set(_ value: String, for key: KeychainKey) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.readyaimgo.beamwallet",
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func string(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.readyaimgo.beamwallet",
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.readyaimgo.beamwallet",
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum AuthorizationError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        }
    }
}

private final class AuthorizationControllerSession: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    private var controller: ASAuthorizationController?

    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }

    func perform(_ request: ASAuthorizationRequest) {
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        controller.delegate = nil
        self.controller = nil
        completion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        controller.delegate = nil
        self.controller = nil
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            completion(.failure(AuthorizationError.cancelled))
        } else {
            completion(.failure(error))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private struct GoogleAuthorizationResult {
    let code: String
    let codeVerifier: String
}

private struct FirebaseAuthSession {
    let idToken: String
    let localID: String
}

private enum GoogleAuthError: LocalizedError {
    case cancelled
    case invalidURL
    case missingCallback
    case stateMismatch
    case missingAuthorizationCode
    case invalidTokenResponse
    case invalidFirebaseResponse
    case couldNotStartSession
    case oauth(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .invalidURL:
            return "Invalid Google sign-in URL."
        case .missingCallback:
            return "Google sign-in did not return a callback URL."
        case .stateMismatch:
            return "Google sign-in returned an invalid state. Please try again."
        case .missingAuthorizationCode:
            return "Google sign-in did not return an authorization code."
        case .invalidTokenResponse:
            return "Google sign-in returned an invalid token response."
        case .invalidFirebaseResponse:
            return "Firebase did not return a valid Google sign-in session."
        case .couldNotStartSession:
            return "Could not start Google sign-in."
        case .oauth(let message):
            return message
        }
    }
}

private final class AuthSessionPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFormAllowed) ?? self
    }
}

private extension CharacterSet {
    static let urlFormAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return allowed
    }()
}
