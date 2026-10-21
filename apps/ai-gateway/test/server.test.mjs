import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { afterEach, test } from 'node:test';
import { createHandler } from '../src/server.mjs';
import { eduworkRevision, evidenceFromPages, rankEvidence, validateArtifact } from '../src/notebook.mjs';
import { requestLocal as fetch } from './local-http.mjs';

const servers = [];
afterEach(async () => {
  for (const server of servers.splice(0)) await new Promise((done) => server.close(done));
});

async function serve(config, fetcher) {
  const server = createServer(createHandler(config, fetcher));
  servers.push(server);
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  return `http://127.0.0.1:${server.address().port}`;
}

const config = {
  POCKETBASE_URL: 'http://127.0.0.1:8090',
  CHATECNU_API_KEY: 'test-only-key',
};

test('forge routes enforce ordinary account authentication before provider or database requests', async () => {
  let calls = 0;
  const base = await serve(config, async (url) => {
    calls++;
    assert.ok(url.endsWith('/auth-refresh'));
    return Response.json({ record: { id: 'user123', verified: false } });
  });
  for (const path of ['status', 'github', 'github/stars', 'github/import', 'releases/refresh', 'analyze', 'check']) {
    const method = path === 'status' ? 'GET' : 'POST';
    assert.equal((await fetch(`${base}/v1/forge/${path}`, {method})).status, 401);
    assert.equal((await fetch(`${base}/v1/forge/${path}`, {method, headers: {Authorization: 'Bearer test-user'}})).status, 403);
  }
  assert.equal(calls, 7);
});

test('forge status is wired for verified accounts and keeps server credentials private', async () => {
  const base = await serve(config, async () => Response.json({record: {id: 'user123', verified: true}}));
  const response = await fetch(`${base}/v1/forge/status`, {headers: {Authorization: 'Bearer test-user'}});
  assert.equal(response.status, 200);
  const data = await response.json();
  assert.equal(data.providers.chatecnu.configured, true);
  assert.equal(data.providers.deepseek.model, 'deepseek-flash');
  assert.equal(data.providers.educhat.endpointConfigured, false);
  assert.ok(!JSON.stringify(data).includes('test-only-key'));
});

test('forge model check calls the selected provider through the authenticated server route', async () => {
  const base = await serve(config, async (url, options) => {
    if (url.endsWith('/auth-refresh')) return Response.json({record: {id: 'user123', verified: true}});
    assert.equal(url, 'https://api.deepseek.com/chat/completions');
    assert.equal(options.headers.Authorization, 'Bearer per-request-fixture');
    return Response.json({choices: [{message: {content: '{"ok":true}'}, finish_reason: 'stop'}]});
  });
  const response = await fetch(`${base}/v1/forge/check`, {method: 'POST', headers: {Authorization: 'Bearer test-user', 'Content-Type': 'application/json'}, body: JSON.stringify({provider: 'deepseek', apiKey: 'per-request-fixture'})});
  assert.equal(response.status, 200);
  assert.equal((await response.json()).ok, true);
});

test('model transport failures return actionable errors without leaking credentials', async () => {
  for (const [name, status, message] of [['TimeoutError',504,'模型响应超时'], ['TypeError',502,'模型连接失败']]) {
    const base = await serve(config, async (url) => {
      if (url.endsWith('/auth-refresh')) return Response.json({record:{id:'user1',verified:true}});
      if (url.includes('/course_notes/records/')) return Response.json({owner:'user1',courseId:'c1',title:'教材',content:'知识点'});
      throw Object.assign(new Error('private transport message'),{name});
    });
    const response = await fetch(`${base}/v1/ask`,{method:'POST',headers:{Authorization:'Bearer token','Content-Type':'application/json'},body:JSON.stringify({courseId:'c1',sourceIds:['note:n1'],question:'问题'})});
    assert.equal(response.status,status);
    const body = await response.text();
    assert.ok(body.includes(message));
    assert.ok(!body.includes('test-only-key') && !body.includes('private transport message'));
  }
});

