import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createForgeRuntime } from '../src/forge.mjs';

const analysis = {
  summary: '面向校园的开源地图工具', useCases: ['查找校园设施'],
  gettingStarted: ['阅读 README 后配置地图数据'], risks: ['请核对地图更新时间'],
  suggestedCategory: '校园工具', suggestedTags: ['地图', 'Flutter'],
};
const project = (id, owner = 'user1', extra = {}) => ({ id, owner, name: `Project ${id}`,
  summary: '校园代码', repositoryUrl: `https://github.com/demo/${id === 'repo1' ? 'one' : id}`,
  visibility: 'public', reviewState: 'approved', schoolVerified: true, universityId: 'ecnu', ...extra });
const ghRepo = (name, extra = {}) => ({ id: 123, private: false, full_name: name,
  name: name.split('/')[1], html_url: `https://github.com/${name}`, description: '项目简介',
  homepage: 'https://example.com/demo', language: 'Dart', topics: ['flutter', 'campus'],
  stargazers_count: 10, forks_count: 2, open_issues_count: 1, license: { spdx_id: 'MIT' },
  default_branch: 'main', archived: false, updated_at: '2026-10-20T01:00:00Z', ...extra });
const ghRelease = (id, extra = {}) => ({ id, tag_name: `v${id}`, name: `Version ${id}`,
  html_url: `https://github.com/demo/one/releases/tag/v${id}`, body: '版本说明',
  published_at: '2026-10-20T02:00:00Z', prerelease: false, draft: false, ...extra });

