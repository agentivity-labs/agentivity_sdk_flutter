import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a conversation says how the person keeps it, and whether it is theirs or shared with them', () {
    DeskConversation of(String? participation) => DeskConversation.fromJson({
          'executionId': 'e1',
          'title': 'Invoice 2026-118',
          'entityId': 'a1',
          'entityName': 'Invoice check',
          'entityKind': 'Team',
          'state': 'active',
          'status': 'waiting',
          'waiting': 1,
          'pinned': true,
          'groupId': 'g1',
          'cockpitIds': ['finance'],
          'participation': participation,
          'updatedAt': '2026-11-07T08:00:00Z',
          'minutesSaved': 25,
        });

    final mine = of('started');
    expect(mine.title, 'Invoice 2026-118');
    expect(mine.entityKind, 'team');
    expect(mine.status, DeskConversationStatus.waiting);
    expect(mine.pinned, isTrue);
    expect(mine.groupId, 'g1');
    expect(mine.cockpitIds, ['finance']);
    expect(mine.minutesSaved, 25);
    expect(mine.mine, isTrue);
    expect(mine.mayReply, isTrue);
    expect(of('read').mayReply, isFalse);
    expect(of('asked').mayReply, isFalse);
    expect(of('reply').mine, isFalse);
  });

  test('a query of conversations says only what it filters on', () {
    final query = DeskConversationQuery(search: ' october ', statuses: {DeskConversationStatus.waiting}, cockpitIds: {'finance'}, groupId: 'none', archived: true, skip: 50).toQuery();

    expect(query['q'], 'october');
    expect(query['status'], ['waiting']);
    expect(query['cockpit'], ['finance']);
    expect(query['group'], 'none');
    expect(query['archived'], isTrue);
    expect(query.containsKey('pinned'), isFalse);
    expect(query['skip'], 50);
    expect(const DeskConversationQuery().toQuery().keys, unorderedEquals(['skip', 'take']));
  });

  test('the Desk opens with its brand, the cockpits and what each published element says', () {
    final overview = DeskOverview.fromJson({
      'brand': {'name': 'Acme', 'colour': '#5B3BD6'},
      'cockpits': [
        {'id': 'finance', 'name': 'Finance', 'entityIds': ['a1'], 'waiting': 2},
      ],
      'shown': ['a1'],
      'entities': {
        'a1': {'starters': ['Check an invoice'], 'minutesSaved': 25},
      },
      'groups': [
        {'id': 'g1', 'name': 'Year-end close', 'colour': '#C26A00', 'solutionIds': ['a1'], 'count': 14},
      ],
      'counts': {'waiting': 3, 'conversations': 312, 'archived': 4},
      'emailQuestions': false,
    });

    expect(overview.brand.name, 'Acme');
    expect(overview.cockpits.single.waiting, 2);
    expect(overview.publishes('a1'), isTrue);
    expect(overview.publishes('a2'), isFalse);
    expect(overview.entities['a1']!.starters, ['Check an invoice']);
    expect(overview.groups.single.solutionIds, ['a1']);
    expect(overview.conversations, 312);
    expect(overview.emailQuestions, isFalse);
    expect(const DeskOverview().publishes('anything'), isTrue);
  });

  test('a question answered in one click is a yes or no', () {
    DeskQuestion of(String kind) => DeskQuestion.fromJson({'requestId': 'q1', 'executionId': 'e1', 'entityId': 'w1', 'entityKind': 'workflow', 'kind': kind, 'askedToYou': true});

    expect(of('Approval').quick, isTrue);
    expect(of('Input').quick, isFalse);
    expect(of('Approval').askedToYou, isTrue);
  });

  test('a person on a seat of the Desk is told apart from one of the Studio, and has initials', () {
    final dana = AccountPerson.fromJson({'id': 'p1', 'name': 'Dana Desk', 'email': 'dana@example.test', 'seat': 'desk'});

    expect(dana.atDesk, isTrue);
    expect(dana.initials, 'DD');
    expect(AccountPerson.fromJson({'id': 'p2', 'name': 'Alex Morgan', 'seat': 'studio'}).atDesk, isFalse);
  });

  test('the setup of the Desk goes back as it came', () {
    final setup = DeskSetup.fromJson({
      'brand': {'name': 'Acme'},
      'shown': null,
      'entities': {
        'a2': {'starters': [], 'minutesSaved': 10},
      },
    });

    final json = setup.toJson();
    expect(json['shown'], isNull);
    expect(json.containsKey('cockpits'), isFalse);
    expect((json['entities'] as Map)['a2']['minutesSaved'], 10);
    expect(setup.copyWith(shown: ['a2']).shown, ['a2']);
    expect(setup.copyWith(shown: ['a2']).copyWith(showAll: true).shown, isNull);
  });

  test('an element says what it does: the service calls it its role', () {
    final unit = EntityUnit.fromJson({'id': 'a1', 'displayName': 'Invoice Clerk', 'kind': 'agent', 'role': 'Reads the supplier invoices you upload.'});
    expect(unit.description, 'Reads the supplier invoices you upload.');
  });

  test('a cockpit is made of blocks, each set as it says, and goes back as it came', () {
    final view = CockpitView.fromJson({
      'id': 'finance',
      'name': 'Finance',
      'colour': '#1F8A5B',
      'entityIds': ['a1'],
      'mayEdit': true,
      'blocks': [
        {
          'id': 'hero',
          'type': 'hero',
          'span': 12,
          'settings': {'text': 'Invoices, checked.'},
        },
        {
          'id': 'tools',
          'type': 'links',
          'span': 6,
          'settings': {
            'links': [
              {'label': 'Expenses', 'url': 'https://example.test/expenses'},
            ],
          },
        },
      ],
    });

    expect(view.mayEdit, isTrue);
    expect(view.content.intro, 'Invoices, checked.');
    final links = view.content.blocks[1];
    expect(links.span, 6);
    expect(links.links.single.url, 'https://example.test/expenses');
    final changed = links.withSetting('title', 'Tools').withSetting('title', ' ');
    expect(changed.settings.containsKey('title'), isFalse);
    expect(changed, links);
    expect(CockpitContent.fromJson(view.content.toJson()).blocks.length, 2);
    final looked = links.withStyle('fill', 'tinted').withStyle('border', 'accent').withStyle('fill', null);
    expect(looked.style, {'border': 'accent'});
    expect(looked == links, isFalse);
    final styled = view.content.copyWith(style: {'background': 'gradient', 'colour': '#0F8B8D', 'colour2': '#E0F2FE'});
    expect(CockpitContent.fromJson(styled.toJson()).style['colour2'], '#E0F2FE');
    expect(view.content.toJson().containsKey('style'), isFalse);

    final managed = ManagedCockpit.fromJson({
      'id': 'finance',
      'draft': view.content.toJson(),
      'published': null,
      'hasChanges': true,
      'owners': [
        {'id': 'p1', 'name': 'Claire Martin', 'email': 'claire@example.test'},
      ],
    });
    expect(managed.isPublished, isFalse);
    expect(managed.owners.single.label, 'Claire Martin');
    final data = CockpitBlockData.fromJson({
      'columns': ['supplier', 'amount'],
      'rows': [
        ['Kestrel', '40'],
      ],
      'total': 3,
    });
    expect(data.rows.single.first, 'Kestrel');
    expect(data.total, 3);
  });
}
