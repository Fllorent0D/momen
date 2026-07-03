# Standup Timer — Roadmap App Store (macOS + iOS)

> Objectif : transformer le projet actuel (app Mac menu-bar + télécommande iPhone) en
> **un produit publiable sur l'App Store**, sur **Mac ET iOS**, avec une version iOS
> **autonome** (= équivalent de l'app Mac, **pas** une télécommande).
>
> Statut : brainstorm en cours. Les sections « DÉCISIONS » listent les choix à valider.
> ✅ = recommandation par défaut · ❓ = à trancher · ⚠️ = risque/blocage App Store.

---

## 1. État actuel (inventaire)

**App Mac (`StandupTimer`)** — app menu-bar (`MenuBarExtra`) :
- Timer de réunion : durée globale, répartition automatique du temps par personne.
- Participants : ajout/retrait/réordonnancement, présence, avatars, ordre aléatoire.
- Presets : sauvegarde/chargement de configurations.
- Déroulé : countdown 3-2-1, démarrage auto, suivant/précédent, reporter à la fin, pause, annuler.
- Dépassement (overtime) : modes optionnel/toujours/jamais.
- Overlay flottant (`NSPanel`) au-dessus de tous les écrans + animation « DVD bounce ».
- Sons (Tink/Ping/Basso/Glass — sons système macOS).
- Stats : historique, détail par intervenant, taux de dépassement, export CSV, copie résumé.
- Gamification : streaks, MVP, awards (dont « Bavard »).
- Fun : GIF Giphy de fin, citations de productivité, confettis.
- Raccourcis clavier globaux (NSEvent + Accessibilité).
- Système : lancement au démarrage (`SMAppService`), rappel quotidien (notif).
- Pro/paywall : achat intégré unique (StoreKit), essai 7 j, palier gratuit (3 participants).
- Remote : `HostPeerService` (MultipeerConnectivity) reçoit les commandes de l'iPhone.

**App iOS (`StandupTimerRemote`)** — **télécommande uniquement** (à supprimer, cf. §3).

**Autour :** landing page statique (`landing-page/`), projet XcodeGen (`project.yml`).

---

## 2. DÉCISIONS À PRENDRE (à valider avant de coder)

| # | Décision | Statut |
|---|----------|--------|
| D1 | **Quelles features « superflues » couper ?** | ✅ **DÉCIDÉ** : couper Giphy + DVD bounce. Gamification → **simplifier en badges d'équipe**. Citations gardées. |
| D2 | **Sort du code « remote » ?** | ✅ **DÉCIDÉ** : tout supprimer maintenant (app iPhone remote + `HostPeerService` + protocole). Réintégrable plus tard. |
| D3 | **Modèle de monétisation ?** | ✅ **DÉCIDÉ** : freemium + achat unique **universel** (1 achat débloque Mac + iOS). |
| D4 | **Cas d'usage principal de l'app iOS ?** | ✅ **DÉCIDÉ** : **standup en présentiel** (téléphone sur la table). Cf. §5. |
| D5 | **Versions OS minimales ?** | ✅ **DÉCIDÉ** : macOS **14** Sonoma + iOS **17** (min requis par `@Observable`). Langues App Store : **fr + en**. |
| D6 | **Android ?** | ✅ **DÉCIDÉ : OUI (gardé).** ⚠️ Hors périmètre de ce repo Swift : réécriture native séparée (Kotlin/Compose) ou stack cross-platform (Flutter/KMP). Pas d'équivalent MultipeerConnectivity → si remote réintégré un jour, utiliser Nearby Connections. **Ordre** : livrer macOS + iOS d'abord, Android ensuite (cf. §11). |
| D7 | **Seuil du palier gratuit ?** | ✅ **DÉCIDÉ : 4 participants gratuits, paywall au 5ᵉ.** Le mur arrive quand le ritual devient une vraie équipe (= a un budget). Moment d'achat à plus forte intention. Remplace l'ancien seuil de 3. |
| D8 | **Prix Pro ?** | ✅ **DÉCIDÉ : achat unique 9,99–14,99 €** (pas d'abonnement — pas de backend cloud, habitude d'achat des utilitaires Mac). Abonnement seulement si un jour : sync cloud / comptes org / stats partagées. |
| D9 | **Sync iCloud Mac ↔ iOS ?** | ✅ **DÉCIDÉ : OUI, et c'est une feature _Pro (payante)_.** En Free = persistance locale. Choix technique à trancher (cf. **§5b**) : KVS / CloudKit / SwiftData+CloudKit. |
| D10 | **Outil de monétisation ?** | ✅ **DÉCIDÉ : RevenueCat** (au lieu de StoreKit brut). Entitlement Pro unifié Apple + Android, validation serveur (règle l'essai contournable), paywalls. Cf. **§7**. |
| D11 | **Design system ?** | ✅ **DÉCIDÉ : Pulse** (« Le Signal »). Redesign complet dark/light, anneau conique, Space Grotesk + JetBrains Mono. ⚠️ **Supprime les 4 thèmes couleur** (un seul signal vert→rouge + accents par personne). Cf. **§4b**. |

---

## 3. Nettoyage des features (D1 + D2)

### À couper (proposé)
- [ ] **Giphy** — `GiphyService.swift`, `GifImageView.swift`, toggle « GIF de fin », clé API.
      ⚠️ Évite : permission réseau, clé API dans le binaire, risque modération de contenu en review.
- [ ] **DVD bounce** — logique de rebond dans `OverlayPanel.swift` (gadget macOS, non portable).
- [ ] **Remote complet** (D2) — cible `StandupTimerRemote`, `HostPeerService.swift`,
      `Shared/RemoteProtocol.swift`, `Models/RemoteProtocol.swift`, tous les `broadcastStatus()`,
      `peerService` dans `MeetingManager`. ⚠️ Supprime la permission « Réseau local ».

### Décidé : simplifier (pas couper)
- [x] **Citations de productivité** — **gardées** (légères, sans risque).
- [ ] **Gamification → badges d'équipe** : retirer l'award « Bavard » et le MVP individuel
      (logique compétitive / pointage de doigt). Recadrer en **badges collectifs positifs** :
      ex. « Réunion éclair » (équipe), « Semaine parfaite » (0 dépassement sur la semaine),
      « Assidu » (X standups au compteur), streak d'équipe. Objectif : valoriser le rituel, pas juger.

### À garder (cœur du produit)
- Timer, participants, presets, déroulé, overtime, sons, stats/export, thèmes, rappel quotidien, confettis.

---

## 4. Refactor architecture — cœur partagé (le gros du travail)

Aujourd'hui **tout** est dans la cible macOS et `MeetingManager` instancie en dur des services
macOS (`OverlayPanel`, `KeyboardShortcutManager`, `HostPeerService`, `SMAppService`, `NSPasteboard`,
`NSSavePanel`). Il faut séparer le code en 3 unités.

```
StandupKit (partagé, sans AppKit/UIKit direct)
 ├── Models       : Meeting, MeetingPreset, Participant, MeetingRecord, TimerState, enums
 ├── Logic        : MeetingManager (machine à états du timer), StatsStore, [GamificationStore]
 ├── Utilities    : TimeFormatter, ThemeColors
 ├── ProAccess    : ProAccessManager (StoreKit — déjà cross-platform ✅)
 └── Protocols    : OverlayPresenting, SoundPlaying, ExportService, (HotkeyHandling, LaunchAtLogin = macOS)

StandupTimer (macOS)            StandupTimer (iOS)
 ├── App MenuBarExtra            ├── App plein écran (NavigationStack)
 ├── ConfigurationView (popover) ├── ConfigView (Form/List natif)
 ├── OverlayPanel (NSPanel)      ├── Écran timer plein écran (OverlayView adapté)
 ├── KeyboardShortcutManager     ├── Boutons tactiles + haptique
 ├── SMAppService (login)        ├── Keep-awake, (Live Activity plus tard)
 ├── NSSound                     ├── AVFoundation + fichiers son embarqués
 └── NSPasteboard / NSSavePanel  └── UIPasteboard / share sheet
```

### Tâches refactor
- [ ] Extraire les modèles + logique dans un groupe/cible **StandupKit** (sources partagées par les
      deux apps via `project.yml`, ou framework dédié).
- [ ] **Découpler `MeetingManager`** des services macOS : injecter des protocoles
      (`OverlayPresenting`, `SoundPlaying`, `ExportService`) avec une implémentation par plateforme.
      → supprimer `peerService`/`broadcastStatus` (D2), `keyboardManager`, `overlayPanel` du cœur.
- [ ] Abstraire les **sons** : protocole `SoundPlaying` (macOS = `NSSound`, iOS = `AVAudioPlayer`
      + fichiers son courts embarqués, ou `AudioServicesPlaySystemSound`). ⚠️ `NSSound` n'existe pas sur iOS.
- [ ] Abstraire l'**export** : copie presse-papier (`NSPasteboard`/`UIPasteboard`) + export CSV
      (`NSSavePanel`/share sheet iOS).
- [ ] Abstraire l'**overlay** : macOS = `NSPanel` ; iOS = bascule de vue racine (timer plein écran).
- [ ] Garder `#if os(macOS)` uniquement pour : login auto, raccourcis globaux, multi-écrans.
- [ ] Vérifier `AvatarView` (rendu image) → version cross-platform (`Image(uiImage:)`/`Image(nsImage:)`).

---

## 4b. Design system — Pulse 🎨 (redesign complet · D11)

> Réf : `Standup timer multiplateforme/Pulse - Design System.dc.html` + `Standup Timer - Directions.dc.html` + `screenshots/`.
> **Tout l'UI est à redessiner selon Pulse**, en **dark + light**, sur iOS / macOS / (Android plus tard).

**Concept fondateur — « Le Signal » :** la couleur encode le temps. Dégradé unique
**vert → lime → ambre → rouge** ; le timer central devient un **anneau conique** (fini la barre).
Le mouvement **s'accélère avec la tension** (calme en vert, nerveux en rouge).

**Tokens couleur (sombre / clair)** — le code n'appelle **jamais un hex en dur** :
- `canvas` #0A0B0D / #F4F6F5 · `surface` #131519 / #FFFFFF · `surface-2` #1A1D22 / #F1F3F1
- `ink` #F4F6F5 / #0B0D10 · `ink-muted` #AAB2AE / #5A635D
- `signal` (en cours) #00E08A / #00C878 · `warn` (limite) #FFC53D / #E0A11F · `over` (dépassement) #FF4D4D / #F5392F
- **Accents par personne** (teinte stable/membre, jamais pour le signal) : #5B6CFF #FF9A3D #2FBF71 #36C2FF #FF5B8A #B07CFF #2FD4C4

**Typo :** **Space Grotesk** (UI/titres) + **JetBrains Mono** (chrono, %, labels, `tabular-nums`) — à embarquer (Google Fonts, OFL).

**Motion :** `pulseGlow` 2.8s (halo anneau) · `breathe` 1.6→0.8s (pastille, + vite près de la limite) · `overPulse` 1s (chrono en dépassement) · ring sweep (changement d'orateur).

**Composants à reskinner :** boutons (primaire vert / secondaire outline / neutre / destructif / icône rond), interrupteurs, pastilles d'état (EN COURS/LIMITE/DÉPASSEMENT), contrôle segmenté, rangée participant (avatar accent + rôle + % + toggle + file), stepper, slider. Rayons 13–18px.

**Par plateforme :**
- **macOS** : menu bar extra (glyphe au repos → chrono + couleur en réunion), popover vibrancy, **2 modes overlay** : l'**anneau** (focus) et **le bandeau qui se vide** (ambiant pleine largeur, voile teinté dans les derniers instants) = évolution de l'overlay actuel.
- **iOS** : **anneau plein écran** (= mode table présentiel D4), **Live Activity / Dynamic Island promu en v1**, Liquid Glass + SF Symbols + haptique, icône *tinted* iOS 18.
- **Android** (plus tard) : Material 3, FAB « Suivant », Material You, notif ongoing.

**Icône :** anneau-timer + triangle « go », dégradé nuit #16191C→#0A0B0D, halo vert, squircle r 22,5%, glyphe dans 60% central (masque adaptatif Android).

**⚠️ Réconciliations avec les décisions déjà prises :**
- Les **4 thèmes couleur** (Vert/Rouge, Bleu/Orange…) **disparaissent** (Pulse = UN signal). → la « personnalisation Pro » devient **accents par personne + position du bandeau + effets** (plus de choix de palette).
- L'overlay Mac **n'est pas supprimé** : redessiné (anneau + bandeau qui se vide). Le **DVD bounce reste coupé**.
- Le **médaillon de badge** (`BADGES.md` + `Medallion.dc.html` / `Pulse - Badges.dc.html`) suit l'esthétique Pulse (signal, mono, halo). Rendu **procédural** (un composant, 23 glyphes) — plus d'artworks PNG bespoke.

---

## 5. App iOS autonome (D4 — positionnement)

✅ **DÉCIDÉ : standup en présentiel** — téléphone posé/calé sur la table pendant le daily debout.
(Rappel : sur iOS, **pas d'overlay au-dessus des autres apps** — impossible. L'écran timer EST l'app.)

Implications design :
- **Mode table** : affichage XXL de l'intervenant + temps restant, lisible à ~1–2 m, fort contraste.
- **Portrait ET paysage** (téléphone calé dans les deux sens).
- **Gros boutons tactiles** en bas (précédent / pause / suivant / reporter) + **retour haptique**.
- **Écran toujours allumé** pendant la réunion (`isIdleTimerDisabled`).
- **Synchro iCloud Mac ↔ iOS** (D9) — **feature Pro**. Presets + config suivent l'utilisateur entre appareils. Cf. **§5b**.

### Tâches app iOS (selon D4)
- [ ] Créer la cible iOS `StandupTimer` (iPhone + iPad) dans `project.yml`.
- [ ] **Écran timer plein écran** : adapter `OverlayView` (barre compacte 750pt → plein écran portrait/paysage),
      gros chiffres, intervenant courant + suivant, progression, dots.
- [ ] **Contrôles tactiles** : précédent / pause / suivant / reporter — gros boutons, **retour haptique**.
- [ ] **Écran config** : convertir `ConfigurationView` (popover 420pt) en `NavigationStack` + `Form`/`List`
      groupée native iOS (sections : Réunion, Participants, Presets, Personnalisation, Système).
- [ ] **Écran stats** : adapter `StatsView` à iOS.
- [ ] **Empêcher la veille** (`isIdleTimerDisabled`) pendant une réunion.
- [ ] **Sons + haptique** iOS (cf. §4), lecture audio en arrière-plan si pertinent.
- [ ] **Rappel quotidien** : `UNUserNotificationCenter` (déjà cross-platform ✅).
- [ ] Optionnel plus tard : **Live Activity / Dynamic Island**, widget, raccourci clavier iPad.
- [ ] **Synchro iCloud** (Pro) des presets/config/stats — cf. **§5b** (D9).

---

## 5b. Synchro iCloud Mac ↔ iOS (D9) — feature Pro

**Objectif :** un utilisateur **Pro** sur le même compte iCloud retrouve ses **presets** et sa **config**
sur Mac et iPhone ; idéalement l'**historique stats** unifié. ⚠️ **Derrière le paywall** : en Free,
persistance **locale uniquement**.

**Données & persistance actuelles :**
- Config réunion → `UserDefaults.standard` (clés `meeting.*`)
- Presets → fichier JSON (`Application Support/StandupTimer/presets.json`) + `selectedPresetId` en `UserDefaults`
- Stats → fichier (historique `MeetingRecord`, **croît** dans le temps)
- Essai/trial → `UserDefaults` (**ne pas synchroniser** ; le Pro suit déjà l'Apple ID via StoreKit)

**Choix technique (à trancher — D9) :**

| Option | Pour | Contre |
|--------|------|--------|
| **A. iCloud KVS** (`NSUbiquitousKeyValueStore`) : presets + config ; stats locales (v1) | Trivial (miroir de UserDefaults), instantané, zéro backend | Limite 1 Mo / 1024 clés ; dernier-écrivain-gagne ; stats non synchro |
| **B. CloudKit** : presets + config + stats | Scalable, par-enregistrement (pas de perte sur stats append-only), robuste | Container + entitlement + code de sync/merge/offline = plus de travail |
| **C. SwiftData + CloudKit** (migrer la persistance) | Sync auto complète, « propre » long terme, profite du refactor M2 | Migration des modèles (`@Model`) = gros refactor + quirks SwiftData |

**Reco v1 : A** (presets + config via KVS, stats locales) — couvre la valeur clé « je configure une
fois, dispo partout » à risque minimal. Stats unifiées = **B/C plus tard**. Note : M2 refactorant déjà
la persistance, **C** est tentant si on veut tout faire « propre » d'un coup.

**Gating Pro :** n'activer la sync que si `isProUnlocked` ; sinon paywall (nouveau `PaywallReason.sync`).
⚠️ iCloud = **Apple uniquement** → côté Android (§11), une sync Pro devra passer par un autre mécanisme.

---

## 6. Nettoyage macOS

- [ ] Retirer le code remote (D2) et le DVD bounce (D1) de la cible Mac.
- [ ] Vérifier que l'overlay multi-écrans reste correct sans le bounce.
- [ ] Conserver raccourcis globaux / login auto / overlay (spécifiques Mac, valeur ajoutée Mac).

---

## 7. Monétisation (D3)

État actuel : achat unique `be.floca.standup-timer.pro` via **StoreKit brut**, essai 7 j (stocké en
`UserDefaults`, **trivialement contournable**), gate à 3 participants. → On bascule sur **RevenueCat** (D10).

**Décidé :**
- [x] **Freemium + achat unique universel** (D3) — 1 achat débloque Pro sur Mac + iOS.
- [x] **Prix 9,99–14,99 € one-time** (D8) — pas d'abonnement.
- [x] **Seuil gratuit = 4 participants** (D7), paywall à l'ajout du 5ᵉ.
- [x] **Split** — Free = 4 participants (persistance locale) ; Pro = illimité + personnalisation (accents/position/effets — **plus de thèmes couleur**, cf. D11) + stats/export + **synchro iCloud** (D9).
- [x] **Outil = RevenueCat** (D10).

**Pourquoi RevenueCat :** entitlement Pro **unifié Apple + Android** (clé pour D6), **validation serveur**
(règle l'essai contournable et le partage Mac↔iOS sans dépendre de l'achat universel App Store), paywalls +
A/B + analytics intégrés. Gratuit jusqu'à ~2,5 k$ MTR puis ~1 %.

**Tâches RevenueCat :**
- [ ] Intégrer le SDK `RevenueCat` (Swift Package) dans les cibles Mac + iOS.
- [ ] **Réécrire `ProAccessManager`** sur RevenueCat (`Purchases.configure`, `CustomerInfo`, entitlement
      `pro`) — remplace l'API `StoreKit.Transaction` actuelle ; `isProUnlocked` = entitlement RC.
- [ ] Supprimer l'essai « date en `UserDefaults` » → **trial géré par RevenueCat / offre d'intro** (fiable).
- [ ] Configurer le dashboard RevenueCat : entitlement `pro`, offering, produit lié à App Store Connect.
- [ ] App Store Connect : créer l'achat intégré (+ achat universel Mac/iOS, ou laisser RC unifier).
- [ ] Mettre à jour le gate **3 → 4** participants + ajouter `PaywallReason.sync` (gate la sync, cf. §5b).
- [ ] Fichier **`.storekit`** + sandbox RevenueCat pour tester achats / restore / trial.
- [ ] ⚠️ **Privacy** : le SDK RC fait des appels réseau (ID anonyme, achats) → déclarer dans
      `PrivacyInfo.xcprivacy` + étiquette de confidentialité (cf. §8).

---

## 8. Préparation App Store (Mac + iOS)

### Signing / build
- [ ] Cible Mac : ajouter `DEVELOPMENT_TEAM`, passer en signature **App Store** (actuellement
      `CODE_SIGN_IDENTITY: "-"` + manuel → ad-hoc, **non publiable**).
- [ ] Activer **App Sandbox** (entitlement) sur la cible Mac (requis Mac App Store).
- [ ] Vérifier que `be.floca.standup-timer` (iOS) et la cible Mac partagent la config d'achat universel.
- [x] **Versions OS** : macOS 14, iOS 17 → mettre à jour `deploymentTarget` dans `project.yml`. ⚠️ Vérifier les API qui exigeaient 26.0.

### Assets & métadonnées
- [ ] **Icônes** finales Mac + iOS (les `AppIcon.appiconset` existent — vérifier qu'ils sont remplis).
- [ ] **`PrivacyInfo.xcprivacy`** : aligner sur l'usage réel (Giphy/remote coupés) ; ⚠️ **déclarer RevenueCat** (appels réseau, ID achat) + **iCloud** (sync Pro).
- [ ] **Localisation du code** : externaliser les chaînes (tout en dur en fr) en String Catalog (`.xcstrings`) + traduction **en**.
- [ ] **Captures d'écran** App Store (Mac + iPhone + iPad), descriptions, mots-clés (fr + en).
- [ ] **URL de politique de confidentialité** + **URL de support** (obligatoires).
- [ ] Décider du **nom App Store** (vérifier dispo de « Standup Timer »).

### Landing page
- [ ] Mettre à jour `landing-page/` : retirer la promo « remote iPhone », ajouter l'app iOS autonome,
      remplacer les `mailto:` par les liens App Store réels.

---

## 9. Ordre proposé

1. **Décisions** D1–D9 (ce doc).
2. **Nettoyage** features coupées (§3) — réduit la surface avant le refactor.
3. **Refactor** cœur partagé StandupKit (§4) — débloque tout le reste.
4. **Design system Pulse** (§4b) — couche de tokens + composants, base du reskin Mac et de l'app iOS.
5. **App iOS** (§5) — construite Pulse-native.
6. **Synchro iCloud Pro** (§5b) — une fois les deux apps debout (test cross-device).
7. **Monétisation** RevenueCat (§7).
8. **Prep App Store** Mac + iOS (§8) + landing page.
9. Soumission Apple.
10. **Android** (§11) — cycle suivant, après la v1 Apple.

---

## 10. Questions ouvertes / à creuser
- **Nom de produit** : vérifier la disponibilité de « Standup Timer » sur l'App Store (sinon, variante).
- **Identité visuelle / icône** commune Mac + iOS (+ Android).
- **D9 (tech sync)** encore à trancher : KVS / CloudKit / SwiftData+CloudKit (reco A). Stats unifiées = B/C plus tard.

---

## 11. Android (D6 — gardé, livré après Mac/iOS)

⚠️ **Pas dans ce repo Swift.** Aucune ligne du code actuel ne se porte sur Android. Choix de stack à trancher :

| Option | Pour | Contre |
|--------|------|--------|
| **Kotlin + Jetpack Compose** (natif) | Qualité/perf native, écosystème Play | 2ᵉ codebase à maintenir en parallèle de Swift |
| **Flutter** (Dart) | 1 codebase Android+iOS, UI cohérente | Abandonner SwiftUI iOS déjà prévu, repartir de zéro |
| **KMP** (Kotlin Multiplatform) | Partager la **logique** (timer/stats), UI native chacun | Le cœur Swift `StandupKit` (§4) n'est pas réutilisable → logique à réécrire en Kotlin |

Décision pragmatique : **macOS + iOS d'abord en Swift** (code déjà là), **Android ensuite**.
À ce moment, soit Kotlin/Compose natif, soit re-évaluer Flutter/KMP selon le temps dispo.

### Implications Android
- [ ] Choisir la stack (Kotlin natif recommandé si on garde Swift pour Apple).
- [ ] Réécrire la logique timer/participants/stats (pas de réutilisation depuis Swift).
- [ ] Monétisation : **RevenueCat** côté Android aussi (Google Play Billing) → **entitlement `pro` unifié** Apple + Android, même split (4 gratuits / illimité Pro).
- [ ] Pas de remote v1 ; si réintégré : **Nearby Connections API** (≠ MultipeerConnectivity).
- [ ] Cas d'usage = même « mode table » présentiel que iOS (écran plein, gros chiffres, keep-awake).
- [ ] Assets/store Play distincts (icône adaptive, captures, fiche Play Store fr + en).

---

## 12. Apple Watch + Apple TV (nouvelles cibles Apple)

⚠️ **Statut : scaffold posé** (cibles `StandupTimer-watchOS` + `StandupTimer-tvOS` dans `project.yml`,
chacune = app SwiftUI minimale + stubs de services + vue smoke-test câblée sur `MeetingManager`).
**Reste à faire : le vrai UI + les services réels.** Min OS : watchOS **10**, tvOS **17** (requis par `@Observable`).

Tout repose sur le **cœur partagé `StandupKit`** (§4) — déjà sans AppKit/UIKit, donc il compile aussi
pour watchOS/tvOS. Les deux cibles ont le **même préfixe de bundle id** que Mac/iOS (achat universel, D3) :
`be.floca.standup-timer.watchkitapp` et `be.floca.standup-timer.tvos`.

### D12 — Positionnement de chaque appareil (à valider)
| Appareil | Rôle proposé | Cas d'usage |
|----------|--------------|-------------|
| **Apple Watch** | **Télécommande au poignet** du standup (scrum master debout, sans téléphone en main) | Démarrer / suivant / pause / temps restant en un coup d'œil, retour haptique par phase |
| **Apple TV** | **Affichage « salle »** : le grand écran au mur pendant le daily présentiel | Anneau + intervenant + chrono XXL, lisible de toute la pièce, pilotage Siri Remote |

### Tâches watchOS
- [ ] **UI compacte Pulse** : anneau de signal réduit + intervenant + chrono, adapté petits écrans.
- [ ] **Digital Crown** pour naviguer / ajuster, **boutons** Démarrer/Suivant/Pause.
- [ ] **Haptique** par phase (déjà câblé : `WatchSoundPlayer` → `WKInterfaceDevice.play`).
- [ ] **Complications / Smart Stack** (lancer le standup, temps restant).
- [ ] Sync de la config/presets via iCloud (D9) — sinon app autonome locale.
- [ ] Décider : app **autonome** vs. **compagnon** d'un iPhone (scaffold = autonome, `WKRunsIndependentlyOfCompanionApp`).

### Tâches tvOS
- [ ] **Vue salle plein écran** : anneau + intervenant courant + suivant + chrono géant, fort contraste.
- [ ] **Focus engine / Siri Remote** : Démarrer / Suivant / Pause au clic, swipe pour naviguer.
- [ ] **Top Shelf** + **Brand Assets** (icône en couches tvOS — manquante dans le scaffold, à créer).
- [ ] **Keep-awake** (pas de veille pendant la réunion).
- [ ] Sons via `AudioToolbox` (déjà câblé : `TVSoundPlayer`).

### Communs / limites du scaffold actuel
- [ ] **Services réels** : remplacer les stubs no-op (`*ExportService`, `*OverlayPresenting`,
      `*ShortcutHandler`, `*LaunchAtLogin`) par de vraies implémentations là où ça a du sens.
- [ ] **RevenueCat** (§7) : vérifier le SDK sur watchOS/tvOS, entitlement `pro` partagé.
- [ ] **Compile-check** : les **plateformes** watchOS/tvOS ne sont pas installées sur la machine de dev
      (seuls les SDK stubs le sont) → `xcodebuild -downloadPlatform watchOS` / `tvOS` avant de builder.
- [ ] Assets App Store distincts (captures watchOS/tvOS), fiches localisées fr + en.
</content>
