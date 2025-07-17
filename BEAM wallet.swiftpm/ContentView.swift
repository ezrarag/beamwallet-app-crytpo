import SwiftUI

struct ContentView: View {
    @StateObject private var walletManager = WalletManager()
    @State private var showingDemoAlert = false
    
    var body: some View {
        TabView {
            WalletHomeView()
                .tabItem { 
                    Label("Wallet", systemImage: "bolt.circle.fill") 
                }
                .environmentObject(walletManager)
            
            SendBTCView()
                .tabItem { 
                    Label("Send", systemImage: "paperplane.fill") 
                }
                .environmentObject(walletManager)
            
            ReceiveBTCView()
                .tabItem { 
                    Label("Receive", systemImage: "qrcode") 
                }
                .environmentObject(wcsdup( popk'/./l;prceefcSRWXZOY&O00o,./;v.o
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
            
            SettingsView()
                .tabItem { 
                    Label("Settings", systemImage: "gearshape.fill") 
                }
                .environmentObject(walletManager)
        }
        .accentColor(.purple)
        .onAppear {
            showingDemoAlert = true
        }
        .alert("BEAM Wallet Demo", isPresented: $showingDemoAlert) {
            Button("Continue") { }
        } message: {
            Text("This is a demo version. No real transactions will be processed. All data is simulated for demonstration purposes.")
        }
    }
}
