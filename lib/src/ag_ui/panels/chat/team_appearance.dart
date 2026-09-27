import 'package:flutter/material.dart';

/// How a Team member's group looks: the color it shares with the other members of the group, and the order that keeps a
/// group together. (The icon a member wears is an `IconRef`, drawn via `agUiIcon` — see `src/icons`.)

/// Colors given to groups, in the order groups first appear in a team.
const List<Color> agUiTeamGroupPalette = [
  Color(0xFFFF8A5B),
  Color(0xFF4FD1C5),
  Color(0xFFF6C453),
  Color(0xFFA78BFA),
  Color(0xFF60A5FA),
  Color(0xFFF472B6),
  Color(0xFF84CC16),
  Color(0xFFFB7185),
];

/// The identity of a group — trimmed and case-insensitive, so "Booking" and "booking " are the same group.
String? agUiTeamGroupKey(String? group) {
  final key = group?.trim().toLowerCase();
  return key == null || key.isEmpty ? null : key;
}

/// A color for each group of [groups]: the one the team editor chose ([custom], by group key) or else the default,
/// assigned in order of first appearance and cycling through [agUiTeamGroupPalette] — deterministic for a given team, and
/// the same rule in every SDK.
Map<String, Color> agUiTeamGroupColors(Iterable<String?> groups, {Map<String, Color> custom = const {}}) {
  final colors = <String, Color>{};
  for (final group in groups) {
    final key = agUiTeamGroupKey(group);
    if (key != null && !colors.containsKey(key)) {
      colors[key] = custom[key] ?? agUiTeamGroupPalette[colors.length % agUiTeamGroupPalette.length];
    }
  }
  return colors;
}

/// [items] with the members of each group kept together — groups in order of first appearance, ungrouped members
/// last, original order preserved inside each. Used so a graph draws a group as one cluster.
List<T> agUiOrderByGroup<T>(
  Iterable<T> items,
  String? Function(T item) groupOf,
) {
  final order = <String>[];
  for (final item in items) {
    final key = agUiTeamGroupKey(groupOf(item));
    if (key != null && !order.contains(key)) order.add(key);
  }
  int rank(T item) {
    final key = agUiTeamGroupKey(groupOf(item));
    return key == null ? order.length : order.indexOf(key);
  }

  final indexed =
      items.toList().asMap().entries.toList()..sort((a, b) {
        final byGroup = rank(a.value).compareTo(rank(b.value));
        return byGroup != 0 ? byGroup : a.key.compareTo(b.key);
      });
  return [for (final e in indexed) e.value];
}

/// The `#RRGGBB` color, or `null` when [hex] is not one.
Color? agUiParseHexColor(String? hex) {
  final match = hex == null ? null : RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  return match == null ? null : Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// The group colors the team editor chose, read off [members] carrying a `groupColor`.
Map<String, Color> agUiGroupColorOverrides(Iterable<({String? group, Color? groupColor})> members) => {
  for (final m in members)
    if (agUiTeamGroupKey(m.group) != null && m.groupColor != null) agUiTeamGroupKey(m.group)!: m.groupColor!,
};
