enum WorkflowArgumentType {
  text('Text'),
  textList('TextList'),
  structured('Structured'),
  number('Number'),
  boolean('Boolean'),
  credentials('Credentials'),
  imageRef('ImageRef'),
  choice('Choice');

  const WorkflowArgumentType(this.label);

  final String label;

  static WorkflowArgumentType? parse(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    for (final value in WorkflowArgumentType.values) {
      if (value.label.toLowerCase() == lower) {
        return value;
      }
    }
    return null;
  }

  @override
  String toString() => label;
}

class WorkflowArgumentTypes {
  static const text = 'Text';
  static const textList = 'TextList';
  static const structured = 'Structured';
  static const number = 'Number';
  static const boolean = 'Boolean';
  static const credentials = 'Credentials';
  static const imageRef = 'ImageRef';
  static const choice = 'Choice';

  static const List<String> primary = <String>[text, textList, structured, number, boolean, credentials, imageRef, choice];
}
