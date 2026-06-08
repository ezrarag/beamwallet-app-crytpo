import SwiftUI
import AuthenticationServices
import Security

struct AuthView: View {
    @EnvironmentObject private var walletManager: WalletManager

    @State private var showOtherOptions = false
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    fileprivate enum Field {
        case email
        case password
    }

    private var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        !walletManager.isBusy
    }

    private var canResetPassword: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !walletManager.isBusy
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.16, blue: 0.70).opacity(0.28),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 34)

                    beamLogo

                    VStack(spacing: 8) {
                        Text("Welcome to BEAM")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)

                        Text("Sign in to your wallet")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.62))
                    }

                    if let error = walletManager.authError {
                        errorBanner(error)
                    }

                    VStack(spacing: 14) {
                        AppleSignInButton { result in
                            handleAppleResult(result)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(red: 0.62, green: 0.39, blue: 1.0).opacity(0.45), lineWidth: 1)
                        )
                        .disabled(walletManager.isBusy)

                        Button {
                            focusedField = nil
                            Task {
                                if KeychainPasskeyHint.hasExistingPasskey {
                                    await walletManager.authenticateWithPasskey()
                                } else {
                                    await walletManager.registerPasskey()
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Use Passkey")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 0.42, green: 0.18, blue: 0.82))
                            )
                        }
                        .disabled(walletManager.isBusy)
                    }
                    .opacity(walletManager.isBusy ? 0.72 : 1.0)

                    Button {
                        focusedField = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            showOtherOptions.toggle()
                            walletManager.authError = nil
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Other options")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: showOtherOptions ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
                    }
                    .disabled(walletManager.isBusy)

                    if showOtherOptions {
                        emailPasswordSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if walletManager.isBusy {
                        ProgressView()
                            .tint(Color(red: 0.72, green: 0.55, blue: 1.0))
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 34)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 470)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: walletManager.authError != nil)
    }

    private var beamLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.58, green: 0.31, blue: 1.0),
                            Color(red: 0.36, green: 0.13, blue: 0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: Color.purple.opacity(0.45), radius: 22, y: 8)

            Image(systemName: "bolt.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
        .accessibilityLabel("BEAM")
    }

    private var emailPasswordSection: some View {
        VStack(spacing: 12) {
            AuthTextField(
                placeholder: "Email address",
                text: $email,
                icon: "envelope.fill",
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                focusedField: $focusedField,
                field: .email
            )

            AuthTextField(
                placeholder: "Password",
                text: $password,
                icon: "lock.fill",
                contentType: .password,
                focusedField: $focusedField,
                field: .password,
                isSecure: true
            )

            VStack(spacing: 10) {
                authActionButton(title: "Sign In", filled: true) {
                    Task {
                        await walletManager.signIn(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                }

                authActionButton(title: "Create Account", filled: false) {
                    Task {
                        await walletManager.createAccount(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                }

                Button {
                    focusedField = nil
                    Task {
                        await walletManager.sendPasswordReset(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                } label: {
                    Text("Forgot password?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .disabled(!canResetPassword)
                .opacity(canResetPassword ? 1.0 : 0.5)
            }
        }
    }

    private func authActionButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            focusedField = nil
            action()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(filled ? .white : Color(red: 0.74, green: 0.58, blue: 1.0))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(filled ? Color(red: 0.42, green: 0.18, blue: 0.82) : Color(red: 0.10, green: 0.10, blue: 0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(red: 0.62, green: 0.39, blue: 1.0).opacity(filled ? 0 : 0.45), lineWidth: 1)
                        )
                )
        }
        .disabled(!canSubmitEmail)
        .opacity(canSubmitEmail ? 1.0 : 0.5)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(error)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .foregroundColor(Color(red: 1.0, green: 0.50, blue: 0.50))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 1.0, green: 0.22, blue: 0.22).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.28, blue: 0.28).opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func handleAppleResult(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        switch result {
        case .success(let credential):
            Task {
                await walletManager.signInWithApple(credential: credential)
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                walletManager.authError = nil
            } else {
                walletManager.authError = error.localizedDescription
            }
        }
    }
}

private struct AppleSignInButton: UIViewRepresentable {
    let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.cornerRadius = 14
        button.addTarget(context.coordinator, action: #selector(Coordinator.startSignIn), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
        private var controller: ASAuthorizationController?

        init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
            self.completion = completion
        }

        @objc func startSignIn() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                completion(.failure(AuthViewError.invalidAppleCredential))
                return
            }
            controller.delegate = nil
            self.controller = nil
            completion(.success(credential))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            controller.delegate = nil
            self.controller = nil
            completion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var contentType: UITextContentType
    var keyboardType: UIKeyboardType = .default
    var focusedField: FocusState<AuthView.Field?>.Binding
    var field: AuthView.Field
    var isSecure = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.70, green: 0.52, blue: 1.0))
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .focused(focusedField, equals: field)
            .textContentType(contentType)
            .foregroundColor(.white)
            .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

private enum AuthViewError: LocalizedError {
    case invalidAppleCredential

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Apple sign-in returned an invalid credential."
        }
    }
}

private enum KeychainPasskeyHint {
    static var hasExistingPasskey: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.readyaimgo.beamwallet",
            kSecAttrAccount as String: "beam.passkey.credentialID",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }
}
