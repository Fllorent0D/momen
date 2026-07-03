import StoreKit
import StandupKit
import SwiftUI

/// iOS Pro paywall (Pulse redesign).
///
/// The same offer as the macOS `PaywallView` — a single lifetime purchase (no
/// trial; the free tier up to 4 participants is the trial), three Pro benefits
/// — but rendered with the Pulse design system on
/// the canvas (cards on `surface`, mono prices, `.pulse` buttons) instead of
/// native chrome, matching the store mockups. Binds to the shared
/// ``ProAccessManager``; the presenting sheet's binding clears
/// `proAccess.paywallReason` on dismiss.
struct PaywallView_iOS: View {
    @Bindable var proAccess: ProAccessManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PulseColor.canvas.color(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                    header
                    statusCard
                    benefits
                }
                .padding(PulseSpacing.xl)
                .padding(.bottom, PulseSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { footer }
        }
        .task { await proAccess.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            HStack(alignment: .top) {
                HStack(spacing: PulseSpacing.xs) {
                    PulseStatusPill("ACHAT UNIQUE", systemImage: "lock.open", tone: .signal)
                    PulseStatusPill("ACCÈS À VIE", systemImage: "infinity", tone: .warn)
                }
                Spacer()
                Button { proAccess.dismissPaywall() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(PulseColor.surface2.color(for: colorScheme)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            }

            Text(reason.title)
                .pulseText(.title)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text(reason.message)
                .pulseText(.bodyLarge)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, PulseSpacing.sm)
    }

    private var reason: PaywallReason {
        proAccess.paywallReason ?? .upgrade
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(statusTitle)
                .pulseText(.heading)
                .foregroundStyle(PulseColor.ink.color(for: colorScheme))
            Text(statusDetail)
                .pulseText(.body)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            if let errorMessage = proAccess.errorMessage {
                Text(errorMessage)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.over.color(for: colorScheme))
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    private var statusTitle: String {
        if proAccess.isPurchased {
            return "Pro est déjà actif."
        }
        return "Momen est gratuit jusqu'à 4 participants."
    }

    private var statusDetail: String {
        if proAccess.isPurchased {
            return "Votre achat intégré unique est restauré automatiquement via l'App Store."
        }
        return "Débloquez Pro une fois pour toutes et gardez l'accès à vie."
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("AVEC PRO")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))

            benefitRow(icon: "person.3.fill", title: "Participants illimités",
                       detail: "Passez de 4 à toute l'équipe.")
            benefitRow(icon: "paintpalette.fill", title: "Personnalisation complète",
                       detail: "Accents par personne et effets visuels.")
            benefitRow(icon: "chart.bar.xaxis", title: "Statistiques avancées",
                       detail: "Historique, tendances et export CSV.")
        }
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PulseColor.signal.color(for: colorScheme))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: PulseSpacing.xxs) {
                Text(title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink.color(for: colorScheme))
                Text(detail)
                    .pulseText(.body)
                    .foregroundStyle(PulseColor.inkMuted.color(for: colorScheme))
            }
            Spacer(minLength: 0)
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PulseRadius.card, style: .continuous)
                .fill(PulseColor.surface.color(for: colorScheme))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: PulseSpacing.sm) {
            Button {
                Task { await proAccess.purchase() }
            } label: {
                HStack(spacing: PulseSpacing.xs) {
                    if proAccess.isProcessingPurchase {
                        ProgressView().controlSize(.small).tint(PulseColor.canvas.color(for: .dark))
                    }
                    Text(proAccess.purchaseButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.primary, accent: .signal, size: .large))
            .disabled(proAccess.isProcessingPurchase || proAccess.isPurchased)

            Button {
                Task { await proAccess.restorePurchases() }
            } label: {
                Text("Restaurer les achats").frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.secondary, accent: .signal, size: .large))
            .disabled(proAccess.isProcessingPurchase)

            Button {
                proAccess.dismissPaywall()
            } label: {
                Text("Continuer avec Free")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.neutral))
        }
        .padding(.horizontal, PulseSpacing.xl)
        .padding(.top, PulseSpacing.sm)
        .padding(.bottom, PulseSpacing.xs)
        .background(
            PulseColor.canvas.color(for: colorScheme)
                .opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
