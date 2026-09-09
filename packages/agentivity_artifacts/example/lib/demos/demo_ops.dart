import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoOps extends StatelessWidget {
  const DemoOps({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'Real-time Ops Dashboard',
      sections: [
        DemoSection(
          label: 'Platform Health',
          delayMs: 350,
          child: AgStatGrid(props: {
            'columns': 4,
            'metrics': [
              {'title': 'Uptime',      'value': '99.94 %', 'delta': '−0.04 %', 'trend': 'down', 'subtitle': '30-day rolling'},
              {'title': 'Latency p99', 'value': '234 ms',  'delta': '+42 ms',   'trend': 'up',   'subtitle': 'EU-West-1'},
              {'title': 'Error Rate',  'value': '2.8 %',   'delta': '+1.4 %',   'trend': 'up',   'subtitle': 'last 15 min'},
              {'title': 'Req / s',     'value': '1,847',   'delta': '+12 %',    'trend': 'up',   'subtitle': 'peak today'},
            ],
          }),
        ),
        DemoSection(
          label: 'System Status — All Services',
          delayMs: 900,
          child: Column(
            children: [
              AgStatusCard(props: {
                'title': 'CDN — All edge nodes operational',
                'status': 'success',
                'message': '24 / 24 PoPs healthy. Avg cache-hit ratio 94.2 %.',
                'details': [
                  'Frankfurt, London, New York: nominal',
                  'Cache purge completed 3 min ago',
                ],
              }),
              const SizedBox(height: 8),
              AgStatusCard(props: {
                'title': 'DB Replica lag — CRITICAL',
                'status': 'error',
                'message': 'Primary → replica replication delay reached +3.2 s.',
                'details': [
                  'Replica node-2 write queue stalled',
                  'Writes degraded to primary-only',
                  'SLA breach in < 4 min at current rate',
                ],
              }),
              const SizedBox(height: 8),
              AgStatusCard(props: {
                'title': 'Auto-failover in progress',
                'status': 'running',
                'message': 'Promoting replica node-3 to primary. ETA ~45 s.',
                'details': [
                  'Health check passed on node-3',
                  'Connection pool draining on node-2',
                ],
              }),
              const SizedBox(height: 8),
              AgStatusCard(props: {
                'title': 'Memory pressure — k8s-worker-03',
                'status': 'warning',
                'message': 'Node at 91 % RAM. Horizontal pod autoscaler triggered.',
                'details': [
                  '+2 replica pods initialising',
                  'Estimated ready in ~90 s',
                ],
              }),
            ],
          ),
        ),
        DemoSection(
          label: 'Error Spike — Last 60 Minutes',
          delayMs: 850,
          child: AgBarChart(props: {
            'title': 'Errors / 5 min window',
            'labels': ['14:00','14:05','14:10','14:15','14:20','14:25',
                       '14:30','14:35','14:40','14:45','14:50','14:55'],
            'datasets': [
              {'label': 'Errors', 'data': <num>[2,3,2,4,8,23,45,38,19,12,8,5]},
            ],
            'height': 200,
          }),
        ),
        DemoSection(
          label: 'Incident Timeline',
          delayMs: 800,
          child: AgTimeline(props: {
            'title': 'INC-2847 · DB Replication Failure',
            'events': [
              {'label': 'Anomaly detected',      'time': '14:28', 'status': 'error',   'note': 'Replica lag crossed 500 ms threshold'},
              {'label': 'Alert fired',            'time': '14:29', 'status': 'success', 'note': 'PagerDuty P1 — DB-Replication-Lag'},
              {'label': 'On-call paged',          'time': '14:29', 'status': 'success', 'note': '@david (primary) + @ana (secondary)'},
              {'label': 'Root cause identified',  'time': '14:37', 'status': 'success', 'note': 'Long-running VACUUM FULL blocked WAL sender'},
              {'label': 'Failover initiated',     'time': '14:42', 'status': 'running', 'note': 'node-3 promotion in progress'},
              {'label': 'Traffic rerouted',       'time': '',       'status': 'pending'},
              {'label': 'Post-mortem',            'time': '',       'status': 'pending'},
            ],
          }),
        ),
      ],
    );
  }
}
