# Standup Timer — Backlog (issues à faire)

> Liste actionnable dérivée des décisions de [`ROADMAP.md`](./ROADMAP.md).
> Chaque issue : objectif, fichiers/symboles concrets, étapes, et « Fait quand » (DoD).
> ⚠️ Les numéros de ligne sont **indicatifs** (dérivent au fil des édits).

## Jalons & ordre

| Jalon | Thème | Dépend de |
|-------|-------|-----------|
| **M1** | Nettoyage (couper le superflu) | — |
| **M2** | Refactor cœur partagé (StandupKit) | M1 |
| **M2b** | Design system Pulse (tokens + composants) | M2 |
| **M3** | App iOS autonome (présentiel) | M2b |
| **M4** | Badges d'équipe | M2 |
| **M5** | Monétisation propre | M2 |
| **M6** | Prep App Store (Mac + iOS) | M3 |
| **M7** | Landing page | M3 |
| **M8** | Synchro iCloud Pro (Mac ↔ iOS) | M2 (build) · M3 (test) |
| **M9** | Android (cycle suivant) | post-v1 Apple |

---

## M1 — Nettoyage

### #1 — Supprimer l'app remote + MultipeerConnectivity ✅ FAIT (itération 1)
**Dépend de :** —
**Supprimer :** `StandupTimerRemote/` (dossier entier), `Shared/RemoteProtocol.swift`, `StandupTimer/Models/RemoteProtocol.swift`, `StandupTimer/Services/HostPeerService.swift`
**Éditer :**
- [x] `project.yml` — retirer la cible `StandupTimerRemote`
- [x] `MeetingManager.swift` — retirer `let peerService` (~l.36), les closures `onCommandReceived`/`onPeerCountChanged` + `peerService.start()` (~l.57-71), la fonction `broadcastStatus()` (~l.505-532) et ses ~10 appels (~l.206, 213, 219, 239, 299, 312, 319, 334, 451)
- [x] `StandupTimer/Info.plist` — retirer `NSLocalNetworkUsageDescription` + `NSBonjourServices` (~l.29-31)
**Fait quand :** build macOS OK ; `grep -r 'Multipeer\|TimerStatus\|PeerMessage\|TimerCommand\|broadcastStatus'` → vide. ✅ Build SUCCEEDED, grep vide.

### #2 — Supprimer Giphy + « GIF de fin » ✅ FAIT (itération 2)
**Dépend de :** —
**Supprimer :** `StandupTimer/Services/GiphyService.swift`, `StandupTimer/Views/Components/GifImageView.swift`
**Éditer :**
- [ ] `Meeting.swift` — retirer `endScreenGif` (prop ~l.47, load ~l.116, save ~l.144, defaults ~l.169)
- [ ] `MeetingPreset.swift` — retirer `endScreenGif` (champ ~l.15, decode ~l.35, init ~l.54, apply ~l.72)
- [ ] `ConfigurationView.swift` — retirer le toggle « GIF de fin » (~l.676)
- [ ] `OverlayView.swift` — retirer `@State gifURL` (~l.23), le fetch `GiphyService` (~l.71-75), `GifImageView` (~l.264) ; `finishedContent` → icône statique (`party.popper.fill`/`checkmark.circle.fill`) ; **découpler la citation** (toujours affichée, plus liée à `endScreenGif`, ~l.277)
- [ ] Vérifier `GIPHY_API_KEY` dans `Info.plist`/`project.yml` → retirer si présent
**Fait quand :** écran de fin = icône + citation + résumé, **zéro appel réseau** ; build OK.

