import SwiftUI

struct MultiChainMarketplaceView: View {
    @StateObject private var marketplaceManager = MarketplaceManager()
    @State private var selectedChain: SupportedChain = .beam
    @State private var searchText = ""
    @State private var showingChainSelector = false
    @State private var selectedCategory: TokenCategory = .all
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with chain selector
                        ChainSelectorHeader(
                            selectedChain: $selectedChain,
                            showingChainSelector: $showingChainSelector
                        )
                        
                        // Search bar
                        SearchBar(searchText: $searchText)
                        
                        // Portfolio overview
                        PortfolioOverview(manager: marketplaceManager)
                        
                        // Category filter
                        CategoryFilter(selectedCategory: $selectedCategory)
                        
                        // Featured tokens
                        FeaturedTokensSection(
                            tokens: filteredTokens,
                            selectedChain: selectedChain
                        )
                        
                        // Bridge section
                        CrossChainBridgeSection()
                        
                        // All tokens list
                        TokenListSection(
                            tokens: filteredTokens,
                            selectedChain: selectedChain
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Multi-Chain Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingChainSelector = true }) {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingChainSelector) {
                ChainSelectorSheet(selectedChain: $selectedChain)
            }
        }
    }
    
    private var filteredTokens: [Token] {
        let chainTokens = marketplaceManager.tokens.filter { $0.chain == selectedChain }
        let categoryFiltered = selectedCategory == .all ? chainTokens : chainTokens.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) || 
                $0.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Chain Selector Header
