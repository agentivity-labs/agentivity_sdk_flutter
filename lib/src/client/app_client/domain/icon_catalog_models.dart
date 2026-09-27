import '../../../icons/icon_ref.dart';

/// One icon of the platform's catalog (`GET /api/v1/icons`): what an [IconRef] designates. The catalog is generic —
/// organised by icon set ([type]) — so it serves any screen that lets a user pick an icon.
class IconInfo {
  const IconInfo({required this.type, required this.value, required this.name});

  /// The icon set (`material` today).
  final String type;

  /// The icon inside that set: the Material code point, in hex (`E322`). This is what is stored.
  final String value;

  /// The Material name (`hotel_baseline`) — for search and tooltips only, never stored.
  final String name;

  /// The reference to store for this entry.
  IconRef get ref => IconRef(type: type, value: value);

  factory IconInfo.fromJson(Map<String, dynamic> json) {
    String text(dynamic v) => v == null ? '' : v.toString().trim();
    return IconInfo(type: text(json['type']).toLowerCase(), value: text(json['value']).toUpperCase(), name: text(json['name']));
  }
}