test('status requires a verified ordinary user and reports the headless integration', async () => {
  const base = await serve(config, async (url, options) => {
    assert.equal(options.headers.Authorization, 'user-token');
    if (!url.endsWith('/auth-refresh')) return Response.json({ items: [] });
    return Response.json({ record: { id: 'user123', verified: true } });
  });
  const denied = await fetch(`${base}/v1/status`);
  assert.equal(denied.status, 401);
  const ok = await fetch(`${base}/v1/status`, {
    headers: { Authorization: 'Bearer user-token' },
  });
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), {
    contract: 'campus-eduwork-gateway/v1',
    ready: true,
    aiReady: true,
    eduworkRevision,
    integration: 'campulse-headless',
    capabilities: ['search', 'citations', 'chat', 'quiz', 'flashcards', 'mindmap', 'agents'],
  });
});

test('ask reads only the current user course note and calls ChatECNU server-side', async () => {
  let modelCalls = 0;
  const base = await serve(config, async (url, options) => {
    if (url.endsWith('/auth-refresh')) {
      return Response.json({ record: { id: 'user123', verified: true } });
    }
    if (url.includes('/course_notes/records/')) {
      assert.equal(options.headers.Authorization, 'user-token');
      return Response.json({ owner: 'user123', courseId: 'course1', title: '我的笔记', content: '牛顿定律' });
    }
    modelCalls++;
    assert.equal(url, 'https://chat.ecnu.edu.cn/open/api/v1/chat/completions');
    assert.equal(options.headers.Authorization, 'Bearer test-only-key');
    assert.match(JSON.parse(options.body).messages[1].content, /牛顿定律/);
    return Response.json({ choices: [{ message: { content: '根据资料[1]...' } }] });
  });
  const result = await fetch(`${base}/v1/ask`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ courseId: 'course1', question: '是什么？', sourceIds: ['note:note123'] }),
  });
  assert.equal(result.status, 200);
  assert.equal((await result.json()).answer, '根据资料[1]...');
  assert.equal(modelCalls, 1);
});

test('cross-course source is rejected before model invocation', async () => {
  let modelCalls = 0;
  const base = await serve(config, async (url) => {
    if (url.endsWith('/auth-refresh')) return Response.json({ record: { id: 'user123', verified: true } });
    if (url.includes('/course_notes/records/')) {
      return Response.json({ owner: 'other-user', courseId: 'course1', content: 'secret' });
    }
    modelCalls++;
    throw new Error('model should not be called');
  });
  const result = await fetch(`${base}/v1/ask`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ courseId: 'course1', question: '问题', sourceIds: ['note:note123'] }),
  });
  assert.equal(result.status, 403);
  assert.equal(modelCalls, 0);
});

test('review schedules a card with FSRS and writes the next due date to PocketBase', async () => {
  let updated;
  const base = await serve(config, async (url, options) => {
    if (url.endsWith('/auth-refresh')) return Response.json({ record: { id: 'user123', verified: true } });
    if (url.includes('/course_review_cards/records/')) {
      if (options.method === 'PATCH') {
        updated = JSON.parse(options.body);
        return Response.json({ id: 'abc123def456ghi', owner: 'user123',
          courseId: 'course1', front: '问题', back: '答案', ...updated });
      }
      return Response.json({ id: 'abc123def456ghi', owner: 'user123',
        courseId: 'course1', front: '问题', back: '答案', scheduler: {} });
    }
    throw new Error(`unexpected request ${url}`);
  });
  const result = await fetch(`${base}/v1/cards/abc123def456ghi/review`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ rating: 3 }),
  });
  assert.equal(result.status, 200);
  assert.ok(updated.scheduler.reps >= 1);
  assert.ok(Date.parse(updated.due) > 0);
  assert.equal(updated.reviewHistory.length, 1);
});

test('review rejects invalid rating and another owner before writing', async () => {
  let writes = 0;
  const base = await serve(config, async (url, options) => {
    if (url.endsWith('/auth-refresh')) return Response.json({ record: { id: 'user123', verified: true } });
    if (options.method === 'PATCH') writes++;
    return Response.json({ id: 'abc123def456ghi', owner: 'someone-else', scheduler: {} });
  });
  const headers = { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' };
  const invalid = await fetch(`${base}/v1/cards/abc123def456ghi/review`, {
    method: 'POST', headers, body: JSON.stringify({ rating: 5 }),
  });
  assert.equal(invalid.status, 400);
  const forbidden = await fetch(`${base}/v1/cards/abc123def456ghi/review`, {
    method: 'POST', headers, body: JSON.stringify({ rating: 3 }),
  });
  assert.equal(forbidden.status, 403);
  assert.equal(writes, 0);
});