### #3 — Retirer le DVD bounce + le flag orphelin `overtimeShake` ✅ FAIT (itération 2)
**Dépend de :** —
**Note :** `overtimeShake` est un flag **orphelin** (jamais lu ; l'effet réel = le bounce, lancé inconditionnellement en overtime). Le toggle « Tremblement overtime » ne fait donc rien → on le retire avec le bounce.
**Éditer :**
- [ ] `OverlayPanel.swift` — supprimer tout l'état + méthodes bounce (`startBounce`/`stopBounce`/`tickBounce`, vars `bounce*`, `bounceStartDate`) ; **garder** `resetPosition()`, `show`, `close`
- [ ] `MeetingManager.swift` — supprimer `startOverlayBounce`/`stopOverlayBounce` (~l.91-97) + appels (`cancel` ~l.304, `tick`/overtime ~l.491) ; **garder** `resetOverlayPosition` (utilisé ~l.233)
- [ ] `Meeting.swift` — retirer `overtimeShake` (~l.46, 115, 143, 168)
- [ ] `MeetingPreset.swift` — retirer `overtimeShake` (~l.14, 34, 53, 71)
- [ ] `ConfigurationView.swift` — retirer le toggle « Tremblement overtime » (~l.677)
**Fait quand :** l'overtime n'anime plus le déplacement du panneau ; build OK.

### #4 — Compat décodage des presets après suppression de champs ✅ FAIT (itération 2)
**Dépend de :** #2, #3
**Note :** `MeetingPreset.init(from:)` décode `endScreenGif`/`overtimeShake` **explicitement** (`decode`, pas `decodeIfPresent`) → un preset sauvegardé planterait au chargement une fois les champs retirés.
- [ ] Rendre le décodage tolérant (retrait propre des clés) et tester le chargement d'un `presets.json` existant.
**Fait quand :** un preset créé avant le nettoyage se charge sans erreur.

---

## M2 — Refactor cœur partagé (StandupKit)

### #5 — Créer l'unité partagée StandupKit ✅ FAIT (itération 3)
**Dépend de :** M1
**Objectif :** code agnostique compilé dans les deux apps (sources partagées via `project.yml`, ou framework `StandupKit`).
**Périmètre :** Models (Meeting, MeetingPreset, Participant, MeetingRecord, TimerState, enums) · Logic (cœur MeetingManager, StatsStore) · Utilities (TimeFormatter, ThemeColors) · ProAccessManager (StoreKit, déjà cross-platform).
**Fait quand :** la cible macOS compile en consommant StandupKit ; aucun import AppKit dans StandupKit.

### #6 — Découpler MeetingManager des services macOS (protocoles) ✅ FAIT (itération 4)
**Dépend de :** #5
**Objectif :** injecter `OverlayPresenting`, `SoundPlaying`, `ExportService` ; sortir `overlayPanel`/`keyboardManager` du cœur (`peerService` déjà retiré en #1).
- [ ] Définir les protocoles dans StandupKit ; impl macOS dans la cible Mac ; injection à l'init.
**Fait quand :** `MeetingManager` compile **sans importer AppKit**.

### #7 — Abstraire le son (`SoundPlaying`) ✅ FAIT (itération 4)
**Dépend de :** #6
**Note :** `SoundManager` utilise `NSSound(named:)` (Tink/Ping/Basso/Glass) — **macOS-only**.
- [ ] Protocole `SoundPlaying` (transition/warning/overtime/finished) ; impl macOS = NSSound (impl iOS en #12).
**Fait quand :** le cœur ne référence plus `NSSound`.

### #8 — Abstraire l'export (`ExportService`) ✅ FAIT (itération 4)
**Dépend de :** #6
**Objectif :** sortir `NSPasteboard` (`copySummaryToClipboard` ~l.340) et `NSSavePanel` (`saveCSVToFile` ~l.369) de MeetingManager.
**Fait quand :** le cœur produit texte/CSV ; la plateforme gère copie/partage.

### #9 — AvatarView cross-platform ✅ FAIT (itération 5)
**Dépend de :** #5
**Objectif :** rendu de `avatarData: Data?` sans `NSImage` → `Image(nsImage:)` / `Image(uiImage:)` selon plateforme.
**Fait quand :** `AvatarView` compile sur Mac + iOS.

### #10 — Localisation : String Catalog ✅ FAIT (itération l10n)
**Dépend de :** M1 (parallélisable)
**État :** ✅ 4 `Localizable.xcstrings` (macOS app, StandupKit, iOS app, widget) — 304 chaînes, base **fr** + **en** 100% traduit ; `developmentLanguage: fr` ; rawValues persistés intacts (affichage via `.label` localisé) ; bloc `schemes:` ajouté (le scheme iOS avait sauté). Builds verts.
**Objectif :** externaliser les chaînes fr (en dur) en `.xcstrings` ; préparer la trad **en**.
**Fait quand :** chaînes via catalog ; build OK.

---

## M2b — Design system Pulse (cf. ROADMAP §4b + `Standup timer multiplateforme/`)

> Redesign complet selon **Pulse** (« Le Signal ») : tokens dark/light, anneau conique, Space Grotesk + JetBrains Mono.
> Fondation construite dans StandupKit → consommée par le reskin Mac ET l'app iOS Pulse-native.

### #44 — Couche de tokens Pulse (StandupKit) ✅ FAIT (itération 5)
**Dépend de :** #5
- [ ] Couleurs sémantiques dark/light : `canvas`, `surface`, `surface-2`, `ink`, `ink-muted`, `signal`, `warn`, `over`
- [ ] Échelle typo, spacing, rayons (13–18px), durées de motion
- [ ] Helpers `Color`/`Font` → **zéro hex en dur** dans les vues
**Fait quand :** tokens dispo Mac + iOS, bascule dark/light automatique.

### #45 — Embarquer les fonts (Space Grotesk + JetBrains Mono) ✅ FAIT (itération 7)
**Dépend de :** #44
- [ ] Ajouter les polices (OFL) aux deux cibles + déclaration Info.plist
- [ ] Helpers `Font` ; chrono en JetBrains Mono `tabular-nums`
**Fait quand :** les deux familles s'affichent Mac + iOS.

### #46 — Composant anneau « Signal » ✅ FAIT (itération 6)
**Dépend de :** #44
**Objectif :** anneau conique vert→lime→ambre→rouge piloté par le temps restant, halo `pulseGlow`, état dépassement (`overPulse`), chrono mono centré. **Remplace la barre** de `OverlayView`.
**Fait quand :** l'anneau reflète temps + état, réutilisable Mac/iOS.

### #47 — Reskin des composants Pulse ✅ FAIT (itération 13)
**Dépend de :** #44, #45
- [ ] Boutons (primaire/secondaire/neutre/destructif/icône), interrupteurs, pastilles d'état, segmented, rangée participant, stepper, slider
**Fait quand :** config + stats utilisent les composants Pulse.

### #48 — Accents par personne ✅ FAIT (itération 15)
**Dépend de :** #44
**Objectif :** teinte stable par participant (palette Pulse) pour avatars / file / surbrillance — remplace la coloration d'avatar actuelle ; **jamais** pour le signal temps.
**Fait quand :** chaque membre a sa teinte constante sur toutes les vues.

### #49 — Thème clair + sombre ✅ FAIT (itération 16)
**Dépend de :** #44
**Objectif :** toutes les vues passent par les tokens, rendu correct clair ET sombre.
**Fait quand :** bascule système OK, aucune couleur en dur.

### #50 — Retirer les 4 thèmes couleur (`ColorTheme`) ✅ FAIT (itération 7)
**Dépend de :** #44, #46
**Note :** Pulse = un seul signal (D11).
- [ ] Supprimer `ColorTheme` (enum + persistance + picker `ConfigurationView`) ; le timer utilise le Signal
- [ ] Ajuster la perso Pro : accents / position bandeau / effets (plus de palette)
**Fait quand :** plus de sélecteur de thème ; Signal partout.

### #51 — Overlay Mac redesign (anneau + bandeau qui se vide) ✅ FAIT (itération 12)
**Dépend de :** #46
**Objectif :** remplacer l'overlay actuel par les 2 modes Pulse — anneau focus + bandeau pleine largeur qui se vide (voile teinté en fin) ; conserve la position (`BannerPosition`).
**Fait quand :** overlay Mac conforme à Pulse, lisible à 3 m.

---

## M3 — App iOS autonome (présentiel)

### #11 — Créer la cible iOS ✅ FAIT (itération 8)
**Dépend de :** #5
**Objectif :** app `StandupTimer` iOS (iPhone + iPad, iOS 17), bundle `be.floca.standup-timer` (achat universel), consomme StandupKit.
**Fait quand :** app iOS qui build + run en simulateur.

### #12 — Impl iOS des protocoles plateforme ✅ FAIT (itération 9)
**Dépend de :** #7, #8, #11
- [ ] `SoundPlaying` iOS = `AVAudioPlayer` + 4 fichiers son courts embarqués (ou `AudioServicesPlaySystemSound`)
- [ ] `ExportService` iOS = `UIPasteboard` + share sheet (CSV)
- [ ] `OverlayPresenting` iOS = bascule de vue racine (le timer devient l'écran)
**Fait quand :** sons + copie + export CSV OK sur iOS.

### #13 — Écran timer plein écran « mode table » (anneau Signal) ✅ FAIT (itération 11)
**Dépend de :** #11, #12, #46
**Objectif :** écran focus Pulse plein écran = **anneau Signal** (#46) + orateur, chrono mono géant, suivant, file ; lisible à 1–2 m ; **portrait + paysage**. (Remplace la barre `OverlayView`.)
**Fait quand :** anneau + chrono lisibles à distance dans les deux orientations.

### #14 — Contrôles tactiles + haptique ✅ FAIT (itération 12)
**Dépend de :** #13
**Objectif :** gros boutons précédent / pause / suivant / reporter ; `UIImpactFeedbackGenerator` aux transitions et en overtime.
**Fait quand :** pilotage au doigt + retour haptique.

### #15 — Écran config iOS (NavigationStack / Form) ✅ FAIT (itération 9)
**Dépend de :** #11
**Objectif :** convertir `ConfigurationView` (popover 420pt) en `Form`/`List` groupée native iOS — sections : Réunion, Participants, Presets, Personnalisation, Système.
**Fait quand :** config complète éditable sur iPhone/iPad.

### #16 — Écran stats iOS ✅ FAIT (itération 9)
**Dépend de :** #11
**Objectif :** adapter `StatsView` à iOS (historique, détail par intervenant, taux de dépassement).
**Fait quand :** stats consultables ; export via share sheet.

### #17 — Keep-awake + rappel quotidien iOS ✅ FAIT (itération 12)
**Dépend de :** #11
- [ ] `UIApplication.shared.isIdleTimerDisabled = true` pendant la réunion (remettre `false` à la fin)
- [ ] Rappel quotidien via `UNUserNotificationCenter` (cross-platform)
**Fait quand :** l'écran ne s'éteint pas en réunion ; notif quotidienne OK.

### #52 — Live Activity / Dynamic Island (iOS) ✅ FAIT (itération live-activity)
**Dépend de :** #13
**Note :** promu par Pulse en cible v1 (peut glisser en v1.1 si le planning serre).
**Objectif :** anneau + chrono + orateur dans l'île et en Live Activity (suivi hors de l'app).
**Fait quand :** l'état du standup s'affiche dans la Dynamic Island / écran verrouillé.

---

## M4 — Badges d'équipe (cf. [`BADGES.md`](./BADGES.md))

> Refonte de la gamification en **système de badges à paliers**, fun, collectif/positif.
> Reveal **façon Apple Watch** en fin de standup. Catalogue + mécanique détaillés : `BADGES.md`.

### #18 — `BadgeStore` + catalogue (logique, StandupKit) ✅ FAIT (itération 6)
**Dépend de :** #5
**Objectif :** remplacer `Gamification.swift` (awards « Bavard »/MVP individuels supprimés) par un catalogue de badges à paliers + persistance.
- [ ] Modèle `Badge` (id, titre, sous-titre, icône, palier, secret, règle, cible) + paliers (Commun→Légendaire + Secret)
- [ ] Catalogue ~20 badges (cf. BADGES.md), règles calculées depuis `MeetingRecord` (réutiliser `currentStreak` / comptages parfaits)
- [ ] `BadgeStore` : ensemble persisté `{ badgeId: date }` ; `evaluate(stats:)` après `finishMeeting()` → renvoie les **nouveaux**
**Fait quand :** les badges se débloquent correctement, sont persistés, et les nouveaux sont détectés.

### #19 — Médaillon **procédural** (composant d'affichage) ✅ FAIT (port SwiftUI, itération badges-3)
**Dépend de :** #18
**Design de référence :** `Standup timer multiplateforme/Medallion.dc.html` (+ `Pulse - Badges.dc.html`).
**État :** ✅ `Medallion.dc.html` porté en SwiftUI (StandupKit). Chrome (anneau/disque/halo) **procédural** fidèle au design ; **glyphe = SF Symbol** (`Badge.systemImage`) — les primitives géométriques du mockup ont été jugées trop ternes. Compile Mac + iOS + StandupKit.
- [x] `AchievementMedallion.swift` : anneau conique par palier (5 métaux, tables couleur du `.dc.html`), disque nuit gravé, rim/hairline, halo + shimmer (reveal), arc de progression vert (verrouillé), « ? » (secret) ; dessin en base 200 puis `scale(size/200)`
- [x] Glyphe = `Image(systemName:)` gravé, teinté par le dégradé métal (hi→lo)
- [x] 3 états (`.unlocked` / `.locked` graphite + arc X/N / `.secret`) ; init `Badge` conservé (call sites intacts) + init « designer » `systemName:tier:state:…`
- [x] Grilles Stats passent `progress`, reveal passe `reveal: true`
**Fait quand :** ✅ chaque badge s'affiche à toutes tailles (reveal + grille), Mac + iOS.
**Reste (polish, optionnel) :** finesse du shimmer/halo au reveal ; choix fin des SF Symbols par badge.

### #42 — Reveal « Achievement » en fin de standup (façon Apple Watch) ✅ FAIT (iOS + macOS)
**Dépend de :** #19
**État :** ✅ `BadgeRevealView` partagé (StandupKit, confettis SwiftUI cross-platform, spring+halo, chaînage, reduce-motion) branché sur l'écran de fin **iOS** (son+haptique) ET **macOS** (panneau centré agrandi, son). Une fois par fin, jamais si zéro badge.
**Objectif :** afficher le(s) nouveau(x) badge(s) en grand à la fin (iOS plein écran ; macOS panneau centré agrandi).
- [ ] Médaillon en entrée spring + halo/éclat radial + **confettis** (`ConfettiView`) + **son** + **haptique** (iOS)
- [ ] Enchaîner si plusieurs badges ; tap / auto pour fermer
**Fait quand :** débloquer un badge déclenche un reveal satisfaisant.

### #43 — Grille des badges dans Stats (Mac + iOS) ✅ FAIT (itération badges-2)
**Dépend de :** #19, #16
**Objectif :** section « Badges » : débloqués (couleur + date) / verrouillés (grisé + **progression** X/N) / secrets (« ??? ») + compteur global.
**Fait quand :** la collection est consultable sur les deux plateformes.

---

## M5 — Monétisation (RevenueCat — D10)

> **D10 : RevenueCat** remplace StoreKit brut. Entitlement `pro` unifié Apple + Android, validation
> serveur (règle l'essai contournable + le partage Mac↔iOS), paywalls intégrés.

### #20 — Intégrer le SDK RevenueCat + configurer le dashboard
**Dépend de :** #5
- [ ] Ajouter `RevenueCat` (Swift Package) aux cibles Mac + iOS
- [ ] `Purchases.configure(withAPIKey:)` au lancement
- [ ] Dashboard RC : entitlement `pro`, offering, produit lié à App Store Connect
- [ ] App Store Connect : créer l'achat intégré (one-time, **9,99–14,99 €** — D8)
**Fait quand :** le SDK est configuré et récupère l'offering.

### #21 — Réécrire ProAccessManager sur RevenueCat
**Dépend de :** #20
**Objectif :** remplacer l'API `StoreKit.Transaction` actuelle par RevenueCat.
- [ ] `isProUnlocked` = entitlement `pro` de `CustomerInfo` (plus de `Transaction.currentEntitlements`)
- [ ] Achat / restore via `Purchases.shared`
- [ ] **Supprimer l'essai « date en `UserDefaults` »** (`pro.trialStartDate`) → trial via offre d'intro RC (fiable, serveur)
**Fait quand :** Pro débloqué/restauré via RC ; l'essai ne se ré-arme plus en réinstallant.

### #22 — Fichier `.storekit` + tests d'achat (sandbox RC)
**Dépend de :** #20
**Fait quand :** achat / restore / trial testables en local (simulateur iOS + Mac).

### #23 — Brancher les gates Pro (Mac + iOS)
**Dépend de :** #15, #21
**Objectif :** appliquer le split via l'entitlement RC + paywalls.
- [ ] Gates : participants illimités, personnalisation, stats/export, **synchro iCloud** (cf. #34)
- [ ] Paywall iOS (réutiliser/adapter `PaywallView`)
**Fait quand :** gates + paywall fonctionnels sur les deux plateformes.

### #31 — Appliquer le nouveau seuil gratuit (4 participants, paywall au 5ᵉ) ✅ FAIT (itération 1)
**Dépend de :** —
**Note :** décision D7 (remplace l'ancien seuil de 3).
- [x] `ProAccessManager.swift` — `freeParticipantLimit` : **3 → 4**
- [x] `ProAccessManager.swift` — textes `PaywallReason` : « jusqu'a 3 participants » → « 4 », « equipes de 4+ » → « 5+ »
- [x] `ConfigurationView.swift` (+ écran iOS) — « Free est limité à 3 participants » → « 4 » *(écran iOS pas encore créé — à refaire en #15)*
**Fait quand :** 4 participants gratuits ; paywall déclenché à l'ajout du 5ᵉ. ✅ Gating vérifié (4 free, 5e gated).

---

## M6 — Prep App Store (Mac + iOS)

### #24 — Signing Mac App Store + sandbox
**Dépend de :** M1
**Objectif :** cible Mac → `DEVELOPMENT_TEAM`, signature App Store (au lieu de `CODE_SIGN_IDENTITY "-"` manuel) ; activer **App Sandbox** (entitlement).
**Fait quand :** archive Mac signée App Store.

### #25 — Abaisser deploymentTarget (macOS 14 / iOS 17) + audit API ✅ FAIT (itération 14)
**Dépend de :** M1
**Objectif :** `project.yml` → macOS 14, iOS 17 ; corriger les API exigeant 26.0/18.0.
**Fait quand :** build sur les cibles minimales.

### #26 — Icône Pulse (Mac + iOS) ✅ FAIT (itération icon)
**Dépend de :** #44
**État :** ✅ Icône générée par script CoreGraphics (`scripts/generate_appicon.swift`) — dégradé nuit + anneau countdown vert (halo + point de tête) + triangle « go » ; macOS set complet 16–1024, iOS universel 1024 + variantes **dark & tinted iOS 18** (luminosity, fond transparent) ; actool OK, builds verts.
**Objectif :** icône Pulse (anneau-timer + triangle « go », dégradé nuit, halo vert, squircle r 22,5 %) ; variante **tinted iOS 18** ; safe-zone 60 % pour le masque adaptatif Android. Remplir les `AppIcon.appiconset`.
**Fait quand :** icônes complètes, toutes tailles + variantes.

### #27 — PrivacyInfo aligné + permissions ✅ FAIT (itération 16)
**Dépend de :** M1
**Note :** RevenueCat/iCloud à re-déclarer quand ces features arrivent (manifeste SDK RC bundlé séparément).
**Objectif :** `PrivacyInfo.xcprivacy` reflète l'usage réel — réseau local retiré (#1), Giphy retiré (#2) ; ⚠️ **déclarer RevenueCat** (appels réseau, ID achat) + **iCloud** (sync Pro).
**Fait quand :** étiquette de confidentialité minimale et exacte.

### #28 — Métadonnées + captures (fr + en) ⚠️ PARTIEL (métadonnées faites)
**Dépend de :** #13, #15
**État :** ✅ Copie App Store fr + en rédigée → `docs/app-store-metadata.md` (nom/sous-titre/promo/description/keywords/nouveautés + légendes de captures, limites respectées). ⚠️ **Captures** (Mac + iPhone + iPad) = étape manuelle (lancer les apps). Nom à figer (#29).
**Objectif :** captures Mac + iPhone + iPad ; descriptions, mots-clés ; **fr + en**.
**Fait quand :** fiches App Store prêtes.

### #29 — URLs légales + nom produit ⚠️ PARTIEL (itération 15)
**Dépend de :** —
**Objectif :** URL politique de confidentialité + URL support (obligatoires) ; vérifier la dispo du nom « Standup Timer » sur l'App Store.
**Fait quand :** URLs en ligne ; nom confirmé.
**État :** ✅ Pages `privacy.html` + `support.html` créées (à déployer sur de vraies URLs avant soumission). ⚠️ **« Standup Timer » est DÉJÀ PRIS sur l'App Store** → renommage requis. Suggestions : **Standup Signal** (reco), StandTime, Daily Ring, Tempo Standup, Roundtable Timer. **Décision utilisateur en attente.**

---

## M7 — Landing page

### #30 — Mettre à jour la landing page ✅ FAIT (itération 13)
**Dépend de :** M3
**Objectif :** retirer la promo « remote iPhone », présenter l'app iOS autonome, remplacer les `mailto:` par les liens App Store réels.
**Fichiers :** `landing-page/`.
**Fait quand :** la page reflète le produit publié.

---

## M8 — Synchro iCloud Pro (Mac ↔ iOS)

> **Feature Pro** (D9, cf. ROADMAP §5b). Mécanisme à trancher : **A** KVS (reco v1) · **B** CloudKit · **C** SwiftData+CloudKit.
> ⚠️ Ne **pas** synchroniser le trial (le Pro suit déjà l'Apple ID via RevenueCat).

### #32 — Activer la capability iCloud
**Dépend de :** #11
- [ ] Entitlement iCloud sur les deux cibles (KVS, ou container CloudKit selon A/B/C)
- [ ] `project.yml` — entitlements + `DEVELOPMENT_TEAM` cohérents
**Fait quand :** les deux apps démarrent avec iCloud activé (même compte).

### #33 — Sync des presets + config (cœur de la valeur)
**Dépend de :** #5, #32
**Objectif :** `PresetStore` + réglages `Meeting` synchronisés entre appareils.
- [ ] Miroir de la persistance vers iCloud (KVS : refléter `UserDefaults`/JSON ; sinon CloudKit/SwiftData)
- [ ] Observer les changements distants (`NSUbiquitousKeyValueStore.didChangeExternallyNotification` ou équiv.) → rafraîchir l'UI
**Fait quand :** un preset créé sur Mac apparaît sur iPhone (et inversement).

### #34 — Gater la sync derrière Pro
**Dépend de :** #21, #33
**Objectif :** la sync ne s'active que pour les utilisateurs Pro (entitlement RevenueCat).
- [ ] Ajouter `PaywallReason.sync`
- [ ] N'activer le miroir iCloud que si `isProUnlocked` ; sinon paywall
**Fait quand :** Free = local only ; Pro = sync active.

### #35 — Sync de l'historique stats + conflits
**Dépend de :** #33
**Note :** stats = log append-only qui croît → KVS (1 Mo) risqué ; CloudKit par-enregistrement préférable.
- [ ] Selon A/B/C : KVS plafonné (garder N derniers) **ou** CloudKit/SwiftData (sans perte)
- [ ] Stratégie de fusion (deux appareils hors-ligne) ; presets/config = dernier-écrivain acceptable
**Fait quand :** historique cohérent sur les deux appareils (ou explicitement local en v1 si option A).

### #36 — Test cross-device Mac ↔ iOS
**Dépend de :** #33, M3
- [ ] Même Apple ID : créer/éditer presets des deux côtés → vérifier la convergence
- [ ] Couper le réseau, éditer, reconnecter → vérifier le rattrapage
- [ ] Vérifier que Free ne synchronise pas (gate #34)
**Fait quand :** scénarios de sync validés à la main sur Mac + appareil iOS réel.

---

## M9 — Android (cycle suivant — D6, ROADMAP §11)

> **Hors repo Swift** : aucune réutilisation du code Apple. À livrer **après la v1 Apple**.

### #37 — Choisir la stack Android
**Dépend de :** v1 Apple livrée
**Objectif :** Kotlin + Jetpack Compose (natif, reco si on garde Swift côté Apple) ou ré-évaluer Flutter/KMP.
**Fait quand :** stack décidée + projet Android amorcé.

### #38 — Réécrire la logique (timer/participants/stats)
**Dépend de :** #37
**Note :** `StandupKit` (Swift) non réutilisable → portage de la machine à états + stores.
**Fait quand :** parité fonctionnelle du cœur avec iOS.

### #39 — UI « mode table » présentiel (Compose)
**Dépend de :** #37
**Objectif :** même positionnement que iOS (plein écran, gros chiffres, keep-awake, gros boutons).
**Fait quand :** écran timer + config + stats utilisables.

### #40 — Monétisation RevenueCat Android
**Dépend de :** #37
**Objectif :** RevenueCat + Google Play Billing → **entitlement `pro` unifié** Apple + Android ; même split (4 gratuits / illimité Pro).
**Fait quand :** achat/restore Play OK ; Pro reconnu cross-platform.

### #41 — Fiche Play Store (fr + en)
**Dépend de :** #39
**Objectif :** icône adaptive, captures, descriptions, mots-clés ; politique de confidentialité.
**Fait quand :** fiche Play prête à soumettre.
</content>
