import { createServer, request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2' };

// Local-only proxy keeps authentication and AI on the same origin as the web client.
export function createWebDevServer({ root = 'apps/mobile/build/web', upstream = 'https://campus.allezafrique.cn' } = {}) {
  const base = new URL(upstream);
  if (!['https:', 'http:'].includes(base.protocol) || base.username || base.password || base.pathname !== '/') {
    throw new Error('Use an HTTP(S) upstream origin without credentials or a path');
  }
  const directory = resolve(root);
  return createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      const origin = req.headers.origin;
      const localOrigin = origin && /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(origin);
      if (localOrigin) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
        if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
      }
      if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/ai/')) {
        const target = new URL(url.pathname + url.search, base);
        const headers = { ...req.headers, host: target.host };
        delete headers.origin;
        delete headers.referer;
        const proxy = (base.protocol === 'https:' ? httpsRequest : httpRequest)(target, {
          method: req.method, headers, timeout: 120000,
        }, remote => { res.writeHead(remote.statusCode, { ...remote.headers, 'cache-control': 'no-store' }); remote.pipe(res); });
        proxy.on('timeout', () => proxy.destroy(new Error('Upstream timeout')));
        proxy.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end('Backend connection failed'); });
        req.on('aborted', () => proxy.destroy());
        req.pipe(proxy);
        return;
      }
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return; }
      if (url.pathname === '/' || url.pathname === '/app') { res.writeHead(302, { Location: '/app/' }); res.end(); return; }
      if (!url.pathname.startsWith('/app/')) { res.writeHead(404); res.end(); return; }
      const relative = decodeURIComponent(url.pathname.slice(5)) || 'index.html';
      const file = resolve(directory, relative);
      if (!file.startsWith(directory + sep)) { res.writeHead(403); res.end(); return; }
      const info = await stat(file);
      if (!info.isFile()) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream',
        'Content-Length': info.size, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      if (req.method === 'HEAD') { res.end(); return; }
      createReadStream(file).on('error', () => res.destroy()).pipe(res);
    } catch { if (!res.headersSent) res.writeHead(404); res.end(); }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.CAMPULSE_WEB_PORT || 5027);
  createWebDevServer({ root: process.env.CAMPULSE_WEB_ROOT, upstream: process.env.CAMPULSE_WEB_UPSTREAM })
    .listen(port, '127.0.0.1', () => console.log(`Campulse web: http://127.0.0.1:${port}/app/`));
}
