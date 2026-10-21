import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AdminClient, appPayload, ownerFilter, workspaceSummary, workspaceFilter, sections, collections, workspaceViews, editableFields, isMultilineField, searchFilter } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';

const recordId = '0123456789abcde';

for (const [view, collection] of [
  ['projectCategories', 'forge_categories'],
  ['projectBookmarks', 'forge_bookmarks'],
  ['releaseSubscriptions', 'forge_subscriptions'],
  ['releaseEvents', 'forge_release_events'],
]) {
  test(`${view} requires an owner and preserves the private collection filter`, async () => {
    assert.equal(workspaceViews[view].collection, collection);
    assert.ok(collections[collection]);
    assert.equal(workspaceFilter(view, recordId), ownerFilter(recordId));
    assert.throws(() => workspaceFilter(view));
    assert.throws(() => workspaceFilter(view, '" || true'));
    let requested;
    const client = new AdminClient('', async url => { requested = url; return Response.json({ items: [] }); });
    await client.list(collection, { view, owner: recordId, page: 2 });
    const url = new URL(requested, 'https://example.test');
    assert.equal(url.pathname, `/api/collections/${collection}/records`);
    assert.equal(url.searchParams.get('filter'), ownerFilter(recordId));
    assert.equal(url.searchParams.get('page'), '2');
    assert.equal(url.searchParams.get('expand'), 'owner');
    await assert.rejects(client.list(collection, { view }));
  });
}

test('private library JSON fields remain editable arrays and objects', async () => {
  const fields = ['tags', 'analysis', 'githubMetadata', 'payload'].map(name => ({ name, type: 'json' }));
  assert.deepEqual(editableFields({ fields }).map(field => field.name), fields.map(field => field.name));
  for (const field of fields) assert.equal(isMultilineField(field), true);
  const writes = [];
  const client = new AdminClient('', async (url, options) => {
    const body = JSON.parse(options.body);
    writes.push({ url, body });
    return Response.json({ id: recordId, ...body });
  });
  const bookmark = { owner: recordId, repository: '123456789abcdef', tags: ['Flutter', '校园工具'], note: '个人备注\n继续整理', analysis: { summary: 'README 摘要', recommendations: ['使用文档'] }, githubMetadata: { language: 'Dart', topics: ['campus'], archived: false } };
  const saved = await client.saveRecord('forge_bookmarks', bookmark, recordId);
  assert.deepEqual(writes[0].body, bookmark);
  assert.deepEqual(saved.tags, bookmark.tags);
  assert.deepEqual(saved.analysis, bookmark.analysis);
  assert.deepEqual(saved.githubMetadata, bookmark.githubMetadata);
  const event = { owner: recordId, repository: '123456789abcdef', subscription: '123456789abcdeg', externalId: 'release-1', payload: { tag: 'v1.0', body: '# 更新\n详细说明', assets: [{ name: 'app.apk', url: 'https://example.test/app.apk' }] }, read: true };
  const release = await client.saveRecord('forge_release_events', event);
  assert.deepEqual(writes[1].body, event);
  assert.deepEqual(release.payload, event.payload);
  const source = readFileSync(new URL('../deploy/pocketbase/pb_public/assets/admin.mjs', import.meta.url), 'utf8');
  assert.match(source, /tags: name === 'forge_bookmarks' \? \[\]/);
  assert.match(source, /JSON\.parse\(input\.value\)/);
});