function fixture(config = {}) {
  const state = {
    requests: [], writes: [], reads: [], readOptions: [], busyUsers: new Set(), fetchOverride: null, pbOverride: null,
    modelContent: JSON.stringify(analysis),
    db: {
      forge_repositories: [project('repo1'), project('repo2', 'user2')],
      forge_bookmarks: [], forge_stars: [], forge_subscriptions: [], forge_release_events: [],
    },
  };
  async function pb(path, token, options = {}) {
    assert.equal(token, 'Bearer test-token');
    state.reads.push(path);
    state.readOptions.push({ path, options });
    const override = await state.pbOverride?.(path, options);
    if (override !== undefined) return override;
    const url = new URL(path, 'http://pocketbase.test');
    const [, collection, recordId] = /\/collections\/([^/]+)\/records(?:\/([^/]+))?$/.exec(url.pathname) || [];
    assert.ok(state.db[collection], path);
    const rows = state.db[collection];
    if (options.method === 'POST') {
      const row = { id: `created${state.writes.length + 1}`, ...structuredClone(options.body) };
      rows.push(row); state.writes.push({ collection, method: 'POST', body: structuredClone(options.body), id: row.id });
      return structuredClone(row);
    }
    if (recordId) {
      const row = rows.find((item) => item.id === recordId);
      if (!row) throw Object.assign(new Error('record missing'), { status: 404 });
      if (options.method === 'PATCH') {
        Object.assign(row, structuredClone(options.body));
        state.writes.push({ collection, method: 'PATCH', body: structuredClone(options.body), id: row.id });
      }
      return structuredClone(row);
    }
    const comparisons = [...(url.searchParams.get('filter') || '').matchAll(/([A-Za-z]+) = ("(?:[^"\\]|\\.)*")/g)]
      .map(([, field, value]) => [field, JSON.parse(value)]);
    const found = rows.filter((row) => comparisons.every(([field, value]) => row[field] === value));
    const page = Number(url.searchParams.get('page') || 1);
    const perPage = Number(url.searchParams.get('perPage') || 1);
    return structuredClone({ items: found.slice((page - 1) * perPage, page * perPage),
      totalItems: found.length, totalPages: Math.ceil(found.length / perPage), page, perPage });
  }
  async function fetcher(input, options) {
    const url = new URL(input);
    state.requests.push({ url, options });
    assert.ok(options.signal instanceof AbortSignal);
    const override = await state.fetchOverride?.(url, options);
    if (override !== undefined) return override;
    if (url.hostname === 'api.github.com') {
      assert.equal(options.method, 'GET');
      assert.equal(options.redirect, 'manual');
      assert.equal(options.headers['X-GitHub-Api-Version'], '2026-03-10');
      if (url.pathname === '/user/starred') return Response.json([ghRepo('demo/one')]);
      const match = /^\/repos\/([^/]+\/[^/]+)(\/readme|\/releases)?$/.exec(url.pathname);
      assert.ok(match, input);
      const [, name, suffix] = match;
      if (suffix === '/readme') return Response.json({ encoding: 'base64',
        content: Buffer.from('# README\n校园地图工具').toString('base64'), path: 'README.md',
        html_url: `https://github.com/${name}/blob/main/README.md` });
      if (suffix === '/releases') return Response.json([ghRelease(11), ghRelease(12, { prerelease: true }), ghRelease(13, { draft: true })]);
      return Response.json(ghRepo(name));
    }
    assert.ok(['chat.ecnu.edu.cn', 'api.deepseek.com', 'localhost'].includes(url.hostname), input);
    assert.equal(options.method, 'POST');
    assert.equal(url.pathname.endsWith('/chat/completions'), true);
    return Response.json({ choices: [{ finish_reason: 'stop', message: { content: state.modelContent } }] });
  }
  const runtime = createForgeRuntime({ pb, fetcher, config, busyUsers: state.busyUsers });
  return { state, runtime, call: (path, body = {}, userId = 'user1', method = 'POST') =>
    runtime.handle(`/v1/forge/${path}`, method, body, 'Bearer test-token', userId) };
}
const rejects = (promise, status) => assert.rejects(promise, (error) => error.status === status);

test('status reports provider configuration without exposing keys or claiming authentication', async () => {
  const { call, state, runtime } = fixture({ CHATECNU_API_KEY: 'server-secret', EDUCHAT_BASE_URL: 'http://localhost:9000/v1' });
  assert.equal(runtime.matches('/v1/forge/analyze'), true);
  assert.equal(runtime.matches('/v1/forge/unknown'), false);
  const status = await call('status', {}, 'user1', 'GET');
  assert.equal(status.contract, 'campulse-forge/v1');
  assert.deepEqual(status.providers.chatecnu, { configured: true, endpointConfigured: true, model: 'ecnu-plus' });
  assert.equal(status.providers.deepseek.model, 'deepseek-flash');
  assert.equal(status.providers.deepseek.configured, false);
  assert.equal(status.providers.educhat.endpointConfigured, true);
  assert.ok(!JSON.stringify(status).includes('server-secret'));
  assert.equal(state.requests.length + state.reads.length, 0);
  await rejects(call('status'), 405);
  await rejects(call('unknown'), 404);
});

test('GitHub metadata reads the bound public URL and saves only a personal snapshot', async () => {
  const { call, state } = fixture();
  state.db.forge_bookmarks.push({ id: 'bookmark1', owner: 'user1', repository: 'repo1',
    category: '手工分类', tags: ['保留'], note: '我的备注', analysis: { old: true } });
  const result = await call('github', { repositoryId: 'repo1', githubToken: 'personal-token', url: 'http://private.test' });
  assert.equal(result.metadata.repo.fullName, 'demo/one');
  assert.equal(result.metadata.repo.stars, 10);
  assert.match(result.metadata.readme.text, /校园地图工具/);
  assert.equal(result.metadata.releases.length, 2);
  assert.ok(state.requests.every(({ url, options }) => url.hostname === 'api.github.com' &&
    options.headers.Authorization === 'Bearer personal-token'));
  assert.deepEqual(state.writes[0].body, { githubMetadata: result.metadata });
  assert.equal(result.bookmark.category, '手工分类');
  assert.deepEqual(result.bookmark.tags, ['保留']);
  assert.deepEqual(result.bookmark.analysis, { old: true });
  assert.equal(JSON.stringify(state.writes).includes('personal-token'), false);
});

test('hidden campus projects and invalid bound URLs fail before any external request', async () => {
  const { call, state } = fixture();
  state.db.forge_repositories[1].reviewState = 'pending';
  await rejects(call('github', { repositoryId: 'repo2' }), 403);
  state.db.forge_repositories[0].repositoryUrl = 'https://github.com.evil.test/demo/one';
  await rejects(call('github', { repositoryId: 'repo1' }), 400);
  assert.equal(state.requests.length, 0);
  assert.equal(state.writes.length, 0);
});

test('a token does not turn a private GitHub repository into a shared project', async () => {
  const { call, state } = fixture();
  state.fetchOverride = (url) => url.pathname === '/repos/demo/one'
    ? Response.json(ghRepo('demo/one', { private: true })) : undefined;
  await rejects(call('github', { repositoryId: 'repo1', githubToken: 'personal-token' }), 403);
  assert.equal(state.requests.length, 1);
  assert.equal(state.writes.length, 0);
});

test('README absence and bounded large text remain explicit in metadata', async () => {
  const { call, state } = fixture();
  state.fetchOverride = (url) => url.pathname.endsWith('/readme') ? new Response('', { status: 404 }) : undefined;
  assert.equal((await call('github', { repositoryId: 'repo1' })).metadata.readme.text, '');
  state.fetchOverride = (url) => url.pathname.endsWith('/readme') ? Response.json({ encoding: 'base64',
    content: Buffer.from('大'.repeat(65000)).toString('base64'), path: 'README.md' }) : undefined;
  const result = await call('github', { repositoryId: 'repo1' });
  assert.equal(result.metadata.readme.text.length, 4000);
  assert.equal(result.metadata.readme.truncated, true);
});

test('persisted GitHub snapshots obey the UTF-8 field limit for large Chinese READMEs and releases', async () => {
  const { call, state } = fixture();
  state.fetchOverride = (url) => url.pathname.endsWith('/readme') ? Response.json({ encoding: 'base64',
    content: Buffer.from('大'.repeat(65000)).toString('base64'), path: 'README.md' })
    : url.pathname.endsWith('/releases') ? Response.json(Array.from({ length: 5 }, (_, i) => ghRelease(i + 1, { body: '版本'.repeat(9000) })))
      : url.pathname === '/repos/demo/one' ? Response.json(ghRepo('demo/one', { topics: Array(30).fill('长'.repeat(100)) })) : undefined;
  const result = await call('github', { repositoryId: 'repo1' });
  assert.ok(Buffer.byteLength(JSON.stringify(result.bookmark.githubMetadata), 'utf8') <= 32768);
  assert.equal(result.metadata.readme.truncated, true);
  assert.equal(result.metadata.releases.every((entry) => entry.bodyTruncated), true);
  assert.equal(result.metadata.readme.path, 'README.md');
});

test('GitHub rate limit and redirects provide bounded failures and release the user lock', async () => {
  const { call, state } = fixture();
  state.fetchOverride = () => Response.json({ message: 'API rate limit exceeded' },
    { status: 403, headers: { 'retry-after': '47' } });
  await assert.rejects(call('github', { repositoryId: 'repo1' }), (error) => {
    assert.equal(error.status, 429); assert.equal(error.retryAfter, 47); assert.match(error.message, /47 秒/); return true;
  });
  assert.equal(state.busyUsers.size, 0);
  state.fetchOverride = () => new Response('', { status: 301, headers: { location: 'http://internal.test' } });
  await rejects(call('github', { repositoryId: 'repo1' }), 502);
  assert.ok(state.requests.every(({ url }) => url.hostname === 'api.github.com'));
});

test('GitHub Stars is personal, paged and excludes private repositories', async () => {
  const { call, state } = fixture({ GITHUB_TOKEN: 'server-github-token' });
  await rejects(call('github/stars'), 400);
  state.fetchOverride = () => Response.json([ghRepo('demo/one'), ghRepo('demo/secret', { private: true })],
    { headers: { link: '<https://api.github.com/user/starred?per_page=20&page=3>; rel="next"' } });
  const result = await call('github/stars', { githubToken: 'my-github-token', page: 2 });
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].fullName, 'demo/one');
  assert.equal(result.nextPage, 3);
  assert.equal(state.requests[0].url.searchParams.get('per_page'), '20');
  assert.equal(state.requests[0].url.searchParams.get('page'), '2');
  assert.equal(state.requests[0].options.headers.Authorization, 'Bearer my-github-token');
  assert.equal(state.writes.length, 0);
});

