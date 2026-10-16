import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { AdminClient } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';

const local = process.argv.includes('--local');
if (!local && !process.argv.includes('--apply')) throw new Error('Remote checks create disposable records. Add --apply.');
const base = local ? 'http://127.0.0.1:18097' : process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn';
let service, admin, count = 0;
const users = [], records = [];
function check(label, ok) { assert.ok(ok, label); console.log(`PASS ${label}`); count++; }
async function request(collection, token, { method = 'GET', body, suffix = '/records' } = {}) {
  const response = await fetch(`${base}/api/collections/${collection}${suffix}`, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30000),
  });
  return { status: response.status, data: await response.json().catch(() => ({})) };
}
async function create(collection, token, body) {
  const result = await request(collection, token, { method: 'POST', body });
  assert.equal(result.status, 200, `${collection} creation HTTP ${result.status}: ${JSON.stringify(result.data.data)}`);
  if (collection !== 'users') records.push([collection, result.data.id]);
  return result.data;
}
const get = (collection, token, id) => request(collection, token, { suffix: `/records/${id}` });
const patch = (collection, token, id, body) => request(collection, token, { method: 'PATCH', body, suffix: `/records/${id}` });
try {
  let identity, password;
  if (local) {
    const dir = `.tools/community-check-${Date.now()}`;
    fs.mkdirSync(`${dir}/pb_migrations`, { recursive: true });
    fs.copyFileSync('deploy/pocketbase/pb_migrations/1790210013_campus_square.js', `${dir}/pb_migrations/1790210013_campus_square.js`);
    const exe = process.env.POCKETBASE_EXE || 'E:/pocketbase_0.40.4_windows_amd64/pocketbase.exe';
    const args = [`--dir=${dir}/pb_data`, `--migrationsDir=${dir}/pb_migrations`];
    const migration = spawnSync(exe, ['migrate', 'up', ...args], { encoding: 'utf8' });
    assert.equal(migration.status, 0, migration.stderr || migration.stdout);
    identity = 'community-check@example.com'; password = crypto.randomBytes(24).toString('hex');
    assert.equal(spawnSync(exe, ['superuser', 'upsert', identity, password, ...args], { stdio: 'ignore' }).status, 0);
    service = spawn(exe, ['serve', '--http=127.0.0.1:18097', ...args], { stdio: 'ignore' });
    let healthy = false;
    for (let i = 0; i < 40 && !healthy; i++) {
      await new Promise(r => setTimeout(r, 100));
      healthy = await fetch(`${base}/api/health`).then(r => r.ok).catch(() => false);
    }
    check('disposable PocketBase starts after migration', healthy);
  } else {
    const env = Object.fromEntries(fs.readFileSync(process.env.CAMPULSE_ACCEPTANCE_ENV || '.tools/remote-acceptance.env', 'utf8')
      .split(/\r?\n/).filter(l => /^[A-Z_]+\s*=/.test(l)).map(l => {
        const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^(['"])(.*)\1$/, '$2')];
      }));
    identity = env.REMOTE_ADMIN_EMAIL; password = env.REMOTE_ADMIN_PASSWORD;
  }
  const auth = await request('_superusers', null, { method: 'POST', body: { identity, password }, suffix: '/auth-with-password' });
  assert.equal(auth.status, 200, 'Administrator authentication'); admin = auth.data.token;
  const accounts = [];
  for (let i = 0; i < 3; i++) {
    const password = crypto.randomBytes(24).toString('hex');
    const email = `community-check-${Date.now()}-${i}@example.com`;
    const row = await create('users', admin, { email, password, passwordConfirm: password, verified: true });
    users.push(row.id);
    const login = await request('users', null, { method: 'POST', body: { identity: email, password }, suffix: '/auth-with-password' });
    assert.equal(login.status, 200); accounts.push({ id: row.id, token: login.data.token, email, password });
  }
  const [a, b, c] = accounts;
  const payload = { owner: a.id, universityId: 'ecnu', title: '验收专用羽毛球约局', body: '完成后自动清理',
    displayName: '验收发起人', kind: 'sport', campus: 'minhang', location: '校内公共场地', tags: '羽毛球', status: 'open' };
  const post = await create('community_posts', a.token, payload);
  check('anonymous reader is blocked', (await get('community_posts', null, post.id)).status !== 200);
  check('verified participant reads the post', (await get('community_posts', b.token, post.id)).status === 200);
  check('post owner impersonation is rejected', (await request('community_posts', b.token, { method: 'POST', body: payload })).status !== 200);
  check('school scope is enforced', (await request('community_posts', a.token, { method: 'POST', body: { ...payload, universityId: 'other' } })).status !== 200);
  check('post owner stays immutable', (await patch('community_posts', a.token, post.id, { owner: b.id })).status !== 200);
  check('participant cannot change the host post', (await patch('community_posts', b.token, post.id, { title: 'overwrite' })).status !== 200);
  const interest = await create('community_interests', b.token, { owner: b.id, post: post.id, displayName: '验收参与人', message: '报名私密留言' });
  check('host reads registration', (await get('community_interests', a.token, interest.id)).status === 200);
  check('other users are isolated from registration', (await get('community_interests', c.token, interest.id)).status === 404);
  check('duplicate registration is rejected', (await request('community_interests', b.token, { method: 'POST', body: { owner: b.id, post: post.id, displayName: '重复' } })).status !== 200);
  const reply = await create('community_replies', b.token, { owner: b.id, post: post.id, displayName: '验收参与人', body: '请问集合时间？' });
  check('discussion is visible to verified members', (await get('community_replies', c.token, reply.id)).status === 200);
  check('reply parent binding stays immutable', (await patch('community_replies', b.token, reply.id, { owner: a.id })).status !== 200);
  const profile = await create('community_profiles', a.token, { owner: a.id, displayName: '兴趣验收', bio: '编程与运动', interests: '羽毛球', campus: 'minhang', published: false });
  const consoleClient = new AdminClient(base); consoleClient.token = admin;
  await consoleClient.loadCollections();
  const ownedPosts = await consoleClient.list('community_posts', { view: 'squarePosts', owner: a.id });
  check('admin personal view returns the selected user post', ownedPosts.items.some(row => row.id === post.id) && ownedPosts.items.every(row => row.owner === a.id));
  const ownInterests = await consoleClient.list('community_interests', { view: 'squareInterests', owner: b.id });
  check('admin registration view follows participant ownership', ownInterests.items.some(row => row.id === interest.id) && ownInterests.items.every(row => row.owner === b.id));
  const received = await consoleClient.list('community_interests', { view: 'squareReceivedInterests', owner: a.id });
  check('admin host view includes incoming registrations', received.items.some(row => row.id === interest.id));
  const joined = await request('community_interests', b.token, { suffix: '/records?' + new URLSearchParams({ filter: `owner = "${b.id}" && post.universityId = "ecnu" && post.kind = "sport"`, expand: 'post', perPage: '20', page: '1' }) });
  check('joined feed uses paged owner relations with expanded posts', joined.status === 200 && joined.data.totalItems === 1 && joined.data.items[0].expand?.post?.id === post.id);
  check('admin global feed contains the published gathering', (await consoleClient.list('community_posts', { view: 'squareFeed' })).items.some(row => row.id === post.id));
  check('private interest card stays owner-only', (await get('community_profiles', b.token, profile.id)).status === 404);
  await patch('community_profiles', a.token, profile.id, { published: true });
  check('opt-in card reaches other members', (await get('community_profiles', b.token, profile.id)).status === 200);
  check('public card stays behind account verification', (await get('community_profiles', null, profile.id)).status !== 200);
  const second = await request('users', null, { method: 'POST', body: { identity: a.email, password: a.password }, suffix: '/auth-with-password' });
  check('second independent login reads cloud post', second.status === 200 && (await get('community_posts', second.data.token, post.id)).data.title === payload.title);
  if (!local) {
    const pin = await create('user_favorites', a.token, { owner: a.id, board: 'courses', entryKey: 'cross-device-check' });
    check('second login reads course pin', (await get('user_favorites', second.data.token, pin.id)).data.board === 'courses');
    check('course pin stays isolated from other accounts', (await get('user_favorites', b.token, pin.id)).status === 404);
  }
  await patch('community_posts', a.token, post.id, { status: 'closed' });
  check('closed post rejects new registration', (await request('community_interests', c.token, { method: 'POST', body: { owner: c.id, post: post.id, displayName: '迟到报名' } })).status !== 200);
  check('closed post rejects new discussion', (await request('community_replies', c.token, { method: 'POST', body: { owner: c.id, post: post.id, displayName: '成员', body: '迟到讨论' } })).status !== 200);
  check('participant can withdraw after closing', (await request('community_interests', b.token, { method: 'DELETE', suffix: `/records/${interest.id}` })).status === 204);
  console.log(`PASS ${count} community acceptance assertions (${local ? 'disposable local database' : 'remote API'})`);
} finally {
  let cleanupErrors = 0;
  if (admin) {
    for (const [collection, id] of records.reverse()) {
      const result = await request(collection, admin, { method: 'DELETE', suffix: `/records/${id}` }).catch(() => ({ status: 0 }));
      if (![204, 404].includes(result.status)) cleanupErrors++;
    }
    for (const id of users) {
      const result = await request('users', admin, { method: 'DELETE', suffix: `/records/${id}` }).catch(() => ({ status: 0 }));
      if (![204, 404].includes(result.status)) cleanupErrors++;
    }
  }
  service?.kill();
  if (cleanupErrors) { console.error(`Cleanup needs attention: ${cleanupErrors} records`); process.exitCode = 1; }
  else console.log('Disposable test accounts and records cleaned up.');
}
