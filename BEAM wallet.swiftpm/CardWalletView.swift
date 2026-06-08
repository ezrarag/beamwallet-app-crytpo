import SwiftUI
import PassKit

// =============================================================================
// CardWalletView.swift — JIT Virtual Card + Apple Wallet Provisioning
//
// ARCHITECTURE NOTE — TWO HARD PREREQUISITES BEFORE THIS CODE IS LIVE-TESTABLE:
//
//  1. Apple entitlement: `com.apple.developer.payment-pass-provisioning`
//     Email support-issuing@stripe.com with:
//       - Card network (Visa or Mastercard)
//       - Card name shown in Wallet
//       - App name
//       - Developer Team ID  (Apple Developer → Membership)
//       - ADAM ID            (App Store Connect numeric ID)
//       - Bundle ID          (com.readyaimgo.beamwallet)
//     Approval takes ~1 week. This entitlement only works with distribution
//     profiles — end-to-end testing requires TestFlight or App Store.
//
//  2. Stripe iOS SDK — add to Package.swift (requires Xcode, not Playgrounds):
//       .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0")
//     Add product "StripeIssuingObjC" to AppModule target.
//     Import as:  import StripeIssuingObjC
//
//  3. Digital wallet tokens are LIVE MODE ONLY — sandbox cannot test PassKit.
//
//  Until #1 and #2 are complete, this file compiles and shows UI state
//  correctly but `PKAddPaymentPassViewController` cannot present.
// =============================================================================

// MARK: - Card model (populated from POST /api/cards/create response)

struct BeamCard {
    let cardId: String
    let last4: String
    let brand: String
    let expMonth: Int
    let expYear: Int
    let isApplePayEligible: Bool           // wallets.apple_pay.eligible
    let primaryAccountIdentifier: String   // wallets.primary_account_identifier
}

// MARK: - Provisioning state machine

enum ProvisioningState {
    case loading
    case eligible
    case alreadyProvisioned
    case notEligible(reason: String)
    case provisioning
    case success
    case error(message: String)
}

// MARK: - Main View

struct CardWalletView: View {
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var viewModel = CardWalletViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Card art ─────────────────────────────────────────
                    CardArtView(card: viewModel.card)
                        .padding(.top, 8)

                    // ── Apple Wallet button / state ──────────────────────
                    ProvisioningControlView(
                        state: viewModel.provisioningState,
                        onAddToWallet: { viewModel.beginProvisioning() }
                    )

