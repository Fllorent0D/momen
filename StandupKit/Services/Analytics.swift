import Foundation
#if os(iOS) || os(macOS)
import PostHog
#endif

/// Analytics produit, adossé à PostHog (host EU). Configuré uniquement sur
/// iOS/macOS ; sur watchOS/tvOS c'est un no-op. Clé publique de projet (safe à
/// embarquer). Aucun tracking cross-app → pas d'ATT requis.
public enum Analytics {
    /// Clé publique du projet PostHog « Momen » (EU).
    private static let apiKey = "phc_C9kTYoYaAoTqpfZ2jr5h2wHxzLwsKnGg4a6UU4MMspsn"
    private static let host = "https://eu.i.posthog.com"

    /// À appeler une fois au lancement, avant le premier `capture`.
    public static func configure() {
        #if os(iOS) || os(macOS)
        let config = PostHogConfig(apiKey: apiKey, host: host)
        // Pas de capture d'écran auto ni de session replay : événements explicites.
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
        #endif
    }

    /// Émet un événement produit avec des propriétés optionnelles.
    public static func capture(_ event: String, _ properties: [String: Any]? = nil) {
        #if os(iOS) || os(macOS)
        PostHogSDK.shared.capture(event, properties: properties)
        #endif
    }
}
