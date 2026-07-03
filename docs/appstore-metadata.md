# App Store metadata — Standup Timer

> À copier/coller dans App Store Connect. Base = **fr**, traduction = **en**.
> Généré le 2026-07-01. Aligné sur ROADMAP §7–8 (freemium, achat unique universel).

## Fiche produit (identité)

| Champ | Valeur |
|-------|--------|
| Nom App Store | **Standup Timer** (vérifier dispo dans ASC — sinon « Standup Timer: Daily ») |
| Bundle ID | `be.floca.standup-timer` (iOS + Mac, achat universel) |
| Catégorie principale | Productivité |
| Catégorie secondaire | Économie et entreprise |
| Prix de l'app | Gratuit (freemium) |
| Classement d'âge | 4+ |
| Langues | Français (base), Anglais |

## Achat intégré (In-App Purchase)

| Champ | Valeur |
|-------|--------|
| Product ID | `be.floca.standuptimer.pro` |
| Type | Non-consommable (achat unique, débloque Mac + iOS) |
| Prix (Tier) | 9,99–14,99 € — trancher le tier à la création (D8) |
| Nom d'affichage (fr) | Standup Timer Pro |
| Nom d'affichage (en) | Standup Timer Pro |
| Description (fr) | Débloque les participants illimités, la synchro iCloud entre Mac et iPhone, les stats et l'export, et la personnalisation. Achat unique, pas d'abonnement. |
| Description (en) | Unlock unlimited participants, iCloud sync between Mac and iPhone, stats and export, and personalization. One-time purchase, no subscription. |

---

## FR (langue de base)

**Sous-titre** (30 car. max)
> Le minuteur de vos standups

**Texte promotionnel** (170 car. max — modifiable sans review)
> Gardez vos réunions debout courtes et équitables. Chaque intervenant a son temps, l'équipe voit le signal passer du vert au rouge.

**Mots-clés** (100 car. max, séparés par des virgules, sans espaces)
> standup,daily,scrum,minuteur,réunion,timer,agile,sprint,équipe,productivité,chrono,meeting

**Description**
```
Standup Timer garde vos réunions debout courtes, équitables et vivantes.

Fixez une durée globale : l'app répartit automatiquement le temps entre les
participants. Un anneau passe du vert au rouge — toute l'équipe voit le signal,
personne ne monopolise la parole.

CŒUR
• Répartition automatique du temps par personne
• Déroulé mains libres : compte à rebours 3-2-1, suivant/précédent, pause
• Gestion du dépassement (optionnel / toujours / jamais)
• Sons de transition discrets
• Participants : présence, avatars, ordre aléatoire
• Presets : enregistrez vos configurations d'équipe
• Rappel quotidien

MAC
• Vit dans la barre des menus
• Overlay flottant au-dessus de toutes vos fenêtres et écrans
• Raccourcis clavier globaux
• Lancement au démarrage

STATS & RITUEL
• Historique des réunions, détail par intervenant, taux de dépassement
• Badges d'équipe positifs pour ancrer le rituel
• Citations de productivité

GRATUIT / PRO
Gratuit jusqu'à 4 participants, en local. Passez en Pro (achat unique, pas
d'abonnement) pour : participants illimités, synchro iCloud Mac ↔ iPhone,
stats & export, et personnalisation. Un seul achat débloque Mac et iPhone.

Fait en Belgique. Pas de compte, pas de pub, pas de pistage.
```

**URL de politique de confidentialité** : https://floca.be/standup-timer/privacy (à publier)
**URL de support** : https://floca.be/standup-timer/support (à publier)
**URL marketing** (optionnel) : https://floca.be/standup-timer

---

## EN

**Subtitle** (30 char)
> The timer for your standups

**Promotional text** (170 char)
> Keep your stand-up meetings short and fair. Everyone gets their slice of time, and the whole team watches the signal go from green to red.

**Keywords** (100 char)
> standup,daily,scrum,timer,meeting,agile,sprint,team,productivity,retro,scrummaster,huddle

**Description**
```
Standup Timer keeps your stand-up meetings short, fair, and alive.

Set one total duration and the app splits the time automatically between
participants. A ring shifts from green to red — the whole team sees the signal,
nobody runs long.

CORE
• Automatic per-person time allocation
• Hands-free flow: 3-2-1 countdown, next/previous, pause
• Overtime handling (optional / always / never)
• Subtle transition sounds
• Participants: presence, avatars, shuffle order
• Presets: save your team setups
• Daily reminder

MAC
• Lives in the menu bar
• Floating overlay above every window and screen
• Global keyboard shortcuts
• Launch at login

STATS & RITUAL
• Meeting history, per-speaker detail, overtime rate
• Positive team badges to anchor the ritual
• Productivity quotes

FREE / PRO
Free for up to 4 participants, stored locally. Go Pro (one-time purchase, no
subscription) for: unlimited participants, iCloud sync between Mac and iPhone,
stats & export, and personalization. One purchase unlocks Mac and iPhone.

Made in Belgium. No account, no ads, no tracking.
```

**Privacy policy URL**: https://floca.be/standup-timer/privacy
**Support URL**: https://floca.be/standup-timer/support

---

## Privacy nutrition labels (App Privacy)

Déclarer dans ASC → App Privacy. Basé sur l'usage réel post-nettoyage (Giphy/remote coupés) :

| Data type | Collectée ? | Usage | Liée à l'identité | Tracking |
|-----------|-------------|-------|-------------------|----------|
| Purchases (historique d'achat) | Oui (via RevenueCat) | Fonctionnalité de l'app | Non (ID anonyme RC) | Non |
| Identifiants (RevenueCat anonymous App User ID) | Oui | Fonctionnalité de l'app | Non | Non |
| Contenu utilisateur (noms de participants, presets, stats) | Stocké **sur l'appareil** + iCloud privé de l'utilisateur — **non collecté** par le dev | — | — | Non |

- ⚠️ **RevenueCat** : appels réseau + ID achat → à déclarer + `PrivacyInfo.xcprivacy`.
- ⚠️ **iCloud** (sync Pro) : reste dans le conteneur iCloud privé de l'utilisateur → pas « collecté ».
- Aucun SDK de pub/analytics tiers. Pas de tracking (ATT non requis).

## Screenshots requis (à produire — assets non générables ici)

Réf. maquettes : `Standup timer multiplateforme/screenshots/` + frames iOS/Android.

| Plateforme | Tailles obligatoires |
|-----------|----------------------|
| iPhone 6.9" | 1290 × 2796 (obligatoire) |
| iPhone 6.5" | 1242 × 2688 ou 1284 × 2778 |
| iPad 13" | 2064 × 2752 (si l'app supporte iPad) |
| Mac | 1280 × 800 / 1440 × 900 / 2560 × 1600 / 2880 × 1800 |

Min. 1 capture/plateforme, jusqu'à 10. Fournir en fr et en (ou jeu unique localisable).

## Checklist restante avant soumission (hors métadonnées)

- [ ] **RevenueCat** : activer **Mac App Store** dans les réglages du projet RC, puis créer l'app Mac (bloqué côté API — voir résumé).
- [ ] **RevenueCat** : configurer la **clé App Store Connect API** dans l'app RC (pour lier le produit au store).
- [ ] **App Store Connect** : créer l'IAP `be.floca.standuptimer.pro` (non-consommable) + le rendre universel Mac/iOS.
- [ ] **Signing Mac** : `DEVELOPMENT_TEAM` + signature App Store + App Sandbox (cf. §8).
- [ ] Publier les URLs privacy + support.
- [ ] Produire icônes finales + screenshots.
