import SwiftUI

// MARK: - Sign In / Register View

struct SignInView: View {
    @EnvironmentObject var walletManager: WalletManager

    // Form mode
    @State private var isRegistering = false

    // Field values
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    // Focus management
    @FocusState private var focused: FormField?

    enum FormField { case name, email, password }

    // MARK: - Derived state

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        (!isRegistering || !name.trimmingCharacters(in: .whitespaces).isEmpty) &&
        !walletManager.isBusy
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [Color.purple.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // MARK: Logo mark
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.49, green: 0.23, blue: 0.93),
                                             Color(red: 0.42, green: 0.18, blue: 0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.purple.opacity(0.45), radius: 20, y: 6)

                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 28)

                    // MARK: Headline
                    VStack(spacing: 6) {
                        Text(isRegistering ? "Create Account" : "Welcome Back")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text(isRegistering
                             ? "Join the BEAM cooperative"
                             : "Sign in to your BEAM wallet")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.55))
                    }
                    .padding(.bottom, 36)

                    // MARK: Error banner
                    if let error = walletManager.authError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.28, blue: 0.28).opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(red: 1.0, green: 0.28, blue: 0.28).opacity(0.25), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Form fields
                    VStack(spacing: 12) {

                        // Name field (register only)
                        if isRegistering {
                            BeamField(
                                placeholder: "Full Name",
                                text: $name,
                                icon: "person",
                                contentType: .name,
                                focused: $focused,
                                tag: .name
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        BeamField(
                            placeholder: "Email Address",
                            text: $email,
                            icon: "envelope",
                            contentType: .emailAddress,
                            focused: $focused,
                            tag: .email,
                            keyboardType: .emailAddress
                        )

                        BeamField(
                            placeholder: "Password",
                            text: $password,
                            icon: "lock",
                            contentType: isRegistering ? .newPassword : .password,
                            focused: $focused,
                            tag: .password,
                            isSecure: true
                        )
                    }
                    .padding(.bottom, 24)

                    // MARK: Primary action button
                    Button {
                        focused = nil
                        Task {
                            if isRegistering {
                                await walletManager.createAccount(
                                    email: email.trimmingCharacters(in: .whitespaces),
                                    password: password,
                                    name: name.trimmingCharacters(in: .whitespaces)
                                )
                            } else {
                                await walletManager.signIn(
                                    email: email.trimmingCharacters(in: .whitespaces),
                                    password: password
                                )
                            }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    canSubmit
                                    ? LinearGradient(
                                        colors: [Color(red: 0.52, green: 0.24, blue: 0.98),
                                                 Color(red: 0.42, green: 0.18, blue: 0.82)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                    : LinearGradient(
                                        colors: [Color(white: 0.22), Color(white: 0.18)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                )
                                .frame(height: 52)
                                .shadow(color: canSubmit ? Color.purple.opacity(0.4) : .clear,
                                        radius: 12, y: 4)

                            if walletManager.isBusy {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                Text(isRegistering ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(canSubmit ? .white : Color(white: 0.45))
                            }
                        }
                    }
                    .disabled(!canSubmit)
                    .animation(.easeInOut(duration: 0.2), value: canSubmit)
                    .padding(.bottom, 18)

                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.45))
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                    }
                    .padding(.bottom, 18)

                    Button {
                        focused = nil
                        Task {
                            await walletManager.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            GoogleMark()
                                .frame(width: 20, height: 20)

                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(walletManager.isBusy)
                    .opacity(walletManager.isBusy ? 0.65 : 1.0)
                    .padding(.bottom, 20)

                    // MARK: Mode toggle
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isRegistering.toggle()
                            walletManager.authError = nil
                            name = ""
                            email = ""
                            password = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isRegistering ? "Already have an account?" : "New to BEAM?")
                                .foregroundColor(Color(white: 0.5))
                            Text(isRegistering ? "Sign In" : "Create Account")
                                .foregroundColor(Color(red: 0.65, green: 0.45, blue: 1.0))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isRegistering)
                .animation(.easeInOut(duration: 0.25), value: walletManager.authError != nil)
            }
        }
    }
}

// MARK: - Reusable field component

private struct GoogleMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)

            Text("G")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
    }
}

private struct BeamField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var contentType: UITextContentType = .emailAddress
    var focused: FocusState<SignInView.FormField?>.Binding
    var tag: SignInView.FormField
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var isFocused: Bool { focused.wrappedValue == tag }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? Color(red: 0.65, green: 0.45, blue: 1.0) : Color(white: 0.45))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .textContentType(contentType)
            .focused(focused, equals: tag)
            .foregroundColor(.white)
            .font(.system(size: 16))
            .submitLabel(tag == .password ? .go : .next)
            .onSubmit {
                switch tag {
                case .name:     focused.wrappedValue = .email
                case .email:    focused.wrappedValue = .password
                case .password: focused.wrappedValue = nil
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isFocused
                            ? Color(red: 0.60, green: 0.38, blue: 1.0).opacity(0.7)
                            : Color(white: 0.18),
                            lineWidth: 1.5
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
