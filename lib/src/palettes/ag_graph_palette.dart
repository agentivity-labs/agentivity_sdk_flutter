import 'package:flutter/widgets.dart';

import 'ag_graph_palettes_data.dart';

/// What a palette is made for: the backgrounds its colors read well on. An indication: nothing is refused.
enum AgGraphPaletteSuits { light, dark, both }

/// One color per kind of workflow step: what a step does.
class AgGraphPaletteSteps {
  const AgGraphPaletteSteps({required this.start, required this.decision, required this.human, required this.ai, required this.action, required this.end});

  final Color start;
  final Color decision;
  final Color human;
  final Color ai;
  final Color action;
  final Color end;

  AgGraphPaletteSteps copyWith({Color? start, Color? decision, Color? human, Color? ai, Color? action, Color? end}) => AgGraphPaletteSteps(
    start: start ?? this.start,
    decision: decision ?? this.decision,
    human: human ?? this.human,
    ai: ai ?? this.ai,
    action: action ?? this.action,
    end: end ?? this.end,
  );
}

/// The colors of an execution: what a member or a step is doing.
class AgGraphPaletteStates {
  const AgGraphPaletteStates({required this.working, required this.waiting, required this.done, required this.failed});

  final Color working;
  final Color waiting;
  final Color done;
  final Color failed;

  AgGraphPaletteStates copyWith({Color? working, Color? waiting, Color? done, Color? failed}) =>
      AgGraphPaletteStates(working: working ?? this.working, waiting: waiting ?? this.waiting, done: done ?? this.done, failed: failed ?? this.failed);
}

/// A named set of colors for the graphs: a team's groups, a workflow's steps, the states of an execution. It is separate from the
/// theme, which gives the background, the text and the shapes: any palette goes with any theme, and the same palette on a team
/// and on its workflows makes them match.
class AgGraphPalette {
  const AgGraphPalette({required this.id, required this.category, required this.name, required this.suits, required this.groups, required this.steps, required this.states});

  /// Stable name, the one a team, an agent or a workflow keeps: `modern-red-blue-mauve`.
  final String id;

  /// Its family: Corporate, Soft, Futurist…
  final String category;
  final String name;
  final AgGraphPaletteSuits suits;

  /// The colors offered to a team's groups, in the order groups first appear. A group can still have a color of its own.
  final List<Color> groups;
  final AgGraphPaletteSteps steps;
  final AgGraphPaletteStates states;

  /// A palette of your own, made from this one: what is not given is kept.
  AgGraphPalette copyWith({String? id, String? category, String? name, AgGraphPaletteSuits? suits, List<Color>? groups, AgGraphPaletteSteps? steps, AgGraphPaletteStates? states}) => AgGraphPalette(
    id: id ?? this.id,
    category: category ?? this.category,
    name: name ?? this.name,
    suits: suits ?? this.suits,
    groups: groups ?? this.groups,
    steps: steps ?? this.steps,
    states: states ?? this.states,
  );
}

const String agDefaultGraphPaletteId = 'modern-red-blue-mauve';

/// The palette named [id], or null when the SDK has no palette of that name.
AgGraphPalette? agGraphPaletteById(String? id) {
  final name = id?.trim();
  for (final palette in agGraphPalettes) {
    if (palette.id == name) return palette;
  }
  return null;
}

/// The palette graphs are drawn with when nothing says otherwise.
final AgGraphPalette agDefaultGraphPalette = agGraphPaletteById(agDefaultGraphPaletteId)!;

/// Gives every graph below it the same palette, whatever the teams and workflows it shows have chosen.
class AgGraphPaletteScope extends InheritedWidget {
  const AgGraphPaletteScope({super.key, required this.palette, required super.child});

  final AgGraphPalette palette;

  /// The palette a graph is drawn with: the one the app imposes, then its own, then the default.
  static AgGraphPalette of(BuildContext context, [AgGraphPalette? own]) =>
      context.dependOnInheritedWidgetOfExactType<AgGraphPaletteScope>()?.palette ?? own ?? agDefaultGraphPalette;

  @override
  bool updateShouldNotify(AgGraphPaletteScope oldWidget) => palette != oldWidget.palette;
}
