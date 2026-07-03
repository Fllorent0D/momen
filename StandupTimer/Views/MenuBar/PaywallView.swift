import StoreKit
import StandupKit
import SwiftUI

struct PaywallView: View {
    @Environment(ProAccessManager.self) private var proAccess
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.lg) {
            header
            statusCard
            benefits
            footer
        }
        .padding(PulseSpacing.xl)
        .frame(width: 420)
        // The Pro screen tracks system appearance like the rest of the menu-bar
        // chrome and the iOS app — light variant in Light mode, dark in Dark.
        .background(PulseColor.canvas)
        .task {
            await proAccess.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(alignment: .top) {
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(PulseColor.signal)
                    Text("Pulse Pro")
                        .pulseText(.label)
                        .foregroundStyle(PulseColor.signal)
                }

                Spacer()

                Button {
                    proAccess.dismissPaywall()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.pulse(.icon))
            }

            Text(proAccess.paywallReason?.title ?? PaywallReason.upgrade.title)
                .pulseText(.heading)
                .foregroundStyle(PulseColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(proAccess.paywallReason?.message ?? PaywallReason.upgrade.message)
                .pulseText(.body)
                .foregroundStyle(PulseColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PulseSpacing.xs) {
                PulseStatusPill("Achat unique", systemImage: "lock.open", tone: .signal)
                PulseStatusPill("Accès à vie", systemImage: "infinity", tone: .warn)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            if proAccess.isPurchased {
                Text("Momen Pro est deja actif sur ce Mac.")
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)
                Text("Votre achat integre unique est restaure automatiquement via l'App Store.")
                    .pulseText(.body)
                    .foregroundStyle(PulseColor.inkMuted)
            } else {
                Text("Momen est gratuit jusqu'a 4 participants.")
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)
                Text("Debloquez Pro une fois pour toutes et gardez l'acces a vie.")
                    .pulseText(.body)
                    .foregroundStyle(PulseColor.inkMuted)
            }

            if let errorMessage = proAccess.errorMessage {
                Text(errorMessage)
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.over)
            }
        }
        .padding(PulseSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseColor.surface, in: RoundedRectangle(cornerRadius: PulseRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: PulseRadius.card)
                .strokeBorder(PulseColor.ink.opacity(0.06))
        )
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text("AVEC PRO")
                .pulseText(.label)
                .foregroundStyle(PulseColor.inkMuted)

            benefitRow(icon: "person.3.fill", title: "Participants illimites", detail: "Passez de 4 a toute l'equipe.")
            benefitRow(icon: "paintpalette.fill", title: "Personnalisation complete", detail: "Themes, position de l'overlay et effets visuels.")
            benefitRow(icon: "chart.bar.xaxis", title: "Statistiques avancees", detail: "Historique, tendances et export CSV.")
        }
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.sm) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(PulseColor.signal)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .pulseText(.callout)
                    .foregroundStyle(PulseColor.ink)
                Text(detail)
                    .pulseText(.label)
                    .foregroundStyle(PulseColor.inkMuted)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: PulseSpacing.sm) {
            Button {
                Task {
                    await proAccess.purchase()
                    if proAccess.isPurchased {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if proAccess.isProcessingPurchase {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(proAccess.purchaseButtonTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.pulse(.primary, accent: .signal, size: .large))
            .disabled(proAccess.isProcessingPurchase || proAccess.isPurchased)

            Button {
                Task {
                    await proAccess.restorePurchases()
                    if proAccess.isPurchased {
                        dismiss()
                    }
                }
            } label: {
                Text("Restaurer les achats")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.secondary, accent: .inkMuted))
            .disabled(proAccess.isProcessingPurchase)

            Button {
                proAccess.dismissPaywall()
                dismiss()
            } label: {
                Text("Continuer avec Free")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pulse(.neutral))
        }
    }
}