test('GitHub import creates a private unverified draft and is idempotent without overwriting author content', async () => {
  const { call, state } = fixture();
  const first = await call('github/import', { fullName: 'demo/imported' });
  assert.equal(first.imported, true);
  assert.equal(first.project.owner, 'user1');
  assert.equal(first.project.visibility, 'private');
  assert.equal(first.project.reviewState, 'draft');
  assert.equal(first.project.schoolVerified, false);
  assert.equal(first.project.universityId, 'ecnu');
  assert.equal(state.db.forge_stars[0].repository, first.project.id);
  state.db.forge_repositories.find((row) => row.id === first.project.id).readme = '作者后来写的说明';
  const second = await call('github/import', { fullName: 'demo/imported' });
  assert.equal(second.imported, false);
  assert.equal(second.project.id, first.project.id);
  assert.equal(second.project.readme, '作者后来写的说明');
  assert.equal(state.db.forge_stars.length, 1);
  assert.equal(state.db.forge_bookmarks.length, 1);
  assert.equal(state.requests.every(({ options }) => options.method === 'GET'), true);
});

test('import recognizes existing owner projects with trailing slash or clone URL suffixes', async () => {
  const { call, state } = fixture();
  state.db.forge_repositories[0].repositoryUrl = 'https://github.com/demo/one.git/';
  const result = await call('github/import', { fullName: 'demo/one' });
  assert.equal(result.imported, false);
  assert.equal(result.project.id, 'repo1');
  assert.equal(state.db.forge_repositories.length, 2);
});

