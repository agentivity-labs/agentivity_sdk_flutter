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
        {'id': 'g1', 'name': 'Year-end close', 'colour': '#C26A00', 'rule': {'contains': 'close'}, 'count': 14},
      ],
      'counts': {'waiting': 3, 'conversations': 312, 'archived': 4},
      'emailQuestions': false,
    });

    expect(overview.brand.name, 'Acme');
    expect(overview.cockpits.single.waiting, 2);
    expect(overview.publishes('a1'), isTrue);
    expect(overview.publishes('a2'), isFalse);
    expect(overview.entities['a1']!.starters, ['Check an invoice']);
    expect(overview.groups.single.rule!.contains, 'close');
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
      'cockpits': [
        {'id': 'hr', 'name': 'HR', 'entityIds': ['a2']},
      ],
      'shown': null,
      'entities': {
        'a2': {'starters': [], 'minutesSaved': 10},
      },
    });

    final json = setup.toJson();
    expect(json['shown'], isNull);
    expect((json['cockpits'] as List).single['name'], 'HR');
    expect((json['entities'] as Map)['a2']['minutesSaved'], 10);
    expect(setup.copyWith(shown: ['a2']).shown, ['a2']);
    expect(setup.copyWith(shown: ['a2']).copyWith(showAll: true).shown, isNull);
  });
}
