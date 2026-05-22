import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoScientific extends StatelessWidget {
  const DemoScientific({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'Scientific Research Report',
      sections: [
        DemoSection(
          label: 'Mathematical Formulas',
          delayMs: 400,
          child: Column(
            children: [
              AgLatex(props: {
                'title': 'Black–Scholes Call Price',
                'tex': r'C = S \cdot N(d_1) - K e^{-rT} N(d_2)'
                    r'\quad\text{where}\quad '
                    r'd_1 = \frac{\ln(S/K)+(r+\frac{\sigma^2}{2})T}{\sigma\sqrt{T}}',
                'display': true,
              }),
              const SizedBox(height: 8),
              AgLatex(props: {
                'title': 'Fourier Series',
                'tex': r'f(x) = \frac{a_0}{2} + '
                    r'\sum_{n=1}^{\infty}\!\left('
                    r'a_n\cos\frac{n\pi x}{L} + b_n\sin\frac{n\pi x}{L}'
                    r'\right)',
                'display': true,
              }),
            ],
          ),
        ),
        DemoSection(
          label: 'Function Plot — Trigonometric',
          delayMs: 900,
          child: AgLineChart(props: {
            'title': 'sin(x), cos(x), sin(x)+cos(x)  over  [−π, π]',
            'labels': ['−π','−5π/6','−2π/3','−π/2','−π/3','−π/6',
                       '0','π/6','π/3','π/2','2π/3','5π/6','π'],
            'datasets': [
              {'label': 'sin(x)',
               'data': <num>[0,-0.5,-0.87,-1.0,-0.87,-0.5,0,0.5,0.87,1.0,0.87,0.5,0],
               'smooth': true},
              {'label': 'cos(x)',
               'data': <num>[-1.0,-0.87,-0.5,0,0.5,0.87,1.0,0.87,0.5,0,-0.5,-0.87,-1.0],
               'smooth': true},
              {'label': 'sin+cos',
               'data': <num>[-1.0,-1.37,-1.37,-1.0,-0.37,0.37,1.0,1.37,1.37,1.0,0.37,-0.37,-1.0],
               'smooth': true},
            ],
            'height': 220,
          }),
        ),
        DemoSection(
          label: 'Implementation',
          delayMs: 950,
          child: AgCodeBlock(props: {
            'title': 'Black–Scholes pricer · Python',
            'language': 'python',
            'code': r'''from scipy import stats
import numpy as np

def bs_call(S: float, K: float, T: float,
            r: float, sigma: float) -> float:
    """Black–Scholes European call price."""
    d1 = (np.log(S / K) + (r + 0.5 * sigma**2) * T) \
         / (sigma * np.sqrt(T))
    d2 = d1 - sigma * np.sqrt(T)
    return S * stats.norm.cdf(d1) - K * np.exp(-r * T) * stats.norm.cdf(d2)

# Example: AAPL 145-strike call, 3-month expiry
price = bs_call(S=143.0, K=145.0, T=0.25, r=0.05, sigma=0.22)
print(f"Call price: ${price:.2f}")   # → $5.84''',
            'maxLines': 18,
          }),
        ),
        DemoSection(
          label: 'Experiment Parameters',
          delayMs: 750,
          child: AgKeyValue(props: {
            'title': 'Model Configuration',
            'items': [
              {'key': 'Underlying (S)',     'value': '143.00 USD'},
              {'key': 'Strike (K)',         'value': '145.00 USD', 'highlight': true},
              {'key': 'Maturity (T)',       'value': '0.25 yr  (90 d)'},
              {'key': 'Risk-free rate (r)', 'value': '5.00 %'},
              {'key': 'Implied vol (σ)',    'value': '22.00 %',    'highlight': true},
              {'key': 'Fair value',         'value': '5.84 USD'},
              {'key': 'Delta',              'value': '0.434'},
            ],
          }),
        ),
      ],
    );
  }
}
