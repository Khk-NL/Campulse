import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = new URL('../', import.meta.url);
const forbidden = /没有|不是|不能|无法|不支持|尚未|未配置|未接入|暂无|不代表|不会/;

test('Chinese UI labels use direct wording', () => {
  const copy = JSON.parse(fs.readFileSync(new URL('apps/mobile/lib/l10n/app_zh.arb', root), 'utf8'));
  for (const [key, value] of Object.entries(copy)) {
    if (!key.startsWith('@') && typeof value === 'string') assert.ok(!forbidden.test(value), key);
  }
});

test('feature strings omit negative explanatory copy', () => {
  const directory = new URL('apps/mobile/lib/features/', root);
  for (const entry of fs.readdirSync(directory, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.dart')) continue;
    const file = path.join(entry.parentPath, entry.name);
    const source = fs.readFileSync(file, 'utf8').split(/\r?\n/)
      .filter(line => !line.trimStart().startsWith('//')).join('\n');
    assert.ok(!forbidden.test(source), path.relative(new URL('.', root).pathname, file));
  }
});

test('public website copy retains identity and privacy information with direct wording', () => {
  const directory = new URL('deploy/pocketbase/pb_public/', root);
  for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.html'))) {
    const html = fs.readFileSync(new URL(name, directory), 'utf8');
    assert.ok(!forbidden.test(html), name);
  }
  const privacy = fs.readFileSync(new URL('privacy.html', directory), 'utf8');
  assert.ok(privacy.includes('独立运营'));
  assert.ok(privacy.includes('数据库管理员'));
  assert.ok(privacy.includes('发送给 ChatECNU'));
});

test('public pages keep administrative navigation separate', () => {
  const directory = new URL('deploy/pocketbase/pb_public/', root);
  for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.html') && name !== 'admin.html')) {
    const html = fs.readFileSync(new URL(name, directory), 'utf8');
    assert.ok(!/href=["'][^"']*(?:admin\.html|\/_\/)/.test(html), name);
  }
});

test('public product pages lead with campus projects and keep daily campus tools', () => {
  const directory = new URL('deploy/pocketbase/pb_public/', root);
  for (const name of ['index.html', 'features.html', 'community.html', 'about.html']) {
    const html = fs.readFileSync(new URL(name, directory), 'utf8');
    assert.match(html, /项目/);
    assert.match(html, /GitHub/);
    assert.doesNotMatch(html, /笔记|PDF|闪卡|思维导图|课程问答|AI 问答|AI 网关/);
  }
  const index = fs.readFileSync(new URL('index.html', directory), 'utf8');
  assert.match(index, /href="\/app\/">进入项目社区/);
  assert.match(index, /课表、课程通知和官方快速访问/);
  assert.match(index, /约球与扩列/);
  const community = fs.readFileSync(new URL('community.html', directory), 'utf8');
  assert.match(community, /每个项目独立申请华师大归属核验与上架审核/);
  assert.match(community, /社区互动属于 Campulse/);
});

test('feature tabs start with projects and retain matching accessibility targets', () => {
  const html = fs.readFileSync(new URL('deploy/pocketbase/pb_public/features.html', root), 'utf8');
  const tabs = [...html.matchAll(/<button id="(tab-[^"]+)" role="tab" aria-selected="(true|false)" aria-controls="([^"]+)" tabindex="(-?\d+)">/g)];
  assert.equal(tabs.length, 3);
  assert.deepEqual(tabs.map(([, , selected]) => selected), ['true', 'false', 'false']);
  assert.equal(tabs[0][3], 'projects');
  assert.equal(tabs[0][4], '0');
  for (const [, tab, , panel] of tabs) {
    assert.ok(html.includes(`id="${panel}" class="tab-panel" role="tabpanel" aria-labelledby="${tab}"`));
  }
  assert.match(html, /id="learning"/);
  assert.match(html, /课程通知/);
  assert.match(html, /校园广场/);
});
