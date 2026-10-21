import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { createWebDevServer } from './serve-web.mjs';
import { requestLocal as fetch } from '../apps/ai-gateway/test/local-http.mjs';

test('web server redirects, serves only build files and forwards authenticated API requests', async t => {
  let received;
  const upstream = createServer((req, res) => {
    received = { path: req.url, auth: req.headers.authorization, method: req.method };
    res.setHeader('Content-Type', 'application/json'); res.end('{"ok":true}');
  }).listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const server = createWebDevServer({ root: 'apps/mobile/web', upstream: `http://127.0.0.1:${upstream.address().port}` }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); upstream.closeAllConnections(); server.close(); upstream.close(); });
  const url = `http://127.0.0.1:${server.address().port}`;
  const redirect = await fetch(url, { redirect: 'manual' });
  assert.equal(redirect.headers.get('location'), '/app/');
  const index = await fetch(`${url}/app/`);
  assert.match(await index.text(), /Campulse/); assert.equal(index.headers.get('cache-control'), 'no-store');
  assert.equal((await fetch(`${url}/app/missing.js`)).status, 404);
  assert.equal((await fetch(`${url}/password.env`)).status, 404);
  assert.equal((await fetch(`${url}/app/%2e%2e%2fpackage.json`)).status, 403);
  assert.equal((await fetch(`${url}/app/index.html`, { method: 'POST' })).status, 405);
  const api = await fetch(`${url}/ai/v1/ask?q=1`, { method: 'POST', headers: { Authorization: 'Bearer test-token' }, body: '{}' });
  assert.equal(api.status, 200);
  assert.deepEqual(received, { path: '/ai/v1/ask?q=1', auth: 'Bearer test-token', method: 'POST' });
  const preflight = await fetch(`${url}/ai/v1/ask`, { method: 'OPTIONS', headers: { Origin: 'http://localhost:5030' } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:5030');
  const remoteOrigin = await fetch(`${url}/ai/v1/status`, { headers: { Origin: 'https://example.com' } });
  assert.equal(remoteOrigin.headers.get('access-control-allow-origin'), null);
});

test('web proxy requires a fixed credential-free upstream origin', () => {
  assert.throws(() => createWebDevServer({ upstream: 'https://user:password@example.com' }));
  assert.throws(() => createWebDevServer({ upstream: 'file:///tmp' }));
});