                    // ── Card details ─────────────────────────────────────
                    if let card = viewModel.card {
                        CardDetailsView(card: card)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("BEAM Card")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadCard(walletManager: walletManager)
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class CardWalletViewModel: ObservableObject {
    @Published var card: BeamCard? = nil
    @Published var provisioningState: ProvisioningState = .loading
    @Published var presentPassController = false

    private var presentingViewController: UIViewController?

    // ── Load card from server and check PassKit eligibility ───────────────
    func loadCard(walletManager: WalletManager) async {
        guard !walletManager.authToken.isEmpty else {
            provisioningState = .error(message: "Not signed in.")
            return
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/api/cards/create") else { return }

        // NOTE: In production, POST /api/cards/create is idempotent — calling it
        // on every app launch returns the existing card if one already exists.
        // For a better UX, persist cardId locally (UserDefaults/Keychain) and
        // call GET /api/cards/{cardId} instead after the first creation.
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(walletManager.authToken)", forHTTPHeaderField: "Authorization")

        // NOTE: In production, collect full KYC data (name, email, billing address)
        // from a separate onboarding form and pass it here.
        req.httpBody = try? JSONSerialization.data(withJSONObject: [:])

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cardId = json["cardId"] as? String else {
                provisioningState = .error(message: "Could not load card data.")
                return
            }

            let walletsJson = json["wallets"] as? [String: Any]
            let applePayJson = walletsJson?["apple_pay"] as? [String: Any]
            let isEligible = applePayJson?["eligible"] as? Bool ?? false
            let primaryId = applePayJson?["primary_account_identifier"] as? String ?? ""

            let beamCard = BeamCard(
                cardId: cardId,
                last4: json["last4"] as? String ?? "••••",
                brand: json["brand"] as? String ?? "visa",
                expMonth: json["expMonth"] as? Int ?? 0,
                expYear: json["expYear"] as? Int ?? 0,
                isApplePayEligible: isEligible,
                primaryAccountIdentifier: primaryId
            )
            self.card = beamCard
            checkPassKitEligibility(card: beamCard)

        } catch {
            provisioningState = .error(message: error.localizedDescription)
        }
    }

    // ── Step 1: Check server-side + device-side eligibility ───────────────
    // Stripe docs: you MUST check both conditions before showing the button.
    // Showing PKAddPassButton without checking → App Review rejection.
    private func checkPassKitEligibility(card: BeamCard) {
        guard card.isApplePayEligible else {
            provisioningState = .notEligible(reason: "Apple Pay is not yet enabled on this card program.")
            return
        }

        // Check if card is already provisioned on this device or a paired watch.
        // Pass empty string if primary_account_identifier is empty (Stripe docs).
        let alreadyAdded = PKPassLibrary().canAddSecureElementPass(
            primaryAccountIdentifier: card.primaryAccountIdentifier
        )

        if !alreadyAdded {
            // canAddSecureElementPass returns false when the card IS already added.
            // This counter-intuitive naming is correct per Apple docs.
            provisioningState = .alreadyProvisioned
        } else {
            provisioningState = .eligible
        }
    }

    // ── Step 2: Begin provisioning flow ───────────────────────────────────
    func beginProvisioning() {
        guard let card = card else { return }
        provisioningState = .provisioning

        // PKAddPaymentPassViewController requires a UIViewController presenter.
        // We use the UIKit bridge below (PassKitPresenter) to surface it.
        guard PKAddPaymentPassViewController.canAddPaymentPass() else {
            provisioningState = .notEligible(reason: "This device cannot add payment passes.")
            return
        }

        // STPPushProvisioningContext requires the Stripe iOS SDK.
        // See: https://docs.stripe.com/issuing/cards/digital-wallets?platform=ios
        //
        // Implementation sketch (requires StripeIssuingObjC import):
        //
        //   let keyProvider = BeamIssuingKeyProvider(cardId: card.cardId, walletManager: walletManager)
        //   let context = STPPushProvisioningContext(keyProvider: keyProvider)
        //   let config = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)!
        //   config.cardholderName = "BEAM Member"
        //   config.primaryAccountSuffix = card.last4
        //   config.localizedDescription = "BEAM Financial Services"
        //   config.primaryAccountIdentifier = card.primaryAccountIdentifier
        //   let vc = STPFakeAddPaymentPassViewController(requestConfiguration: config, delegate: context)
        //   // Present vc via PassKitPresenter UIViewControllerRepresentable
        //
        // Until the entitlement is granted, print the config for verification:
        print("[CardWallet] Would provision card \(card.cardId) last4=\(card.last4)")
        print("[CardWallet] primaryAccountIdentifier: \(card.primaryAccountIdentifier)")

        // TODO: Replace with real STPPushProvisioningContext once entitlement is approved
        provisioningState = .error(message: "Push provisioning requires the Apple entitlement. See CardWalletView.swift comments.")
    }
}

// MARK: - Provisioning control (shows the PKAddPassButton or status)

private struct ProvisioningControlView: View {
    let state: ProvisioningState
    let onAddToWallet: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .loading:
                ProgressView("Loading card…")
                    .tint(.purple)

            case .eligible:
                // The PKAddPaymentPassButton must be used — App Review rejects
                // any custom "Add to Wallet" button that mimics the official UI.
                PKAddWalletButton(action: onAddToWallet)
                    .frame(height: 50)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)

            case .alreadyProvisioned:
                Label("Already in Wallet", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
                    .padding(.vertical, 12)

            case .provisioning:
                HStack(spacing: 10) {
                    ProgressView().tint(.purple)
                    Text("Adding to Wallet…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .success:
                Label("Added to Apple Wallet", systemImage: "wallet.pass.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.purple)

            case .notEligible(let reason):
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

            case .error(let message):
                VStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}

// MARK: - PKAddPassButton UIViewRepresentable wrapper
// PKAddPassButton is UIKit-only and must be bridged for SwiftUI.

private struct PKAddWalletButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - Card art view

private struct CardArtView: View {
    let card: BeamCard?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.40, green: 0.18, blue: 0.82),
                                 Color(red: 0.22, green: 0.08, blue: 0.50)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.purple.opacity(0.35), radius: 20, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("BEAM")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.title3)
                }
                Spacer()
                Text(card != nil ? "•••• •••• •••• \(card!.last4)" : "•••• •••• •••• ••••")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                HStack {
                    if let card {
                        Text(String(format: "%02d/%02d", card.expMonth, card.expYear % 100))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(card?.brand.uppercased() ?? "VISA")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(24)
        }
        .frame(height: 200)
    }
}

// MARK: - Card details

private struct CardDetailsView: View {
    let card: BeamCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Details")
                .font(.headline)
            HStack {
                Text("Number")
                    .foregroundColor(.secondary)
                Spacer()
                Text("•••• \(card.last4)")
                    .fontDesign(.monospaced)
            }
            HStack {
                Text("Expires")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%02d/%02d", card.expMonth, card.expYear % 100))
                    .fontDesign(.monospaced)
            }
            HStack {
                Text("Network")
                    .foregroundColor(.secondary)
                Spacer()
                Text(card.brand.capitalized)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Ephemeral Key Provider (requires StripeIssuingObjC SDK)
//
// When the Stripe iOS SDK is available, implement STPIssuingCardEphemeralKeyProvider
// to bridge the PassKit delegate to your backend:
//
// import StripeIssuingObjC
//
// final class BeamIssuingKeyProvider: NSObject, STPIssuingCardEphemeralKeyProvider {
//     let cardId: String
//     let authToken: String
//
//     init(cardId: String, walletManager: WalletManager) {
//         self.cardId = cardId
//         self.authToken = walletManager.authToken
//     }
//
//     func createIssuingCardKey(
//         withAPIVersion apiVersion: String,
//         completion: @escaping STPJSONResponseCompletionBlock
//     ) {
//         guard let url = URL(string: "\(AppConfig.apiBaseURL)/api/cards/\(cardId)/ephemeral-key") else {
//             completion(nil, NSError(domain: "BeamIssuing", code: -1))
//             return
//         }
//         var req = URLRequest(url: url)
//         req.httpMethod = "POST"
//         req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//         req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
//         req.httpBody = try? JSONSerialization.data(withJSONObject: ["apiVersion": apiVersion])
//
//         URLSession.shared.dataTask(with: req) { data, _, error in
//             guard let data,
//                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
//                 completion(nil, error ?? NSError(domain: "BeamIssuing", code: -1))
//                 return
//             }
//             completion(json, nil)
//         }.resume()
//     }
// }
