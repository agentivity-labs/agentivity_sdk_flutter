import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the palettes of the SDK', () {
    test('are complete, each under a name of its own', () {
      expect(agGraphPalettes, hasLength(24));
      expect(agGraphPalettes.map((p) => p.id).toSet(), hasLength(24));
      for (final p in agGraphPalettes) {
        expect(p.groups.length, greaterThanOrEqualTo(6), reason: p.id);
      }
    });

    test('never show the member at work in the color of a failure', () {
      for (final p in agGraphPalettes) {
        expect(p.states.working, isNot(p.states.failed), reason: p.id);
      }
    });

    test('give Modern, Red Blue Mauve by default', () {
      expect(agDefaultGraphPalette.id, 'modern-red-blue-mauve');
      expect(agUiTeamGroupPalette, agDefaultGraphPalette.groups);
    });
  });

  test('a palette of your own is made from another, changing only what is given', () {
    final azure = agGraphPaletteById('corporate-azure')!;
    final mine = azure.copyWith(id: 'acme', steps: azure.steps.copyWith(ai: const Color(0xFF123456)));

    expect(mine.id, 'acme');
    expect(mine.steps.ai, const Color(0xFF123456));
    expect(mine.steps.human, azure.steps.human);
    expect(mine.groups, azure.groups);
  });

  test("a team's groups take the palette's colors, a group keeping the color chosen for it", () {
    final electric = agGraphPaletteById('futurist-electric')!;
    final colors = agUiTeamGroupColors(['Booking', 'Money'], custom: {'money': const Color(0xFF123456)}, palette: electric.groups);

    expect(colors['booking'], electric.groups[0]);
    expect(colors['money'], const Color(0xFF123456));
  });

  test('a team reads the palette it chose', () {
    final team = TeamStructure.fromJson({'id': 't', 'name': 'T', 'orchestratorId': 'sequential', 'palette': 'neon-night'});

    expect(team.palette, 'neon-night');
  });

  testWidgets('the palette the app imposes wins, then its own, then the default', (tester) async {
    final neon = agGraphPaletteById('neon-night')!;
    final sport = agGraphPaletteById('sport-energy')!;
    late AgGraphPalette imposed, own, none;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            AgGraphPaletteScope(palette: neon, child: Builder(builder: (context) {
              imposed = AgGraphPaletteScope.of(context, sport);
              return const SizedBox();
            })),
            Builder(builder: (context) {
              own = AgGraphPaletteScope.of(context, sport);
              none = AgGraphPaletteScope.of(context);
              return const SizedBox();
            }),
          ],
        ),
      ),
    );

    expect(imposed, neon);
    expect(own, sport);
    expect(none, agDefaultGraphPalette);
  });
}
