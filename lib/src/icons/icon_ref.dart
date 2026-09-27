import 'package:flutter/widgets.dart';

/// A reference to an icon of the platform's catalog — the backend's `NodeIconDef` shape (`{ "type": "material", "value": "E322" }`).
/// `type` is the icon set, `value` the icon inside it: for the standard set, [materialType], the Material Icons code point
/// in hex — the same code point Flutter's `MaterialIcons` font, Studio and the React SDK's font all use.
class IconRef {
  const IconRef({required this.type, required this.value, this.color});

  /// The standard icon set.
  static const materialType = 'material';

  /// The Material icon at [hexCodePoint] (`E322`).
  const IconRef.material(String hexCodePoint) : this(type: materialType, value: hexCodePoint);

  final String type;
  final String value;

  /// Optional tint (`#RRGGBB`) — only for sets that carry one; the standard set is drawn in the surrounding color.
  final String? color;

  /// Reads the shape the backend stores; `null` for anything else (no icon, a bare string, a missing type or value).
  static IconRef? tryParse(Object? json) {
    if (json is! Map) return null;
    final type = json['type']?.toString().trim().toLowerCase();
    final value = json['value']?.toString().trim();
    if (type == null || type.isEmpty || value == null || value.isEmpty) return null;
    final color = json['color']?.toString().trim();
    return IconRef(type: type, value: value, color: color == null || color.isEmpty ? null : color);
  }

  Map<String, dynamic> toJson() => {'type': type, 'value': value, if (color != null) 'color': color};

  @override
  bool operator ==(Object other) => other is IconRef && other.type == type && other.value == value && other.color == color;

  @override
  int get hashCode => Object.hash(type, value, color);

  @override
  String toString() => '$type:$value';
}

/// The glyph for [icon], or `null` when there is none: no icon, a set this SDK does not draw, or a value that is not a
/// code point. The caller then falls back to initials or its own default.
IconData? agUiIcon(IconRef? icon) {
  if (icon == null || icon.type != IconRef.materialType) return null;
  final codePoint = int.tryParse(icon.value, radix: 16);
  return codePoint == null || codePoint <= 0 ? null : IconData(codePoint, fontFamily: 'MaterialIcons');
}
