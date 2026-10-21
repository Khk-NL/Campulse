import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { AdminClient } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';

// --local uses a disposable database under .tools; remote uses existing test users.
const local = process.argv.includes('--local');
const base = local ? 'http://127.0.0.1:18094' : (process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn');
let service, adminToken;
const createdUsers = [], repositories = [];
const personalRows = [];
let checks = 0;
async function request(collection, token, body, method = body ? 'POST' : 'GET', suffix = '/records') {
  const response = await fetch(`${base}/api/collections/${collection}${suffix}`, { method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30000) });
  return { status: response.status, data: await response.json().catch(() => ({})) };
}
function check(label, condition) { assert.ok(condition, label); checks++; console.log(`PASS ${label}`); }
async function good(label, collection, token, body, method, suffix) {
  const result = await request(collection, token, body, method, suffix);
  check(label, result.status === 200); return result.data;
}
try {
  let credentials;
  if (local) {
    const executable = process.env.POCKETBASE_EXE || 'E:/pocketbase_0.40.4_windows_amd64/pocketbase.exe';
    const directory = `.tools/pb-forge-check-${Date.now()}`;
    fs.mkdirSync(`${directory}/pb_migrations`, { recursive: true });
    fs.copyFileSync('experiments/pocketbase/pb_migrations/1790208001_campus_content.js', `${directory}/pb_migrations/1790208001_campus_content.js`);
    fs.copyFileSync('deploy/pocketbase/pb_migrations/1790210012_user_relationships.js', `${directory}/pb_migrations/1790210012_user_relationships.js`);
    // Code asset copied mechanically; credentials remain in process memory.
    fs.copyFileSync('deploy/pocketbase/pb_migrations/1790210010_forge_community.js', `${directory}/pb_migrations/1790210010_forge_community.js`);
    fs.copyFileSync('deploy/pocketbase/pb_migrations/1790210011_forge_project_review.js', `${directory}/pb_migrations/1790210011_forge_project_review.js`);
    const common = [`--dir=${directory}/pb_data`, `--migrationsDir=${directory}/pb_migrations`];
    const up = spawnSync(executable, ['migrate', 'up', ...common], { encoding: 'utf8' });
    if (up.status !== 0) throw new Error(`Migration failed: ${up.stderr}`);
    const password = crypto.randomBytes(24).toString('hex');
    const admin = spawnSync(executable, ['superuser', 'upsert', 'forge-test@example.com', password, ...common], { encoding: 'utf8' });
    assert.equal(admin.status, 0, 'Disposable administrator initialization');
    service = spawn(executable, ['serve', '--http=127.0.0.1:18094', ...common], { stdio: 'ignore' });
    let healthy = false;
    for (let i = 0; i < 30 && !healthy; i++) {
      await new Promise(resolve => setTimeout(resolve, 100));
      healthy = await fetch(`${base}/api/health`).then(r => r.ok).catch(() => false);
    }
    assert.ok(healthy, 'Disposable service startup');
    const adminAuth = await good('本机试验管理员认证', '_superusers', null, { identity: 'forge-test@example.com', password }, undefined, '/auth-with-password');
    adminToken = adminAuth.token;
    credentials = [];
    for (let i = 0; i < 2; i++) {
      const userPassword = crypto.randomBytes(24).toString('hex');
      const email = `forge-${Date.now()}-${i}@example.com`;
      const user = await good('创建独立试验用户', 'users', adminToken, { email, password: userPassword, passwordConfirm: userPassword, verified: true });
      createdUsers.push(user.id); credentials.push({ email, password: userPassword });
    }
  } else {
    credentials = JSON.parse(fs.readFileSync(process.env.CAMPULSE_TEST_USERS || '.tools/remote-test-users.json', 'utf8')).slice(0, 2);
    const env = Object.fromEntries(fs.readFileSync('.tools/remote-acceptance.env', 'utf8').split(/\r?\n/).filter(line => /^[A-Z_]+\s*=/.test(line)).map(line => {
      const split = line.indexOf('='); return [line.slice(0, split).trim(), line.slice(split + 1).trim().replace(/^(['"])(.*)\1$/, '$2')];
    }));
    const auth = await good('远程管理员认证', '_superusers', null, { identity: env.REMOTE_ADMIN_EMAIL, password: env.REMOTE_ADMIN_PASSWORD }, undefined, '/auth-with-password');
    adminToken = auth.token;
  }
  const [a, b] = await Promise.all(credentials.map(async c => {
    const auth = await good('普通用户登录', 'users', null, { identity: c.email, password: c.password }, undefined, '/auth-with-password');
    return { id: auth.record.id, token: auth.token };
  }));
  const favorite = await good('收藏绑定用户A', 'user_favorites', a.token, { owner: a.id, board: 'web', entryKey: `qa-${Date.now()}` });
  personalRows.push({ collection: 'user_favorites', id: favorite.id });
  check('收藏对用户B隔离', (await request('user_favorites', b.token, undefined, 'GET', `/records/${favorite.id}`)).status === 404);
  check('收藏归属固定', (await request('user_favorites', a.token, { owner: b.id }, 'PATCH', `/records/${favorite.id}`)).status !== 200);
  const personalClient = new AdminClient(base); personalClient.token = adminToken; await personalClient.loadCollections();
  check('运营台按用户读回收藏', (await personalClient.list('user_favorites', { view: 'favorites', owner: a.id })).items.some(row => row.id === favorite.id));
  for (const kind of ['task', 'announcement']) {
    const row = await good('管理员分配个人' + kind, 'campus_content', adminToken, { owner: a.id, kind, universityId: 'ecnu', published: true, schemaVersion: 1, payload: { id: `qa-${Date.now()}`, title: '关系验收' } });
    personalRows.push({ collection: 'campus_content', id: row.id });
    await good('用户A读回个人' + kind, 'campus_content', a.token, undefined, 'GET', `/records/${row.id}`);
    check('个人' + kind + '对用户B隔离', (await request('campus_content', b.token, undefined, 'GET', `/records/${row.id}`)).status === 404);
    check('匿名访问隔离个人' + kind, (await request('campus_content', null, undefined, 'GET', `/records/${row.id}`)).status === 404);
  }
  const directory = await personalClient.list('campus_content', { view: 'websites', owner: a.id });
  check('官方目录保持公共归属', directory.items.every(row => !row.owner && row.kind === 'service' && row.payload.origin === 'official'));
  const repository = await good('用户A提交待审核项目', 'forge_repositories', a.token, { owner: a.id, name: `community-qa-${Date.now()}`, summary: '交流流程验收', readme: '# 项目\n参与讨论', topics: '校园 测试', visibility: 'public', reviewState: 'pending', universityId: 'ecnu', schoolVerified: false, reviewNote: '', schoolProof: '专用验收材料' });
  repositories.push({ id: repository.id, token: a.token });
  const second = await good('同一用户保留独立草稿项目', 'forge_repositories', a.token, { owner: a.id, name: `draft-${Date.now()}`, visibility: 'private', reviewState: 'draft', universityId: 'ecnu', schoolVerified: false, reviewNote: '', repositoryUrl: 'https://github.com/Khk-NL/Campulse' });
  repositories.push({ id: second.id, token: a.token });
  for (const token of [null, b.token]) {
    check('待审核项目对其他访客隔离', (await request('forge_repositories', token, undefined, 'GET', `/records/${repository.id}`)).status === 404);
  }
  await good('作者查看待审核项目', 'forge_repositories', a.token, undefined, 'GET', `/records/${repository.id}`);
  check('普通用户无法自行审批', (await request('forge_repositories', a.token, { reviewState: 'approved', schoolVerified: true }, 'PATCH', `/records/${repository.id}`)).status !== 200);
  check('待审核项目停止跨用户讨论', (await request('forge_discussions', b.token, { owner: b.id, repository: repository.id, title: '提前讨论', body: '验收', kind: 'question', status: 'open' })).status !== 200);
  const consoleClient = new AdminClient(base); consoleClient.token = adminToken;
  const personalScope = `owner = "${a.id}" && (id = "${repository.id}" || id = "${second.id}")`;
  const personal = await good('本人仓库按作者查询全部项目', 'forge_repositories', a.token, undefined, 'GET', `/records?filter=${encodeURIComponent(personalScope)}`);
  check('本人仓库同时展示待审核与私有草稿', personal.totalItems === 2 && personal.items.some(row => row.id === repository.id && row.reviewState === 'pending') && personal.items.some(row => row.id === second.id && row.visibility === 'private' && row.reviewState === 'draft'));
  const rejected = await consoleClient.reviewProject(repository.id, false, '请补充校园使用场景及核验材料');
  check('管理员可按校园相关性退回修改', rejected.reviewState === 'rejected' && rejected.schoolVerified === false);
  const afterRejection = await good('退回后作者继续查看全部仓库', 'forge_repositories', a.token, undefined, 'GET', `/records?filter=${encodeURIComponent(personalScope)}`);
  check('退回项目保留在本人仓库', afterRejection.totalItems === 2 && afterRejection.items.some(row => row.id === repository.id && row.reviewState === 'rejected'));
  for (const token of [null, b.token]) {
    check('退回项目继续对其他访客隔离', (await request('forge_repositories', token, undefined, 'GET', `/records/${repository.id}`)).status === 404);
  }
  await good('作者逐项目重新提交', 'forge_repositories', a.token, { reviewState: 'pending' }, 'PATCH', `/records/${repository.id}`);
  check('运营台管理员审核华师大项目', (await consoleClient.reviewProject(repository.id, true)).reviewState === 'approved');
  const other = await good('审批后读回同用户另一草稿', 'forge_repositories', a.token, undefined, 'GET', `/records/${second.id}`);
  check('逐项目审核互不影响且绑定GitHub', other.reviewState === 'draft' && other.repositoryUrl === 'https://github.com/Khk-NL/Campulse');
  await good('匿名查看公开项目', 'forge_repositories', null, undefined, 'GET', `/records/${repository.id}`);
  const forbidden = await request('forge_repositories', b.token, { owner: a.id, name: '伪造归属', visibility: 'public' });
  check('用户B创建项目不能伪造用户A归属', forbidden.status !== 200);
  const edit = await request('forge_repositories', b.token, { name: '越权编辑' }, 'PATCH', `/records/${repository.id}`);
  check('其他用户不能编辑仓库', edit.status !== 200);
  const thread = await good('用户B提出问题', 'forge_discussions', b.token, { owner: b.id, repository: repository.id, title: '如何贡献？', body: '希望参与这个项目', kind: 'question', status: 'open' });
  const reply = await good('项目所有者回复', 'forge_replies', a.token, { owner: a.id, discussion: thread.id, body: '欢迎从文档开始' });
  await good('另一会话读回回复', 'forge_replies', b.token, undefined, 'GET', `/records/${reply.id}`);
  const star = await good('用户B关注项目', 'forge_stars', b.token, { owner: b.id, repository: repository.id });
  const starredFilter = `id = "${repository.id}" && forge_stars_via_repository.owner ?= "${b.id}" && visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = "ecnu"`;
  const saved = await good('我的Star使用项目反向关系查询', 'forge_repositories', b.token, undefined, 'GET', `/records?filter=${encodeURIComponent(starredFilter)}&sort=-updated,id&perPage=20`);
  check('我的Star实际读回本人收藏', saved.items.length === 1 && saved.items[0].id === repository.id);
  const ownStars = await good('另一用户的Star查询独立', 'forge_repositories', a.token, undefined, 'GET', `/records?filter=${encodeURIComponent(`id = "${repository.id}" && forge_stars_via_repository.owner ?= "${a.id}"`)}`);
  check('另一用户的Star列表保持本人范围', ownStars.totalItems === 0);
  const projectScope = encodeURIComponent(`id = "${repository.id}" || id = "${second.id}"`);
  const firstPage = await good('项目名称排序第一页', 'forge_repositories', a.token, undefined, 'GET', `/records?filter=${projectScope}&sort=name,id&perPage=1&page=1`);
  const nextPage = await good('项目名称排序第二页', 'forge_repositories', a.token, undefined, 'GET', `/records?filter=${projectScope}&sort=name,id&perPage=1&page=2`);
  check('服务端排序与分页配合', firstPage.totalItems === 2 && firstPage.items[0].id === repository.id && nextPage.items[0].id === second.id);
  const issueScope = `repository = "${repository.id}" && status = "open" && kind = "question" && (title ~ "参与" || body ~ "参与")`;
  const searched = await good('讨论正文关键词与类型状态组合查询', 'forge_discussions', b.token, undefined, 'GET', `/records?filter=${encodeURIComponent(issueScope)}`);
  check('讨论组合搜索命中真实正文', searched.totalItems === 1 && searched.items[0].id === thread.id);
  const bugs = await good('讨论类型筛选独立', 'forge_discussions', b.token, undefined, 'GET', `/records?filter=${encodeURIComponent(`repository = "${repository.id}" && kind = "bug"`)}`);
  check('讨论类型筛选保留项目范围', bugs.totalItems === 0);
  const duplicate = await request('forge_stars', b.token, { owner: b.id, repository: repository.id });
  check('重复关注受唯一索引限制', duplicate.status !== 200);
  const anonymous = await request('forge_replies', null, { owner: b.id, discussion: thread.id, body: '匿名写入' });
  check('匿名回复被拒绝', anonymous.status !== 200);
  await good('项目所有者关闭问题', 'forge_discussions', a.token, { status: 'closed' }, 'PATCH', `/records/${thread.id}`);
  const resolved = await good('关闭状态参与组合搜索', 'forge_discussions', b.token, undefined, 'GET', `/records?filter=${encodeURIComponent(`repository = "${repository.id}" && status = "closed" && kind = "question" && title ~ "贡献"`)}`);
  check('关闭讨论仍可搜索读回', resolved.totalItems === 1 && resolved.items[0].id === thread.id);
  const closed = await request('forge_replies', b.token, { owner: b.id, discussion: thread.id, body: '关闭后回复' });
  check('关闭问题停止追加回复', closed.status !== 200);
  await good('问题作者重新开启', 'forge_discussions', b.token, { status: 'open' }, 'PATCH', `/records/${thread.id}`);
  check('已审核内容禁止绕过复审直接改动', (await request('forge_repositories', a.token, { name: '绕过审核' }, 'PATCH', `/records/${repository.id}`)).status !== 200);
  await good('项目修改后进入复审', 'forge_repositories', a.token, { name: '调整后的验收项目', reviewState: 'pending' }, 'PATCH', `/records/${repository.id}`);
  check('复审项目重新对其他用户隐藏', (await request('forge_repositories', b.token, undefined, 'GET', `/records/${repository.id}`)).status === 404);
  await good('项目转为私有', 'forge_repositories', a.token, { visibility: 'private', reviewState: 'pending' }, 'PATCH', `/records/${repository.id}`);
  const hiddenStar = await good('私有项目退出他人Star列表', 'forge_repositories', b.token, undefined, 'GET', `/records?filter=${encodeURIComponent(starredFilter)}`);
  check('Star列表服从项目可见性', hiddenStar.totalItems === 0);
  for (const [collection, id] of [['forge_repositories', repository.id], ['forge_discussions', thread.id], ['forge_replies', reply.id], ['forge_stars', star.id]]) {
    const hidden = await request(collection, b.token, undefined, 'GET', `/records/${id}`);
    check(`私有项目隔离 ${collection}`, hidden.status === 404);
  }
  const hiddenWrite = await request('forge_discussions', b.token, { status: 'closed' }, 'PATCH', `/records/${thread.id}`);
  check('原讨论作者无法修改已转私有项目内容', hiddenWrite.status !== 200);
  await good('所有者继续读回私有讨论', 'forge_discussions', a.token, undefined, 'GET', `/records/${thread.id}`);
  console.log(`PASS ${checks} community checks`);
} finally {
  for (const row of personalRows) await request(row.collection, adminToken, undefined, 'DELETE', `/records/${row.id}`).catch(() => {});
  for (const row of repositories) await request('forge_repositories', row.token, undefined, 'DELETE', `/records/${row.id}`).catch(() => {});
  for (const id of createdUsers) await request('users', adminToken, undefined, 'DELETE', `/records/${id}`).catch(() => {});
  if (service) { service.kill(); await new Promise(resolve => service.once('exit', resolve)); }
}