test('import matches GitHub names case-insensitively across owner pages without selecting a prefix repository', async () => {
  const { call, state } = fixture();
  state.db.forge_repositories = [
    project('prefix', 'user1', { repositoryUrl: 'https://github.com/demo/one-extra' }),
    ...Array.from({ length: 99 }, (_, index) => project(`old${index}`, 'user1', { repositoryUrl: '' })),
    project('ownMatch', 'user1', { repositoryUrl: 'https://github.com/DEMO/ONE.git/', readme: '用户自己的原文' }),
    project('foreign', 'user2', { repositoryUrl: 'https://github.com/demo/one' }),
  ];
  const result = await call('github/import', { fullName: 'demo/one' });
  assert.equal(result.imported, false);
  assert.equal(result.project.id, 'ownMatch');
  assert.equal(result.project.readme, '用户自己的原文');
  assert.equal(state.db.forge_repositories.length, 102);
  const pages = state.reads.filter((path) => path.startsWith('/api/collections/forge_repositories/records?'))
    .map((path) => new URL(path, 'http://pb.test').searchParams);
  assert.deepEqual(pages.map((params) => params.get('page')), ['1', '2']);
  assert.ok(pages.every((params) => params.get('fields') === 'id,owner,repositoryUrl'));
  assert.equal(state.db.forge_stars[0].repository, 'ownMatch');
});

