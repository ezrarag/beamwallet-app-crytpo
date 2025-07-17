import Foundation

struct TransactionModel: Identifiable, Codable {
    let id: String
    let hash: String
    let amount: Double
    let type: String // "sent" or "received"
    let timestamp: Date
    let address: String
    let confirmations: Int
}

class BlockchainService {
    static let shared = BlockchainService()
    private let baseURL = "https://api.blockcypher.com/v1/btc/test3"
    private let session = URLSession.shared

    // Fetch balance for a given address
    func getBalance(for address: String, completion: @escaping (Result<Double, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/addrs/\(address)/balance")!
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(BalanceResponse.self, from: data)
                completion(.success(Double(decoded.final_balance) / 1e8))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Fetch transactions for a given address
    func getTransactions(for address: String, completion: @escaping (Result<[TransactionModel], Error>) -> Void) {
        let url = URL(string: "\(baseURL)/addrs/\(address)")!
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(AddressResponse.self, from: data)
                let txs = decoded.txrefs?.map { tx in
                    TransactionModel(
                        id: tx.tx_hash,
                        hash: tx.tx_hash,
                        amount: Double(tx.value) / 1e8 * (tx.tx_input_n == -1 ? 1 : -1),
                        type: tx.tx_input_n == -1 ? "received" : "sent",
                        timestamp: Date(timeIntervalSince1970: TimeInterval(tx.confirmed?.toDate()?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)),
                        address: address,
                        confirmations: tx.confirmations
                    )
                } ?? []
                completion(.success(txs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Placeholder for sending transaction (real signing not implemented)
    func sendTransaction(from: String, to: String, amount: Double, privateKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Placeholder: In real app, build, sign, and push raw tx
        completion(.failure(NSError(domain: "Not implemented", code: -1)))
    }
}

// MARK: - Codable Models
struct BalanceResponse: Codable {
    let final_balance: Int
}

struct AddressResponse: Codable {
    let txrefs: [TxRef]?
}

struct TxRef: Codable {
    let tx_hash: String
    let value: Int
    let confirmations: Int
    let confirmed: String?
    let tx_input_n: Int
}

// MARK: - Date Parsing Helper
extension String {
    func toDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
} 