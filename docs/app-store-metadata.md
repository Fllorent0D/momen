# App Store Connect — Métadonnées / Listing (texte seul)

> Issue **#28** (`ISSUES.md`, jalon M6) — métadonnées App Store **fr-BE + en**, sans captures (les screenshots sont une étape manuelle séparée, voir la fin du document).
>
> ⚠️ **NOM À CONFIRMER (TBC).** « Standup Timer » est **déjà pris** sur l'App Store. Le nom de travail recommandé est **« Standup Signal »** (décision finale du propriétaire en attente, cf. `ISSUES.md` #29 et `landing-page/NAME-RESEARCH.md`). Tout le texte ci-dessous est rédigé pour être **facilement remplaçable par rechercher/remplacer** : remplacer « Standup Signal » par le nom final retenu.
>
> ⚠️ **iCloud sync = « à venir / coming soon ».** La synchro iCloud (M8) n'est **pas** implémentée à ce jour ; elle est annoncée comme à venir et **ne doit pas** être présentée comme livrée.
>
> ℹ️ **Langues App Store :** fr (Français) + en (English) — cf. décision D5.
> ℹ️ Les compteurs de caractères sont indicatifs (à revérifier dans App Store Connect, qui compte les emoji/espaces à sa façon).

---

## 🇫🇷 Français (fr-BE)

### Nom de l'app (≤ 30) — **14 car.**
```
Standup Signal
```
> ⚠️ Nom provisoire (TBC). Remplacer si le propriétaire choisit un autre nom.

### Sous-titre (≤ 30) — **26 car.**
```
Minuteur de daily d'équipe
```

### Texte promotionnel (≤ 170) — **140 car.**
```
Cadencez vos daily standups : un temps par personne, un Signal couleur qui se vide, des stats claires. Sans compte, sans pub, sans tracking.
```

### Description (≤ 4000) — **~2 050 car.**
```
Le standup qui s'éternise ? Standup Signal donne à chaque personne son temps de parole — et le rend visible de tous, d'un seul coup d'œil.

LE SIGNAL
La couleur encode le temps qui reste : vert, puis ambre, puis rouge. Sur Mac, un bandeau flottant se vide au fil de la prise de parole ; sur iPhone et iPad, un grand anneau « mode table » se draine en plein écran. Lisible à plusieurs mètres, posé au milieu de l'équipe.

COMMENT ÇA MARCHE
• Réglez une durée de réunion répartie entre les présents, OU un temps fixe par personne.
• Lancez : décompte 3-2-1, puis chacun son tour.
• Suivant, précédent, pause, reporter quelqu'un à la fin — tout est à portée de clic ou de doigt.
• Le dépassement est géré proprement (optionnel, toujours, ou jamais).

CE QUE VOUS GARDEZ
• Historique des standups, détail par intervenant, taux de dépassement.
• Export CSV pour vos rétros.
• Des badges d'équipe positifs, révélés façon Apple Watch à la fin du daily — pour valoriser le rituel, jamais pointer du doigt.

DEUX PLATEFORMES, UN ACHAT
• macOS : app de barre de menus + overlay « Signal » flottant au-dessus de vos fenêtres.
• iPhone / iPad : minuteur plein écran « mode table », Live Activity et Dynamic Island pour suivre le standup hors de l'app.
Un seul achat Pro débloque Mac, iPhone et iPad.

GRATUIT, PUIS PRO
Gratuit et pleinement utilisable pour les petites équipes (jusqu'à 4 participants). Passez Pro (achat unique, pas d'abonnement) pour :
• participants illimités
• personnalisation
• statistiques et export
• synchro iCloud entre vos appareils (à venir)

VOTRE VIE PRIVÉE, INTACTE
Pas de compte. Pas de tracking. Pas d'analytics. Vos données restent en local sur votre appareil. C'est tout.

Conçu en Belgique par Florent Cardoen.
```

