# Badges d'équipe — Standup Timer

> **Design de référence (source de vérité) :**
> - `Standup timer multiplateforme/Medallion.dc.html` — le composant médaillon (artwork).
> - `Standup timer multiplateforme/Pulse - Badges.dc.html` — catalogue, états, écran Stats, reveal, fiche.
>
> Esthétique **Pulse** (signal `#00E08A`, JetBrains Mono, halo). Cf. ROADMAP §4b.

## 🎨 Le médaillon (artwork **procédural**, pas de PNG bespoke)

Un **seul composant** — `AchievementMedallion(badge:size:)` — décliné en 23. Rendu 100 %
procédural (primitives géométriques), **aucun asset PNG par badge à fournir/importer**.

**Anatomie** (cf. `Medallion.dc.html`) :
- **Anneau** — métal via dégradé conique (bandes claires/sombres = reflet brossé). **La couleur encode la rareté.**
- **Disque** — nuit creusée (`#0A0B0D`), ombre interne : le glyphe paraît gravé.
- **Glyphe** — **SF Symbol** monochrome (gravé dans le disque), teinté du métal du palier. (Les glyphes géométriques bespoke du `.dc.html` ont été jugés moins nets → on s'appuie sur SF Symbols.)
- **Halo + shimmer** — éclat radial + balayage rotatif **au reveal seulement** ; calme dans la grille.

## Décidé

- ✅ **Rendu procédural** (un composant) — **remplace** l'ancienne option « artworks bespoke PNG ». Chrome (anneau/disque/halo) fidèle au `.dc.html` ; **glyphe = SF Symbol** (les primitives géométriques du mockup abandonnées, trop ternes).
- ✅ **5 paliers = 5 métaux** : Commun (bronze) → Peu commun (argent) → Rare (or) → Légendaire (diamant) + Secret (irisé).
- ✅ **Palier = anneau** : le métal seul encode la rareté (même anatomie partout).
- ✅ **État verrouillé** : **désaturation auto** intégrée au composant (graphite grisé + glyphe en sourdine) + **arc de progression** vert (X/N).
- ✅ **Secret** : anneau irisé éteint + « ? », nom masqué jusqu'au déblocage.
- ✅ **Reveal plein écran façon Apple Watch** en fin de standup (spring + halo + shimmer + confettis + son/haptique). iOS plein écran ; macOS panneau centré.
- ✅ **Tout calculé localement** depuis l'historique des standups (aucune condition subjective) ; persisté `{ badgeId: date }`, suit iCloud.

## Catalogue — 23 badges

> Glyphe = glyphe de référence du `Medallion.dc.html` (indicatif). L'app rend un **SF Symbol** par badge (`Badge.systemImage`). Conditions calculées depuis `MeetingRecord`.

### Commun · bronze (5) — rapides, pour accrocher
| Badge | Condition | Glyphe |
|---|---|---|
| Action ! | Terminer son 1ᵉʳ standup | `play` |
| Pile à l'heure | 1 standup sans aucun dépassement | `check` |
| Au complet | Tous les participants présents | `trio` |
| Vite fait | Un standup bouclé en < 5 min | `bolt` |
| On remet ça | 3 standups au total | `refresh` |

### Peu commun · argent (5) — la régularité s'installe
| Badge | Condition | Glyphe |
|---|---|---|
| Semaine carrée | 5 standups dans la même semaine | `week` |
| Petite série | 3 jours consécutifs | `flame` |
| Net | 5 standups parfaits (cumulés) | `sparkle` |
| Grande tablée | Un standup avec 8+ participants | `table` |
| Lève-tôt | Un standup terminé avant 9h | `sunrise` |

### Rare · or (5) — discipline confirmée
| Badge | Condition | Glyphe |
|---|---|---|
| Régulier | 25 standups au total | `pulse` |
| En feu | 10 jours consécutifs | `flame2` |
| Sans faute | 10 standups parfaits d'affilée | `bullseye` |
| Métronome | 5 d'affilée sans dépassement | `metronome` |
| Mois assidu | 20 standups en un mois | `month` |

### Légendaire · diamant (5) — exploits long terme
| Badge | Condition | Glyphe |
|---|---|---|
| Centurion | 100 standups | `trophy` |
| Horloge suisse | 1 mois entier sans dépassement | `clock` |
| Discipline de fer | 30 jours consécutifs | `shield` |
| Perfection | 30 standups parfaits d'affilée | `gem` |
| Vétéran | Actif depuis 1 an | `star` |

### Secret · irisé (3) — easter eggs, par surprise
| Badge | Condition | Glyphe |
|---|---|---|
| Vendredi tonique | 10 standups un vendredi | `burst` |
| Couche-tard | Un standup terminé après 18h | `moon` |
| Marathonien | Un standup > 30 min | `hourglass` |

## Encore à préciser

- **Ton** : garder les clins d'œil (« Marathonien », « Couche-tard ») ou 100 % sérieux-positif ? (défaut : garder).
- **Compteur « parfait »** : « sans aucun dépassement » = définition à figer (par personne vs global).
