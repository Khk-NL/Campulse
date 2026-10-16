import fs from 'node:fs';

const config = JSON.parse(
  fs.readFileSync(new URL('../apps/mobile/config/eduwork.production.example.json', import.meta.url), 'utf8'),
);
const pocketBase = new URL(config.POCKETBASE_URL);
const gateway = new URL(config.CAMPUS_EDUWORK_GATEWAY_URL);

if (pocketBase.protocol !== 'https:' || gateway.protocol !== 'https:') {
  throw new Error('生产 PocketBase 和 AI 网关必须使用 HTTPS');
}
if (pocketBase.host !== gateway.host || gateway.pathname !== '/ai') {
  throw new Error('生产 PocketBase 与 AI 网关必须指向同一站点，网关路径为 /ai');
}
if (pocketBase.hostname === 'campus.allezafrique.cn') {
  console.log(
    '::warning title=临时后端域名::APK 仍使用 campus.allezafrique.cn。正式域名恢复后，需同时改回 APK 配置和 PocketBase meta.appURL。',
  );
} else if (pocketBase.hostname !== 'campus.scsldr.cn') {
  throw new Error(`未核准的生产后端域名：${pocketBase.hostname}`);
}
