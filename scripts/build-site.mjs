import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

const root = path.resolve(import.meta.dirname, '../deploy/pocketbase/pb_public');
const github = 'https://github.com/Khk-NL/Campulse';
const assetVersion = (name) => createHash('sha256').update(fs.readFileSync(path.join(root, 'assets', name))).digest('hex').slice(0, 10);
const routes = [['index.html', '首页'], ['features.html', '功能'], ['community.html', '校园共建'], ['about.html', '关于项目'], ['download.html', '下载']];
const eyebrow = (text) => `<div class="eyebrow">${text}</div>`;
const button = (url, text, secondary = false) => `<a class="button${secondary ? ' secondary' : ''}" href="${url}">${text}<span aria-hidden="true">↗</span></a>`;
const heading = (tag, title, description) => `<div class="page-heading reveal">${eyebrow(tag)}<h1>${title}</h1><p class="lead">${description}</p></div>`;
const cards = (items) => `<div class="grid">${items.map(([n, h, p]) => `<section class="panel reveal"><small>${n}</small><h3>${h}</h3><p>${p}</p></section>`).join('')}</div>`;

function page(file, title, body) {
 return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="Campulse：面向华东师范大学的校园项目共享社区，发现学生作品、交流问题、连接源码与贡献者。"><meta name="theme-color" content="#fbf9f7"><title>${title} · Campulse</title><link rel="icon" href="/assets/favicon.png"><link rel="stylesheet" href="/assets/site.css?v=${assetVersion('site.css')}"><script src="/assets/site.js?v=${assetVersion('site.js')}" defer></script></head><body><a class="skip-link" href="#main">跳到正文</a><header><a class="brand" href="/"><img src="/assets/campulse-logo.png" alt="" width="42" height="42">Campulse</a><nav aria-label="主导航">${routes.map(([f, t]) => `<a href="/${f === 'index.html' ? '' : f}" ${f === file ? 'aria-current="page"' : ''}>${t}</a>`).join('')}</nav><a class="header-source" href="${github}" aria-label="查看 GitHub 源码">GitHub ↗</a></header><main id="main">${body}</main><footer><div><a class="brand" href="/">Campulse<span class="brand-dot"></span></a><p>发现同学的作品，参与校园里的开发与交流。</p><small>独立开发 · 华东师范大学适配</small></div><div class="footer-links"><a href="/about.html">关于项目</a><a href="/privacy.html">隐私说明</a><a href="${github}">GitHub</a><a href="mailto:kongb3124@qq.com">联系开发者</a><small>© 2026 Campulse</small></div></footer></body></html>`;
}

const pages = {
 'index.html': ['校园项目共享社区', `
<section class="hero">
 <div class="hero-copy reveal">
  ${eyebrow('CAMPUS CODE. SHARED IDEAS.')}
  <h1>校园里的代码，<br><em>在这里相遇。</em></h1>
  <p class="lead">发现华师大学生的项目，收藏好用的工具，<br class="desktop-break">把问题和想法留给正在做它的人。</p>
  <div class="actions">${button('/app/', '进入项目社区')}${button('/community.html', '了解校园共建', true)}</div>
  <p class="release-note"><span class="status-dot"></span> Web · Android · Windows 预览版</p>
 </div>
 <div class="hero-art" aria-label="校园项目、源码与讨论的连接">
  <div class="orbit orbit-one"></div><div class="orbit orbit-two"></div><div class="orbit orbit-three"></div>
  <div class="logo-disc"><img src="/assets/campulse-logo.png" alt="Campulse 标志" width="512" height="512"></div>
  <span class="orbit-label label-one">探索同学的项目</span><span class="orbit-label label-two">Star 与 Issue 讨论</span><span class="orbit-label label-three">找到源码与作者</span>
  <span class="spark spark-one"></span><span class="spark spark-two"></span>
 </div>
 <a class="scroll-cue" href="#why">继续探索 <span aria-hidden="true">↓</span></a>
</section>
<section class="statement section" id="why">
 <div class="reveal">${eyebrow('WHY CAMPULSE')}<h2>你的项目，<br>也许正好帮到同校的人。</h2></div>
 <div class="reveal"><p class="lead">选课脚本、课程设计、开源工具。写完之后，把项目带到同学面前，听听他们怎么用、遇到了什么问题。</p><p>Campulse 把学生项目放在首页。个人仓库整理自己的作品，每个项目独立提交华师大归属核验与上架审核，通过后进入校园探索和搜索。</p><a class="text-link" href="/features.html#projects">查看项目社区功能 →</a></div>
</section>
<section class="section community-banner reveal">
 ${eyebrow('CAMPUS GITHUB')}<h2>校园的 GitHub，<br>从一个项目开始。</h2><p>在 Campulse 关注项目、发起 Issue 式讨论和回复，通过项目的 GitHub 链接阅读源码、参与代码协作。Star 和讨论保存在 Campulse 社区。</p>${button('/app/', '发现校园作品')}
</section>
<section class="section split">
 <div class="reveal">${eyebrow('CAMPUS, STILL CONNECTED')}<h2>做项目之外，<br>也照顾校园日常。</h2><p>课表、课程通知和官方快速访问放在辅助入口。校园广场保留竞赛组队、约球与扩列，方便在同一个校园找到伙伴。</p></div>
 <div class="progress-card reveal"><span class="pill">当前 · 预览版</span><h3>从这里开始</h3><ul class="plain-list"><li>探索项目，收藏感兴趣的作品</li><li>建立个人仓库，逐项目提交审核</li><li>在讨论中提问题、交流进展</li></ul><a class="text-link" href="/download.html">选择浏览器或客户端 →</a></div>
</section>`],
 'features.html': ['功能', `
${heading('PROJECTS FIRST', '先看到作品，<br>再开始交流。', '项目探索与个人仓库是主线，校园日常留在需要时能找到的位置。')}
<section class="feature-switcher reveal">
 <div class="tabs" role="tablist" aria-label="功能分类">
  <button id="tab-projects" role="tab" aria-selected="true" aria-controls="projects" tabindex="0">项目社区</button>
  <button id="tab-services" role="tab" aria-selected="false" aria-controls="services" tabindex="-1">校园日常</button>
  <button id="tab-learning" role="tab" aria-selected="false" aria-controls="learning" tabindex="-1">课表与通知</button>
 </div>
 <div id="projects" class="tab-panel" role="tabpanel" aria-labelledby="tab-projects">
  <div class="feature-title"><span class="feature-number">01</span><div><h2>分享项目，<br>找到使用者和同行。</h2><p>浏览通过审核的校园作品，按分类与关键词探索。项目详情集中展示介绍、使用入口、GitHub 源码链接和社区交流。</p></div></div>
  ${cards([['自己的作品','个人仓库与审核','建立项目、绑定 GitHub，每个项目独立提交华师大归属核验与上架审核，并查看审核状态。'],['持续关注','Star 与快速访问','Star 保存在 Campulse；已上架项目还可以加入个人快速入口，方便再次使用。'],['一起改进','Issue 式讨论与回复','围绕项目提出问题、交流需求、回复进展。讨论与回复直接参与，项目上架按审核流程处理。']])}
  <p class="fine-print">源码访问和代码协作通过项目绑定的 GitHub 仓库进行；Campulse 保存项目介绍、审核状态及社区互动。</p>
 </div>
 <div id="services" class="tab-panel" role="tabpanel" aria-labelledby="tab-services" hidden>
  <div class="feature-title"><span class="feature-number">02</span><div><h2>保留顺手的入口，<br>也保留见面的机会。</h2><p>官方小程序、学校网站统一整理到快速访问。校园广场容纳日常召集，找队友、约球和扩列都可以在这里交流。</p></div></div>
  ${cards([['官方入口','搜索与分类','按服务名称查找学校网站和小程序，打开后在对应服务完成登录与操作。'],['个人常用','收藏与快捷访问','收藏官方服务和校园作品，把常用入口放在手边。'],['校园广场','组队、约球与扩列','查看召集详情，报名参与，并在自己的报名列表继续跟进。']])}
 </div>
 <div id="learning" class="tab-panel" role="tabpanel" aria-labelledby="tab-learning" hidden>
  <div class="feature-title"><span class="feature-number">03</span><div><h2>看清这周的课，<br>及时收到课程消息。</h2><p>保留课程列表、课程表与课程通知。课程安排作为校园辅助功能，与项目社区共用账号。</p></div></div>
  ${cards([['安排','课程表与 CSV 导入','预览导入内容，检查重复课程与时间冲突。'],['课程','课程列表','按课程查看教师、教室与时间安排。'],['消息','课程通知','集中查看课程相关公告与提醒，继续处理日常待办。']])}
 </div>
</section>
<section class="section cta reveal"><h2>先看看同学们在做什么。</h2>${button('/app/', '进入项目社区')}</section>`],
 'community.html': ['校园共建', `
${heading('BUILT BY STUDENTS', '把自己的项目，<br>带到同学面前。', '从一次试用、一条问题反馈开始，找到一起完善作品的人。')}
<section class="section manifesto reveal"><span class="large-quote" aria-hidden="true">“</span><h2>好用的校园工具，<br>值得有一个交流的地方。</h2><p>Campulse 是校园项目共享社区。发现作品、认识作者，再围绕具体项目讨论需求和问题。社区互动属于 Campulse，源码通过项目绑定的 GitHub 链接访问。</p></section>
${cards([['FOR BUILDERS','整理自己的仓库','创建项目并填写介绍、使用入口与 GitHub 链接。个人仓库展示自己的各个项目，也记录每一项的审核状态。'],['FOR CAMPUS','逐项目提交审核','每个项目独立申请华师大归属核验与上架审核，通过后进入校园作品、搜索和探索。'],['FOR EVERYONE','在项目中交流','Star 感兴趣的作品，发起 Issue 式讨论并回复。讨论与回复直接参与，反馈可以留在对应项目。']])}
<section class="section split"><div class="reveal">${eyebrow('MEET ON CAMPUS')}<h2>写代码，也找伙伴。</h2><p>校园广场保留竞赛组队、约球和扩列。项目交流围绕作品展开，日常召集在广场继续。</p></div><div class="join-card reveal">${button('/app/', '进入 Campulse 社区')}${button(github, '阅读 Campulse 源码', true)}<a class="text-link" href="${github}/issues">向 Campulse 开发者反馈 →</a></div></section>`],
 'about.html': ['关于项目', `
${heading('A SMALL TEAM, A CLEAR FOCUS', '把校园代码共享，<br>做得更顺手。', 'Campulse 是面向华东师范大学的独立校园项目社区，现阶段以预览版持续开发。')}
<section class="section split"><div class="reveal">${eyebrow('OUR STARTING POINT')}<h2>从找入口，<br>到找同学的作品。</h2></div><div class="reveal"><p class="lead">项目最初从聚合校园小程序和网站出发。做着做着，我们更想解决的是：同学写出的工具，怎样被同校的人找到，又怎样获得具体反馈。</p><p>现在把项目探索、个人仓库与讨论放到中心。课表、课程通知和官方快速访问保留为辅助功能，校园广场继续承接组队和日常交流。</p><p>视觉参考华东师范大学配色规范，产品使用 Campulse 自有标志，由项目开发者独立运营。</p></div></section>
<section class="section" id="progress">${eyebrow('PRODUCT FOCUS')}<h2 class="reveal">围绕一次真实的项目交流。</h2><div class="timeline">
 <section class="reveal"><span class="pill">创作</span><h3>先整理自己的项目</h3><p>在个人仓库填写介绍和使用入口，关联 GitHub 源码链接，再为需要公开的项目独立提交审核。</p></section>
 <section class="reveal"><span class="pill outlined">发现</span><h3>让校园作品被找到</h3><p>通过华师大归属核验与上架审核的项目进入校园作品、搜索和探索，供同学浏览、Star 和使用。</p></section>
 <section class="reveal"><span class="pill outlined">交流</span><h3>把反馈留在项目里</h3><p>Issue 式讨论和回复记录问题、建议与处理进展。源码阅读与代码贡献沿着项目的 GitHub 链接继续。</p></section>
</div></section>
<section class="section" id="architecture">${eyebrow('HOW IT WORKS')}<h2 class="reveal">社区数据与源码，各有去处。</h2><div class="architecture reveal"><div><b>Web · Android · Windows</b><span>项目探索 · 个人仓库 · 校园辅助</span></div><span aria-hidden="true">→</span><div><b>PocketBase</b><span>账号 · 项目审核 · Star 与讨论</span></div><span aria-hidden="true">↗</span><div><b>GitHub</b><span>项目源码 · 代码协作</span></div></div><p>各端通过 HTTPS 访问同一套 Campulse 数据。学校网站、小程序与 GitHub 继续使用各自的账号与权限。开发记录和实际验收结果维护在项目文档中。</p><a class="text-link" href="/privacy.html">阅读隐私与数据说明 →</a></section>`],
 'download.html': ['下载', `
${heading('WEB & CLIENT PREVIEW', '在电脑上发现，<br>在手机上继续。', '浏览器即可进入 Campulse，Android 与 Windows 安装包通过 GitHub 自动构建发布。具体版本、构建状态与校验信息以发布页为准。')}
<div class="download-box reveal"><img src="/assets/campulse-logo.png" alt="" width="100" height="100"><div><span class="pill">Web · Android · Windows</span><h2>Campulse 预览版</h2><p>选择适合自己的方式，使用同一套账号与社区数据。</p></div>${button('/app/', '打开 Web 版')}</div>
<section class="section">${eyebrow('GET STARTED')}${cards([['浏览器','打开即用','在浏览器进入项目社区，登录后继续管理仓库、Star 和讨论。'],['客户端','GitHub 下载','Android 与 Windows 预览包、版本说明及文件校验信息均在 GitHub Releases 提供。'],['反馈','告诉我们具体场景','反馈时附上客户端版本、操作步骤和错误现象，提交前隐去账号凭据及他人隐私。']])}<div class="actions">${button(`${github}/releases/tag/campulse-preview`, '前往 GitHub 下载')}${button(`${github}/issues`, '提交体验反馈', true)}</div></section>`]
};

for (const [file, [title, body]] of Object.entries(pages)) fs.writeFileSync(path.join(root, file), page(file, title, body));
const privacyPath = path.join(root, 'privacy.html');
let privacy = fs.readFileSync(privacyPath, 'utf8').match(/<main[^>]*>([\s\S]*?)<\/main>/)?.[1];
if (!privacy) throw new Error('隐私说明正文缺失');
privacy = privacy.replace(/^<a href="\/">[\s\S]*?<\/a>/, '').replace(/^<article class="privacy">([\s\S]*)<\/article>$/, '$1');
fs.writeFileSync(privacyPath, page('privacy.html', '隐私说明', `<article class="privacy">${privacy}</article>`));
for (const [file, target] of [['hub.html', 'features.html#projects'], ['course.html', 'features.html#learning'], ['workflow.html', 'about.html#architecture']]) {
 fs.writeFileSync(path.join(root, file), `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=/${target}"><title>页面已合并 · Campulse</title></head><body><a href="/${target}">前往新版页面</a></body></html>`);
}
console.log('Generated Campulse project-first website and preserved legacy links.');
