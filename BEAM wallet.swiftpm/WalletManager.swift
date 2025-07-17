import SwiftUI
import Combine

class WalletManager: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var transactions: [TransactionModel] = []
    @Published var address: String = "mpXwg5r6r6Qw6Qw6Qw6Qw6Qw6Qw6Qw6Qw6" // BlockCypher testnet address
    @Published var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchWalletData()
    }

    func fetchWalletData() {
        BlockchainService.shared.getBalance(for: address) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let bal):
                    self?.balance = bal
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch balance: \(error.localizedDescription)"
                }
            }
        }
        BlockchainService.shared.getTransactions(for: address) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let txs):
                    self?.transactions = txs
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch transactions: \(error.localizedDescription)"
                }
            }
        }
    }

    func sendBTC(to address: String, amount: Double, privateKey: String, completion: @escaping (Bool, String?) -> Void) {
        BlockchainService.shared.sendTransaction(from: self.address, to: address, amount: amount, privateKey: privateKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let txHash):
                    completion(true, txHash)
                    self.fetchWalletData()
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
}