struct ChainSelectorHeader: View {
    @Binding var selectedChain: SupportedChain
    @Binding var showingChainSelector: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Multi-Chain Portfolio")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Button(action: { showingChainSelector = true }) {
                HStack {
                    ChainIcon(chain: selectedChain)
                        .frame(width: 24, height: 24)
                    
                    Text(selectedChain.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedChain.accentColor, lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Search tokens...", text: $searchText)
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Portfolio Overview
struct PortfolioOverview: View {
    let manager: MarketplaceManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Total Portfolio Value")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Text("$\(manager.totalPortfolioValue.formatted())")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            HStack {
                Text("+$\(manager.dailyChange.formatted())")
                    .foregroundColor(.green)
                Text("(+\(manager.dailyChangePercent.formatted())%)")
                    .foregroundColor(.green)
                Text("24h")
                    .foregroundColor(.white.opacity(0.7))
            }
            .font(.subheadline)
            
            // Chain distribution
            HStack(spacing: 12) {
                ForEach(SupportedChain.allCases, id: \.self) { chain in
                    ChainAllocationView(
                        chain: chain,
                        percentage: manager.chainAllocation(for: chain)
                    )
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

struct ChainAllocationView: View {
    let chain: SupportedChain
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            ChainIcon(chain: chain)
                .frame(width: 20, height: 20)
            
            Text("\(percentage.formatted())%")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Filter
enum TokenCategory: String, CaseIterable {
    case all = "All"
    case defi = "DeFi"
    case nft = "NFT"
    case gaming = "Gaming"
    case stablecoin = "Stable"
    case meme = "Meme"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .defi: return "chart.line.uptrend.xyaxis"
        case .nft: return "photo.artframe"
        case .gaming: return "gamecontroller"
        case .stablecoin: return "dollarsign.circle"
        case .meme: return "face.smiling"
        }
    }
}

struct CategoryFilter: View {
    @Binding var selectedCategory: TokenCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TokenCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryButton: View {
    let category: TokenCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.purple : Color.white.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        }
    }
}

// MARK: - Featured Tokens Section
struct FeaturedTokensSection: View {
    let tokens: [Token]
    let selectedChain: SupportedChain
    
    var featuredTokens: [Token] {
        tokens.filter { $0.isFeatured }.prefix(3).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured on \(selectedChain.displayName)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredTokens) { token in
                        FeaturedTokenCard(token: token)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FeaturedTokenCard: View {
    let token: Token
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TokenIcon(token: token)
                    .frame(width: 40, height: 40)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("$\(token.price.formatted())")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(token.priceChange24h >= 0 ? "+" : "")\(token.priceChange24h.formatted())%")
                        .font(.caption)
                        .foregroundColor(token.priceChange24h >= 0 ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(token.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(token.symbol)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Mini chart placeholder
            HStack {
                ForEach(0..<7) { _ in
                    Rectangle()
                        .fill(token.priceChange24h >= 0 ? Color.green : Color.red)
                        .frame(width: 4, height: Double.random(in: 8...24))
                }
            }
            .frame(height: 24)
        }
        .padding()
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(token.chain.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cross-Chain Bridge Section
struct CrossChainBridgeSection: View {
    @State private var showingBridge = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cross-Chain Bridge")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Bridge Assets") {
                    showingBridge = true
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
            
            HStack(spacing: 16) {
                BridgeOptionCard(
                    fromChain: .ethereum,
                    toChain: .beam,
                    title: "ETH → BEAM",
                    subtitle: "Bridge Ethereum assets"
                )
                
                BridgeOptionCard(
                    fromChain: .polygon,
                    toChain: .beam,
                    title: "MATIC → BEAM",
                    subtitle: "Bridge Polygon assets"
                )
            }
        }
        .sheet(isPresented: $showingBridge) {
            CrossChainBridgeView()
        }
    }
}

struct BridgeOptionCard: View {
    let fromChain: SupportedChain
    let toChain: SupportedChain
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ChainIcon(chain: fromChain)
                    .frame(width: 20, height: 20)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                
                ChainIcon(chain: toChain)
                    .frame(width: 20, height: 20)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Token List Section
struct TokenListSection: View {
    let tokens: [Token]
    let selectedChain: SupportedChain
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All \(selectedChain.displayName) Tokens")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 8) {
                ForEach(tokens) { token in
                    TokenRow(token: token)
                }
            }
        }
    }
}

struct TokenRow: View {
    let token: Token
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack {
                TokenIcon(token: token)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(token.symbol)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ChainBadge(chain: token.chain)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(token.price.formatted())")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(token.priceChange24h >= 0 ? "+" : "")\(token.priceChange24h.formatted())%")
                        .font(.caption)
                        .foregroundColor(token.priceChange24h >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingDetail) {
            TokenDetailView(token: token)
        }
    }
}

// MARK: - Supporting Views
struct ChainIcon: View {
    let chain: SupportedChain
    
    var body: some View {
        ZStack {
            Circle()
                .fill(chain.accentColor)
            
            Text(chain.iconSymbol)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct ChainBadge: View {
    let chain: SupportedChain
    
    var body: some View {
        Text(chain.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chain.accentColor.opacity(0.2))
            .foregroundColor(chain.accentColor)
            .cornerRadius(4)
    }
}

struct TokenIcon: View {
    let token: Token
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [token.primaryColor, token.secondaryColor]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(token.symbol.prefix(2))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Chain Selector Sheet
struct ChainSelectorSheet: View {
    @Binding var selectedChain: SupportedChain
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(SupportedChain.allCases, id: \.self) { chain in
                    ChainSelectorRow(
                        chain: chain,
                        isSelected: selectedChain == chain
                    ) {
                        selectedChain = chain
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Select Chain")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ChainSelectorRow: View {
    let chain: SupportedChain
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ChainIcon(chain: chain)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading) {
                    Text(chain.displayName)
                        .font(.headline)
                    
                    Text("Chain ID: \(chain.chainId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 4)
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Cross-Chain Bridge View
struct CrossChainBridgeView: View {
    @State private var fromChain: SupportedChain = .ethereum
    @State private var toChain: SupportedChain = .beam
    @State private var amount = ""
    @State private var selectedToken: Token?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bridge Assets")) {
                    HStack {
                        Text("From")
                        Spacer()
                        Picker("From Chain", selection: $fromChain) {
                            ForEach(SupportedChain.allCases.filter { $0 != .beam }, id: \.self) { chain in
                                Text(chain.displayName).tag(chain)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    HStack {
                        Text("To")
                        Spacer()
                        Text("BEAM Network")
                            .foregroundColor(.purple)
                    }
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Bridge Fee")) {
                    HStack {
                        Text("Estimated Fee")
                        Spacer()
                        Text("~$2.50")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Time")
                        Spacer()
                        Text("~5 minutes")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Bridge Assets") {
                        // Implement bridge logic
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(amount.isEmpty)
                }
            }
            .navigationTitle("Cross-Chain Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Token Detail View
struct TokenDetailView: View {
    let token: Token
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Token header
                    VStack(spacing: 16) {
                        TokenIcon(token: token)
                            .frame(width: 80, height: 80)
                        
                        Text(token.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("$\(token.price.formatted())")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("\(token.priceChange24h >= 0 ? "+" : "")\(token.priceChange24h.formatted())% (24h)")
                            .foregroundColor(token.priceChange24h >= 0 ? .green : .red)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button("Buy") {
                            // Implement buy logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Sell") {
                            // Implement sell logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Token stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Token Information")
                            .font(.headline)
                        
                        TokenStatRow(label: "Market Cap", value: "$\(token.marketCap.formatted())")
                        TokenStatRow(label: "24h Volume", value: "$\(token.volume24h.formatted())")
                        TokenStatRow(label: "Chain", value: token.chain.displayName)
                        TokenStatRow(label: "Category", value: token.category.rawValue)
                    }
                }
                .padding()
            }
            .navigationTitle(token.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct TokenStatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models
enum SupportedChain: String, CaseIterable {
    case beam = "BEAM"
    case ethereum = "ETH"
    case polygon = "MATIC"
    case avalanche = "AVAX"
    case arbitrum = "ARB"
    case optimism = "OP"
    
    var chainId: Int {
        switch self {
        case .beam: return 1337
        case .ethereum: return 1
        case .polygon: return 137
        case .avalanche: return 43114
        case .arbitrum: return 42161
        case .optimism: return 10
        }
    }
    
    var displayName: String {
        switch self {
        case .beam: return "BEAM Network"
        case .ethereum: return "Ethereum"
        case .polygon: return "Polygon"
        case .avalanche: return "Avalanche"
        case .arbitrum: return "Arbitrum"
        case .optimism: return "Optimism"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .beam: return .purple
        case .ethereum: return .blue
        case .polygon: return Color(red: 0.5, green: 0.3, blue: 0.9)
        case .avalanche: return .red
        case .arbitrum: return Color(red: 0.2, green: 0.4, blue: 0.9)
        case .optimism: return Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
    
    var iconSymbol: String {
        switch self {
        case .beam: return "⚡"
        case .ethereum: return "Ξ"
        case .polygon: return "⬟"
        case .avalanche: return "▲"
        case .arbitrum: return "◆"
        case .optimism: return "○"
        }
    }
}

struct Token: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let price: Double
    let priceChange24h: Double
    let marketCap: Double
    let volume24h: Double
    let chain: SupportedChain
    let category: TokenCategory
    let isFeatured: Bool
    let primaryColor: Color
    let secondaryColor: Color
}

class MarketplaceManager: ObservableObject {
    @Published var tokens: [Token] = []
    @Published var totalPortfolioValue: Double = 45678.90
    @Published var dailyChange: Double = 1234.56
    @Published var dailyChangePercent: Double = 2.78
    
    init() {
        loadMockTokens()
    }
    
    private func loadMockTokens() {
        tokens = [
            // BEAM tokens
            Token(name: "BEAM Coin", symbol: "BEAM", price: 0.0234, priceChange24h: 5.67, marketCap: 50000000, volume24h: 2500000, chain: .beam, category: .all, isFeatured: true, primaryColor: .purple, secondaryColor: .blue),
            
            // Ethereum tokens
            Token(name: "Ethereum", symbol: "ETH", price: 2456.78, priceChange24h: 3.45, marketCap: 295000000000, volume24h: 15000000000, chain: .ethereum, category: .all, isFeatured: true, primaryColor: .blue, secondaryColor: .cyan),
            Token(name: "Uniswap", symbol: "UNI", price: 6.78, priceChange24h: -2.34, marketCap: 5100000000, volume24h: 125000000, chain: .ethereum, category: .defi, isFeatured: false, primaryColor: .pink, secondaryColor: .purple),
            Token(name: "Chainlink", symbol: "LINK", price: 14.56, priceChange24h: 1.23, marketCap: 8200000000, volume24h: 450000000, chain: .ethereum, category: .defi, isFeatured: true, primaryColor: .blue, secondaryColor: .indigo),
            
            // Polygon tokens
            Token(name: "Polygon", symbol: "MATIC", price: 0.89, priceChange24h: 4.56, marketCap: 8300000000, volume24h: 380000000, chain: .polygon, category: .all, isFeatured: true, primaryColor: .purple, secondaryColor: .indigo),
            Token(name: "Aave", symbol: "AAVE", price: 89.45, priceChange24h: -1.78, marketCap: 1300000000, volume24h: 85000000, chain: .polygon, category: .defi, isFeatured: false, primaryColor: .teal, secondaryColor: .blue),
            
            // Avalanche tokens
            Token(name: "Avalanche", symbol: "AVAX", price: 34.67, priceChange24h: 2.89, marketCap: 12700000000, volume24h: 520000000, chain: .avalanche, category: .all, isFeatured: false, primaryColor: .red, secondaryColor: .orange),
        ]
    }
    
    func chainAllocation(for chain: SupportedChain) -> Double {
        switch chain {
        case .beam: return 35.5
        case .ethereum: return 28.3
        case .polygon: return 15.7
        case .avalanche: return 12.1
        case .arbitrum: return 5.2
        case .optimism: return 3.2
        }
    }
}