test('analysis validates JSON, records provenance and keeps manual bookmark fields unchanged', async () => {
  const { call, state } = fixture({ CHATECNU_API_KEY: 'server-ai-token' });
  state.db.forge_bookmarks.push({ id: 'bookmark1', owner: 'user1', repository: 'repo1',
    category: '手工分类', tags: ['保留'], note: '手动备注' });
  state.db.forge_repositories[0].readme = '作者补充的校园部署方法';
  const result = await call('analyze', { repositoryId: 'repo1', apiKey: 'personal-ai-token' });
  assert.equal(result.analysis.summary, analysis.summary);
  assert.equal(result.analysis.source.provider, 'chatecnu');
  assert.equal(result.analysis.source.model, 'ecnu-plus');
  assert.equal(result.analysis.source.githubRepository, 'demo/one');
  assert.ok(isoDate(result.analysis.source.analyzedAt));
  const request = state.requests.find(({ url }) => url.hostname === 'chat.ecnu.edu.cn');
  assert.equal(request.url.href, 'https://chat.ecnu.edu.cn/open/api/v1/chat/completions');
  assert.equal(request.options.headers.Authorization, 'Bearer personal-ai-token');
  assert.match(JSON.parse(request.options.body).messages[1].content, /README/);
  const input = JSON.parse(JSON.parse(request.options.body).messages[1].content);
  assert.equal(input.campusProject.readme, '作者补充的校园部署方法');
  assert.match(input.githubReadme, /校园地图工具/);
  assert.equal(result.bookmark.category, '手工分类');
  assert.deepEqual(result.bookmark.tags, ['保留']);
  assert.equal(result.bookmark.note, '手动备注');
  assert.equal(result.bookmark.analysisAt, result.analysis.source.analyzedAt);
  assert.equal(JSON.stringify(state.writes).includes('personal-ai-token'), false);
  assert.equal(state.writes.every((write) => write.collection === 'forge_bookmarks'), true);
});

test('native Campulse project analysis uses its own README without a GitHub binding or request', async () => {
  const { call, state } = fixture({ CHATECNU_API_KEY: 'server-ai-token' });
  Object.assign(state.db.forge_repositories[0], { repositoryUrl: '', readme: '# 校园项目\n自己的使用方法', topics: '校园 工具' });
  state.db.forge_bookmarks.push({ id: 'bookmark1', owner: 'user1', repository: 'repo1',
    category: '手工分类', tags: ['保留'], note: '个人备注', githubMetadata: { previous: true } });
  const result = await call('analyze', { repositoryId: 'repo1' });
  assert.equal(result.analysis.source.contentSource, 'campulse');
  assert.equal(result.analysis.source.repositoryId, 'repo1');
  assert.equal(Object.hasOwn(result.analysis.source, 'githubRepository'), false);
  assert.deepEqual(result.bookmark.githubMetadata, { previous: true });
  assert.equal(result.bookmark.note, '个人备注');
  assert.equal(state.requests.length, 1);
  const input = JSON.parse(JSON.parse(state.requests[0].options.body).messages[1].content);
  assert.equal(input.campusProject.readme, '# 校园项目\n自己的使用方法');
  assert.equal(input.campusProject.topics, '校园 工具');
  assert.equal(Object.hasOwn(input, 'github'), false);
});
const isoDate = (value) => Number.isFinite(Date.parse(value));

test('DeepSeek uses its current default and EduChat requires an operator-managed endpoint', async () => {
  const { call, state } = fixture({ DEEPSEEK_API_KEY: 'deepseek-server' });
  const deepseek = await call('analyze', { repositoryId: 'repo1', provider: 'deepseek' });
  assert.equal(deepseek.analysis.source.model, 'deepseek-flash');
  const request = state.requests.find(({ url }) => url.hostname === 'api.deepseek.com');
  const body = JSON.parse(request.options.body);
  assert.deepEqual(body.thinking, { type: 'disabled' });
  assert.deepEqual(body.response_format, { type: 'json_object' });
  assert.equal(body.max_tokens, 3500);
  await rejects(call('analyze', { repositoryId: 'repo1', provider: 'educhat', apiKey: 'personal' }), 503);
  const local = fixture({ EDUCHAT_BASE_URL: 'http://localhost:9000/v1', EDUCHAT_MODEL: 'educhat-local' });
  const result = await local.call('analyze', { repositoryId: 'repo1', provider: 'educhat' });
  assert.equal(result.analysis.source.model, 'educhat-local');
  const eduRequest = local.state.requests.find(({ url }) => url.hostname === 'localhost');
  assert.equal(eduRequest.options.headers.Authorization, undefined);
  assert.equal(JSON.parse(eduRequest.options.body).thinking, undefined);
});

