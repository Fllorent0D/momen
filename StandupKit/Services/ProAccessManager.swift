import Foundation
import RevenueCat

public enum PaywallReason: String, Identifiable {
    case upgrade
    case participantsLimit
    case customization
    case stats

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .upgrade:
            String(localized: "Passez a Momen Pro", bundle: .standupKit)
        case .participantsLimit:
            String(localized: "Passez a Pro pour les equipes de 5+", bundle: .standupKit)
        case .customization:
            String(localized: "La personnalisation est reservee a Pro", bundle: .standupKit)
        case .stats:
            String(localized: "Les statistiques sont reservees a Pro", bundle: .standupKit)
        }
    }

    public var message: String {
        switch self {
        case .upgrade:
            String(localized: "Debloquez les participants illimites, la personnalisation complete et les statistiques avancees.", bundle: .standupKit)
        case .participantsLimit:
            String(localized: "La version gratuite couvre jusqu'a 4 participants. Pro debloque les equipes completes.", bundle: .standupKit)
        case .customization:
            String(localized: "Debloquez les themes, la position de l'overlay et les effets visuels.", bundle: .standupKit)
        case .stats:
            String(localized: "Accedez a l'historique complet, aux tendances et a l'export CSV.", bundle: .standupKit)
        }
    }
}

/// Gate d'accès Pro adossé à RevenueCat (décision D10).
///
/// Pro = achat unique **non-consommable** (`be.floca.standuptimer.pro`, package
/// `$rc_lifetime` de l'offering `default`). L'entitlement `pro` de `CustomerInfo`
/// est l'unique source de vérité — validée serveur, partagée entre les appareils
/// du même Apple ID (achat universel Mac + iOS). Il n'y a pas d'essai à durée :
/// le palier gratuit (4 participants) *est* l'essai (décision v1).
@MainActor
@Observable
public final class ProAccessManager {
    public static let productID = "be.floca.standuptimer.pro"
    public static let entitlementID = "pro"
    public static let freeParticipantLimit = 4

    public private(set) var isPurchased = false
    public private(set) var isLoadingProduct = false
    public private(set) var isProcessingPurchase = false
    public private(set) var errorMessage: String?
    /// Prix localisé du package Pro (ex. « 12,99 € »), nil tant qu'il n'est pas chargé.
    public private(set) var displayPrice: String?

    public var paywallReason: PaywallReason?

    /// Opens the Pro screen as a standalone window. Wired by the app layer to
    /// `openWindow(id:)`. The paywall can't live in a `.sheet` on the menu-bar
    /// popover: clicking dismisses the popover and the sheet dies with it, so it
    /// gets its own window instead.
    public var openPaywallWindow: (() -> Void)?

    private var package: Package?
    private var updatesTask: Task<Void, Never>?

    /// Configure le SDK RevenueCat avec la clé publique de la plateforme. À appeler
    /// une fois au lancement de l'app, avant que le premier `ProAccessManager`
    /// touche `Purchases.shared`. Les clés publiques SDK sont conçues pour être
    /// embarquées dans le binaire (elles ne donnent pas d'accès en écriture).
    public static func configureRevenueCat() {
        // Achat universel : le Mac partage le bundle id de l'iOS, donc le même
        // enregistrement App Store et la même app RevenueCat (type `app_store`).
        // La clé publique SDK iOS vaut aussi pour macOS — pas d'app Mac séparée
        // (ce ne serait requis que pour un « legacy Mac », app pré-2020 non
        // universelle). watchOS/tvOS ne sont pas encore publiés → non configurés.
        #if os(iOS) || os(macOS)
        let apiKey = "appl_psgRWhiObfCUzzsgngTJImcagQp"
        #else
        let apiKey = ""
        #endif

        guard !apiKey.isEmpty, !Purchases.isConfigured else { return }
        Purchases.configure(withAPIKey: apiKey)
    }

    public init() {
        #if DEBUG
        // Unlock Pro immediately in dev, before the async entitlement refresh, so
        // the first frame already renders as Pro (no free→pro flash).
        isPurchased = true
        #endif

        updatesTask = observeCustomerInfo()

        Task {
            await refresh()
        }
    }

    public var isPaywallPresented: Bool {
        paywallReason != nil
    }

    public var isProUnlocked: Bool {
        isPurchased
    }

    public var purchaseButtonTitle: String {
        if let displayPrice {
            return String(localized: "Debloquer Pro definitivement - \(displayPrice)", bundle: .standupKit)
        }
        return String(localized: "Debloquer Pro definitivement", bundle: .standupKit)
    }

    public func presentPaywall(_ reason: PaywallReason) {
        errorMessage = nil
        paywallReason = reason
        openPaywallWindow?()
    }

    public func dismissPaywall() {
        paywallReason = nil
        errorMessage = nil
    }

    public func refresh() async {
        await loadOffering()
        await refreshEntitlements()
    }

    public func purchase() async {
        await loadOffering()

        guard Purchases.isConfigured else {
            errorMessage = String(localized: "Les achats ne sont pas disponibles sur cet appareil.", bundle: .standupKit)
            return
        }

        guard let package else {
            errorMessage = String(localized: "Impossible de charger l'achat integre pour le moment.", bundle: .standupKit)
            return
        }

        isProcessingPurchase = true
        errorMessage = nil
        defer { isProcessingPurchase = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }

            applyEntitlement(from: result.customerInfo)
            if isPurchased {
                Analytics.capture("pro_purchased", ["price": displayPrice ?? ""])
                paywallReason = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        guard Purchases.isConfigured else { return }

        isProcessingPurchase = true
        errorMessage = nil
        defer { isProcessingPurchase = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyEntitlement(from: info)

            if isPurchased {
                paywallReason = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadOffering() async {
        guard Purchases.isConfigured else { return }
        guard package == nil, !isLoadingProduct else { return }

        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let pkg = offerings.current?.lifetime ?? offerings.current?.availablePackages.first
            package = pkg
            displayPrice = pkg?.storeProduct.localizedPriceString
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        // Dev builds always run as Pro so gated features are testable without a
        // real purchase. Setting the stored flag (rather than overriding the
        // computed gate) keeps `@Observable` tracking and the "Pro" badge in sync.
        isPurchased = true
        return
        #endif

        guard Purchases.isConfigured else { return }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyEntitlement(from: info)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyEntitlement(from info: CustomerInfo) {
        #if DEBUG
        isPurchased = true
        #else
        isPurchased = info.entitlements[Self.entitlementID]?.isActive == true
        #endif
    }

    /// Réagit en direct aux changements d'entitlement (achat sur un autre appareil,
    /// restauration, expiration) via le flux `CustomerInfo` de RevenueCat.
    private func observeCustomerInfo() -> Task<Void, Never> {
        Task { [weak self] in
            guard Purchases.isConfigured else { return }

            for await info in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self?.applyEntitlement(from: info)
            }
        }
    }
}
