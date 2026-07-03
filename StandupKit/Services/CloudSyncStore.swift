import Foundation

/// Synchro iCloud des données d'équipe (presets, stats, badges) — **feature Pro**
/// (décision D9). S'appuie sur `NSUbiquitousKeyValueStore` : Foundation pur,
/// disponible sur toutes les plateformes Apple, et l'achat universel fait que Mac
/// et iPhone partagent le même conteneur iCloud (même bundle id).
///
/// Semantique : chaque store enregistre une clé + un **merge** (jamais un écrasement
/// aveugle), donc l'historique n'est jamais perdu quand deux appareils divergent.
/// Convergence par re-push après merge (KVS ne re-notifie pas une valeur inchangée).
///
/// Le trial n'est PAS concerné : le statut Pro suit déjà l'Apple ID via RevenueCat.
/// KVS plafonne à 1 Mo / 1024 clés — les stats sont cappées à 500 entrées côté
/// `StatsStore`, ce qui tient largement.
@MainActor
public final class CloudSyncStore {
    public static let shared = CloudSyncStore()

    private let kvs = NSUbiquitousKeyValueStore.default
    /// clé → application d'un blob distant (merge + persistance locale).
    private var handlers: [String: (Data) -> Void] = [:]
    public private(set) var isEnabled = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] note in
            let changed = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated {
                self?.pull(keys: changed)
            }
        }
    }

    /// Un store déclare sa clé cloud et comment fusionner un blob entrant.
    public func register(key: String, apply: @escaping (Data) -> Void) {
        handlers[key] = apply
    }

    /// Gate Pro. À l'activation : tire les valeurs cloud existantes dans les stores
    /// (qui re-pousseront leur union). À la désactivation : sync locale uniquement.
    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        guard enabled else { return }
        kvs.synchronize()
        pull(keys: nil)
    }

    /// Pousse un blob local vers iCloud (no-op si la sync Pro est coupée).
    public func push(key: String, data: Data) {
        guard isEnabled else { return }
        kvs.set(data, forKey: key)
        kvs.synchronize()
    }

    /// Applique les blobs cloud pour les clés données (toutes si `nil`).
    private func pull(keys: [String]?) {
        guard isEnabled else { return }
        let targets = keys ?? Array(handlers.keys)
        for key in targets {
            guard let apply = handlers[key], let data = kvs.data(forKey: key) else { continue }
            apply(data)
        }
    }
}
