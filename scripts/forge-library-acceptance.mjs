import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';

// Local-only acceptance. Every run owns a fresh database and in-memory credentials.
const root = fileURLToPath(new URL('../', import.meta.url));
assert.ok(process.argv.slice(2).every(value => value === '--local'), 'Use --local for the disposable acceptance database');
const executable = process.env.POCKETBASE_EXE || path.join(root, '.tools/pocketbase-bin/pocketbase.exe');
assert.ok(fs.existsSync(executable), 'Set POCKETBASE_EXE to a local PocketBase executable');
fs.mkdirSync(path.join(root, '.tools'), { recursive: true });
const directory = fs.mkdtempSync(path.join(root, '.tools/forge-library-'));
const migrations = path.join(directory, 'pb_migrations');
fs.mkdirSync(migrations);
for (const name of ['1790210010_forge_community.js', '1790210011_forge_project_review.js', '1790210014_forge_library.js']) {
  fs.copyFileSync(path.join(root, 'deploy/pocketbase/pb_migrations', name), path.join(migrations, name));
}
const common = [`--dir=${path.join(directory, 'pb_data')}`, `--migrationsDir=${migrations}`];
const adminEmail = 'forge-library-acceptance@example.test';
const adminPassword = crypto.randomBytes(24).toString('hex');
const records = [];
let service, adminToken, base, checks = 0;
const libraryCollections = ['forge_categories', 'forge_bookmarks', 'forge_subscriptions', 'forge_release_events'];

function check(label, condition) { assert.ok(condition, label); checks++; console.log(`PASS ${label}`); }
function command(args, input) {
  const result = spawnSync(executable, [...args, ...common], { cwd: root, encoding: 'utf8', timeout: 30000, input });
  assert.equal(result.status, 0, `PocketBase ${args[0]} ${args[1]} completed`);
}
async function freePort() {
  const listener = net.createServer();
  listener.listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const port = listener.address().port;
  await new Promise(resolve => listener.close(resolve));
  return port;
}
async function start() {
  service = spawn(executable, ['serve', `--http=${new URL(base).host}`, '--automigrate=false', ...common], { cwd: root, stdio: 'ignore' });
  await once(service, 'spawn');
  for (let attempt = 0; attempt < 50; attempt++) {
    if (service.exitCode !== null) throw new Error('Disposable PocketBase exited during startup');
    const healthy = await fetch(`${base}/api/health`, { signal: AbortSignal.timeout(1000) }).then(response => response.ok).catch(() => false);
    if (healthy) return;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('Disposable PocketBase startup timed out');
}
async function stop() {
  if (!service || service.exitCode !== null || service.signalCode !== null) return;
  const current = service;
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { current.kill('SIGKILL'); reject(new Error('Disposable PocketBase shutdown timed out')); }, 5000);
    current.once('exit', () => { clearTimeout(timer); resolve(); });
    current.kill();
  });
}
async function raw(suffix, token, body, method = body === undefined ? 'GET' : 'POST') {
  const response = await fetch(`${base}${suffix}`, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(10000),
  });
  return { status: response.status, data: await response.json().catch(() => ({})) };
}
async function request(collection, token, body, method, suffix = '/records') {
  return raw(`/api/collections/${collection}${suffix}`, token, body, method);
}
async function good(label, collection, token, body, method, suffix) {
  const result = await request(collection, token, body, method, suffix);
  check(`${label} (HTTP ${result.status})`, result.status === 200 || (method === 'DELETE' && result.status === 204));
  return result.data;
}
async function create(label, collection, token, body) {
  const row = await good(label, collection, token, body);
  records.push({ collection, id: row.id });
  return row;
}
async function denied(label, collection, token, body, method, suffix) {
  const result = await request(collection, token, body, method, suffix);
  check(label, result.status >= 400 && result.status < 500);
}
async function patch(label, collection, token, id, body) {
  return good(label, collection, token, body, 'PATCH', `/records/${id}`);
}
async function read(label, collection, token, id) {
  return good(label, collection, token, undefined, 'GET', `/records/${id}`);
}
async function isolated(collection, row, other) {
  for (const token of [other, null]) {
    await denied(`${collection} record is owner-only`, collection, token, undefined, 'GET', `/records/${row.id}`);
    const list = await good(`${collection} foreign list succeeds without disclosure`, collection, token, undefined, 'GET', `/records?filter=${encodeURIComponent(`id = "${row.id}"`)}`);
    check(`${collection} foreign list is empty`, list.totalItems === 0);
    await denied(`${collection} foreign update is rejected`, collection, token, {}, 'PATCH', `/records/${row.id}`);
    await denied(`${collection} foreign delete is rejected`, collection, token, undefined, 'DELETE', `/records/${row.id}`);
  }
}
async function loginAdmin() {
  const result = await good('Disposable administrator authenticates', '_superusers', null, { identity: adminEmail, password: adminPassword }, 'POST', '/auth-with-password');
  adminToken = result.token;
}

