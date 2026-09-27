import 'package:flutter/material.dart';

import '../../../icons/icon_ref.dart';

/// Identity of a team member/agent whose turn is being rendered (active-member indicator or a message's speaker label).
class AgUiChatMember {
  const AgUiChatMember({this.memberEntityId, this.displayName});
  final String? memberEntityId;
  final String? displayName;
}

/// What to render for a member's avatar. All fields optional — an app can supply
/// whichever it has (`imageUrl` wins if present, then `emoji`, then a catalog `icon`, then initials).
/// `color` styles the background when no `imageUrl` is given.
class AgUiMemberAvatar {
  const AgUiMemberAvatar({
    this.imageUrl,
    this.emoji,
    this.icon,
    this.color,
    this.initials,
  });
  final String? imageUrl;
  final String? emoji;

  /// An icon of the platform's catalog (`IconRef.material('E297')` — see [agUiIcon]). One this SDK does not draw is
  /// ignored, and the avatar falls back to initials.
  final IconRef? icon;
  final Color? color;
  final String? initials;
}

const _defaultPalette = [
  Color(0xFFE3A94F),
  Color(0xFFF1633B),
  Color(0xFF4F8C82),
  Color(0xFF8B6B9C),
  Color(0xFF3B7CF1),
  Color(0xFFC9506B),
];

int _hashString(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

String _initialsFrom(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1)
    return parts.first
        .substring(0, parts.first.length.clamp(0, 2))
        .toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Resolves the avatar for [member]: consults [resolver] first (an app-supplied mapping
/// from member identity to image/emoji/color), falling back to a deterministic
/// initials+color avatar derived from the member's id/name so a caller that configures
/// nothing still gets a stable, distinct-looking avatar per member.
AgUiMemberAvatar resolveMemberAvatar(
  AgUiChatMember member,
  AgUiMemberAvatar? Function(AgUiChatMember member)? resolver,
) {
  final resolved = resolver?.call(member);
  final key = member.memberEntityId ?? member.displayName ?? '';
  final fallbackColor =
      _defaultPalette[_hashString(key) % _defaultPalette.length];
  final fallbackInitials = _initialsFrom(
    member.displayName ?? member.memberEntityId ?? '?',
  );
  return AgUiMemberAvatar(
    imageUrl: resolved?.imageUrl,
    emoji: resolved?.emoji,
    icon: resolved?.icon,
    color: resolved?.color ?? fallbackColor,
    initials: resolved?.initials ?? fallbackInitials,
  );
}

/// Renders a small round avatar for [member] — image, then emoji, then initials on a colored circle.
class MemberAvatarWidget extends StatelessWidget {
  const MemberAvatarWidget({
    super.key,
    required this.member,
    this.resolver,
    this.size = 26,
  });

  final AgUiChatMember member;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolver;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = resolveMemberAvatar(member, resolver);
    if (avatar.imageUrl != null) {
      return ClipOval(
        child: Image.network(
          avatar.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final glyph = avatar.emoji == null ? agUiIcon(avatar.icon) : null;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: avatar.color,
      child:
          glyph != null
              ? Icon(glyph, size: size * 0.55, color: Colors.white)
              : Text(
                avatar.emoji ?? avatar.initials ?? '?',
                style: TextStyle(fontSize: size * 0.42, color: Colors.white),
              ),
    );
  }
}
