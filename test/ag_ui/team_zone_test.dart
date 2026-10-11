import 'dart:ui';

import 'package:agentivity_sdk/src/ag_ui/panels/chat/team_layouts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The distance from [p] to the segment [a]–[b].
double _distance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Whether the zone, bands and discs included, passes over [box].
bool _covers(ZoneShape zone, Rect box, List<Offset> polygon) {
  final corners = [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight, box.center];
  for (final c in corners) {
    if (zone.points.any((p) => (p - c).distance < zoneHalfWidth)) return true;
    if (zone.links.any((l) => _distance(c, l.$1, l.$2) < zoneHalfWidth)) return true;
  }
  return false;
}

void main() {
  // One group of three all round a manager (manager-led), or round the shared conversation (group chat): same geometry.
  const center = Offset(200, 190);
  const around = [Offset(200, 60), Offset(330, 270), Offset(70, 270)];

  test('a group that goes round something is not drawn over it: bands between its members, no filled area', () {
    final hub = memberObstacles(center, radius: 21);
    final zone = zoneShape(around, hub);

    expect(zone.filled, isFalse);
    // The three members stay one group: two bands, passing clear of the manager.
    expect(zone.links, hasLength(2));
    expect(_covers(zone, hub.first.box, around), isFalse);
  });

  test('the same three members with nothing between them are one filled area, as before', () {
    final zone = zoneShape(around, memberObstacles(const Offset(380, 20)));

    expect(zone.filled, isTrue);
    expect(zone.links, hasLength(3));
  });

  test('two members opposite each other across the center are not joined through it', () {
    final dot = ZoneObstacle(Rect.fromCircle(center: center, radius: 10));
    final zone = zoneShape(const [Offset(70, 190), Offset(330, 190)], [dot]);

    expect(zone.links, isEmpty);
    expect(zone.points, hasLength(2));
  });

  test('members of a group apart in a chain, another member between them: no band over that member', () {
    const a = Offset(60, 100);
    const stranger = Offset(160, 100);
    const b = Offset(260, 100);
    final zone = zoneShape(const [a, b], memberObstacles(stranger));

    expect(zone.links, isEmpty);
    expect(_covers(zone, memberObstacles(stranger).first.box.deflate(4), const [a, b]), isFalse);
  });

  test('when a direct band is barred, the members are joined the other way round', () {
    // Four members on a ring round a center: opposite ones cannot be joined directly, neighbours can.
    const ring = [Offset(200, 60), Offset(330, 190), Offset(200, 320), Offset(70, 190)];
    final zone = zoneShape(ring, memberObstacles(center, radius: 21));

    expect(zone.filled, isFalse);
    expect(zone.links, hasLength(3));
    for (final link in zone.links) {
      expect(_distance(center, link.$1, link.$2), greaterThan(zoneHalfWidth + 21));
    }
  });
}
