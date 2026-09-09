import 'dart:convert';

import 'workflow_argument_type.dart';
import 'workflow_annotation_palette.dart';
import 'canvas_annotation_shared.dart';
import 'agentivity_entity.dart';

export 'canvas_annotation_shared.dart' show NodePosition, AnnotationSize, CanvasAnnotation;

const Object _sentinel = Object();

class WorkflowEntity implements AgentivityEntity {
  WorkflowEntity({
    required this.id,
    required this.name,
    this.role,
    this.entryNode,
    required this.nodes,
    required this.connections,
    List<WorkflowAnnotation>? annotations,
    Map<String, dynamic>? metadata,
    Map<String, WorkflowDataTable>? dataTables,
    this.createdAt,
    this.updatedAt,
    List<String>? tags,
  })  : tags = tags ?? const [],
        metadata = metadata == null ? <String, dynamic>{} : Map<String, dynamic>.from(metadata),
        dataTables = _cloneWorkflowDataTables(dataTables),
        annotations = annotations == null ? <WorkflowAnnotation>[] : List<WorkflowAnnotation>.from(annotations.map((annotation) => annotation.copy()));

  @override
  String id;
  @override
  String name;
  @override
  String? role;
  String? entryNode;
  List<NodeModel> nodes;
  List<WorkflowConnection> connections;
  List<WorkflowAnnotation> annotations;
  Map<String, dynamic> metadata;
  Map<String, WorkflowDataTable> dataTables;
  @override
  DateTime? createdAt;
  @override
  DateTime? updatedAt;
  @override
  List<String> tags;

  factory WorkflowEntity.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final nodesJson = json['nodes'] as List<dynamic>? ?? const [];
    final connectionsJson = json['connections'] as List<dynamic>? ?? const [];
    final annotationsJson = json['annotations'] as List<dynamic>? ?? const [];

