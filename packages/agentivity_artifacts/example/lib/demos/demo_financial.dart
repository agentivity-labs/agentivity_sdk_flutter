import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoFinancial extends StatelessWidget {
  const DemoFinancial({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'Financial Intelligence',
      sections: [
        DemoSection(
          label: 'Portfolio Overview',
          delayMs: 350,
          child: AgStatGrid(props: {
            'columns': 4,
            'metrics': [
              {'title': 'Price',       'value': '\$243.10', 'delta': '+\$5.02', 'trend': 'up',   'subtitle': 'AAPL'},
              {'title': '24 h Change', 'value': '+2.11 %',  'delta': '+\$5.02', 'trend': 'up',   'subtitle': 'vs yesterday'},
              {'title': 'Volume',      'value': '61.2 M',   'delta': '+42 %',   'trend': 'up',   'subtitle': 'vs avg 30d'},
              {'title': 'P/E Ratio',   'value': '31.4×',    'delta': '-0.8',    'trend': 'down', 'subtitle': 'trailing 12m'},
            ],
          }),
        ),
        DemoSection(
          label: 'Price History — 12 Months',
          delayMs: 800,
          child: AgLineChart(props: {
            'title': 'AAPL · Price & Moving Averages',
            'labels': ['Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'],
            'datasets': [
              {'label': 'Price',
               'data': <num>[168,175,179,171,177,181,188,196,203,215,228,243],
               'smooth': true},
              {'label': 'MA 20',
               'data': <num>[165,170,174,173,174,177,183,190,197,208,220,233],
               'smooth': true},
              {'label': 'MA 50',
               'data': <num>[160,163,167,169,171,173,177,182,187,194,202,211],
               'smooth': true},
            ],
            'height': 230,
          }),
        ),
        DemoSection(
          label: 'Volume & Allocation',
          delayMs: 900,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AgBarChart(props: {
                  'title': 'Daily Volume (M)',
                  'labels': ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
                  'datasets': [
                    {'label': 'Volume', 'data': <num>[42,38,51,47,55,43,61]},
                  ],
                  'height': 180,
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AgPieChart(props: {
                  'title': 'Allocation',
                  'sections': [
                    {'label': 'AAPL',  'value': 35},
                    {'label': 'MSFT',  'value': 25},
                    {'label': 'GOOGL', 'value': 20},
                    {'label': 'NVDA',  'value': 12},
                    {'label': 'Cash',  'value':  8},
                  ],
                  'donut': true,
                  'height': 180,
                }),
              ),
            ],
          ),
        ),
        DemoSection(
          label: 'Portfolio Risk Profile',
          delayMs: 950,
          child: AgRadarChart(props: {
            'title': 'Risk Dimensions — Portfolio vs Benchmark',
            'labels': ['Sharpe', 'Volatility', 'Drawdown', 'Beta', 'Liquidity'],
            'datasets': [
              {'label': 'Portfolio', 'data': <num>[4.2, 3.1, 4.5, 2.8, 4.0]},
              {'label': 'Benchmark', 'data': <num>[3.5, 3.5, 3.5, 3.5, 3.5]},
            ],
            'max': 5.0,
            'height': 260,
          }),
        ),
        DemoSection(
          label: 'Instrument Detail',
          delayMs: 750,
          child: AgKeyValue(props: {
            'title': 'AAPL — Apple Inc.',
            'items': [
              {'key': 'Exchange',      'value': 'NASDAQ'},
              {'key': 'Sector',        'value': 'Technology',   'highlight': true},
              {'key': 'Market Cap',    'value': '\$3.76 T'},
              {'key': '52-week High',  'value': '\$243.10',      'highlight': true},
              {'key': '52-week Low',   'value': '\$164.08'},
              {'key': 'Div. Yield',    'value': '0.44 %'},
              {'key': 'P/E Ratio',     'value': '31.4×'},
            ],
          }),
        ),
      ],
    );
  }
}
