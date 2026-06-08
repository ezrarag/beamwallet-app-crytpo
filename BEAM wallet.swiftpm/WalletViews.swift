import SwiftUI
import AVFoundation
import UIKit

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.type == .received ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(transaction.type.color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type == .received ? "Received BEAM" : "Sent BEAM")
                    .font(.headline)

                Text(transaction.hash.prefix(20) + "…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)

                Text(transaction.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(transaction.type.symbol)\(transaction.amount, specifier: "%.4f") BEAM")
                .font(.headline)
                .foregroundColor(transaction.type.color)
                .fontDesign(.monospaced)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Wallet Home View
struct WalletHomeView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingAllTransactions = false
    @State private var showingCashOutSheet = false
    @State private var cashOutAmount = ""
    @State private var cashOutMessage: String? = nil
    @State private var showingCashOutAlert = false
    @State private var cashOutAlertTitle = "Cash Out"

    private var parsedCashOutAmount: Double? {
        Double(cashOutAmount.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canWithdraw: Bool {
        guard let amount = parsedCashOutAmount else { return false }
        return amount > 0 && amount <= walletManager.balance && !walletManager.isBusy
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Error banner
                    if let error = walletManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Balance card
                    VStack(spacing: 8) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(walletManager.balance, specifier: "%.4f") BEAM")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))

                        if walletManager.pendingBalance > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text("Pending: \(walletManager.pendingBalance, specifier: "%.4f") BEAM")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Quick actions
                    HStack(spacing: 16) {
                        NavigationLink(destination: SendBEAMView()) {
                            QuickActionButton(title: "Send", icon: "paperplane.fill", color: .purple)
                        }
                        NavigationLink(destination: ReceiveBEAMView()) {
                            QuickActionButton(title: "Receive", icon: "qrcode", color: .blue)
                        }
                        Button(action: { showingAllTransactions = true }) {
                            QuickActionButton(title: "History", icon: "clock.fill", color: .green)
                        }
                    }
                    .padding(.horizontal)

                    Button(action: startCashOutFlow) {
                        Label("Cash Out", systemImage: "banknote.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(walletManager.isBusy)
                    .opacity(walletManager.isBusy ? 0.65 : 1.0)

                    Text("1 BEAM = $1.00 USD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Recent transactions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                            Spacer()
                            Button("View All") { showingAllTransactions = true }
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal)

                        if walletManager.transactions.isEmpty {
                            Text("No transactions yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(walletManager.transactions.prefix(3)) { tx in
                                    TransactionRow(transaction: tx)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("BEAM Wallet")
            .refreshable { walletManager.fetchWalletData() }
            .sheet(isPresented: $showingAllTransactions) {
                TransactionHistoryView().environmentObject(walletManager)
            }
            .sheet(isPresented: $showingCashOutSheet) {
                cashOutSheet
            }
            .alert(cashOutAlertTitle, isPresented: $showingCashOutAlert) {
                Button("OK") { }
            } message: {
                Text(cashOutMessage ?? "")
            }
        }
    }

    private var cashOutSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount")) {
                    TextField("0.00", text: $cashOutAmount)
                        .keyboardType(.decimalPad)
                        .fontDesign(.monospaced)

                    Text("1 BEAM = $1.00 USD")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Available: \(walletManager.balance, specifier: "%.4f") BEAM")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Estimated arrival: 2-3 business days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: withdrawToBank) {
                        if walletManager.isBusy {
                            HStack {
                                ProgressView().tint(.white)
                                Text("Withdrawing...")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                        } else {
                            Text("Withdraw to Bank")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(canWithdraw ? Color.green : Color.gray)
                    .disabled(!canWithdraw)
                }
            }
            .navigationTitle("Cash Out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCashOutSheet = false
                    }
                }
            }
        }
    }

    private func startCashOutFlow() {
        walletManager.checkStripeConnectStatus { onboarded, error in
            if let error {
                showCashOutAlert(title: "Cash Out Unavailable", message: error)
                return
            }

            if onboarded {
                cashOutAmount = ""
                showingCashOutSheet = true
            } else {
                walletManager.createStripeConnectOnboardingLink { url, error in
                    if let error {
                        showCashOutAlert(title: "Connect Onboarding", message: error)
                        return
                    }
                    guard let url else {
                        showCashOutAlert(title: "Connect Onboarding", message: "Missing onboarding link.")
                        return
                    }
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func withdrawToBank() {
        guard let amount = parsedCashOutAmount else { return }
        walletManager.redeemBeam(amount: amount) { success, message in
            showingCashOutSheet = false
            showCashOutAlert(
                title: success ? "Cash Out Submitted" : "Cash Out Failed",
                message: message ?? (success ? "Withdrawal submitted." : "Unable to cash out.")
            )
        }
    }

    private func showCashOutAlert(title: String, message: String) {
        cashOutAlertTitle = title
        cashOutMessage = message
        showingCashOutAlert = true
    }
}

// MARK: - Send BEAM View
struct SendBEAMView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var recipientMode: RecipientMode = .phone
    @State private var recipientInput = ""
    @State private var resolvedRecipientUID = ""
    @State private var amount = ""
    @State private var memo = ""
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var showingScanner = false
    @State private var isError = false
    @State private var isResolvingRecipient = false
    @State private var statusMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode

    private var parsedAmount: Double? { Double(amount) }
    private var usdEstimate: Double { max(parsedAmount ?? 0, 0) }
    private var canSend: Bool {
        !recipientInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedAmount != nil &&
        parsedAmount! > 0 &&
        !walletManager.isBusy &&
        !isResolvingRecipient
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient")) {
                    Picker("Recipient Type", selection: $recipientMode) {
                        ForEach(RecipientMode.allCases) { mode in
                            Text(mode.segmentTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: recipientMode) { _, _ in
                        recipientInput = ""
                        resolvedRecipientUID = ""
                        statusMessage = nil
                    }

                    HStack(spacing: 10) {
                        TextField(recipientMode.placeholder, text: $recipientInput)
                            .keyboardType(recipientMode == .phone ? .phonePad : .default)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .fontDesign(recipientMode == .walletID ? .monospaced : .default)
                            .onChange(of: recipientInput) { _, newValue in
                                resolvedRecipientUID = ""
                                guard recipientMode == .phone else { return }
                                let formatted = PhoneNumberFormatter.usDisplayString(from: newValue)
                                if formatted != newValue {
                                    recipientInput = formatted
                                }
                            }

                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan wallet QR code")
                    }

                    if recipientMode == .walletID {
                        Text("Advanced")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !resolvedRecipientUID.isEmpty && recipientMode != .walletID {
                        Text("Resolved wallet: \(resolvedRecipientUID.prefix(16))…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    }
                }

                Section(header: Text("Amount")) {
                    TextField("0.0000", text: $amount)
                        .keyboardType(.decimalPad)
                        .fontDesign(.monospaced)
                    Text("≈ $\(usdEstimate, specifier: "%.2f") USD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Available: \(walletManager.balance, specifier: "%.4f") BEAM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Memo (optional)")) {
                    TextField("Note for recipient", text: $memo)
                }

                Section {
                    Button(action: prepareTransfer) {
                        if walletManager.isBusy || isResolvingRecipient {
                            HStack {
                                ProgressView().tint(.white)
                                Text(isResolvingRecipient ? "Resolving…" : "Sending…")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                        } else {
                            Text("Send BEAM")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(canSend ? Color.purple : Color.gray)
                    .disabled(!canSend)
                }
            }
            .navigationTitle("Send BEAM")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingScanner) {
                QRCodeScannerView { value in
                    recipientMode = .walletID
                    recipientInput = WalletQRCodeParser.walletID(from: value)
                    resolvedRecipientUID = recipientInput
                    showingScanner = false
                }
            }
            .alert("Confirm Transfer", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send") { sendBeam() }
            } message: {
                Text("Send \(amount) BEAM to \(resolvedRecipientUID.prefix(16))…?")
            }
            .alert("Transfer Sent!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text(statusMessage ?? "Your BEAM allocation was submitted successfully.")
            }
            .alert("Transfer Failed", isPresented: $isError) {
                Button("OK") { }
            } message: {
                Text(statusMessage ?? "An unknown error occurred.")
            }
        }
    }

    private func prepareTransfer() {
        guard canSend else { return }
        isResolvingRecipient = true
        statusMessage = nil

        Task {
            do {
                let uid = try await resolveRecipientUID()
                resolvedRecipientUID = uid
                showingConfirmation = true
            } catch {
                statusMessage = error.localizedDescription
                isError = true
            }
            isResolvingRecipient = false
        }
    }

    private func resolveRecipientUID() async throws -> String {
        let trimmedInput = recipientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        switch recipientMode {
        case .phone:
            let e164 = try PhoneNumberFormatter.e164USNumber(from: trimmedInput)
            return try await FirestoreUIDResolver.uid(
                collection: "userPhoneIndex",
                documentID: e164
            )
        case .username:
            let username = trimmedInput
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            guard !username.isEmpty else {
                throw RecipientResolutionError.invalidUsername
            }
            return try await FirestoreUIDResolver.uid(
                collection: "usernames",
                documentID: username
            )
        case .walletID:
            guard !trimmedInput.isEmpty else {
                throw RecipientResolutionError.emptyWalletID
            }
            return trimmedInput
        }
    }

    private func sendBeam() {
        guard let amt = parsedAmount, !resolvedRecipientUID.isEmpty else { return }
        walletManager.allocateBeam(
            to: resolvedRecipientUID,
            amount: amt,
            memo: memo.isEmpty ? nil : memo
        ) { success, message in
            if success {
                statusMessage = message.map { "Transaction ID: \($0)" }
                showingSuccess = true
            } else {
                statusMessage = message
                isError = true
            }
        }
    }
}

private enum RecipientMode: String, CaseIterable, Identifiable {
    case phone
    case username
    case walletID

    var id: String { rawValue }

    var segmentTitle: String {
        switch self {
        case .phone: return "Phone"
        case .username: return "Username"
        case .walletID: return "Wallet ID"
        }
    }

    var placeholder: String {
        switch self {
        case .phone: return "(555) 555-5555"
        case .username: return "username"
        case .walletID: return "Advanced wallet ID"
        }
    }
}

private enum RecipientResolutionError: LocalizedError {
    case invalidPhoneNumber
    case invalidUsername
    case emptyWalletID
    case notFound
    case invalidFirestoreResponse
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Enter a valid 10-digit US phone number."
        case .invalidUsername:
            return "Enter a valid username."
        case .emptyWalletID:
            return "Enter a wallet ID."
        case .notFound:
            return "No wallet was found for that recipient."
        case .invalidFirestoreResponse:
            return "The recipient lookup returned an invalid response."
        case .cameraUnavailable:
            return "Camera access is unavailable."
        }
    }
}

private enum PhoneNumberFormatter {
    static func usDisplayString(from value: String) -> String {
        let digits = value.filter(\.isNumber).prefix(10)
        var result = ""

        for (index, digit) in digits.enumerated() {
            if index == 0 { result += "(" }
            if index == 3 { result += ") " }
            if index == 6 { result += "-" }
            result.append(digit)
        }

        return result
    }

    static func e164USNumber(from value: String) throws -> String {
        let digits = String(value.filter(\.isNumber))
        if digits.count == 10 {
            return "+1\(digits)"
        }
        if digits.count == 11 && digits.first == "1" {
            return "+\(digits)"
        }
        throw RecipientResolutionError.invalidPhoneNumber
    }
}

private enum FirestoreUIDResolver {
    static func uid(collection: String, documentID: String) async throws -> String {
        let encodedDocumentID = documentID.urlPathEncoded
        let urlString = "https://firestore.googleapis.com/v1/projects/\(AppConfig.firebaseProjectID)/databases/(default)/documents/\(collection)/\(encodedDocumentID)?key=\(AppConfig.firebaseApiKey)"

        guard let url = URL(string: urlString) else {
            throw RecipientResolutionError.invalidFirestoreResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 404 {
            throw RecipientResolutionError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            throw RecipientResolutionError.invalidFirestoreResponse
        }

        let uidField = fields["uid"] as? [String: Any]
        guard let uid = uidField?["stringValue"] as? String,
              !uid.isEmpty else {
            throw RecipientResolutionError.notFound
        }

        return uid
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(onCodeScanned: onCodeScanned)
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onCodeScanned: (String) -> Void
    private let session = AVCaptureSession()

    init(onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureScanner()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureScanner() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showUnavailableState()
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showUnavailableState()
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        let guide = UIView()
        guide.layer.borderColor = UIColor.systemPurple.cgColor
        guide.layer.borderWidth = 3
        guide.layer.cornerRadius = 16
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)

        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guide.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.68),
            guide.heightAnchor.constraint(equalTo: guide.widthAnchor)
        ])
    }

    private func showUnavailableState() {
        let label = UILabel()
        label.text = RecipientResolutionError.cameraUnavailable.localizedDescription
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.layer.sublayers?.first { $0 is AVCaptureVideoPreviewLayer } as? AVCaptureVideoPreviewLayer)?.frame = view.bounds
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = readableObject.stringValue else { return }
        session.stopRunning()
        onCodeScanned(value)
    }
}

private enum WalletQRCodeParser {
    static func walletID(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let components = URLComponents(string: trimmed) {
            let queryItems = components.queryItems ?? []
            if let uid = queryItems.first(where: { ["uid", "wallet", "walletId", "walletID"].contains($0.name) })?.value,
               !uid.isEmpty {
                return uid
            }
        }

        if trimmed.hasPrefix("beam:") {
            return String(trimmed.dropFirst("beam:".count))
        }

        return trimmed
    }
}

private extension String {
    var urlPathEncoded: String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

// MARK: - Receive BEAM View
struct ReceiveBEAMView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingCopiedAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Your BEAM Wallet ID")
                        .font(.headline)

                    Text(walletManager.address.isEmpty ? "Sign in to view your wallet ID" : walletManager.address)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            guard !walletManager.address.isEmpty else { return }
                            UIPasteboard.general.string = walletManager.address
                            showingCopiedAlert = true
                        }
                }

                // QR placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 200, height: 200)
                    VStack {
                        Image(systemName: "qrcode")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.primary)
                        Text("QR Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    guard !walletManager.address.isEmpty else { return }
                    UIPasteboard.general.string = walletManager.address
                    showingCopiedAlert = true
                }) {
                    Label("Copy Wallet ID", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(walletManager.address.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Receive BEAM")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Copied!", isPresented: $showingCopiedAlert) {
                Button("OK") { }
            } message: {
                Text("Wallet ID copied to clipboard.")
            }
        }
    }
}

// MARK: - Transaction History View
struct TransactionHistoryView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if walletManager.transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No transactions yet.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(walletManager.transactions) { tx in
                            TransactionRow(transaction: tx)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }
            )
        }
    }
}
