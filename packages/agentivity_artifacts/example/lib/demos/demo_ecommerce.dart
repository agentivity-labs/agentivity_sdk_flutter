import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoEcommerce extends StatelessWidget {
  const DemoEcommerce({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'E-commerce Sales Burst',
      sections: [
        DemoSection(
          label: 'Flash Sale — Today vs Yesterday',
          delayMs: 350,
          child: AgStatGrid(props: {
            'columns': 4,
            'metrics': [
              {'title': 'GMV',        'value': '€ 127.5k', 'delta': '+34 %',  'trend': 'up',   'subtitle': 'today'},
              {'title': 'Orders',     'value': '1,847',    'delta': '+28 %',  'trend': 'up',   'subtitle': 'today'},
              {'title': 'Avg. Order', 'value': '€ 69.02', 'delta': '+4 %',   'trend': 'up',   'subtitle': 'AOV'},
              {'title': 'Returns',    'value': '3.2 %',   'delta': '−1.1 %', 'trend': 'down', 'subtitle': 'improving ↓'},
            ],
          }),
        ),
        DemoSection(
          label: 'Revenue by Category',
          delayMs: 850,
          child: AgBarChart(props: {
            'title': 'Category Revenue  ·  Today vs Yesterday (k€)',
            'labels': ['Electronics', 'Fashion', 'Home', 'Sports', 'Beauty'],
            'datasets': [
              {'label': 'Today',     'data': <num>[42.8, 31.2, 24.6, 18.9, 9.98]},
              {'label': 'Yesterday', 'data': <num>[35.2, 27.8, 21.1, 16.4,  8.1]},
            ],
            'height': 210,
          }),
        ),
        DemoSection(
          label: 'Intraday Sales & Payment Mix',
          delayMs: 900,
          child: Column(
            children: [
              AgAreaChart(props: {
                'title': 'Orders per Hour',
                'labels': ['08h','09h','10h','11h','12h','13h',
                           '14h','15h','16h','17h','18h','19h'],
                'datasets': [
                  {'label': 'Orders',
                   'data': <num>[52,118,214,287,342,218,195,237,301,388,321,174]},
                ],
                'height': 180,
              }),
              const SizedBox(height: 8),
              AgPieChart(props: {
                'title': 'Payment Methods',
                'sections': [
                  {'label': 'Stripe',    'value': 52},
                  {'label': 'PayPal',    'value': 28},
                  {'label': 'Apple Pay', 'value': 12},
                  {'label': 'BNPL',      'value':  8},
                ],
                'donut': true,
                'height': 180,
              }),
            ],
          ),
        ),
        DemoSection(
          label: 'Top Product',
          delayMs: 750,
          child: AgKeyValue(props: {
            'title': 'AirPods Pro (3rd gen)',
            'items': [
              {'key': 'SKU',             'value': 'APP-AP3-WHT'},
              {'key': 'Units sold',      'value': '284',         'highlight': true},
              {'key': 'Revenue',         'value': '€ 82,564'},
              {'key': 'Stock remaining', 'value': '1,203 units'},
              {'key': 'Rating',          'value': '4.8 / 5.0 ⭐','highlight': true},
              {'key': 'Return rate',     'value': '1.4 %'},
            ],
          }),
        ),
        DemoSection(
          label: 'Order Fulfillment',
          delayMs: 800,
          child: AgTimeline(props: {
            'title': 'Order #47821 — Live Tracking',
            'events': [
              {'label': 'Order placed',       'time': '10:24', 'status': 'success', 'note': 'AirPods Pro × 1  ·  Stripe'},
              {'label': 'Payment confirmed',  'time': '10:24', 'status': 'success', 'note': '€ 289.00 captured'},
              {'label': 'Warehouse picked',   'time': '11:47', 'status': 'success', 'note': 'WH-DE-01  ·  1 item ready'},
              {'label': 'Shipped',            'time': '14:02', 'status': 'running', 'note': 'DHL Express  ·  DE928374651'},
              {'label': 'Out for delivery',   'time': '',       'status': 'pending'},
              {'label': 'Delivered',          'time': '',       'status': 'pending'},
            ],
          }),
        ),
      ],
    );
  }
}
