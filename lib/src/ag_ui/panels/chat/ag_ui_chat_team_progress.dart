import 'package:flutter/material.dart';

import '../../widgets/ag_ui_markdown_body.dart';
import 'member_avatar.dart';
import 'team_appearance.dart';
import 'team_progress.dart';
import 'team_views.dart';

String _agents(int n) => '$n agent${n == 1 ? '' : 's'}';

/// The words of the widget, each with an English default. Same names as the React SDK's `ChatTeamProgressTexts`.
class AgUiTeamProgressTexts {
  const AgUiTeamProgressTexts({
    this.working = 'Your team is working',
    this.waiting = 'Waiting for your answer',
    this.count = _count,
    this.finished = _finished,
    this.failed = _failed,
    this.stopped = _stopped,
    this.agentPending = 'Waiting for its turn',
    this.agentWorking = 'Working on it…',
    this.agentWaiting = 'Waiting for your answer',
    this.agentDone = 'Done',
    this.agentFailed = 'Could not finish this part',
    this.managerWorking = 'Organizing the work',
    this.managerDone = 'Brought it all together',
    this.openResult = 'Read the result of',
    this.closeResult = 'Close the result of',
  });

  final String working;
  final String waiting;

  /// "2 of 4 done" while it works.
  final String Function(int done, int total) count;

  /// The line it collapses to, `took` being "4 min 32 s" when the platform says how long it took.
  final String Function(int agents, String? took) finished;
  final String Function(int agents) failed;
  final String Function(int agents) stopped;
  final String agentPending;
  final String agentWorking;
  final String agentWaiting;
  final String agentDone;
  final String agentFailed;
  final String managerWorking;
  final String managerDone;
  final String openResult;
  final String closeResult;

  static String _count(int done, int total) => '$done of $total done';
  static String _finished(int n, String? took) => took != null ? '${_agents(n)} worked for $took' : '${_agents(n)} worked on this';
  static String _failed(int n) => 'Something went wrong · ${_agents(n)} worked on this';
  static String _stopped(int n) => 'Stopped · ${_agents(n)} worked on this';
}

/// The team at work, in the thread: one line per agent while an execution goes on, with what each does and a result to open. It
/// collapses to one line when the execution ends or waits for an answer; a tap opens it again. [AgUiChatDiscussion] shows it on its
/// own; an app that lays out its chat itself gives it what [AgUiTeamProgressController.progress] returns.
class AgUiChatTeamProgress extends StatefulWidget {
  const AgUiChatTeamProgress({super.key, required this.progress, this.resolveMemberAvatar, this.texts = const AgUiTeamProgressTexts(), this.palette = const AgUiTeamPalette()});

  final TeamProgress progress;

  /// Maps a member's identity to an avatar (image/emoji/color). Falls back to the team's icons and group colors.
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolveMemberAvatar;
  final AgUiTeamProgressTexts texts;
  final AgUiTeamPalette palette;

  @override
  State<AgUiChatTeamProgress> createState() => _AgUiChatTeamProgressState();
}

class _AgUiChatTeamProgressState extends State<AgUiChatTeamProgress> {
  // What the person chose holds until the execution moves on.
  bool? _chosen;