test('invalid or truncated AI output is rejected before any bookmark write', async () => {
  const { call, state } = fixture({ CHATECNU_API_KEY: 'test-key' });
  for (const raw of ['not-json', JSON.stringify({ ...analysis, suggestedTags: ['a'.repeat(61)] }),
    JSON.stringify({ ...analysis, useCases: Array(9).fill('过多条目') })]) {
    state.modelContent = raw;
    await rejects(call('analyze', { repositoryId: 'repo1' }), 502);
  }
  state.fetchOverride = (url) => url.hostname === 'chat.ecnu.edu.cn' ? Response.json({
    choices: [{ finish_reason: 'length', message: { content: JSON.stringify(analysis) } }],
  }) : undefined;
  await rejects(call('analyze', { repositoryId: 'repo1' }), 502);
  assert.equal(state.writes.length, 0);
});

test('AI result limits include provenance and count UTF-8 bytes rather than characters', async () => {
  const { call, state } = fixture({ CHATECNU_API_KEY: 'test-key' });
  state.modelContent = JSON.stringify({ ...analysis, summary: '中'.repeat(2000),
    useCases: Array(8).fill(null).map((_, i) => `${i}${'中'.repeat(998)}`),
    gettingStarted: Array(8).fill(null).map((_, i) => `${i}${'文'.repeat(998)}`),
    risks: Array(8).fill(null).map((_, i) => `${i}${'字'.repeat(998)}`) });
  assert.ok(state.modelContent.length < 40000);
  await rejects(call('analyze', { repositoryId: 'repo1' }), 502);
  assert.equal(state.writes.length, 0);
});

test('a model check performs a real mock transport call and stores nothing', async () => {
  const { call, state } = fixture({ CHATECNU_API_KEY: 'test-key' });
  state.modelContent = '{"ok":true}';
  assert.deepEqual(await call('check'), { ok: true, provider: 'chatecnu', model: 'ecnu-plus' });
  assert.equal(state.requests.length, 1);
  assert.equal(state.requests[0].url.hostname, 'chat.ecnu.edu.cn');
  assert.equal(state.reads.length + state.writes.length, 0);
});

test('release refresh deduplicates events, preserves read status and updates only successful subscriptions', async () => {
  const { call, state } = fixture();
  state.db.forge_subscriptions.push(
    { id: 'sub1', owner: 'user1', repository: 'repo1', includePrereleases: false },
    { id: 'sub2', owner: 'user1', repository: 'repo2', includePrereleases: true },
    { id: 'otherSub', owner: 'user2', repository: 'repo1' },
  );
  state.fetchOverride = (url) => url.pathname.startsWith('/repos/demo/repo2')
    ? Response.json({ message: 'rate limit' }, { status: 429, headers: { 'retry-after': '30' } }) : undefined;
  const first = await call('releases/refresh');
  assert.equal(first.checked, 1);
  assert.equal(first.created, 1);
  assert.equal(first.errors[0].repositoryId, 'repo2');
  assert.equal(first.errors[0].retryAfter, 30);
  assert.equal(first.results[1].checkedAt, undefined);
  assert.ok(isoDate(first.checkedAt));
  assert.ok(isoDate(state.db.forge_subscriptions[0].lastCheckedAt));
  assert.equal(state.db.forge_subscriptions[1].lastCheckedAt, undefined);
  assert.equal(state.db.forge_subscriptions[2].lastCheckedAt, undefined);
  state.db.forge_release_events[0].read = true;
  const second = await call('releases/refresh', { repositoryId: 'repo1' });
  assert.equal(second.created, 0);
  assert.equal(state.db.forge_release_events.length, 1);
  assert.equal(state.db.forge_release_events[0].read, true);
  assert.equal(state.db.forge_release_events[0].externalId, '11');
  assert.equal(state.db.forge_release_events[0].publishedAt, '2026-10-20T02:00:00.000Z');
});

