import 'package:agentivity_sdk/agentivity_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('The outputs a workflow declares', () {
    test('are read and written with the workflow', () {
      final workflow = WorkflowEntity.fromJson({
        'id': 'wf',
        'name': 'Picks a trip',
        'nodes': <dynamic>[],
        'connections': <dynamic>[],
        'outputs': [
          {'name': 'output', 'value': 'A trip to {{pick.city}}'},
          {'name': 'city', 'value': '{{pick.city}}', 'description': 'The city chosen'},
        ],
      });

      expect(workflow.outputs, const [
        WorkflowOutput(name: 'output', value: 'A trip to {{pick.city}}'),
        WorkflowOutput(name: 'city', value: '{{pick.city}}', description: 'The city chosen'),
      ]);
      expect(WorkflowEntity.fromJson(workflow.toJson()).outputs, workflow.outputs);
    });

    test('a workflow that declares none writes none', () {
      final workflow = WorkflowEntity(id: 'wf', name: 'Plain', nodes: const [], connections: const []);

      expect(workflow.outputs, isEmpty);
      expect(workflow.toJson().containsKey('outputs'), isFalse);
    });
  });
}
