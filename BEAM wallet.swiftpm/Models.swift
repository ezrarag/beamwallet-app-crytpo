import SwiftUI

// MARK: - Data Models
struct Transaction: Identifiable, Codable {
    let id: UUID
    let hash: String
    let amount: Double
    let type: TransactionType
    let timestamp: Date
    let address: String
    let confirmations: Int
    
    // Custom initializer for creating new transactions
    init(hash: String, amount: Double, type: TransactionType, timestamp: Date, address: String, confirmations: Int) {
        self.id = UUID()
        self.hash = hash
        self.amount = amount
        self.type = type
        self.timestamp = timestamp
        self.address = address
        self.confirmations = confirmations
    }
    
    // Custom coding keys to handle UUID properly
    enum CodingKeys: String, CodingKey {
        case id, hash, amount, type, timestamp, address, confirmations
    }
    
    enum TransactionType: String, Codable, CaseIterable {
        case sent = "sent"
        case received = "received"
        
        var symbol: String {
            switch self {
            case .sent: return "-"
            case .received: return "+"
            }
        }
        
        var color: Color {
            switch self {
            case .sent: return .red
            case .received: return .green
            }
        }
    }
}

struct WalletInfo: Codable {
    let address: String
    let balance: Double
    let isTestnet: Bool
}

struct Proposal: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String
    let votesFor: Int
    let votesAgainst: Int
    let endDate: Date
    
    var totalVotes: Int {
        votesFor + votesAgainst
    }
    
    var supportPercentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(votesFor) / Double(totalVotes) * 100
    }
}