test('private library navigation groups distinct actions under campus projects', () => {
  const source = readFileSync(new URL('../deploy/pocketbase/pb_public/assets/admin.mjs', import.meta.url), 'utf8');
  assert.match(source, /const library = branch\(forge, '收藏与订阅', false, 'star'\)/);
  assert.match(source, /\['projectCategories','projectBookmarks','releaseSubscriptions','releaseEvents'\]\) leaf\(library, id\)/);
  assert.equal(sections.forge_categories.action, '新增项目分类');
  assert.equal(sections.forge_bookmarks.action, '新增项目收藏');
  assert.equal(sections.forge_subscriptions.action, '新增版本订阅');
  assert.equal(sections.forge_release_events.action, '新增版本消息');
  const html = readFileSync(new URL('../deploy/pocketbase/pb_public/admin.html', import.meta.url), 'utf8');
  for (const symbol of ['repo', 'star', 'bell']) assert.ok(html.includes(`id="icon-${symbol}"`));
});
test('console uses unique IDs and an accessible layered sidebar', () => {
  const html = readFileSync(new URL('../deploy/pocketbase/pb_public/admin.html', import.meta.url), 'utf8');
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length);
  assert.match(html, /<aside id="sidebar"/);
  assert.match(html, /aria-controls="sidebar"/);
  assert.match(html, /id="breadcrumbs" aria-label="当前位置"/);
  assert.match(html, /class="skip-link" href="#workspace"/);
  for (const match of html.matchAll(/href="#(icon-[^"]+)"/g)) assert.ok(ids.includes(match[1]));
});
test('console styles respect reduced motion and bound table overflow', () => {
  const css = readFileSync(new URL('../deploy/pocketbase/pb_public/assets/admin.css', import.meta.url), 'utf8');
  assert.match(css, /prefers-reduced-motion:reduce/);
  assert.match(css, /\.badge\{white-space:nowrap\}/);
  assert.match(css, /\.table-wrap table\{min-width:700px\}/);
  assert.ok(!css.includes('transition:all'));
});
test('official quick access is global while favorites and tasks require a user', () => {
  const filter = workspaceFilter('websites', recordId);
  assert.ok(filter.includes('owner = ""') && filter.includes('payload.origin = "official"'));
  assert.ok(!filter.includes(recordId));
  assert.equal(workspaceFilter('favorites', recordId), ownerFilter(recordId));
  assert.ok(workspaceFilter('tasks', recordId).includes('kind = "task"'));
  assert.throws(() => workspaceFilter('favorites'));
});
test('workspace separates received and authored project interactions', () => {
  assert.equal(workspaceFilter('incomingDiscussions', recordId), `repository.owner = "${recordId}" && owner != "${recordId}"`);
  assert.equal(workspaceFilter('incomingReplies', recordId), `discussion.repository.owner = "${recordId}" && owner != "${recordId}"`);
  assert.equal(workspaceFilter('discussions', recordId), `owner = "${recordId}" && repository.owner != "${recordId}"`);
  assert.ok(workspaceFilter('notes', recordId, 'a"b').includes('courseId = "a\\"b"'));
});

test('square administration preserves personal ownership and provides a global moderation view', () => {
  for (const view of ['squarePosts', 'squareInterests', 'squareReplies', 'squareProfiles']) {
    assert.equal(workspaceFilter(view, recordId), ownerFilter(recordId));
    assert.throws(() => workspaceFilter(view));
  }
  assert.equal(workspaceFilter('squareFeed'), '');
  assert.equal(workspaceFilter('squareReceivedInterests', recordId), `post.owner = "${recordId}" && owner != "${recordId}"`);
  assert.throws(() => workspaceFilter('squareReceivedInterests'));
  assert.equal(sections.community_interests.action, '新增活动报名');
});

test('multiline domain fields retain line breaks in the schema editor', () => {
  for (const name of ['content', 'front', 'back', 'body', 'message', 'bio']) {
    assert.equal(isMultilineField({ type: 'text', name }), true);
  }
  assert.equal(isMultilineField({ type: 'text', name: 'title' }), false);
  assert.equal(isMultilineField({ type: 'json', name: 'payload' }), true);
  assert.equal(isMultilineField({ type: 'select', name: 'tags', maxSelect: 5 }), true);
  assert.equal(isMultilineField({ type: 'file', name: 'attachments', maxSelect: 5 }), false);
  const source = readFileSync(new URL('../deploy/pocketbase/pb_public/assets/admin.mjs', import.meta.url), 'utf8');
  assert.match(source, /else if \(isMultilineField\(field\)\)/);
  assert.match(source, /field\.type === 'file' \|\| isMultilineField\(field\)/);
});
test('domain listing preserves relationship scopes', async () => {
  let requested;
  const client = new AdminClient('', async url => { requested = url; return new Response('{"items":[]}'); });
  await client.list('forge_discussions', { view: 'incomingDiscussions', owner: recordId });
  assert.equal(new URL(requested, 'https://example.com').searchParams.get('filter'), workspaceFilter('incomingDiscussions', recordId));
  await assert.rejects(client.list('course_notes', { view: 'websites' }));
});
test('project review queues use validated state filters', async () => {
  let requested;
  const client = new AdminClient('', async url => { requested = url; return new Response('{"items":[]}'); });
  await client.list('forge_repositories', { reviewState: 'pending' });
  assert.equal(new URL(requested, 'https://example.com').searchParams.get('filter'), 'reviewState = "pending"');
  await assert.rejects(client.list('forge_repositories', { reviewState: '" || true' }));
});

test('community listing requires approval while personal repositories include every state', async () => {
  const urls = [];
  const client = new AdminClient('', async url => { urls.push(new URL(url, 'https://example.test')); return Response.json({ items: [] }); });
  await client.list('forge_repositories', { view: 'community' });
  assert.equal(urls[0].searchParams.get('filter'), 'reviewState = "approved" && schoolVerified = true && universityId = "ecnu" && visibility = "public"');
  await client.list('forge_repositories', { view: 'repositories', owner: recordId });
  assert.equal(urls[1].searchParams.get('filter'), `owner = "${recordId}"`);
});