### Nouveautés / What's New — v1.0 (≤ 4000) — **~420 car.**
```
Première version de Standup Signal.

• Minuteur de standup pour Mac, iPhone et iPad.
• Le « Signal » couleur : bandeau flottant sur Mac, anneau plein écran « mode table » sur iOS.
• Temps par personne ou durée répartie, dépassement géré, suivant / pause / reporter.
• Historique, taux de dépassement, export CSV.
• Badges d'équipe avec reveal en fin de daily.
• Live Activity et Dynamic Island sur iPhone.
• Sans compte, sans tracking, données en local.

Un retour, une idée ? Écrivez-nous — merci de tester la v1 !
```

### Mots-clés (≤ 100, séparés par des virgules, sans espace) — **94 car.**
```
standup,scrum,daily,minuteur,timer,réunion,agile,sprint,rétro,timeboxing,équipe,chrono,meeting
```

### URL de support
```
https://<domaine-à-déployer>/support.html   →  landing-page/support.html
```
### URL marketing / politique de confidentialité
```
Marketing : https://<domaine-à-déployer>/                →  landing-page/index.html
Confidentialité : https://<domaine-à-déployer>/privacy.html  →  landing-page/privacy.html
```
> ⚠️ Les fichiers existent dans `landing-page/` mais **doivent d'abord être déployés à de vraies URL publiques et stables** avant la soumission (cf. en-têtes de `support.html` / `privacy.html` et `ISSUES.md` #29). Le domaine final est à fixer.

---

## 🇬🇧 English (en)

### App name (≤ 30) — **14 chars**
```
Standup Signal
```
> ⚠️ Working name (TBC). Replace if the owner picks a different name.

### Subtitle (≤ 30) — **26 chars**
```
Keep standups short & fair
```

### Promotional text (≤ 170) — **144 chars**
```
Pace your daily standups: a slice of time per person, a colour Signal that drains, clear stats. No account, no ads, no tracking. Just your team.
```

### Description (≤ 4000) — **~1 980 chars**
```
Standups that drag on? Standup Signal gives everyone their share of speaking time — and makes it visible to the whole team at a glance.

THE SIGNAL
Colour encodes the time left: green, then amber, then red. On Mac, a floating ribbon drains as each person speaks; on iPhone and iPad, a big "table mode" ring drains full-screen. Readable from across the room, sitting in the middle of the team.

HOW IT WORKS
• Set a meeting length split across whoever's present, OR a fixed time per speaker.
• Start: a 3-2-1 countdown, then each person in turn.
• Next, previous, pause, postpone someone to the end — all one click or tap away.
• Overtime is handled cleanly (optional, always, or never).

WHAT YOU KEEP
• Standup history, per-speaker detail, overrun rate.
• CSV export for your retros.
• Positive team badges, revealed Apple-Watch-style at the end of the standup — to celebrate the ritual, never to point fingers.

TWO PLATFORMS, ONE PURCHASE
• macOS: menu-bar app + a floating "Signal" overlay above your windows.
• iPhone / iPad: a full-screen "table mode" timer, with Live Activity and Dynamic Island to follow the standup outside the app.
A single Pro purchase unlocks Mac, iPhone and iPad.

FREE, THEN PRO
Free and fully usable for small teams (up to 4 participants). Go Pro (one-time purchase, no subscription) for:
• unlimited participants
• customisation
• stats and export
• iCloud sync across your devices (coming soon)

YOUR PRIVACY, INTACT
No account. No tracking. No analytics. Your data stays local on your device. That's it.

Made in Belgium by Florent Cardoen.
```

### What's New — v1.0 (≤ 4000) — **~400 chars**
```
The first release of Standup Signal.

• Standup timer for Mac, iPhone and iPad.
• The colour "Signal": a floating ribbon on Mac, a full-screen "table mode" ring on iOS.
• Time per person or a split duration, clean overtime, next / pause / postpone.
• History, overrun rate, CSV export.
• Team badges with an end-of-standup reveal.
• Live Activity and Dynamic Island on iPhone.
• No account, no tracking, data kept local.

Got feedback? Reach out — thanks for trying v1!
```

