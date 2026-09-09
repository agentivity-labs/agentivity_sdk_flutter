// Palette des annotations :
// - On conserve les couleurs existantes (neutres + accents) pour compatibilité.
// - On ajoute 6 nouvelles couleurs plus douces, mais bien contrastées et distinguables.
const List<String> workflowAnnotationPalette = <String>[
  // Palette d'origine (neutres foncés + accents plus vifs)
  '#1F2937', // slate dark
  '#2D3748', // charcoal
  '#374151', // graphite
  '#4B5563', // steel
  '#52525B', // zinc
  '#6B7280', // cool gray

  // Accents assombris pour éviter les fonds trop lumineux
  '#3849B8', // muted deep blue (ancien #5B7CFA)
  '#2D8A72', // muted teal (ancien #3FAF8F)
  '#B38C2F', // muted amber (ancien #E0B84F)
  '#B4506B', // muted red (ancien #D16D85)
  '#6957D0', // muted violet (ancien #8B7CF0)
  '#C16234', // muted orange (ancien #E07A3F)

  // Nouveau set, moins flashy mais pas ternes, bonne lisibilité texte
  '#1D4ED8', // deep desaturated blue
  '#0F766E', // teal sobre
  '#B45309', // warm brownish amber
  '#7C2D12', // burnt sienna
  '#4B5563', // steel gray (déjà présent, renforce la gamme neutre)
  '#047857', // deep jade
  '#6D28D9', // deep violet
];

// Couleur par défaut quand aucune couleur n'est définie explicitement.
// On garde le comportement historique.
const String defaultAnnotationColor = '#1F2937';
