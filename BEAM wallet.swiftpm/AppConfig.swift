import SwiftUI

struct AppConfig {
    static let appName = "BEAM Wallet"
    static let primaryColor = Color.purple

    // Production Vercel deployment — use http://localhost:3000 during local dev
    static let apiBaseURL = "https://fcu.beamthinktank.space"

    // Firebase Web API key (public — safe to embed in client code)
    static var firebaseApiKey: String {
        googleServiceValue("API_KEY") ?? "AIzaSyBm50IRFzB8jUDwjp5o6sAy9sb-xpFuVds"
    }

    static var firebaseProjectID: String {
        googleServiceValue("PROJECT_ID") ?? "beam-home"
    }

    // Google OAuth iOS client ID and redirect scheme are supplied through Info.plist.
    // The redirect scheme should be the reversed client ID:
    // com.googleusercontent.apps.<ios-client-id-prefix>
    static var googleOAuthClientID: String {
        stringInfoValue("GoogleOAuthClientID")
    }

    static var googleRedirectScheme: String {
        let configuredScheme = stringInfoValue("GoogleRedirectScheme")
        if !configuredScheme.isEmpty {
            return configuredScheme
        }

        let suffix = ".apps.googleusercontent.com"
        guard googleOAuthClientID.hasSuffix(suffix) else { return "" }
        return "com.googleusercontent.apps." + googleOAuthClientID.dropLast(suffix.count)
    }

    static let googleFirebaseRequestURI = "http://localhost"

    static let appleFirebaseRequestURI = "https://fcu.beamthinktank.space"
    static let passkeyRelyingPartyID = "fcu.beamthinktank.space"

    // Feature flags
    static let enableMarketplace = true
    static let enableDAO = true

    private static func stringInfoValue(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func googleServiceValue(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