### Keywords (≤ 100, comma-separated, no wasted spaces) — **91 chars**
```
standup,scrum,daily,timer,meeting,agile,sprint,retro,timebox,team,stopwatch,kanban,ceremony
```

### Support URL
```
https://<domain-to-deploy>/support.html   →  landing-page/support.html
```
### Marketing / Privacy Policy URL
```
Marketing: https://<domain-to-deploy>/               →  landing-page/index.html
Privacy:   https://<domain-to-deploy>/privacy.html   →  landing-page/privacy.html
```
> ⚠️ The files exist in `landing-page/` but **must first be deployed to real, stable public URLs** before submission (see the headers of `support.html` / `privacy.html` and `ISSUES.md` #29). Final domain TBD.

---

## Positionnement / Positioning (court)

**FR :** Standup Signal transforme le daily debout en un rituel cadencé et lisible : chacun son temps de parole, un Signal couleur que toute l'équipe voit, et des stats pour s'améliorer. Pensé pour le présentiel (Mac en barre de menus, iPhone/iPad posé sur la table), sans compte ni tracking, avec un achat Pro unique qui suit l'équipe quand elle grandit.

**EN:** Standup Signal turns the daily stand-up into a paced, glanceable ritual: a fair slice of time each, a colour Signal the whole team can see, and stats to improve. Built for in-person standups (Mac in the menu bar, iPhone/iPad on the table), no account, no tracking, with a single Pro purchase that scales as the team grows.

---

## Légendes de captures d'écran suggérées (à utiliser quand le propriétaire capturera les écrans)

> Les captures elles-mêmes sont une **étape manuelle distincte** (Mac + iPhone + iPad). Voici des légendes prêtes, fr + en, à associer aux écrans correspondants.

| # | Écran suggéré | Légende FR | Légende EN |
|---|---------------|-----------|-----------|
| 1 | Overlay anneau / mode table en cours | Le Signal : la couleur dit le temps qui reste | The Signal: colour shows the time left |
| 2 | Bandeau Mac qui se vide au-dessus des fenêtres | Sur Mac, le bandeau se vide au fil de la parole | On Mac, the ribbon drains as you speak |
| 3 | Écran de config (participants + durée) | Un temps par personne, ou une durée répartie | A time per person, or a split duration |
| 4 | Stats / historique + taux de dépassement | Historique, dépassements, export CSV | History, overruns, CSV export |
| 5 | Reveal de badge en fin de standup | Des badges d'équipe pour fêter le rituel | Team badges to celebrate the ritual |
| 6 | Dynamic Island / Live Activity | Suivez le standup depuis la Dynamic Island | Follow the standup from the Dynamic Island |

---

## Notes de vérification (pour le propriétaire)

- ✅ **fr + en complets** sur tous les champs App Store Connect standard.
- ✅ **Limites respectées** : nom 14/30, sous-titre 26/30, promo 140 (fr) et 144 (en) /170, mots-clés 94 (fr) et 91 (en) /100, descriptions et « Nouveautés » bien sous 4000.
- ✅ **Aucune feature inventée** : tout (Signal/bandeau/anneau, mode table, temps par personne ou réparti, dépassement, suivant/pause/reporter, stats/historique/taux de dépassement/CSV, badges + reveal, Live Activity/Dynamic Island, achat Pro unique universel, gratuit jusqu'à 4 participants, local-only/no-tracking) est confirmé dans `ROADMAP.md`, `ISSUES.md` et `BADGES.md`.
- ✅ **iCloud sync** marqué **« à venir / coming soon »** (M8 non livré).
- ✅ **Nom marqué TBC** en tête de document et sous chaque champ « Nom ».
- ✅ **URL** pointent vers `landing-page/support.html`, `landing-page/privacy.html` et `landing-page/index.html`, avec l'avertissement « à déployer sur de vraies URL publiques avant soumission ».
```