  @override
  void didUpdateWidget(AgUiChatTeamProgress old) {
    super.didUpdateWidget(old);
    if (old.progress.phase != widget.progress.phase || old.progress.executionId != widget.progress.executionId) _chosen = null;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final t = widget.texts;
    final phase = progress.phase;
    final atWork = phase == TeamProgressPhase.working;
    final open = _chosen ?? atWork;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final members = [for (final a in progress.agents) if (a.member != null) a.member!];
    final colors = agUiTeamGroupColors(members.map((m) => m.group), custom: agUiGroupColorOverrides(members.map((m) => (group: m.group, groupColor: m.groupColor))));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: atWork ? cs.surfaceContainerLow : null, border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: open,
                child: InkWell(
                  onTap: () => setState(() => _chosen = !open),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          _Mark(status: _markOf(phase), palette: widget.palette),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_headline(progress, t), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: atWork ? FontWeight.w600 : FontWeight.w400, color: atWork ? null : muted))),
                          if (atWork && progress.total > 0) ...[const SizedBox(width: 8), Text(t.count(progress.done, progress.total), style: theme.textTheme.bodySmall?.copyWith(color: muted))],
                          Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (open)
                for (final agent in progress.agents)
                  _AgentLine(
                    key: ValueKey(agent.memberEntityId),
                    agent: agent,
                    texts: t,
                    palette: widget.palette,
                    resolver: agent.member != null ? agUiMemberAvatarFor(agent.member!, colors[agUiTeamGroupKey(agent.member!.group)], widget.resolveMemberAvatar) : widget.resolveMemberAvatar,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentLine extends StatefulWidget {
  const _AgentLine({super.key, required this.agent, required this.texts, required this.palette, this.resolver});

  final TeamProgressAgent agent;
  final AgUiTeamProgressTexts texts;
  final AgUiTeamPalette palette;
  final AgUiMemberAvatar? Function(AgUiChatMember member)? resolver;

  @override
  State<_AgentLine> createState() => _AgentLineState();
}

class _AgentLineState extends State<_AgentLine> {
  bool _reading = false;

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;
    final t = widget.texts;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pending = agent.status == TeamProgressStatus.pending;
    final result = agent.result;
    Widget line = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          MemberAvatarWidget(member: AgUiChatMember(memberEntityId: agent.memberEntityId, displayName: agent.displayName), resolver: widget.resolver, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(agent.displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(_describe(agent, t), style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _Mark(status: agent.status, palette: widget.palette),
        ],
      ),
    );
    if (pending) line = Opacity(opacity: 0.6, child: line);
    if (result != null) {
      line = Semantics(
        button: true,
        expanded: _reading,
        label: '${_reading ? t.closeResult : t.openResult} ${agent.displayName}',
        child: InkWell(onTap: () => setState(() => _reading = !_reading), child: line),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line,
          if (_reading && result != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: AgUiMarkdownBody(data: result)),
            ),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.status, required this.palette});

  final TeamProgressStatus status;
  final AgUiTeamPalette palette;

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    if (status == TeamProgressStatus.working) {
      final still = MediaQuery.disableAnimationsOf(context);
      return SizedBox.square(dimension: size, child: CircularProgressIndicator(strokeWidth: 2, color: palette.working, value: still ? 0.75 : null));
    }
    final filled = status == TeamProgressStatus.done || status == TeamProgressStatus.failed;
    final color = switch (status) {
      TeamProgressStatus.waiting => palette.waiting,
      TeamProgressStatus.done => palette.done,
      TeamProgressStatus.failed => palette.failed,
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? color : null, border: Border.all(color: color, width: 2)));
  }
}

String _describe(TeamProgressAgent agent, AgUiTeamProgressTexts t) {
  if (agent.isManager && agent.status != TeamProgressStatus.waiting && agent.status != TeamProgressStatus.failed) return agent.status == TeamProgressStatus.done ? t.managerDone : t.managerWorking;
  return agent.description ??
      switch (agent.status) {
        TeamProgressStatus.working => t.agentWorking,
        TeamProgressStatus.waiting => t.agentWaiting,
        TeamProgressStatus.done => t.agentDone,
        TeamProgressStatus.failed => t.agentFailed,
        TeamProgressStatus.pending => t.agentPending,
      };
}

String _headline(TeamProgress progress, AgUiTeamProgressTexts t) => switch (progress.phase) {
  TeamProgressPhase.working => t.working,
  TeamProgressPhase.waiting => t.waiting,
  TeamProgressPhase.failed => t.failed(progress.worked),
  TeamProgressPhase.stopped => t.stopped(progress.worked),
  TeamProgressPhase.done => t.finished(progress.worked, progress.duration == null ? null : _took(progress.duration!)),
};

TeamProgressStatus _markOf(TeamProgressPhase phase) => switch (phase) {
  TeamProgressPhase.working => TeamProgressStatus.working,
  TeamProgressPhase.waiting => TeamProgressStatus.waiting,
  TeamProgressPhase.done => TeamProgressStatus.done,
  TeamProgressPhase.failed => TeamProgressStatus.failed,
  TeamProgressPhase.stopped => TeamProgressStatus.pending,
};

String _took(Duration d) {
  final seconds = d.inMilliseconds < 1000 ? 1 : (d.inMilliseconds / 1000).round();
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min ${seconds % 60} s';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}