test('a revoked project yields a per-project failure without reading GitHub or creating events', async () => {
  const { call, state } = fixture();
  state.db.forge_repositories[1].visibility = 'private';
  state.db.forge_subscriptions.push({ id: 'sub1', owner: 'user1', repository: 'repo2' });
  const result = await call('releases/refresh');
  assert.equal(result.checked, 0);
  assert.equal(result.errors.length, 1);
  assert.equal(state.requests.length, 0);
  assert.equal(state.writes.length, 0);
});

test('foreign bookmarks and subscription rows are rejected even if a PB filter is ignored', async () => {
  const { call, state } = fixture();
  state.pbOverride = (path) => path.includes('/forge_bookmarks/records?')
    ? { items: [{ id: 'evil', owner: 'user2', repository: 'repo1' }] } : undefined;
  await rejects(call('github', { repositoryId: 'repo1' }), 403);
  state.pbOverride = (path) => path.includes('/forge_subscriptions/records?')
    ? { items: [{ id: 'evil', owner: 'user2', repository: 'repo1' }] } : undefined;
  await rejects(call('releases/refresh'), 403);
  assert.equal(state.writes.length, 0);
});

test('subscription refresh is stably paged and includes prereleases only when selected', async () => {
  const { call, state } = fixture();
  state.db.forge_subscriptions = Array.from({ length: 21 }, (_, index) => {
    const repository = `paged${index}`;
    state.db.forge_repositories.push(project(repository));
    return { id: `sub${index}`, owner: 'user1', repository, includePrereleases: true };
  });
  const result = await call('releases/refresh');
  assert.equal(result.checked, 20);
  assert.equal(result.created, 40);
  assert.equal(result.nextPage, 2);
  assert.equal((await call('releases/refresh', { page: 2 })).nextPage, null);
  assert.equal(state.db.forge_release_events.length, 42);
});

test('a partial event write can be retried without duplicating earlier events or advancing failed check time', async () => {
  const { call, state } = fixture();
  state.db.forge_subscriptions.push({ id: 'sub1', owner: 'user1', repository: 'repo1', includePrereleases: true });
  state.pbOverride = (path, options) => {
    if (path.endsWith('/forge_release_events/records') && options.method === 'POST' && options.body.externalId === '12') {
      throw Object.assign(new Error('event save failed'), { status: 502 });
    }
    return undefined;
  };
  const first = await call('releases/refresh');
  assert.equal(first.created, 1);
  assert.equal(first.errors.length, 1);
  assert.equal(state.db.forge_subscriptions[0].lastCheckedAt, undefined);
  state.db.forge_release_events[0].read = true;
  state.pbOverride = null;
  const second = await call('releases/refresh');
  assert.equal(second.created, 1);
  assert.equal(second.errors.length, 0);
  assert.equal(state.db.forge_release_events.length, 2);
  assert.equal(state.db.forge_release_events[0].read, true);
  assert.ok(isoDate(state.db.forge_subscriptions[0].lastCheckedAt));
});