    return WorkflowEntity(
      id: json['id'] as String? ?? fallbackId ?? '',
      name: json['name'] as String? ?? fallbackId ?? '',
      role: json['role'] as String?,
      entryNode: json['entryNode'] as String?,
      nodes: nodesJson.map((node) => NodeModel.fromJson(Map<String, dynamic>.from(node as Map))).toList(),
      connections: connectionsJson.map((entry) => WorkflowConnection.fromJson(Map<String, dynamic>.from(entry as Map))).toList(),
      annotations: annotationsJson.map((entry) => WorkflowAnnotation.fromJson(Map<String, dynamic>.from(entry as Map))).toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      dataTables: _parseWorkflowDataTables(json['dataTables']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      tags: (json['tags'] as List<dynamic>?)?.whereType<String>().toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        if (role != null) 'role': role,
        if (tags.isNotEmpty) 'tags': tags,
        if (entryNode != null) 'entryNode': entryNode,
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'connections': connections.map((connection) => connection.toJson()).toList(),
        if (annotations.isNotEmpty) 'annotations': annotations.map((annotation) => annotation.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (dataTables.isNotEmpty) 'dataTables': dataTables.map((name, table) => MapEntry(name, table.toJson())),
      };
}

const String workflowViewportMetadataKey = 'editorViewport';

class WorkflowViewportData {
  const WorkflowViewportData({
    required this.x,
    required this.y,
    required this.zoom,
  });

  final double x;
  final double y;
  final double zoom;

  factory WorkflowViewportData.fromJson(Map<String, dynamic> json) {
    return WorkflowViewportData(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      zoom: _sanitizeZoom(json['zoom']),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'zoom': zoom,
      };

  WorkflowViewportData copyWith({double? x, double? y, double? zoom}) {
    return WorkflowViewportData(
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WorkflowViewportData && other.x == x && other.y == y && other.zoom == zoom;
  }

  @override
  int get hashCode => Object.hash(x, y, zoom);

  static WorkflowViewportData? fromMetadata(Map<String, dynamic> metadata) {
    final payload = metadata[workflowViewportMetadataKey];
    if (payload is Map) {
      return WorkflowViewportData.fromJson(Map<String, dynamic>.from(payload));
    }
    return null;
  }

  static void writeToMetadata(Map<String, dynamic> metadata, WorkflowViewportData viewport) {
    metadata[workflowViewportMetadataKey] = viewport.toJson();
  }

  static void clearFromMetadata(Map<String, dynamic> metadata) {
    metadata.remove(workflowViewportMetadataKey);
  }
}

double _sanitizeZoom(dynamic value) {
  double clampZoom(double input) {
    final clamped = input.clamp(0.05, 8.0);
    return clamped.toDouble();
  }

  if (value is num) {
    return clampZoom(value.toDouble());
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) {
      return clampZoom(parsed);
    }
  }
  return 1.0;
}

const String coreSetNodeType = 'core.set';
const String coreDataTableNodeType = 'core.datatable';
const String interactionRequestInputNodeType = 'interaction.request_input';
const String composableNodeType = 'ai.composable_node';
const String teamNodeType = 'ai.team_node';
const String chatChannelNodeType = 'ai.interactions.chat';

class NodeSetField {
  NodeSetField({
    required this.key,
    required this.type,
    this.label,
    this.description,
    bool? isRequired,
    this.value,
    this.editorMode,
    List<NodeSetFieldChoice>? choiceOptions,
  })  : isRequired = isRequired ?? false,
        choices = choiceOptions == null ? <NodeSetFieldChoice>[] : List<NodeSetFieldChoice>.from(choiceOptions);

  String key;
  String type;
  String? label;
  String? description;
  bool isRequired;
  dynamic value;
  String? editorMode;
  List<NodeSetFieldChoice> choices;

  factory NodeSetField.fromJson(Map<String, dynamic> json) {
    final rawKey = (json['key'] ?? json['name'] ?? '').toString().trim();
    final normalizedType = (json['type'] ?? WorkflowArgumentTypes.text).toString().trim();
    final rawValue = json.containsKey('value')
        ? json['value']
        : json.containsKey('default')
            ? json['default']
            : json.containsKey('defaultValue')
                ? json['defaultValue']
                : null;
    final mode = json['editorMode']?.toString().toLowerCase();
    final parsedChoices = _parseNodeSetFieldChoices(json['choices']);
    return NodeSetField(
      key: rawKey,
      type: normalizedType.isEmpty ? WorkflowArgumentTypes.text : normalizedType,
      label: (json['label'] ?? json['displayName'])?.toString(),
      description: (json['description'] ?? json['help'] ?? json['tooltip'])?.toString(),
      isRequired: json['required'] == true,
      value: _cloneValue(rawValue),
      editorMode: mode == null || mode.isEmpty ? null : mode,
      choiceOptions: parsedChoices,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'key': key,
      'type': type,
    };
    final trimmedLabel = label?.trim();
    if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
      map['label'] = trimmedLabel;
    }
    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      map['description'] = trimmedDescription;
    }
    if (isRequired) {
      map['required'] = true;
    }
    if (value != null) {
      map['value'] = _cloneValue(value);
    }
    if (editorMode != null && editorMode!.isNotEmpty) {
      map['editorMode'] = editorMode;
    }
    if (choices.isNotEmpty) {
      map['choices'] = choices.map((choice) => choice.toJson()).toList();
    }
    return map;
  }

  NodeSetField copy() {
    return NodeSetField(
      key: key,
      type: type,
      label: label,
      description: description,
      isRequired: isRequired,
      value: _cloneValue(value),
      editorMode: editorMode,
      choiceOptions: choices,
    );
  }
}

class NodeSetFieldChoice {
  const NodeSetFieldChoice({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  NodeSetFieldChoice copy() => NodeSetFieldChoice(value: value, label: label);

  Map<String, String> toJson() => {
        'value': value,
        'label': label,
      };
}

List<NodeSetFieldChoice> _parseNodeSetFieldChoices(dynamic payload) {
  if (payload is! List) {
    return const <NodeSetFieldChoice>[];
  }
  final choices = <NodeSetFieldChoice>[];
  for (final entry in payload) {
    if (entry is Map<String, dynamic>) {
      final value = (entry['value'] as String?)?.trim() ?? '';
      if (value.isEmpty) {
        continue;
      }
      final label = (entry['label'] as String?)?.trim();
      choices.add(NodeSetFieldChoice(value: value, label: (label == null || label.isEmpty) ? value : label));
    } else if (entry is Map) {
      final mapped = Map<String, dynamic>.from(entry);
      final value = (mapped['value'] as String?)?.trim() ?? '';
      if (value.isEmpty) {
        continue;
      }
      final label = (mapped['label'] as String?)?.trim();
      choices.add(NodeSetFieldChoice(value: value, label: (label == null || label.isEmpty) ? value : label));
    } else if (entry != null) {
      final value = entry.toString().trim();
      if (value.isEmpty) {
        continue;
      }
      choices.add(NodeSetFieldChoice(value: value, label: value));
    }
  }
  return choices;
}

class NodeModel {
  NodeModel({
    required this.id,
    required this.nodeType,
    required this.position,
    required this.arguments,
    this.zIndex = 0,
    Map<String, dynamic>? metadata,
    Map<String, Map<String, dynamic>>? inputsMetadata,
    List<NodeSetField>? setFields,
    String? parameterKey,
  })  : metadata = metadata == null ? <String, dynamic>{} : Map<String, dynamic>.from(metadata),
        inputsMetadata = inputsMetadata == null ? <String, Map<String, dynamic>>{} : Map<String, Map<String, dynamic>>.from(inputsMetadata),
        setFields = setFields == null ? <NodeSetField>[] : List<NodeSetField>.from(setFields.map((field) => field.copy())),
        _parameterKey = (parameterKey == 'inputs' || parameterKey == 'arguments') ? parameterKey! : 'inputs' {
    _syncSetFieldsMetadata();
  }

  String id;
  String nodeType;
  NodePosition position;
  Map<String, NodeArgument> arguments;
  int zIndex;
  Map<String, dynamic> metadata;
  Map<String, Map<String, dynamic>> inputsMetadata;
  List<NodeSetField> setFields;
  final String _parameterKey;

  String get parameterKey => _parameterKey;

  bool get usesInputsField => _parameterKey == 'inputs';

  bool get isSetNode => nodeType == coreSetNodeType;

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    final positionJson = json['position'] as Map<String, dynamic>?;
    final resolvedNodeType = (json['nodeType'] as String?)?.trim() ?? '';

    // Always normalise to 'inputs' for write — 'arguments' is legacy read-only fallback.
    String parameterKey = 'inputs';
    Map<String, dynamic> rawParameters = const {};

    final metadataJson = json['metadata'];
    Map<String, dynamic> metadata = const {};
    if (metadataJson is Map<String, dynamic>) {
      metadata = metadataJson;
    } else if (metadataJson is Map) {
      metadata = Map<String, dynamic>.from(metadataJson);
    }

    final inputsJson = json['inputs'];
    if (inputsJson is Map<String, dynamic>) {
      rawParameters = inputsJson;
    } else if (inputsJson is Map) {
      rawParameters = Map<String, dynamic>.from(inputsJson);
    } else {
      // Legacy fallback: old API sent 'arguments' instead of 'inputs'.
      final argumentsJson = json['arguments'];
      if (argumentsJson is Map<String, dynamic>) {
        rawParameters = argumentsJson;
      } else if (argumentsJson is Map) {
        rawParameters = Map<String, dynamic>.from(argumentsJson);
      }
    }

    // Parse inputsMetadata: { fieldKey: { editorMode: '...' } }
    final rawInputsMetadata = json['inputsMetadata'];
    final inputsMetadata = <String, Map<String, dynamic>>{};
    if (rawInputsMetadata is Map) {
      rawInputsMetadata.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          inputsMetadata[k.toString()] = v;
        } else if (v is Map) {
          inputsMetadata[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    final setFields = <NodeSetField>[];
    final rawSetFields = metadata['setFields'];
    if (rawSetFields is List) {
      for (final entry in rawSetFields) {
        if (entry is Map<String, dynamic>) {
          setFields.add(NodeSetField.fromJson(entry));
        } else if (entry is Map) {
          setFields.add(NodeSetField.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return NodeModel(
      id: json['id'] as String,
      nodeType: resolvedNodeType,
      position: positionJson == null ? NodePosition.zero() : NodePosition.fromJson(positionJson),
      arguments: rawParameters.map(
        (key, value) => MapEntry(key, NodeArgument.fromJson(key, value)),
      ),
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      metadata: metadata,
      inputsMetadata: inputsMetadata,
      setFields: setFields,
      parameterKey: parameterKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (nodeType.isNotEmpty) 'nodeType': nodeType,
        'position': position.toJson(),
        'zIndex': zIndex,
        if (arguments.isNotEmpty || usesInputsField) _parameterKey: arguments.map((key, argument) => MapEntry(key, argument.toJson())),
        if (inputsMetadata.isNotEmpty) 'inputsMetadata': inputsMetadata,
        if (metadata.isNotEmpty) 'metadata': _buildMetadataJson(),
      };

  Map<String, dynamic> _buildMetadataJson() {
    _syncSetFieldsMetadata();
    if (metadata.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.from(metadata);
  }

  void replaceSetFields(List<NodeSetField> fields) {
    setFields = List<NodeSetField>.from(fields.map((field) => field.copy()));
    _syncSetFieldsMetadata();
  }

  void _syncSetFieldsMetadata() {
    if (setFields.isEmpty) {
      metadata.remove('setFields');
      return;
    }
    metadata['setFields'] = setFields.map((field) => field.toJson()).toList();
  }
}

class WorkflowAnnotation implements CanvasAnnotation {
  WorkflowAnnotation({
    required this.id,
    required this.position,
    required this.size,
    required this.content,
    required this.color,
    this.title,
    this.locked = false,
    this.zIndex = 0,
  });

  @override
  final String id;
  @override
  final NodePosition position;
  @override
  final AnnotationSize size;
  @override
  final String content;
  @override
  final String color;
  @override
  final String? title;
  @override
  final bool locked;
  @override
  final int zIndex;

  factory WorkflowAnnotation.fromJson(Map<String, dynamic> json) {
    final positionJson = json['position'] as Map<String, dynamic>?;
    final sizeJson = json['size'] as Map<String, dynamic>?;
    return WorkflowAnnotation(
      id: (json['id'] as String? ?? '').trim(),
      position: positionJson == null ? NodePosition.zero() : NodePosition.fromJson(positionJson),
      size: sizeJson == null ? const AnnotationSize(width: 320, height: 160) : AnnotationSize.fromJson(sizeJson),
      // Do not trim content so leading/trailing newlines/spaces used for
      // markdown formatting (for example blank lines before the first
      // paragraph) are preserved.
      content: (json['content'] as String? ?? ''),
      title: (json['title'] as String?)?.trim(),
      color: _normalizeAnnotationColor(json['color']),
      locked: json['locked'] == true,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'id': id,
      'position': position.toJson(),
      'size': size.toJson(),
      'content': content,
      'color': color,
      'locked': locked,
      'zIndex': zIndex,
    };
    if (title != null && title!.isNotEmpty) {
      payload['title'] = title;
    }
    return payload;
  }

  WorkflowAnnotation copyWith({
    NodePosition? position,
    AnnotationSize? size,
    String? content,
    Object? title = _sentinel,
    String? color,
    bool? locked,
    int? zIndex,
  }) {
    return WorkflowAnnotation(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      content: content ?? this.content,
      title: title == _sentinel ? this.title : title as String?,
      color: color ?? this.color,
      locked: locked ?? this.locked,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  WorkflowAnnotation copy() => copyWith();
}

class NodeArgument {
  NodeArgument({required this.name, this.value});

  String name;
  dynamic value;

  factory NodeArgument.fromJson(String name, dynamic value) {
    return NodeArgument(name: name, value: value);
  }

  dynamic toJson() => value;

  String asReadableValue() {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return value as String;
    }
    return jsonEncode(value);
  }
}

dynamic _cloneValue(dynamic value) {
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key, _cloneValue(v)));
  }
  if (value is List) {
    return value.map(_cloneValue).toList();
  }
  return value;
}

Map<String, WorkflowDataTable> _parseWorkflowDataTables(dynamic payload) {
  if (payload is List) {
    final result = <String, WorkflowDataTable>{};
    for (final entry in payload) {
      Map<String, dynamic>? tableJson;
      if (entry is Map<String, dynamic>) {
        tableJson = entry;
      } else if (entry is Map) {
        tableJson = Map<String, dynamic>.from(entry);
      }
      if (tableJson == null) {
        continue;
      }
      final tableName = (tableJson['name'] ?? tableJson['id'] ?? '').toString().trim();
      if (tableName.isEmpty) {
        continue;
      }
      result[tableName] = WorkflowDataTable.fromJson(tableName, tableJson);
    }
    return result;
  }

  if (payload is! Map) {
    return <String, WorkflowDataTable>{};
  }
  final source = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload);
  final result = <String, WorkflowDataTable>{};
  source.forEach((key, value) {
    final tableName = key.toString().trim();
    if (tableName.isEmpty) {
      return;
    }
    if (value is Map<String, dynamic>) {
      result[tableName] = WorkflowDataTable.fromJson(tableName, value);
    } else if (value is Map) {
      result[tableName] = WorkflowDataTable.fromJson(tableName, Map<String, dynamic>.from(value));
    } else {
      result[tableName] = WorkflowDataTable(name: tableName);
    }
  });
  return result;
}

Map<String, WorkflowDataTable> _cloneWorkflowDataTables(Map<String, WorkflowDataTable>? source) {
  if (source == null || source.isEmpty) {
    return <String, WorkflowDataTable>{};
  }
  final result = <String, WorkflowDataTable>{};
  source.forEach((key, value) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final clone = value.copy();
    clone.name = trimmed;
    result[trimmed] = clone;
  });
  return result;
}

Map<String, dynamic> _cloneTableRow(Map<String, dynamic> row) {
  final clone = <String, dynamic>{};
  for (final entry in row.entries) {
    clone[entry.key] = _cloneValue(entry.value);
  }
  return clone;
}

String _normalizeAnnotationColor(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    final trimmed = value.trim();
    if (trimmed.startsWith('#')) {
      return trimmed.toUpperCase();
    }
    return '#${trimmed.toUpperCase()}';
  }
  return defaultAnnotationColor;
}

class WorkflowConnection {
  WorkflowConnection({
    required this.sourceNodeId,
    required this.targetNodeId,
    String? sourcePortId,
    String? targetPortId,
    List<ConnectionMapping>? mapping,
  })  : sourcePortId = sourcePortId?.trim() ?? '',
        targetPortId = targetPortId?.trim() ?? '',
        mapping = mapping ?? <ConnectionMapping>[];

  static const String defaultOutputPort = 'default';
  static const String defaultInputPort = 'in';
  static const Set<String> _legacyOutputPorts = {'_default_output'};
  static const Set<String> _legacyInputPorts = {'_default_input'};

  final String sourceNodeId;
  final String targetNodeId;
  final String sourcePortId;
  final String targetPortId;
  final List<ConnectionMapping> mapping;

  factory WorkflowConnection.fromJson(Map<String, dynamic> json) {
    final fromPayload = _parseEndpointPayload(json['from'], keyName: 'from');
    final toPayload = _parseEndpointPayload(json['to'], keyName: 'to');
    final mappingEntries = (json['mapping'] as List<dynamic>? ?? const []).map((entry) => ConnectionMapping.fromJson(Map<String, dynamic>.from(entry as Map))).toList();

    final normalizedSourcePort = _normalizePortId(
      rawPortId: (json['fromPort'] as String?) ?? fromPayload.portId,
      defaultValue: defaultOutputPort,
      legacyDefaultNames: _legacyOutputPorts,
    );

    final normalizedTargetPort = _normalizePortId(
      rawPortId: (json['toPort'] as String?) ?? toPayload.portId,
      defaultValue: defaultInputPort,
      legacyDefaultNames: _legacyInputPorts,
    );

    return WorkflowConnection(
      sourceNodeId: fromPayload.nodeId,
      sourcePortId: normalizedSourcePort,
      targetNodeId: toPayload.nodeId,
      targetPortId: normalizedTargetPort,
      mapping: mappingEntries,
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedSourcePort = sourcePortId.isEmpty ? defaultOutputPort : sourcePortId;
    final normalizedTargetPort = targetPortId.isEmpty ? defaultInputPort : targetPortId;
    return {
      'from': sourceNodeId,
      'fromPort': normalizedSourcePort,
      'to': targetNodeId,
      'toPort': normalizedTargetPort,
      if (mapping.isNotEmpty) 'mapping': mapping.map((entry) => entry.toJson()).toList(),
    };
  }

  static _EndpointPayload _parseEndpointPayload(dynamic payload, {required String keyName}) {
    if (payload is String) {
      return _parseEndpointString(payload);
    }
    if (payload is Map<String, dynamic>) {
      return _EndpointPayload(
        nodeId: _extractNodeId(payload, keyName: keyName),
        portId: _extractPortId(payload),
      );
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      return _EndpointPayload(
        nodeId: _extractNodeId(map, keyName: keyName),
        portId: _extractPortId(map),
      );
    }
    throw StateError('Unsupported connection endpoint payload for $keyName: ${payload.runtimeType}');
  }

  static _EndpointPayload _parseEndpointString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw StateError('Connection endpoint string is empty.');
    }
    for (final separator in ['.', ':', '->']) {
      final parts = trimmed.split(separator);
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return _EndpointPayload(nodeId: parts[0], portId: parts[1]);
      }
    }
    return _EndpointPayload(nodeId: trimmed, portId: null);
  }

  static String _extractNodeId(Map<String, dynamic> payload, {required String keyName}) {
    for (final field in ['nodeId', 'node', 'id']) {
      final candidate = payload[field];
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    throw StateError('Connection endpoint missing node identifier for $keyName: $payload');
  }

  static String? _extractPortId(Map<String, dynamic> payload) {
    for (final field in ['port', 'argument', 'name', 'input', 'output', 'socket']) {
      final candidate = payload[field];
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }

  static String _normalizePortId({
    required String? rawPortId,
    required String defaultValue,
    required Set<String> legacyDefaultNames,
  }) {
    final trimmed = rawPortId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    if (trimmed == defaultValue || legacyDefaultNames.contains(trimmed)) {
      return '';
    }
    return trimmed;
  }
}

enum WorkflowDataTableColumnType {
  text('Text'),
  number('Number'),
  boolean('Boolean'),
  textList('TextList');

  const WorkflowDataTableColumnType(this.wireName);

  final String wireName;

  static WorkflowDataTableColumnType parse(dynamic value) {
    if (value == null) {
      return WorkflowDataTableColumnType.text;
    }
    final normalized = value.toString().trim().toLowerCase();
    switch (normalized) {
      case 'number':
        return WorkflowDataTableColumnType.number;
      case 'boolean':
        return WorkflowDataTableColumnType.boolean;
      case 'textlist':
      case 'text_list':
        return WorkflowDataTableColumnType.textList;
      case 'text':
      default:
        return WorkflowDataTableColumnType.text;
    }
  }
}

class WorkflowDataTableColumn {
  const WorkflowDataTableColumn({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
    this.isSystem = false,
    this.isReadOnly = false,
  });

  const WorkflowDataTableColumn.system({
    required this.name,
    required this.type,
  })  : isRequired = true,
        defaultValue = null,
        isSystem = true,
        isReadOnly = true;

  final String name;
  final WorkflowDataTableColumnType type;
  final bool isRequired;
  final dynamic defaultValue;
  final bool isSystem;
  final bool isReadOnly;

  WorkflowDataTableColumn copyWith({
    String? name,
    WorkflowDataTableColumnType? type,
    bool? isRequired,
    Object? defaultValue = _sentinel,
    bool? isSystem,
    bool? isReadOnly,
  }) {
    return WorkflowDataTableColumn(
      name: name ?? this.name,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      defaultValue: defaultValue == _sentinel ? _cloneValue(this.defaultValue) : defaultValue,
      isSystem: isSystem ?? this.isSystem,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }

  factory WorkflowDataTableColumn.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] as String?)?.trim() ?? '';
    final columnType = WorkflowDataTableColumnType.parse(json['type']);
    dynamic defaultValue;
    if (json.containsKey('default')) {
      defaultValue = _cloneValue(json['default']);
    } else if (json.containsKey('defaultValue')) {
      defaultValue = _cloneValue(json['defaultValue']);
    }
    return WorkflowDataTableColumn(
      name: rawName,
      type: columnType,
      isRequired: json['required'] == true,
      defaultValue: defaultValue,
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'name': name,
      'type': type.wireName,
    };
    if (isRequired) {
      payload['required'] = true;
    }
    if (defaultValue != null) {
      payload['default'] = _cloneValue(defaultValue);
    }
    return payload;
  }
}

class WorkflowDataTable {
  WorkflowDataTable({
    required String name,
    List<WorkflowDataTableColumn>? columns,
    List<Map<String, dynamic>>? rows,
  })  : name = name.trim(),
        columns = columns == null ? <WorkflowDataTableColumn>[] : List<WorkflowDataTableColumn>.from(columns.map((column) => column.copyWith())),
        rows = rows == null ? <Map<String, dynamic>>[] : rows.map(_cloneTableRow).toList();

  String name;
  List<WorkflowDataTableColumn> columns;
  List<Map<String, dynamic>> rows;

  static const List<WorkflowDataTableColumn> systemColumns = <WorkflowDataTableColumn>[
    WorkflowDataTableColumn.system(name: 'id', type: WorkflowDataTableColumnType.number),
    WorkflowDataTableColumn.system(name: 'CreatedAt', type: WorkflowDataTableColumnType.text),
    WorkflowDataTableColumn.system(name: 'UpdatedAt', type: WorkflowDataTableColumnType.text),
  ];

  factory WorkflowDataTable.fromJson(String name, Map<String, dynamic> json) {
    final columnsJson = json['columns'] as List<dynamic>? ?? const [];
    final rowsJson = json['rows'] as List<dynamic>? ?? const [];
    final parsedColumns = <WorkflowDataTableColumn>[];
    for (final entry in columnsJson) {
      if (entry is Map<String, dynamic>) {
        parsedColumns.add(WorkflowDataTableColumn.fromJson(entry));
      } else if (entry is Map) {
        parsedColumns.add(WorkflowDataTableColumn.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    final parsedRows = <Map<String, dynamic>>[];
    for (final entry in rowsJson) {
      if (entry is Map<String, dynamic>) {
        parsedRows.add(_cloneTableRow(entry));
      } else if (entry is Map) {
        parsedRows.add(_cloneTableRow(Map<String, dynamic>.from(entry)));
      }
    }
    return WorkflowDataTable(name: name, columns: parsedColumns, rows: parsedRows);
  }

  WorkflowDataTable copy() => WorkflowDataTable(name: name, columns: columns, rows: rows);

  Map<String, dynamic> toJson() => {
        'columns': columns.map((column) => column.toJson()).toList(),
        'rows': rows
            .map(
              (row) => row.entries.fold<Map<String, dynamic>>(
                <String, dynamic>{},
                (acc, entry) {
                  acc[entry.key] = _cloneValue(entry.value);
                  return acc;
                },
              ),
            )
            .toList(),
      };

  bool containsColumn(String columnName) {
    final normalized = columnName.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final userColumnExists = columns.any((column) => column.name == normalized);
    if (userColumnExists) {
      return true;
    }
    return systemColumns.any((column) => column.name == normalized);
  }
}

class ConnectionMapping {
  ConnectionMapping({required this.from, required this.to});

  String from;
  String to;

  factory ConnectionMapping.fromJson(Map<String, dynamic> json) {
    return ConnectionMapping(
      from: (json['from'] as String?)?.trim() ?? '',
      to: (json['to'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
      };
}

class _EndpointPayload {
  const _EndpointPayload({required this.nodeId, this.portId});

  final String nodeId;
  final String? portId;
}

/// Severity of a workflow validation issue
enum WorkflowValidationSeverity {
  info('Info'),
  warning('Warning'),
  error('Error');

  const WorkflowValidationSeverity(this.label);
  final String label;

  factory WorkflowValidationSeverity.fromString(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'info':
        return WorkflowValidationSeverity.info;
      case 'warning':
        return WorkflowValidationSeverity.warning;
      case 'error':
        return WorkflowValidationSeverity.error;
      default:
        return WorkflowValidationSeverity.info;
    }
  }
}

/// A single workflow validation issue
class WorkflowValidationIssue {
  WorkflowValidationIssue({
    required this.code,
    required this.severity,
    this.nodeId,
    List<String>? relatedNodeIds,
    required this.title,
    required this.description,
    this.impact,
    this.suggestion,
    this.example,
    this.documentationUrl,
  }) : relatedNodeIds = relatedNodeIds ?? const <String>[];

  final String code;
  final WorkflowValidationSeverity severity;
  final String? nodeId;
  final List<String> relatedNodeIds;
  final String title;
  final String description;
  final String? impact;
  final String? suggestion;
  final String? example;
  final String? documentationUrl;

  factory WorkflowValidationIssue.fromJson(Map<String, dynamic> json) {
    final relatedNodes = json['relatedNodeIds'];
    List<String> parsedRelatedNodes = const <String>[];
    if (relatedNodes is List) {
      parsedRelatedNodes = relatedNodes.map((e) => e.toString()).toList();
    }

    return WorkflowValidationIssue(
      code: json['code']?.toString() ?? '',
      severity: WorkflowValidationSeverity.fromString(json['severity']?.toString() ?? 'info'),
      nodeId: json['nodeId']?.toString(),
      relatedNodeIds: parsedRelatedNodes,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      impact: json['impact']?.toString(),
      suggestion: json['suggestion']?.toString(),
      example: json['example']?.toString(),
      documentationUrl: json['documentationUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'severity': severity.label,
        if (nodeId != null) 'nodeId': nodeId,
        if (relatedNodeIds.isNotEmpty) 'relatedNodeIds': relatedNodeIds,
        'title': title,
        'description': description,
        if (impact != null) 'impact': impact,
        if (suggestion != null) 'suggestion': suggestion,
        if (example != null) 'example': example,
        if (documentationUrl != null) 'documentationUrl': documentationUrl,
      };
}

/// WorkflowEntity validation result
class WorkflowValidationResult {
  WorkflowValidationResult({
    required this.isValid,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    List<WorkflowValidationIssue>? issues,
  }) : issues = issues ?? const <WorkflowValidationIssue>[];

  final bool isValid;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final List<WorkflowValidationIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  bool get hasErrors => errorCount > 0;
  bool get hasWarnings => warningCount > 0;
  bool get hasInfos => infoCount > 0;

  factory WorkflowValidationResult.empty() {
    return WorkflowValidationResult(
      isValid: true,
      errorCount: 0,
      warningCount: 0,
      infoCount: 0,
      issues: const <WorkflowValidationIssue>[],
    );
  }

  factory WorkflowValidationResult.fromJson(Map<String, dynamic> json) {
    final issuesJson = json['issues'];
    List<WorkflowValidationIssue> parsedIssues = const <WorkflowValidationIssue>[];
    if (issuesJson is List) {
      parsedIssues = issuesJson
          .map((issueJson) {
            if (issueJson is Map<String, dynamic>) {
              return WorkflowValidationIssue.fromJson(issueJson);
            } else if (issueJson is Map) {
              return WorkflowValidationIssue.fromJson(Map<String, dynamic>.from(issueJson));
            }
            return null;
          })
          .whereType<WorkflowValidationIssue>()
          .toList();
    }

    return WorkflowValidationResult(
      isValid: json['isValid'] == true,
      errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
      warningCount: (json['warningCount'] as num?)?.toInt() ?? 0,
      infoCount: (json['infoCount'] as num?)?.toInt() ?? 0,
      issues: parsedIssues,
    );
  }

  Map<String, dynamic> toJson() => {
        'isValid': isValid,
        'errorCount': errorCount,
        'warningCount': warningCount,
        'infoCount': infoCount,
        'issues': issues.map((issue) => issue.toJson()).toList(),
      };
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}