try {
  command(['migrate', 'up']);
  command(['superuser', 'upsert', adminEmail, adminPassword]);
  base = `http://127.0.0.1:${await freePort()}`;
  await start();
  await loginAdmin();
  const members = [];
  for (const label of ['a', 'b']) {
    const password = crypto.randomBytes(24).toString('hex');
    const email = `library-${crypto.randomUUID()}-${label}@example.test`;
    const user = await create('Create a disposable verified member', 'users', adminToken, { email, password, passwordConfirm: password, verified: true });
    const auth = await good('Member authenticates', 'users', null, { identity: email, password }, 'POST', '/auth-with-password');
    members.push({ id: user.id, token: auth.token });
  }
  const [a, b] = members;
  const projectBody = { name: 'Library acceptance project', summary: 'Disposable fixture', visibility: 'private', reviewState: 'draft', universityId: 'ecnu', schoolVerified: false, reviewNote: '' };
  const privateProject = await create('Create an owner private project', 'forge_repositories', a.token, { ...projectBody, owner: a.id });
  const publicProject = await create('Create a reviewed public ECNU project', 'forge_repositories', adminToken, { ...projectBody, owner: a.id, visibility: 'public', reviewState: 'approved', schoolVerified: true });
  const foreignSchool = await create('Create another-school fixture', 'forge_repositories', adminToken, { ...projectBody, owner: a.id, visibility: 'public', reviewState: 'approved', schoolVerified: true, universityId: 'other-school' });
  const categoryA = await create('Create owner category', 'forge_categories', a.token, { owner: a.id, name: '开发工具', color: '#A72C43', position: 0, locked: false });
  const categoryB = await create('Create another owner category', 'forge_categories', b.token, { owner: b.id, name: '课程工具', color: '#C49529', position: 1 });
  await isolated('forge_categories', categoryA, b.token);
  await denied('Anonymous category creation is rejected', 'forge_categories', null, { owner: a.id, name: 'anonymous', color: '#123456' });
  await denied('Category owner cannot be forged', 'forge_categories', a.token, { owner: b.id, name: 'forged', color: '#123456' });
  await denied('Category color requires six hex digits', 'forge_categories', a.token, { owner: a.id, name: 'color', color: 'yellow' });
  await denied('Category names are bounded', 'forge_categories', a.token, { owner: a.id, name: 'x'.repeat(81), color: '#123456' });
  await denied('Category positions are integers', 'forge_categories', a.token, { owner: a.id, name: 'position', color: '#123456', position: 1.5 });
  const locked = await patch('Manual category edits can set AI lock', 'forge_categories', a.token, categoryA.id, { locked: true, position: 3 });
  check('Lock and manual ordering round-trip', locked.locked && locked.position === 3);
  await denied('Category owner is immutable', 'forge_categories', a.token, { owner: b.id }, 'PATCH', `/records/${categoryA.id}`);

  const bookmarkBody = { owner: a.id, repository: publicProject.id, category: categoryA.id, tags: ['Flutter', '校园工具'], note: '个人整理备注', analysis: { summary: '分析示例' }, analysisAt: '2026-10-21 12:00:00.000Z', githubMetadata: { language: 'Dart', license: 'MIT' } };
  const bookmark = await create('Create categorized private bookmark', 'forge_bookmarks', a.token, bookmarkBody);
  check('Bookmark tags and metadata round-trip', JSON.stringify(bookmark.tags) === JSON.stringify(bookmarkBody.tags) && bookmark.githubMetadata.language === 'Dart');
  await isolated('forge_bookmarks', bookmark, b.token);
  await create('Each owner has an independent bookmark', 'forge_bookmarks', b.token, { owner: b.id, repository: publicProject.id });
  await denied('Duplicate owner-project bookmark is rejected', 'forge_bookmarks', a.token, bookmarkBody);
  await create('Owner can organize a private project', 'forge_bookmarks', a.token, { owner: a.id, repository: privateProject.id });
  await denied('Other member cannot organize a private project', 'forge_bookmarks', b.token, { owner: b.id, repository: privateProject.id });
  await denied('Another school is outside shared project scope', 'forge_bookmarks', b.token, { owner: b.id, repository: foreignSchool.id });
  await denied('Bookmark owner cannot be forged', 'forge_bookmarks', a.token, { owner: b.id, repository: privateProject.id });
  await denied('Another owner category is rejected on create', 'forge_bookmarks', a.token, { owner: a.id, repository: foreignSchool.id, category: categoryB.id });
  await denied('Another owner category is rejected on update', 'forge_bookmarks', a.token, { category: categoryB.id }, 'PATCH', `/records/${bookmark.id}`);
  const anotherCategory = await create('Create a second owned category', 'forge_categories', a.token, { owner: a.id, name: '阅读材料', color: '#304F92' });
  const moved = await patch('Assign another owned category', 'forge_bookmarks', a.token, bookmark.id, { category: anotherCategory.id });
  check('Updated category references the assigned owned category', moved.category === anotherCategory.id);
  const cleared = await patch('Clear optional category', 'forge_bookmarks', a.token, bookmark.id, { category: '' });
  check('Category can be cleared', cleared.category === '');
  await patch('Restore original owned category', 'forge_bookmarks', a.token, bookmark.id, { category: categoryA.id });
  await denied('Bookmark owner is immutable', 'forge_bookmarks', a.token, { owner: b.id }, 'PATCH', `/records/${bookmark.id}`);
  await denied('Bookmark project is immutable', 'forge_bookmarks', a.token, { repository: privateProject.id }, 'PATCH', `/records/${bookmark.id}`);
  for (const [field, value] of [['tags', ['x'.repeat(8192)]], ['note', 'x'.repeat(4001)], ['analysis', { text: 'x'.repeat(49152) }], ['githubMetadata', { text: 'x'.repeat(32768) }]]) {
    await denied(`Bookmark ${field} has a size limit`, 'forge_bookmarks', a.token, { [field]: value }, 'PATCH', `/records/${bookmark.id}`);
  }
  await good('Deleting a category succeeds', 'forge_categories', a.token, undefined, 'DELETE', `/records/${categoryA.id}`);
  const uncategorized = await read('Category deletion preserves bookmark', 'forge_bookmarks', a.token, bookmark.id);
  check('Deleted category relation is cleared', uncategorized.category === '');
  const star = await create('Star and library are separate relations', 'forge_stars', a.token, { owner: a.id, repository: publicProject.id });
  await good('Remove Star independently', 'forge_stars', a.token, undefined, 'DELETE', `/records/${star.id}`);
  await read('Personal organization survives removing Star', 'forge_bookmarks', a.token, bookmark.id);
  const restoredStar = await create('Restore Star independently', 'forge_stars', a.token, { owner: a.id, repository: publicProject.id });
  const bookmarkList = await good('Bookmark remains unique after restoring Star', 'forge_bookmarks', a.token, undefined, 'GET', `/records?filter=${encodeURIComponent(`repository = "${publicProject.id}"`)}`);
  check('Restored Star reuses one personal bookmark', bookmarkList.totalItems === 1 && bookmarkList.items[0].id === bookmark.id);

  const subscription = await create('Create personal release subscription', 'forge_subscriptions', a.token, { owner: a.id, repository: publicProject.id, includePrereleases: false });
  const subscriptionB = await create('Another owner can subscribe independently', 'forge_subscriptions', b.token, { owner: b.id, repository: publicProject.id });
  const privateSubscription = await create('Owner can subscribe to own private project', 'forge_subscriptions', a.token, { owner: a.id, repository: privateProject.id });
  await isolated('forge_subscriptions', subscription, b.token);
  await denied('Duplicate subscription is rejected', 'forge_subscriptions', a.token, { owner: a.id, repository: publicProject.id });
  await denied('Private project subscription is owner-only', 'forge_subscriptions', b.token, { owner: b.id, repository: privateProject.id });
  await patch('Subscription flags and timestamps update', 'forge_subscriptions', a.token, subscription.id, { includePrereleases: true, lastCheckedAt: '2026-10-21 12:00:00.000Z' });
  for (const body of [{ owner: b.id }, { repository: privateProject.id }]) {
    await denied('Subscription identity is immutable', 'forge_subscriptions', a.token, body, 'PATCH', `/records/${subscription.id}`);
  }
  const eventBody = { owner: a.id, repository: publicProject.id, subscription: subscription.id, externalId: 'release-1', payload: { tag: 'v1.0.0', name: 'First release' }, read: false, publishedAt: '2026-10-21 12:00:00.000Z' };
  const event = await create('Create owner release event', 'forge_release_events', a.token, eventBody);
  await isolated('forge_release_events', event, b.token);
  await denied('Duplicate release event is rejected', 'forge_release_events', a.token, eventBody);
  await create('Same external release stays independent for another owner', 'forge_release_events', b.token, { ...eventBody, owner: b.id, subscription: subscriptionB.id });
  await denied('Foreign subscription cannot be attached', 'forge_release_events', a.token, { ...eventBody, externalId: 'bad-owner', subscription: subscriptionB.id });
  await denied('Subscription must belong to the same project', 'forge_release_events', a.token, { ...eventBody, externalId: 'bad-project', subscription: privateSubscription.id });
  for (const body of [{ owner: b.id }, { repository: privateProject.id }, { subscription: privateSubscription.id }]) {
    await denied('Release event identity is immutable', 'forge_release_events', a.token, body, 'PATCH', `/records/${event.id}`);
  }
  await denied('Release payload is bounded', 'forge_release_events', a.token, { payload: { text: 'x'.repeat(98304) } }, 'PATCH', `/records/${event.id}`);
  await denied('External release ID is bounded', 'forge_release_events', a.token, { ...eventBody, externalId: 'x'.repeat(101) });
  const marked = await patch('Owner marks a release read', 'forge_release_events', a.token, event.id, { read: true });
  check('Release read state round-trips', marked.read === true);
  await good('Owner removes a subscription', 'forge_subscriptions', a.token, undefined, 'DELETE', `/records/${subscription.id}`);
  await denied('Subscription deletion cascades to release events', 'forge_release_events', a.token, undefined, 'GET', `/records/${event.id}`);
  await read('Subscription removal preserves the personal bookmark', 'forge_bookmarks', a.token, bookmark.id);
  await patch('Reviewed project can be withdrawn', 'forge_repositories', adminToken, publicProject.id, { visibility: 'private' });
  for (const collection of ['forge_bookmarks', 'forge_subscriptions', 'forge_release_events']) {
    const hidden = await good('Withdrawn projects disappear from related private lists', collection, b.token, undefined, 'GET', '/records');
    check(`${collection} respects withdrawn project visibility`, hidden.totalItems === 0);
  }

  await stop();
  command(['migrate', 'down', '1'], 'yes\n');
  // serve applies pending JS migrations at bootstrap even with automigrate=false
  // (that flag controls generated schema snapshots). Hide only this copied file.
  const migrationFile = path.join(migrations, '1790210014_forge_library.js');
  fs.renameSync(migrationFile, `${migrationFile}.disabled`);
  await start();
  await loginAdmin();
  const collections = await raw('/api/collections?perPage=200', adminToken);
  check('Rollback removes only the four library collections', collections.status === 200 && libraryCollections.every(name => !collections.data.items.some(row => row.name === name)));
  await read('Rollback preserves source projects', 'forge_repositories', adminToken, publicProject.id);
  await read('Rollback preserves public Star records', 'forge_stars', adminToken, restoredStar.id);
  await stop();
  fs.renameSync(`${migrationFile}.disabled`, migrationFile);
  command(['migrate', 'up']);
  await start();
  await loginAdmin();
  const reapplied = await raw('/api/collections?perPage=200', adminToken);
  check('Library migration reapplies after rollback', reapplied.status === 200 && libraryCollections.every(name => reapplied.data.items.some(row => row.name === name)));
} finally {
  let cleanupError;
  if (service?.exitCode === null && adminToken) {
    for (const row of [...records].reverse()) {
      try {
        const result = await request(row.collection, adminToken, undefined, 'DELETE', `/records/${row.id}`);
        assert.ok([200, 204, 404].includes(result.status), `Cleanup ${row.collection} HTTP ${result.status}`);
      } catch (error) { cleanupError ??= error; }
    }
    if (!cleanupError) {
      for (const name of [...libraryCollections, 'forge_repositories', 'forge_stars', 'users']) {
        try {
          const result = await request(name, adminToken, undefined, 'GET', '/records?perPage=1');
          check(`Disposable fixture cleanup leaves ${name} empty`, result.status === 200 && result.data.totalItems === 0);
        } catch (error) { cleanupError ??= error; }
      }
    }
  }
  await stop();
  if (cleanupError) throw cleanupError;
}
check('Disposable PocketBase process has stopped', service && (service.exitCode !== null || service.signalCode !== null));
console.log(`PASS ${checks} local forge library checks`);
