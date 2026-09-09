import 'package:agentivity_artifacts/agentivity_artifacts.dart';
import 'package:flutter/material.dart';

import '_demo_common.dart';

class DemoArchitecture extends StatelessWidget {
  const DemoArchitecture({super.key});

  static const _kSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 295"
     font-family="monospace" font-size="10">
  <defs>
    <marker id="arr" markerWidth="8" markerHeight="8"
            refX="7" refY="4" orient="auto">
      <polygon points="0,0 8,4 0,8" fill="#000"/>
    </marker>
    <marker id="arr-d" markerWidth="8" markerHeight="8"
            refX="7" refY="4" orient="auto">
      <polygon points="0,0 8,4 0,8" fill="#555"/>
    </marker>
  </defs>
  <rect x="8" y="116" width="72" height="34" fill="none" stroke="#000" stroke-width="2.5"/>
  <text x="44" y="138" text-anchor="middle" font-weight="bold">Client</text>
  <line x1="80" y1="133" x2="118" y2="133" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="122" y="106" width="84" height="54" fill="#ffd100" stroke="#000" stroke-width="2.5"/>
  <text x="164" y="130" text-anchor="middle" font-weight="bold">API</text>
  <text x="164" y="144" text-anchor="middle" font-weight="bold">Gateway</text>
  <line x1="188" y1="112" x2="262" y2="55" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="265" y="30" width="88" height="34" fill="#00d492" stroke="#000" stroke-width="2.5"/>
  <text x="309" y="52" text-anchor="middle" font-weight="bold">Auth Svc</text>
  <line x1="353" y1="47" x2="390" y2="47" stroke="#555" stroke-width="1.5" stroke-dasharray="5,3" marker-end="url(#arr-d)"/>
  <rect x="393" y="30" width="72" height="34" fill="#ffd100" stroke="#000" stroke-width="2.5"/>
  <text x="429" y="48" text-anchor="middle" font-weight="bold">Redis</text>
  <text x="429" y="59" text-anchor="middle">session</text>
  <line x1="206" y1="133" x2="263" y2="133" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="266" y="116" width="88" height="34" fill="#ff5f1f" stroke="#000" stroke-width="2.5"/>
  <text x="310" y="138" text-anchor="middle" font-weight="bold" fill="#fff">Product Svc</text>
  <line x1="354" y1="133" x2="390" y2="133" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="393" y="116" width="72" height="34" fill="#ff0099" stroke="#000" stroke-width="2.5"/>
  <text x="429" y="133" text-anchor="middle" font-weight="bold" fill="#fff">Postgres</text>
  <text x="429" y="145" text-anchor="middle" fill="#fff">products</text>
  <line x1="188" y1="156" x2="263" y2="213" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="266" y="204" width="88" height="34" fill="#1400ff" stroke="#000" stroke-width="2.5"/>
  <text x="310" y="226" text-anchor="middle" font-weight="bold" fill="#fff">Order Svc</text>
  <line x1="354" y1="221" x2="390" y2="221" stroke="#000" stroke-width="2" marker-end="url(#arr)"/>
  <rect x="393" y="204" width="72" height="34" fill="#7928ca" stroke="#000" stroke-width="2.5"/>
  <text x="429" y="221" text-anchor="middle" font-weight="bold" fill="#fff">Postgres</text>
  <text x="429" y="233" text-anchor="middle" fill="#fff">orders</text>
  <line x1="310" y1="238" x2="310" y2="262" stroke="#555" stroke-width="1.5" stroke-dasharray="5,3" marker-end="url(#arr-d)"/>
  <rect x="266" y="265" width="88" height="28" fill="none" stroke="#000" stroke-width="2"/>
  <text x="310" y="283" text-anchor="middle" font-weight="bold">Kafka MQ</text>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return StreamingDemoPage(
      title: 'System Architecture',
      sections: [
        DemoSection(
          label: 'Service Diagram',
          delayMs: 400,
          child: AgSvg(props: {
            'title': 'Microservices Overview',
            'svg': _kSvg,
            'height': 295,
            'fit': 'contain',
          }),
        ),
        DemoSection(
          label: 'Source Code',
          delayMs: 950,
          child: Column(
            children: [
              AgCodeBlock(props: {
                'title': 'API Gateway handler · TypeScript',
                'language': 'typescript',
                'code': r'''import { Router, Request, Response } from 'express';
import { verifyJWT } from './auth';
import { ProductService } from './services/products';
import { OrderService }   from './services/orders';

const router = Router();
router.use(verifyJWT);

router.get('/products', async (req: Request, res: Response) => {
  const { page = 1, limit = 20, category } = req.query;
  const products = await ProductService.list({ page, limit, category });
  res.json({ data: products, page, total: products.total });
});

router.post('/orders', async (req: Request, res: Response) => {
  const order = await OrderService.create({
    userId:  req.user!.sub,
    items:   req.body.items,
    payment: req.body.paymentMethodId,
  });
  res.status(201).json(order);
});

export default router;''',
                'maxLines': 22,
              }),
              const SizedBox(height: 8),
              AgCodeBlock(props: {
                'title': 'docker-compose.yml',
                'language': 'yaml',
                'code': r'''services:
  api-gateway:
    image: api-gateway:latest
    ports: ["3000:3000"]
    environment:
      JWT_SECRET: ${JWT_SECRET}
      REDIS_URL:  redis://redis:6379
    depends_on: [redis, product-svc, order-svc]

  product-svc:
    image: product-svc:latest
    environment:
      DATABASE_URL: postgres://products_db/products

  order-svc:
    image: order-svc:latest
    environment:
      DATABASE_URL: postgres://orders_db/orders
      KAFKA_BROKERS: kafka:9092

  redis:
    image: redis:7-alpine

  kafka:
    image: confluentinc/cp-kafka:7.5.0''',
                'maxLines': 22,
              }),
            ],
          ),
        ),
        DemoSection(
          label: 'Tech Stack',
          delayMs: 800,
          child: AgKeyValue(props: {
            'title': 'Runtime & Infrastructure',
            'items': [
              {'key': 'Runtime',   'value': 'Node.js 20 LTS'},
              {'key': 'Framework', 'value': 'Express + Fastify'},
              {'key': 'Database',  'value': 'PostgreSQL 16',        'highlight': true},
              {'key': 'Cache',     'value': 'Redis 7'},
              {'key': 'Messaging', 'value': 'Apache Kafka 3.6',     'highlight': true},
              {'key': 'Auth',      'value': 'JWT (RS256)'},
              {'key': 'Deploy',    'value': 'Kubernetes 1.29 / GKE'},
            ],
          }),
        ),
        DemoSection(
          label: 'Implementation Roadmap',
          delayMs: 800,
          child: AgTimeline(props: {
            'title': 'Q1 2025 Milestones',
            'events': [
              {'label': 'Auth service',     'time': 'Jan 8',  'status': 'success', 'note': 'JWT + Redis session store shipped'},
              {'label': 'Product catalogue','time': 'Jan 22', 'status': 'success', 'note': 'REST API + search + pagination'},
              {'label': 'Order service',    'time': 'Feb 5',  'status': 'success', 'note': 'Kafka event emission wired'},
              {'label': 'API Gateway',      'time': 'Feb 19', 'status': 'running', 'note': 'Rate-limiting & circuit-breaker in review'},
              {'label': 'Load testing',     'time': 'Mar 5',  'status': 'pending'},
              {'label': 'GA release',       'time': 'Mar 19', 'status': 'pending'},
            ],
          }),
        ),
      ],
    );
  }
}
