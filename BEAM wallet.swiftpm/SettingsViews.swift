import SwiftUI

// MARK: - Enhanced Settings View
struct SettingsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showingSeedPhrase = false
    @State private var biometricEnabled = true
    @State private var notificationsEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Security")) {
                    Button(action: { showingSeedPhrase = true }) {
                        Label("Backup Seed Phrase", systemImage: "key.fill")
                    }
                    
                    Toggle("Biometric Authentication", isOn: $biometricEnabled)
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                }
                
                Section(header: Text("Network")) {
                    Toggle("Use Testnet", isOn: $walletManager.isTestnet)
                    
                    HStack {
                        Text("Network Status")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Export Wallet Data") {
                        // TODO: Implement export functionality
                    }
                    
                    Button("Reset Wallet", role: .destructive) {
                        // TODO: Implement reset functionality
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSeedPhrase) {
                SeedPhraseView()
            }
        }
    }
}

// MARK: - Seed Phrase View
struct SeedPhraseView: View {
    @Environment(\.presentationMode) var presentationMode
    let seedWords = ["abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("⚠️ Keep this safe and private")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("Write down these 12 words in order and store them safely. This is the only way to recover your wallet.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Array(seedWords.enumerated()), id: \.offset) { index, word in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            Text(word)
                                .fontDesign(.monospaced)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                Spacer()
                
                Button("I've Written It Down") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Seed Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
