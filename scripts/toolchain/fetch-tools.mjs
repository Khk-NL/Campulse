/**
 * Campus 工具链下载器 / Campus toolchain downloader
 *
 * 使用 Node 下载并锁定精确工具版本，便于复现。开发入口见 docs/DEVELOPMENT.md。
 *
 * Node downloads pin exact tool versions for reproducible setup; see docs/DEVELOPMENT.md.
 *
 * 产物落在系统临时目录，并写一份 manifest
 * 到工作区，供解压步骤定位。
 *
 * Artifacts land in the OS temp dir, with a manifest inside the workspace so the extract step can
 * find them.
 *
 * 用法 / Usage:
 *   node scripts/toolchain/fetch-tools.mjs                 # 全部 / all
 *   node scripts/toolchain/fetch-tools.mjs postgresql gh   # 指定 / subset
 */
import { createWriteStream } from 'node:fs';
import { mkdir, writeFile, stat } from 'node:fs/promises';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const TEMP_ROOT = path.join(os.tmpdir(), 'campus-toolchain');
const MANIFEST_PATH = path.join(REPO_ROOT, '.tools', 'download-manifest.json');

/** 境内镜像，明显快于 storage.googleapis.com / China mirror, much faster than googleapis */
const FLUTTER_MIRROR = 'https://storage.flutter-io.cn/flutter_infra_release';

const log = (...a) => console.log('[fetch]', ...a);
const warn = (...a) => console.warn('[fetch][warn]', ...a);

function human(bytes) {
  if (!bytes) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

async function head(url) {
  try {
    const res = await fetch(url, { method: 'HEAD', redirect: 'follow' });
    return res.ok ? Number(res.headers.get('content-length') ?? 0) : -1;
  } catch {
    return -1;
  }
}

/** 依次探测候选 URL，返回第一个可用的 / probe candidates, return the first live one */
async function firstLive(candidates, label) {
  for (const url of candidates) {
    const size = await head(url);
    if (size >= 0) {
      log(`${label}: ${url} (${human(size)})`);
      return { url, size };
    }
    warn(`${label}: dead -> ${url}`);
  }
  throw new Error(`${label}: none of ${candidates.length} candidate URLs are live`);
}

function countingTransform(size, label, state) {
  return new Transform({
    transform(chunk, _enc, cb) {
      state.received += chunk.length;
      const now = Date.now();
      if (now - state.lastTick > 5000) {
        state.lastTick = now;
        const pct = size > 0 ? ` (${((state.received / size) * 100).toFixed(1)}%)` : '';
        log(`${label}: ${human(state.received)}${pct}`);
      }
      cb(null, chunk);
    },
  });
}

async function download({ name, url, size }) {
  await mkdir(TEMP_ROOT, { recursive: true });
  const dest = path.join(TEMP_ROOT, `${name}.zip`);

  const existing = await stat(dest).catch(() => null);
  if (existing && size > 0 && existing.size === size) {
    log(`${name}: already complete, skipping (${human(existing.size)})`);
    return dest;
  }

  log(`${name}: downloading -> ${dest}`);
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok || !res.body) throw new Error(`${name}: HTTP ${res.status}`);

  const state = { received: 0, lastTick: Date.now() };
  await pipeline(
    Readable.fromWeb(res.body),
    countingTransform(size, name, state),
    createWriteStream(dest),
  );

  const done = await stat(dest);
  log(`${name}: done ${human(done.size)}`);
  return dest;
}

async function resolveFlutter() {
  const res = await fetch(`${FLUTTER_MIRROR}/releases/releases_windows.json`);
  if (!res.ok) throw new Error(`releases.json HTTP ${res.status}`);
  const data = await res.json();
  const release = data.releases.find((r) => r.hash === data.current_release?.stable);
  if (!release) throw new Error('stable release not found in releases.json');
  const url = `${FLUTTER_MIRROR}/releases/${release.archive}`;
  const size = await head(url);
  if (size < 0) throw new Error(`archive not reachable: ${url}`);
  log(`flutter: stable ${release.version} (${human(size)})`);
  return { name: 'flutter', url, size, version: release.version };
}

async function resolveGh() {
  // 不走 api.github.com：未认证请求会 403 限流。改为读 /releases/latest 的 302 Location。
  // Avoid api.github.com: unauthenticated requests get rate-limited with a 403.
  // Read the 302 Location of /releases/latest instead.
  const res = await fetch('https://github.com/cli/cli/releases/latest', { redirect: 'manual' });
  const location = res.headers.get('location');
  const tag = location?.split('/').filter(Boolean).pop();
  if (!tag || !/^v\d/.test(tag)) {
    throw new Error(`could not resolve latest tag (status ${res.status}, location ${location})`);
  }
  const version = tag.replace(/^v/, '');
  const url = `https://github.com/cli/cli/releases/download/${tag}/gh_${version}_windows_amd64.zip`;
  const size = await head(url);
  if (size < 0) throw new Error(`asset not reachable: ${url}`);
  log(`gh: ${tag} (${human(size)})`);
  return { name: 'gh', url, size, version: tag };
}

async function resolvePostgres() {
  const live = await firstLive(
    [
      'https://get.enterprisedb.com/postgresql/postgresql-16.10-1-windows-x64-binaries.zip',
      'https://get.enterprisedb.com/postgresql/postgresql-16.9-1-windows-x64-binaries.zip',
      'https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64-binaries.zip',
    ],
    'postgresql',
  );
  return { name: 'postgresql', ...live };
}

async function resolveAndroidCmdlineTools() {
  const live = await firstLive(
    [
      'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip',
      'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip',
      'https://dl.google.com/android/repository/commandlinetools-win-10406996_latest.zip',
    ],
    'android-cmdline-tools',
  );
  return { name: 'android-cmdline-tools', ...live };
}

const RESOLVERS = [
  ['postgresql', resolvePostgres],
  ['flutter', resolveFlutter],
  ['android-cmdline-tools', resolveAndroidCmdlineTools],
  ['gh', resolveGh],
];

async function main() {
  await mkdir(path.dirname(MANIFEST_PATH), { recursive: true });
  log(`temp root : ${TEMP_ROOT}`);
  log(`repo root : ${REPO_ROOT}`);

  const only = process.argv.slice(2).filter((a) => !a.startsWith('-'));
  const results = [];

  for (const [name, resolve] of RESOLVERS) {
    if (only.length && !only.includes(name)) continue;
    try {
      const spec = await resolve();
      const file = await download(spec);
      results.push({ ...spec, file });
    } catch (err) {
      warn(`${name}: FAILED - ${err.message}`);
      results.push({ name, error: String(err.message ?? err) });
    }
  }

  const manifest = {
    generatedAt: new Date().toISOString(),
    tempRoot: TEMP_ROOT,
    artifacts: results,
  };
  await writeFile(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  log(`manifest  : ${MANIFEST_PATH}`);

  const failed = results.filter((r) => r.error);
  log(`summary   : ${results.length - failed.length}/${results.length} ok`);
  for (const f of failed) warn(`  ${f.name}: ${f.error}`);
  if (failed.length) process.exitCode = 1;
}

await main();
