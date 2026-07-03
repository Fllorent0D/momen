import Foundation


public enum ProductivityQuotes {
    // User-facing quotes shown on the end-of-standup screen. Localized against
    // StandupKit's catalog (source language fr-BE).
    public static let quotes: [String] = [
        String(localized: "Un bon standup, c'est 15 minutes qui en sauvent 8 heures.", bundle: .standupKit),
        String(localized: "La brièveté est l'âme de l'esprit. — Shakespeare", bundle: .standupKit),
        String(localized: "Fait est mieux que parfait.", bundle: .standupKit),
        String(localized: "Seul on va plus vite, ensemble on va plus loin.", bundle: .standupKit),
        String(localized: "La communication est la clé de toute collaboration réussie.", bundle: .standupKit),
        String(localized: "Les meilleures réunions sont celles qui finissent à l'heure.", bundle: .standupKit),
        String(localized: "Chaque minute compte — utilisez-les avec intention.", bundle: .standupKit),
        String(localized: "La productivité, ce n'est pas faire plus, c'est faire mieux.", bundle: .standupKit),
        String(localized: "Le talent gagne des matchs, mais le travail d'équipe gagne des championnats. — Jordan", bundle: .standupKit),
        String(localized: "La simplicité est la sophistication suprême. — Léonard de Vinci", bundle: .standupKit),
        String(localized: "Un objectif sans plan n'est qu'un souhait. — Antoine de Saint-Exupéry", bundle: .standupKit),
        String(localized: "Le secret du changement : concentrer son énergie pour créer du nouveau.", bundle: .standupKit),
        String(localized: "Il n'y a pas de vent favorable pour celui qui ne sait pas où il va. — Sénèque", bundle: .standupKit),
        String(localized: "L'union fait la force.", bundle: .standupKit),
        String(localized: "Commencez là où vous êtes. Utilisez ce que vous avez. Faites ce que vous pouvez. — Arthur Ashe", bundle: .standupKit),
        String(localized: "La discipline est le pont entre les objectifs et leur réalisation. — Jim Rohn", bundle: .standupKit),
        String(localized: "Ne remettez jamais à demain ce que vous pouvez faire aujourd'hui. — Benjamin Franklin", bundle: .standupKit),
        String(localized: "Le succès est la somme de petits efforts répétés jour après jour. — Robert Collier", bundle: .standupKit),
        String(localized: "Ce qui se mesure s'améliore. — Peter Drucker", bundle: .standupKit),
        String(localized: "Seuls ceux qui prennent le risque d'échouer spectaculairement réussiront brillamment. — JFK", bundle: .standupKit),
        String(localized: "Le progrès, pas la perfection.", bundle: .standupKit),
        String(localized: "La meilleure façon de prédire l'avenir, c'est de le créer. — Peter Drucker", bundle: .standupKit),
        String(localized: "Concentrez-vous sur l'essentiel et éliminez le superflu.", bundle: .standupKit),
        String(localized: "Un petit pas chaque jour mène à de grands résultats.", bundle: .standupKit),
        String(localized: "La créativité, c'est l'intelligence qui s'amuse. — Einstein", bundle: .standupKit),
        String(localized: "Ensemble, nous sommes plus forts que la somme de nos parties.", bundle: .standupKit),
        String(localized: "Le temps est la ressource la plus précieuse — investissez-le judicieusement.", bundle: .standupKit),
        String(localized: "L'excellence n'est pas un acte, c'est une habitude. — Aristote", bundle: .standupKit),
        String(localized: "Moins de réunions, plus d'actions.", bundle: .standupKit),
        String(localized: "La clé du succès : savoir prioriser.", bundle: .standupKit),
    ]

    public static func random() -> String {
        quotes.randomElement() ?? quotes[0]
    }
}
