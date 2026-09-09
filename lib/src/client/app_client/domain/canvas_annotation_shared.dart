// Types partagés entre les annotations du canvas workflow et du canvas team —
// mêmes shapes, réutilisées telles quelles pour que les deux éditeurs puissent
// partager le même widget de rendu (AnnotationCard).

/// Position d'une annotation, en coordonnées graphe (indépendantes du zoom/pan).
class NodePosition {
  NodePosition({required this.x, required this.y});

  double x;
  double y;

  factory NodePosition.fromJson(Map<String, dynamic> json) {
    return NodePosition(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  factory NodePosition.zero() => NodePosition(x: 0, y: 0);

  Map<String, dynamic> toJson() => {
        'x': x.toInt(),
        'y': y.toInt(),
      };
}

/// Taille d'une annotation, en coordonnées graphe.
class AnnotationSize {
  const AnnotationSize({required this.width, required this.height});

  final double width;
  final double height;

  factory AnnotationSize.fromJson(Map<String, dynamic> json) {
    return AnnotationSize(
      width: (json['width'] as num?)?.toDouble() ?? 120,
      height: (json['height'] as num?)?.toDouble() ?? 80,
    );
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
      };

  AnnotationSize copyWith({double? width, double? height}) {
    return AnnotationSize(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Interface commune à toute annotation affichable sur un canvas (workflow ou team) —
/// permet à `AnnotationCard` de rester indépendant du modèle métier concret.
abstract class CanvasAnnotation {
  String get id;
  NodePosition get position;
  AnnotationSize get size;
  String get content;
  String? get title;
  String get color;
  bool get locked;
  int get zIndex;
}
