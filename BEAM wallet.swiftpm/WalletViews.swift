import SwiftUI

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
                
                Text(transaction.hash.prefix(20) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
                
                Text(transaction.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type.symbol)\(transaction.amount, specifier: "%.8f") BEAM")
                    .font(.headline)
                    .foregroundColor(transaction.type.color)
                    .fontDesign(.monospaced)
                
                if transaction.confirmations < 6 {
                    Text("\(transaction.confirmations)/6 confirmations")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text("Confirmed")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Enhanced Wallet Home View (Production)
struct WalletHomeView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingAllTransactions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
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
                    // Balance Card
                    VStack(spacing: 12) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(walletManager.balance, specifier: "%.8f") BTC")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    // Quick Actions
                    HStack(spacing: 16) {
                        NavigationLink(destination: SendBTCView()) {
                            QuickActionButton(
                                title: "Send",
                                icon: "paperplane.fill",
                                color: .purple
                            )
                        }
                        NavigationLink(destination: ReceiveBTCView()) {
                            QuickActionButton(
                                title: "Receive",
                                icon: "qrcode",
                                color: .blue
                            )
                        }
                        Button(action: { showingAllTransactions = true }) {
                            QuickActionButton(
                                title: "History",
                                icon: "clock.fill",
                                color: .green
                            )
                        }
                    }
                    // Recent Transactions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                            Spacer()
                            Button("View All") {
                                showingAllTransactions = true
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                        .padding(.horizontal)
                        LazyVStack(spacing: 8) {
                            ForEach(walletManager.transactions.prefix(3)) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("BEAM Wallet")
            .refreshable {
                walletManager.fetchWalletData()
            }
            .sheet(isPresented: $showingAllTransactions) {
                TransactionHistoryView()
                    .environmentObject(walletManager)
            }
        }
    }
}

// MARK: - Enhanced Send BTC View (Production)
struct SendBTCView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var privateKey = ""
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient")) {
                    HStack {
                        TextField("BTC Address", text: $recipientAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                Section(header: Text("Amount")) {
                    TextField("0.00000000", text: $amount)
                        .keyboardType(.decimalPad)
                        .fontDesign(.monospaced)
                    Text("Available: \(walletManager.balance, specifier: "%.8f") BTC")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Private Key")) {
                    SecureField("Private Key (WIF)", text: $privateKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Section {
                    Button(action: { showingConfirmation = true }) {
                        Text("Review Transaction")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.purple)
                    .disabled(recipientAddress.isEmpty || amount.isEmpty || privateKey.isEmpty)
                }
            }
            .navigationTitle("Send BTC")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm Transaction", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send") {
                    if let amountDouble = Double(amount) {
                        walletManager.sendBTC(to: recipientAddress, amount: amountDouble, privateKey: privateKey) { success, message in
                            if success {
                                showingSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } else {
                                errorMessage = message
                            }
                        }
                    }
                }
            } message: {
                Text("Send \(amount) BTC to \(recipientAddress.prefix(16))...?\n\nThis will broadcast a real transaction.")
            }
            .alert("Transaction Sent!", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your transaction has been submitted to the network.")
            }
            .alert(item: $errorMessage) { msg in
                Alert(title: Text("Error"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// MARK: - Enhanced Receive BTC View (Production)
struct ReceiveBTCView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingCopiedAlert = false
    @State private var requestAmount = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Your BTC Address")
                        .font(.headline)
                    Text(walletManager.address)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            UIPasteboard.general.string = walletManager.address
                            showingCopiedAlert = true
                        }
                }
                // QR Code Placeholder
                VStack(spacing: 16) {
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
                }
                // Request Amount (Optional)
                VStack(spacing: 12) {
                    Text("Request Specific Amount (Optional)")
                        .font(.headline)
                    HStack {
                        TextField("0.00000000", text: $requestAmount)
                            .keyboardType(.decimalPad)
                            .fontDesign(.monospaced)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("BTC")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                VStack(spacing: 12) {
                    Button(action: {
                        let addressToCopy = requestAmount.isEmpty ? 
                        walletManager.address : 
                        "\(walletManager.address)?amount=\(requestAmount)"
                        UIPasteboard.general.string = addressToCopy
                        showingCopiedAlert = true
                    }) {
                        Label("Copy Address", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationTitle("Receive BTC")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Copied!", isPresented: $showingCopiedAlert) {
                Button("OK") { }
            } message: {
                Text("Address copied to clipboard")
            }
        }
    }
}

// MARK: - Transaction History View (Production)
struct TransactionHistoryView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(walletManager.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