test('approval confirmation explicitly includes campus relevance', () => {
  const html = readFileSync(new URL('../deploy/pocketbase/pb_public/admin.html', import.meta.url), 'utf8');
  const source = readFileSync(new URL('../deploy/pocketbase/pb_public/assets/admin.mjs', import.meta.url), 'utf8');
  assert.match(html, /id="review-school"[^>]*>已核验华东师范大学归属，确认项目与校园相关，并检查公开内容/);
  assert.match(source, /if \(approved && !\$\('review-school'\)\.checked\)/);
  assert.ok(source.includes('请核验华师大归属、确认校园相关性并勾选确认'));
});
test('project review checks school material and writes an administrator decision', async () => {
  const calls = [];
  const client = new AdminClient('', async (url, options) => {
    calls.push({ url, options });
    return new Response(JSON.stringify(options.method === 'GET'
      ? { reviewState: 'pending', visibility: 'public', universityId: 'ecnu', schoolProof: '学校归属材料' }
      : JSON.parse(options.body)), { status: 200 });
  });
  const row = await client.reviewProject(recordId, true);
  assert.equal(row.reviewState, 'approved');
  assert.equal(row.schoolVerified, true);
  assert.equal(calls.length, 2);
});
test('project approval requires school proof and the ECNU scope', async () => {
  for (const row of [{ reviewState: 'draft', visibility: 'public', universityId: 'ecnu', schoolProof: '材料' }, { reviewState: 'pending', visibility: 'private', universityId: 'ecnu', schoolProof: '材料' }, { reviewState: 'pending', visibility: 'public', universityId: 'other', schoolProof: '材料' }, { reviewState: 'pending', visibility: 'public', universityId: 'ecnu', schoolProof: '' }]) {
    const client = new AdminClient('', async () => new Response(JSON.stringify(row), { status: 200 }));
    await assert.rejects(client.reviewProject(recordId, true));
  }
});
test('browser fetch is called without a client receiver', async () => {
  const client = new AdminClient('', async function () {
    assert.equal(this, undefined);
    return new Response('{"items":[]}', { status: 200 });
  });
  await client.list('users');
});
test('workspace summary matches mobile completion semantics', () => {
  assert.equal(workspaceSummary({ payload: { activities: [{ completedAt: null }, { completedAt: '2026-10-09' }] } }), '待办 1 · 已完成 1');
  assert.equal(workspaceSummary({}), '待办 0 · 已完成 0');
});
test('owner filters use valid record IDs', () => {
  assert.equal(ownerFilter(recordId), `owner = "${recordId}"`);
  assert.equal(ownerFilter(''), '');
  assert.throws(() => ownerFilter('" || true'));
});
test('app payload retains extra data and supplies mobile-compatible origin', () => {
  const row = appPayload({ name: '作品', url: 'https://example.com', tags: '学习，工具', repository: 'https://github.com/Khk-NL/Campulse' }, { version: '1.0' });
  assert.equal(row.version, '1.0');
  assert.equal(row.origin, 'student-developed');
  assert.deepEqual(row.tags, ['学习', '工具']);
  assert.equal(row.launchTarget.type, 'web');
});
test('app payload validates names, web URLs and repositories', () => {
  assert.throws(() => appPayload({ name: '', url: 'https://example.com' }));
  assert.throws(() => appPayload({ name: 'x', url: 'javascript:alert(1)' }));
  assert.throws(() => appPayload({ name: 'x', url: 'https://example.com', repository: 'https://github.com.evil.com/a/b' }));
});
test('login authenticates superusers and logout clears in-memory token', async () => {
  const calls = [];
  const client = new AdminClient('', async (url, options) => {
    calls.push({ url, options }); return new Response(JSON.stringify({ token: 'test-token' }), { status: 200 });
  });
  await client.login(' admin@example.com ', 'secret');
  assert.equal(calls[0].url, '/api/collections/_superusers/auth-with-password');
  assert.equal(JSON.parse(calls[0].options.body).identity, 'admin@example.com');
  assert.equal(client.token, 'test-token');
  client.logout(); assert.equal(client.token, '');
});
test('lists paginate and filter personal records while protecting internal collections', async () => {
  let requested;
  const client = new AdminClient('', async (url, options) => {
    requested = { url, options }; return new Response(JSON.stringify({ items: [] }), { status: 200 });
  });
  client.token = 'test-token';
  await client.list('course_notes', { page: 2, owner: recordId });
  const url = new URL(requested.url, 'https://example.com');
  assert.equal(url.searchParams.get('page'), '2');
  assert.equal(url.searchParams.get('filter'), ownerFilter(recordId));
  assert.equal(requested.options.headers.Authorization, 'test-token');
  assert.equal(requested.options.cache, 'no-store');
  await assert.rejects(client.list('_superusers'));
});
test('editing apps reads the latest row and retains other fields', async () => {
  const calls = [];
  const client = new AdminClient('', async (url, options) => {
    calls.push({ url, options });
    return new Response(JSON.stringify(options.method === 'GET'
      ? { kind: 'app', payload: { permissions: ['camera'], version: '2' } }
      : JSON.parse(options.body)), { status: 200 });
  });
  const saved = await client.publishApp({ name: 'x', url: 'https://example.com', published: true }, recordId);
  assert.equal(calls[0].options.method, 'GET');
  assert.equal(calls[1].options.method, 'PATCH');
  assert.deepEqual(saved.payload.permissions, ['camera']);
  assert.equal(saved.published, true);
});
test('expired authentication clears the token and surfaces a useful error', async () => {
  const client = new AdminClient('', async () => new Response('{}', { status: 401 }));
  client.token = 'expired';
  await assert.rejects(client.list('users'), /401/);
  assert.equal(client.token, '');
});

