/// A space of the workspace (Finance, HR…) the person is in: each agent, team, workflow and conversation is in one.
class WorkspaceSpace {
  const WorkspaceSpace({required this.id, required this.name, this.description = '', this.isDefault = false, this.isCurrent = false, this.archived = false});

  final String id;
  final String name;
  final String description;

  /// General: everything made without a space, everyone in it.
  final bool isDefault;

  /// The space the person works in now: the lists of the Studio and of the Desk show it.
  final bool isCurrent;
  final bool archived;

  factory WorkspaceSpace.fromJson(Map<String, dynamic> json) => WorkspaceSpace(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isDefault: json['isDefault'] == true,
        isCurrent: json['isCurrent'] == true,
        archived: json['archived'] == true,
      );
}
