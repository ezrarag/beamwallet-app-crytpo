import SwiftUI

// MARK: - Enhanced DAO View
struct DAOView: View {
    @State private var proposals = [
        Proposal(id: 1, title: "Increase Block Size Limit", description: "Proposal to increase the block size limit to improve transaction throughput", votesFor: 1250, votesAgainst: 340, endDate: Date().addingTimeInterval(86400 * 7)),
        Proposal(id: 2, title: "Implement Lightning Network", description: "Integrate Lightning Network support for faster payments", votesFor: 2100, votesAgainst: 150, endDate: Date().addingTimeInterval(86400 * 14))
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Active Proposals")) {
                    ForEach(proposals) { proposal in
                        ProposalRow(proposal: proposal)
                    }
                }
                
                Section(header: Text("Your Voting Power")) {
                    HStack {
                        Text("BEAM Tokens")
                        Spacer()
                        Text("1,500 BEAM")
                            .fontDesign(.monospaced)
                    }
                }
            }
            .navigationTitle("DAO Governance")
        }
    }
}

struct ProposalRow: View {
    let proposal: Proposal
    @State private var hasVoted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(proposal.title)
                .font(.headline)
            
            Text(proposal.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Support: \(proposal.supportPercentage, specifier: "%.1f")%")
                        .font(.caption)
                    
                    ProgressView(value: proposal.supportPercentage, total: 100)
                        .tint(.green)
                }
                
                Spacer()
                
                if !hasVoted {
                    HStack {
                        Button("YES") {
                            hasVoted = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        
                        Button("NO") {
                            hasVoted = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                } else {
                    Text("Voted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