test('each common partition has its own action and editable fields omit server-controlled values', () => {
  assert.equal(sections.course_notes.action, '新增笔记');
  assert.equal(sections.users.action, '新增用户');
  assert.equal(sections.campus_content.action, '新增目录记录');
  assert.equal(new Set(Object.values(sections).map(x => x.action)).size, Object.keys(sections).length);
  assert.equal(sections.forge_discussions.action, '新增项目讨论');
  assert.equal(sections.forge_replies.action, '新增讨论回复');
  assert.deepEqual(editableFields({fields:[{name:'id',type:'text'},{name:'updated',type:'autodate'},{name:'password',type:'password'},{name:'content',type:'text'},{name:'verified',type:'bool'}]}).map(x=>x.name), ['content','verified']);
});

test('schema-derived search escapes literals and joins filters', async () => {
  const schema={name:'course_notes',type:'base',fields:[{name:'owner',type:'relation'},{name:'title',type:'text'},{name:'payload',type:'json'}]};
  assert.match(searchFilter(schema, 'a" || true'), /title ~ "a\\" \|\| true"/);
  let requested;
  const client=new AdminClient('',async url=>{requested=url;return Response.json({items:[]});});
  client.schemas.set('course_notes',schema);
  await client.list('course_notes',{owner:recordId,search:'标题'});
  const filter=new URL(requested,'http://example.com').searchParams.get('filter');
  assert.match(filter,/owner =/);assert.match(filter,/&& \(/);assert.match(filter,/payload.name ~/);
});

test('collection catalog paginates and enables CRUD for discovered collections', async () => {
  const calls=[];
  const client=new AdminClient('',async(url,options)=>{
    calls.push({url,options});
    if(url.startsWith('/api/collections?')) {
      const page=new URL(url,'http://example.com').searchParams.get('page');
      return Response.json({items:[{name:page==='1'?'first_records':'extra_records',type:'base',fields:[]}],totalPages:2});
    }
    return options.method==='DELETE'?new Response(null,{status:204}):Response.json({id:recordId});
  });
  const catalog=await client.loadCollections();
  assert.deepEqual(catalog.map(row=>row.name),['first_records','extra_records']);
  assert.deepEqual(calls.map(row=>new URL(row.url,'http://example.com').searchParams.get('page')),['1','2']);
  await client.getRecord('extra_records',recordId);await client.saveRecord('extra_records',{title:'x'});await client.saveRecord('extra_records',{title:'y'},recordId);await client.deleteRecord('extra_records',recordId);
  assert.equal(calls[2].url,`/api/collections/extra_records/records/${recordId}`);
  assert.deepEqual(calls.slice(2).map(x=>x.options.method),['GET','POST','PATCH','DELETE']);
  assert.throws(()=>client.collectionPath('unlisted_collection'));
  client.schemas.set('read_only',{type:'view'});
  assert.throws(()=>client.saveRecord('read_only',{}));assert.throws(()=>client.deleteRecord('read_only',recordId));
});

test('campus directory kind filters preserve quoted values', async () => {
  let requested;
  const client=new AdminClient('',async url=>{requested=url;return Response.json({items:[]});});
  await client.list('campus_content',{kind:'app'});
  assert.equal(new URL(requested,'http://example.com').searchParams.get('filter'),'kind = "app"');
});

test('file writes preserve multipart boundaries and include authentication', async () => {
  let sent;
  const client=new AdminClient('',async(url,options)=>{sent=options;return Response.json({id:recordId});});client.token='test-only';
  const data=new FormData();data.append('attachment',new Blob(['PDF']), 'book.pdf');
  await client.saveRecord('course_notes',data,recordId);
  assert.equal(sent.body,data);assert.equal(sent.headers.Authorization,'test-only');assert.equal(sent.headers['Content-Type'],undefined);
});
