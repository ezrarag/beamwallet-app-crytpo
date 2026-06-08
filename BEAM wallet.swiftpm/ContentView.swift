import SwiftUI

struct ContentView: View {
    @StateObject private var walletManager = WalletManager()

    var body: some View {
        Group {
            if walletManager.isAuthenticated {
                // ── Authenticated: full app tab shell ──
                TabView {
                    WalletHomeView()
                        .tabItem {
                            Label("Wallet", systemImage: "bolt.circle.fill")
                        }

                    SendBEAMView()
                        .tabItem {
                            Label("Send", systemImage: "paperplane.fill")
                        }

                    ReceiveBEAMView()
                        .tabItem {
                            Label("Receive", systemImage: "qrcode")
                        }

                    MultiChainMarketplaceView()
                        .tabItem {
                            Label("Marketplace", systemImage: "globe")
                        }

                    BeamAnalyticsView()
                        .tabItem {
                            Label("Analytics", systemImage: "chart.bar.fill")
                        }

                    DAOView()
                        .tabItem {
                            Label("DAO", systemImage: "person.3.fill")
                        }

                    CardWalletView()
                        .tabItem {
                            Label("Card", systemImage: "creditcard.fill")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
                .accentColor(.purple)

            } else {
                // ── Unauthenticated: sign-in / register screen ──
                AuthView()
            }
        }
        .environmentObject(walletManager)
    }
}