test('release deadline reaches PB lookup and stops all later writes and check timestamps', async (t) => {
  const { call, state } = fixture();
  const controller = new AbortController();
  const timeout = AbortSignal.timeout;
  t.mock.method(AbortSignal, 'timeout', (ms) => ms === 35000 ? controller.signal : timeout(ms));
  state.db.forge_subscriptions.push({ id: 'sub1', owner: 'user1', repository: 'repo1' });
  state.pbOverride = (path, options) => {
    assert.equal(options.signal, controller.signal);
    if (path.includes('/forge_release_events/records?')) controller.abort();
    return undefined;
  };
  const result = await call('releases/refresh');
  assert.equal(result.checked, 0);
  assert.equal(result.errors.length, 1);
  assert.equal(state.db.forge_release_events.length, 0);
  assert.equal(state.db.forge_subscriptions[0].lastCheckedAt, undefined);
  assert.equal(state.writes.length, 0);
  assert.equal(state.busyUsers.size, 0);
});

test('deadline after an acknowledged event write preserves its count but starts no further PB operation', async (t) => {
  const { call, state } = fixture();
  const controller = new AbortController();
  const timeout = AbortSignal.timeout;
  t.mock.method(AbortSignal, 'timeout', (ms) => ms === 35000 ? controller.signal : timeout(ms));
  state.db.forge_subscriptions.push({ id: 'sub1', owner: 'user1', repository: 'repo1', includePrereleases: true });
  state.pbOverride = (path, options) => {
    assert.equal(options.signal, controller.signal);
    if (path.endsWith('/forge_release_events/records') && options.method === 'POST') {
      const row = { id: 'committed1', ...options.body };
      state.db.forge_release_events.push(row);
      state.writes.push({ collection: 'forge_release_events', method: 'POST', body: options.body });
      controller.abort();
      return row;
    }
    return undefined;
  };
  const result = await call('releases/refresh');
  assert.equal(result.created, 1);
  assert.equal(result.errors.length, 1);
  assert.equal(state.db.forge_release_events.length, 1);
  assert.equal(state.writes.length, 1);
  assert.equal(state.reads.at(-1), '/api/collections/forge_release_events/records');
  assert.equal(state.db.forge_subscriptions[0].lastCheckedAt, undefined);
  assert.equal(state.busyUsers.size, 0);
});

test('aborted initial PB subscription load maps to a timeout and releases the shared lock', async (t) => {
  const { call, state } = fixture();
  const controller = new AbortController();
  const timeout = AbortSignal.timeout;
  t.mock.method(AbortSignal, 'timeout', (ms) => ms === 35000 ? controller.signal : timeout(ms));
  state.pbOverride = () => {
    controller.abort();
    throw Object.assign(new Error('aborted PB read'), { name: 'AbortError' });
  };
  await rejects(call('releases/refresh'), 504);
  assert.equal(state.writes.length, 0);
  assert.equal(state.busyUsers.size, 0);
});

test('shared busyUsers excludes duplicate and global third operations, then releases on failure', async () => {
  const { call, state } = fixture();
  state.busyUsers.add('user1');
  await rejects(call('github', { repositoryId: 'repo1' }), 429);
  state.busyUsers.clear(); state.busyUsers.add('user2'); state.busyUsers.add('user3');
  await rejects(call('github', { repositoryId: 'repo1' }), 429);
  state.busyUsers.clear();
  state.fetchOverride = () => { throw Object.assign(new Error('transport'), { name: 'TimeoutError' }); };
  await rejects(call('github', { repositoryId: 'repo1' }), 504);
  assert.equal(state.busyUsers.size, 0);
  assert.equal(state.writes.length, 0);
});

test('request and model configuration validation happens before remote or persistent mutations', async () => {
  const { call, state } = fixture({ EDUCHAT_BASE_URL: 'http://remote.test/v1' });
  await rejects(call('github', { repositoryId: '../wrong' }), 400);
  await rejects(call('github/import', { fullName: '../private' }), 400);
  await rejects(call('github/stars', { githubToken: 'key\nheader' }), 400);
  await rejects(call('analyze', { repositoryId: 'repo1', provider: 'other' }), 400);
  await rejects(call('check', { provider: 'educhat' }), 503);
  await rejects(call('github', []), 400);
  assert.equal(state.requests.length, 0);
  assert.equal(state.writes.length, 0);
});
