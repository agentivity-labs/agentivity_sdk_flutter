import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoCodeReview extends StatelessWidget {
  const DemoCodeReview({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'AI Code Review',
      sections: [
        DemoSection(
          label: 'PR Summary',
          delayMs: 350,
          child: AgStatGrid(props: {
            'columns': 4,
            'metrics': [
              {'title': 'Files Changed', 'value': '7',       'delta': 'feat/user-validation', 'trend': 'flat', 'subtitle': 'branch'},
              {'title': 'Additions',     'value': '+284',    'delta': '+284',                 'trend': 'up',   'subtitle': 'lines added'},
              {'title': 'Deletions',     'value': '−127',    'delta': '−127',                 'trend': 'down', 'subtitle': 'lines removed'},
              {'title': 'Tests',         'value': '42 / 42', 'delta': '+6 new',               'trend': 'up',   'subtitle': 'all passing'},
            ],
          }),
        ),
        DemoSection(
          label: 'CI Status',
          delayMs: 750,
          child: AgStatusCard(props: {
            'title': 'All 6 checks passed — Ready to merge',
            'status': 'success',
            'message': 'No issues found. Agent applied 3 suggestions automatically.',
            'details': [
              'Build + lint ✓  (42 s)',
              'Test suite ✓  (coverage +2.1 % → 94.2 %)',
              'Snyk security scan ✓  (0 vulnerabilities)',
            ],
          }),
        ),
        DemoSection(
          label: 'Code Diff — Agent Suggestions Applied',
          delayMs: 900,
          child: Column(
            children: [
              AgCodeBlock(props: {
                'title': 'Before  ·  user.service.ts',
                'language': 'typescript',
                'code': '''// ❌  Before agent review
async function getUser(id: string) {
  const user = await db.users.findOne(id);
  if (!user) throw new Error('Not found');
  return user;
}

async function updateUser(id: string, data: any) {
  return db.users.update(id, data);
}''',
                'maxLines': 12,
              }),
              const SizedBox(height: 8),
              AgCodeBlock(props: {
                'title': 'After  ·  user.service.ts  (agent-revised)',
                'language': 'typescript',
                'code': r'''// ✅  After agent review
async function getUser(id: string): Promise<User> {
  if (!id?.trim()) {
    throw new ValidationError('User ID is required');          // + input guard
  }
  const user = await db.users.findOne({ id, deletedAt: null }); // + soft-delete
  if (!user) throw new NotFoundError(`User ${id} not found`);   // + typed error
  return user;
}

async function updateUser(
  id: string,
  data: Partial<UpdateUserDto>,                                 // + typed payload
): Promise<User> {
  await getUser(id);                                            // + existence check
  return db.users.update(id, data);
}''',
                'maxLines': 18,
              }),
            ],
          ),
        ),
        DemoSection(
          label: 'Test Results',
          delayMs: 850,
          child: AgJsonViewer(props: {
            'title': 'jest --coverage  ·  UserService',
            'data': {
              'suite': 'UserService',
              'passed': 42,
              'failed': 0,
              'duration': '1.24 s',
              'coverage': {
                'lines': '94.2 %',
                'branches': '87.5 %',
                'functions': '100.0 %',
              },
              'new_tests': [
                'getUser › throws ValidationError for empty id',
                'getUser › excludes soft-deleted users',
                'updateUser › throws NotFoundError for missing user',
                'updateUser › applies partial update correctly',
              ],
            },
            'expanded': true,
          }),
        ),
        DemoSection(
          label: 'PR Lifecycle',
          delayMs: 800,
          child: AgTimeline(props: {
            'title': 'PR #318 · feat/user-validation',
            'events': [
              {'label': 'PR opened',     'time': '10:15', 'status': 'success', 'note': 'feat: add input validation & soft-delete'},
              {'label': 'CI started',    'time': '10:16', 'status': 'success', 'note': 'Build, lint, test runner triggered'},
              {'label': 'Agent review',  'time': '10:18', 'status': 'success', 'note': '3 suggestions applied, 2 questions raised'},
              {'label': 'Review: @marco','time': '10:45', 'status': 'success', 'note': 'LGTM — good catch on soft-delete'},
              {'label': 'Review: @sarah','time': '11:02', 'status': 'success', 'note': 'Approved — add integration test in follow-up'},
              {'label': 'Merged',        'time': '11:08', 'status': 'success', 'note': 'Squash merge → main · auto-deploy triggered'},
            ],
          }),
        ),
      ],
    );
  }
}
