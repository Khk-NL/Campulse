import { AdminClient, collections, sections, workspaceViews, editableFields, isMultilineField, workspaceSummary } from './admin-client.mjs?v=20261016-review';

const client = new AdminClient(), $ = id => document.getElementById(id);
const labels = { owner:'用户 ID', courseId:'课程 ID', title:'标题', content:'正文', email:'邮箱', verified:'邮箱已验证', emailVisibility:'邮箱可见', name:'名称', payload:'内容数据', schemaVersion:'数据版本', front:'卡片正面', back:'卡片背面', due:'下次复习', scheduler:'排程数据', reviewHistory:'复习记录', attachment:'附件', kind:'类型', published:'公开发布', demo:'演示标记', universityId:'学校 ID', noteId:'笔记 ID', body:'正文', message:'报名留言', bio:'个人介绍', interests:'兴趣与技能', displayName:'显示名称', campus:'校区', location:'活动地点', tags:'标签', startsAt:'开始时间', status:'状态', post:'所属召集' };
let page = 1, totalPages = 1, version = 0, busy = false, editing = null, deleting = null;
let reviewing = null;
let activeView = 'users';
let selectedUser = null;
const navIcons = { users:'users', courses:'book', notes:'note', cards:'cards', artifacts:'spark', timetable:'calendar', plans:'check', notifications:'bell', tasks:'check', repositories:'repo', incomingDiscussions:'chat', incomingReplies:'chat', community:'repo', discussions:'chat', replies:'chat', stars:'star', favorites:'star', reviews:'shield', miniPrograms:'grid', websites:'globe', announcements:'bell', events:'calendar', squarePosts:'calendar', squareFeed:'users', squareInterests:'check', squareReceivedInterests:'users', squareReplies:'chat', squareProfiles:'users' };
function icon(name) {
  const node = document.createElementNS('http://www.w3.org/2000/svg', 'svg'), use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
  node.classList.add('icon'); node.setAttribute('aria-hidden', 'true'); use.setAttribute('href', '#icon-' + name); node.append(use); return node;
}
function setSidebarVisible(visible) {
  if (matchMedia('(max-width:760px)').matches) {
    document.body.classList.toggle('sidebar-open', visible);
    document.body.classList.remove('sidebar-collapsed');
  } else {
    document.body.classList.toggle('sidebar-collapsed', !visible);
    document.body.classList.remove('sidebar-open');
  }
  $('sidebar-toggle').setAttribute('aria-expanded', String(visible));
}
const reviewLabel = state => ({ draft: '待提交', pending: '待审核', approved: '已审核', rejected: '待修改' })[state] || '待提交';
const labelFor = name => collections[name] || name;
Object.assign(labels, { reviewState: '审核状态', schoolProof: '华师大归属材料', schoolVerified: '学校归属已核验', reviewNote: '审核意见', repository: '项目仓库', discussion: '讨论', visibility: '可见范围' });
let messageTimer;
function message(text, persistent = false) {
  clearTimeout(messageTimer); $('message').textContent = text;
  if (!persistent) messageTimer = setTimeout(() => { $('message').textContent = ''; }, 6000);
}
function signedOut() {
  version++; client.logout(); $('dashboard').hidden = true; $('login').hidden = false;
  activeView = 'users'; $('course-context').value = ''; $('user-context').textContent = '选择用户';
  selectedUser = null;
  document.body.classList.remove('authenticated', 'sidebar-open', 'sidebar-collapsed');
  $('rows').replaceChildren(); $('detail-text').textContent = ''; $('detail').hidden = true;
  for (const id of ['app-dialog','record-dialog','delete-dialog','review-dialog']) $(id).close();
  for (const id of ['app-form','record-form','delete-form','review-form']) $(id).reset();
  reviewing = null; $('review-state').value = ''; $('review-material').textContent = '';
  $('owner').value = ''; $('search').value = ''; editing = deleting = null;
}
async function run(action) {
  if (busy) return;
  busy = true;
  document.body.classList.add('busy'); $('workspace').setAttribute('aria-busy', 'true'); $('request-status').textContent = '同步中…';
  let failed = false;
  for (const control of document.querySelectorAll('button,input,select,textarea')) control.disabled = true;
  try { await action(); }
  catch (error) { failed = true; message(error.message || '请求失败，请稍后重试', true); if (!client.token) signedOut(); }
  finally {
    busy = false;
    document.body.classList.remove('busy'); $('workspace').setAttribute('aria-busy', 'false'); $('request-status').textContent = failed ? '请重试' : '已连接';
    for (const control of document.querySelectorAll('button,input,select,textarea')) control.disabled = false;
    syncView(); $('previous').disabled = page <= 1; $('next').disabled = page >= totalPages;
  }
}
function button(label, action, style = 'quiet') {
  const node = document.createElement('button'); node.type = 'button'; node.textContent = label; node.className = style;
  const actionIcon = { '查看':'note', '编辑':'note', '审核申请':'shield', '打开工作区':'users', '课程内容':'book', '发布':'arrow', '作品设置':'grid' }[label];
  if (actionIcon) node.prepend(icon(actionIcon));
  if (label === '删除') node.dataset.destructive = 'true';
  node.addEventListener('click', () => run(action)); return node;
}
async function selectCollection(name) {
  $('collection').value = name; page = 1; $('search').value = ''; $('kind').value = ''; $('review-state').value = name === 'forge_repositories' ? 'pending' : ''; syncView(); await refresh();
}
async function selectView(id) {
  activeView = id;
  if (matchMedia('(max-width:760px)').matches) setSidebarVisible(false);
  await selectCollection(workspaceViews[id].collection);
}
function renderCatalog() {
  $('collection').replaceChildren(); $('sections').replaceChildren();
  const common = document.createElement('optgroup'); common.label = '常用分区';
  const other = document.createElement('optgroup'); other.label = '数据库集合';
  for (const [name, schema] of client.schemas) {
    const option = document.createElement('option'); option.value = name;
    option.textContent = labelFor(name) + (schema.type === 'view' ? ' · 视图' : '');
    (collections[name] ? common : other).append(option);
  }
  $('collection').append(common, other);
  const leaf = (parent, id) => {
    const view = workspaceViews[id];
    if (!client.schemas.has(view.collection)) return;
    const node = button(view.label, () => selectView(id)); node.prepend(icon(navIcons[id] || 'grid')); node.dataset.view = id; parent.append(node);
  };
  const branch = (parent, label, open = false, symbol = 'grid') => {
    const node = document.createElement('details'), title = document.createElement('summary');
    node.open = open; title.textContent = label; title.dataset.label = label; title.prepend(icon(symbol)); node.append(title); parent.append(node); return node;
  };
  const user = branch($('sections'), '用户工作区', true, 'users'); leaf(user, 'users');
  const learning = branch(user, '学习', true, 'book'), course = branch(learning, '课程', false, 'book');
  for (const id of ['courses','notes','cards','artifacts']) leaf(course, id);
  for (const id of ['timetable','plans','notifications','tasks']) leaf(learning, id);
  const forge = branch(user, '校园 GitHub', false, 'repo'), own = branch(forge, '个人仓库', false, 'repo');
  for (const id of ['repositories','incomingDiscussions','incomingReplies']) leaf(own, id);
  const community = branch(forge, '社区项目仓库', false, 'repo');
  for (const id of ['community','discussions','replies','stars']) leaf(community, id);
  leaf(user, 'favorites');
  const square = branch(user, '校园广场', false, 'users');
  for (const id of ['squarePosts', 'squareInterests', 'squareReceivedInterests', 'squareReplies', 'squareProfiles']) leaf(square, id);
  const directory = branch($('sections'), '公共快速访问', true, 'globe');
  leaf(directory, 'miniPrograms'); leaf(directory, 'websites');
  const operations = branch($('sections'), '公共内容与审核', false, 'shield');
  for (const id of ['announcements','events','reviews','squareFeed']) leaf(operations, id);
  $('collection').value = client.schemas.has('users') ? 'users' : client.schemas.keys().next().value;
  $('collection-count').textContent = String(client.schemas.size);
}
function ownerName(row) { return row.expand?.owner?.email || row.owner || row.email || row.kind || '公开目录'; }
function showDetail(row) {
  const visible = { ...row }; for (const key of ['expand','password','tokenKey']) delete visible[key];
  const name = $('collection').value;
  if (name === 'course_notes') $('detail-text').textContent = `${row.title}\n课程：${row.courseId}\n用户：${ownerName(row)}\n更新时间：${row.updated}\n\n${row.content || '请添加笔记正文'}`;
  else if (name === 'study_workspaces') {
    const activities = Array.isArray(row.payload?.activities) ? row.payload.activities : [];
    $('detail-text').textContent = workspaceSummary(row) + '\n\n' + activities.map(activity => `${activity.completedAt != null ? '已完成' : '待办'} · ${activity.title}\n${activity.objective || ''}\n截止：${activity.deadline || '灵活安排'}`).join('\n\n');
  } else $('detail-text').textContent = JSON.stringify(visible, null, 2);
  $('detail').hidden = false;
  $('detail').scrollIntoView({ block: 'nearest', behavior: matchMedia('(prefers-reduced-motion:reduce)').matches ? 'auto' : 'smooth' });
}
function openApp(row = {}) {
  $('app-form').reset(); $('app-message').textContent = '';
  const form = $('app-form'), payload = row.payload || {};
  for (const [key, value] of Object.entries({ id:row.id || '', name:payload.name || '', developerName:payload.developerName || '', url:payload.launchTarget?.url || '', repository:payload.repositoryUrl || '', description:payload.description || '', tags:(payload.tags || []).join(', ') })) form.elements.namedItem(key).value = value;
  form.elements.namedItem('published').checked = row.published ?? false; $('app-dialog').showModal();
}
function inputFor(field, value, row) {
  let input;
  if (field.type === 'select' && field.maxSelect <= 1) {
    input = document.createElement('select');
    for (const value of ['', ...(field.values || [])]) { const option = document.createElement('option'); option.value = value; option.textContent = value || '请选择'; input.append(option); }
  } else if (isMultilineField(field)) {
    input = document.createElement('textarea'); input.rows = field.type === 'json' ? 7 : 5;
  } else input = document.createElement('input');
  input.name = field.name; input.dataset.type = field.type;
  if (field.type === 'bool') { input.type = 'checkbox'; input.checked = Boolean(value); }
  else if (field.type === 'file') { input.type = 'file'; input.multiple = field.maxSelect > 1; if (field.mimeTypes?.length) input.accept = field.mimeTypes.join(','); }
  else {
    if (['email','url','number'].includes(field.type)) input.type = field.type;
    if (field.type === 'number') input.step = 'any';
    input.value = typeof value === 'object' && value !== null ? JSON.stringify(value, null, 2) : value ?? (field.type === 'json' ? '{}' : '');
  }
  input.required = Boolean(field.required && !['bool','file'].includes(field.type));
  if (field.type === 'file' && field.required && !row.id) input.required = true;
  return input;
}
function readForm() {
  const form = $('record-form'), data = {};
  for (const field of editing.fields) {
    const input = form.elements.namedItem(field.name);
    if (field.type === 'file') continue;
    if (field.type === 'bool') data[field.name] = input.checked;
    else if (field.type === 'number') { if (input.value !== '') data[field.name] = Number(input.value); }
    else if (['json','geoPoint'].includes(field.type) || field.maxSelect > 1) {
      try { data[field.name] = input.value.trim() ? JSON.parse(input.value) : null; }
      catch { throw new Error(`${labels[field.name] || field.name}：请填写有效 JSON`); }
    } else data[field.name] = input.value;
  }
  if (!editing.id && editing.schema.type === 'auth') {
    data.password = form.elements.namedItem('password').value; data.passwordConfirm = form.elements.namedItem('passwordConfirm').value;
    if (data.password !== data.passwordConfirm) throw new Error('两次密码请保持一致');
  }
  return data;
}
async function openRecord(row = {}) {
  const name = $('collection').value, schema = client.schemas.get(name);
  if (schema.type === 'view') return showDetail(row);
  const record = row.id ? await client.getRecord(name, row.id) : {};
  editing = { name, schema, id:record.id || '', fields:editableFields(schema) };
  $('record-form').reset(); $('record-fields').replaceChildren(); $('record-message').textContent = '';
  $('record-title').textContent = (record.id ? '编辑' : '新增') + labelFor(name);
  $('record-context').textContent = `${name}${record.id ? ' · ' + record.id : ''} · 保存到当前云端数据库`;
  for (const field of editing.fields) {
    const label = document.createElement('label'); label.textContent = labels[field.name] || field.name;
    if (field.type === 'file' || isMultilineField(field)) label.className = 'wide';
    const view = workspaceViews[activeView];
    const defaults = { owner: view?.personal ? $('owner').value : '', courseId: $('course-context').value, universityId: 'ecnu', schemaVersion: 1, kind: view?.kind || view?.globalKind || (view?.target ? 'service' : undefined), payload: view?.target ? { name: '', origin: 'official', isOfficial: true, status: 'active', launchTarget: { type: view.target } } : undefined };
    const value = record[field.name] ?? defaults[field.name];
    const input = inputFor(field, value, record); label.append(input);
    const hint = document.createElement('small'); hint.className = 'field-help';
    hint.textContent = field.type === 'file' ? `当前附件：${[].concat(record[field.name] || []).filter(Boolean).join('、') || '选择文件上传'}${field.maxSize ? ' · 上限 ' + (field.maxSize / 1048576).toFixed(1) + ' MB' : ''}` : field.type === 'relation' ? `关联集合：${client.schemas.get(field.collectionId)?.name || [...client.schemas.values()].find(s=>s.id===field.collectionId)?.name || field.collectionId}` : field.type === 'date' ? '日期格式：YYYY-MM-DD HH:mm:ss，可包含时区' : field.type;
    label.append(hint); $('record-fields').append(label);
  }
  if (!record.id && schema.type === 'auth') {
    for (const [name,labelText] of [['password','登录密码'],['passwordConfirm','确认密码']]) {
      const label = document.createElement('label'); label.textContent = labelText;
      const input = document.createElement('input'); input.name = name; input.type = 'password'; input.required = true; input.autocomplete = 'new-password'; label.append(input); $('record-fields').append(label);
    }
  }
  $('record-json').value = JSON.stringify(readForm(), null, 2); $('json-options').open = false; $('record-dialog').showModal();
}
async function refresh() {
  const generation = ++version, name = $('collection').value;
  if (workspaceViews[activeView]?.personal && !$('owner').value.trim()) {
    $('rows').replaceChildren(); renderEmpty('从用户列表打开个人工作区，或填写用户 ID'); $('record-count').textContent = '0'; $('summary').textContent = '选择用户后查看个人内容';
    totalPages = 1; $('page').textContent = '1 / 1'; $('detail').hidden = true; return;
  }
  const data = await client.list(name, { page, owner:$('owner').value.trim(), search:$('search').value, kind:activeView ? '' : $('kind').value, reviewState:activeView ? '' : $('review-state').value, view:activeView, courseId:$('course-context').value.trim() });
  if (generation !== version) return;
  $('detail').hidden = true; $('detail-text').textContent = ''; $('rows').replaceChildren(); totalPages = Math.max(1, data.totalPages || 1);
  $('summary').textContent = `${labelFor(name)} · ${data.totalItems} 条记录`; $('record-count').textContent = String(data.totalItems); $('page').textContent = `${page} / ${totalPages}`;
  $('refreshed-at').textContent = '更新于 ' + new Date().toLocaleTimeString('zh-CN');
  for (const row of data.items) {
    const tr = document.createElement('tr'), status = name === 'forge_repositories' ? reviewLabel(row.reviewState) : name === 'campus_content' ? row.published ? '已发布' : '草稿' : name === 'users' ? row.verified ? '已验证' : '待验证' : name === 'study_workspaces' ? workspaceSummary(row) : row.due || row.updated || '云端已保存';
    const title = row.title || row.payload?.name || row.name || row.email || row.front || row.entryKey || row.id;
    const titleCell = document.createElement('td'), line = document.createElement('div'), avatar = document.createElement('span'), titleText = document.createElement('span'), meta = document.createElement('div');
    line.className = 'record-title'; avatar.className = 'record-avatar'; avatar.append(name === 'users' ? document.createTextNode(title.slice(0,1).toUpperCase()) : icon(navIcons[activeView] || 'note')); titleText.textContent = title; line.append(avatar, titleText);
    meta.className = 'record-meta'; meta.textContent = row.id; titleCell.append(line, meta); tr.append(titleCell);
    const ownerCell = document.createElement('td'); ownerCell.textContent = ownerName(row); tr.append(ownerCell);
    const statusCell = document.createElement('td'), badge = document.createElement('span'); badge.className = 'badge'; badge.textContent = status; badge.dataset.status = row.reviewState || (row.verified ? 'verified' : row.published ? 'approved' : 'saved'); statusCell.append(badge); tr.append(statusCell);
    const actions = document.createElement('td'); actions.append(button('查看', async () => showDetail(row)));
    if (name === 'forge_repositories') {
      if (row.reviewState === 'pending') actions.append(button('审核申请', async () => {
        const latest = await client.getRecord(name, row.id);
        if (latest.reviewState !== 'pending') { await refresh(); message('项目状态已更新，请刷新后查看'); return; }
        reviewing = latest.id; $('review-form').reset(); $('review-message').textContent = '';
        $('review-context').textContent = `${latest.name} · ${ownerName(row)} · ${latest.id}`;
        $('review-material').textContent = `学校：${latest.universityId}\nGitHub：${latest.repositoryUrl || '选填'}\n\n简介\n${latest.summary || ''}\n\n华师大归属材料\n${latest.schoolProof || ''}\n\nREADME\n${latest.readme || ''}`;
        $('review-dialog').showModal();
      }, 'secondary'));
    }
    if (client.schemas.get(name).type !== 'view') {
      actions.append(button('编辑', async () => openRecord(row)));
      actions.append(button('删除', async () => { deleting = { name, id:row.id }; $('delete-form').reset(); $('delete-message').textContent = ''; $('delete-context').textContent = `${labelFor(name)} · ${row.id}`; $('delete-dialog').showModal(); }, 'quiet'));
    }
    if (name === 'users') actions.append(button('打开工作区', async () => { selectedUser = { id: row.id, name: row.name || row.email || row.id }; $('owner').value = row.id; $('course-context').value = ''; await selectView('courses'); }));
    if (name === 'user_courses') actions.append(button('课程内容', async () => { $('course-context').value = row.id; await selectView('notes'); }));
    if (name === 'campus_content') {
      if (row.kind === 'app') actions.append(button('作品设置', async () => openApp(row), 'secondary'));
      actions.append(button(row.published ? '转为草稿' : '发布', async () => { await client.setPublished(row.id, !row.published); await refresh(); message('目录状态已更新'); }, 'secondary'));
    }
    tr.append(actions); $('rows').append(tr);
  }
  if (!data.items.length) renderEmpty('内容将在这里展示，可调整筛选或新增记录');
}
function renderEmpty(text) {
  const tr = document.createElement('tr'), td = document.createElement('td'), copy = document.createElement('p');
  td.colSpan = 4; td.className = 'empty-state'; copy.textContent = text; td.append(icon('database'), copy); tr.append(td); $('rows').append(tr);
}
function syncView() {
  const name = $('collection').value, schema = client.schemas.get(name), section = sections[name] || { action:'新增记录',description:'按数据库字段维护集合内容',tone:'purple' };
  const view = workspaceViews[activeView];
  const owner = $('owner').value.trim();
  $('user-context').textContent = owner ? (selectedUser?.id === owner ? selectedUser.name : owner) : '选择用户';
  $('user-context').title = $('user-context').textContent;
  $('owner-field').hidden = view ? !view.personal : !schema?.fields?.some(field=>field.name==='owner'); $('kind-field').hidden = !!view || name !== 'campus_content';
  $('review-field').hidden = !!view || name !== 'forge_repositories';
  $('course-field').hidden = !view?.course;
  $('new-app').hidden = !!view || name !== 'campus_content'; $('new-record').textContent = section.action; $('new-record').disabled = busy || !schema || schema.type === 'view' || !!view?.personal && !$('owner').value.trim();
  $('section-title').textContent = view?.label || labelFor(name); $('section-description').textContent = view?.target ? '全校共用目录 · 用户收藏单独维护' : section.description; $('dashboard').dataset.tone = section.tone;
  $('schema-link').href = '/_/#/collections?collection=' + encodeURIComponent(schema?.id || name);
  let ancestors = [];
  for (const node of $('sections').querySelectorAll('[data-view]')) {
    if (node.dataset.view === activeView) {
      node.setAttribute('aria-current','page');
      for (let parent = node.parentElement; parent && parent !== $('sections'); parent = parent.parentElement) {
        if (parent.tagName === 'DETAILS') { parent.open = true; ancestors.unshift(parent.querySelector(':scope > summary').dataset.label); }
      }
    } else node.removeAttribute('aria-current');
  }
  $('breadcrumbs').replaceChildren();
  for (const [index, text] of [...ancestors, view?.label || labelFor(name)].entries()) {
    if (index) { const separator = document.createElement('span'); separator.className = 'breadcrumb-separator'; separator.textContent = '/'; separator.setAttribute('aria-hidden', 'true'); $('breadcrumbs').append(separator); }
    const crumb = document.createElement('span'); crumb.textContent = text; $('breadcrumbs').append(crumb);
  }
}
const compactLayout = matchMedia('(max-width:760px)');
setSidebarVisible(!compactLayout.matches);
compactLayout.addEventListener('change', event => setSidebarVisible(!event.matches));
$('sidebar-toggle').addEventListener('click', () => setSidebarVisible($('sidebar-toggle').getAttribute('aria-expanded') !== 'true'));
document.addEventListener('keydown', event => { if (event.key === 'Escape' && compactLayout.matches && document.body.classList.contains('sidebar-open')) { setSidebarVisible(false); $('sidebar-toggle').focus(); } });
$('login-form').addEventListener('submit', event => {
  event.preventDefault(); const form = event.currentTarget, email = form.elements.namedItem('email').value, password = form.elements.namedItem('password').value;
  run(async () => { await client.login(email,password); form.elements.namedItem('password').value = ''; await client.loadCollections(); renderCatalog(); $('login').hidden = true; $('dashboard').hidden = false; document.body.classList.add('authenticated'); page = 1; syncView(); await refresh(); message('已连接当前站点的 PocketBase'); });
});
$('collection').addEventListener('change',()=>run(async()=>{activeView='';page=1;$('kind').value='';$('review-state').value = $('collection').value === 'forge_repositories' ? 'pending' : '';syncView();await refresh();}));
$('filters').addEventListener('submit',event=>{event.preventDefault();run(async()=>{page=1;await refresh();});});
$('clear-filter').addEventListener('click',()=>run(async()=>{if(!activeView)$('owner').value='';$('course-context').value='';$('search').value='';$('kind').value='';$('review-state').value='';page=1;await refresh();}));
$('exit-workspace').addEventListener('click',()=>run(async()=>{$('owner').value='';$('course-context').value='';$('user-context').textContent='选择用户';await selectView('users');}));
$('refresh').addEventListener('click',()=>run(refresh));
$('previous').addEventListener('click',()=>run(async()=>{if(page>1){page--;await refresh();}}));
$('next').addEventListener('click',()=>run(async()=>{if(page<totalPages){page++;await refresh();}}));
$('logout').addEventListener('click',()=>{signedOut();message('已退出');});
$('close-detail').addEventListener('click',()=>{$('detail').hidden=true;});
$('new-record').addEventListener('click',()=>run(()=>openRecord()));
$('new-app').addEventListener('click',()=>openApp());
for (const name of ['app','record','delete']) $('cancel-'+name).addEventListener('click',()=>$(name+'-dialog').close());
$('cancel-review').addEventListener('click', () => $('review-dialog').close());
$('review-form').addEventListener('submit', event => {
  event.preventDefault(); const approved = event.submitter?.value === 'approve', note = $('review-note').value.trim();
  if (approved && !$('review-school').checked) { $('review-message').textContent = '请完成华师大归属核验并勾选确认'; return; }
  if (!approved && !note) { $('review-message').textContent = '请填写修改建议'; return; }
  run(async () => {
    try { await client.reviewProject(reviewing, approved, note); $('review-dialog').close(); await refresh(); message(approved ? '项目已审核上架' : '项目已退回修改'); }
    catch (error) { $('review-message').textContent = error.message; throw error; }
  });
});
$('json-options').addEventListener('toggle',()=>{if($('json-options').open){try{$('record-json').value=JSON.stringify(readForm(),null,2);}catch(error){$('record-message').textContent=error.message;}}});
$('apply-json').addEventListener('click',()=>{
  try {
    const data=JSON.parse($('record-json').value); if (!data || typeof data!=='object' || Array.isArray(data)) throw new Error('请填写字段对象');
    const allowed=new Set(editing.fields.filter(f=>f.type!=='file').map(f=>f.name));
    if (!editing.id && editing.schema.type==='auth') {allowed.add('password');allowed.add('passwordConfirm');}
    for(const key of Object.keys(data)) if(!allowed.has(key)) throw new Error(`请通过字段表单维护 ${key}`);
    for(const [key,value] of Object.entries(data)) {const input=$('record-form').elements.namedItem(key);if(input.type==='checkbox')input.checked=Boolean(value);else input.value=typeof value==='object'&&value!==null?JSON.stringify(value,null,2):value??'';}
    $('record-message').textContent='JSON 已应用到字段表单，点击保存提交';
  }catch(error){$('record-message').textContent=error.message;}
});
$('record-form').addEventListener('submit',event=>{
  event.preventDefault();
  let data;try{data=readForm();}catch(error){$('record-message').textContent=error.message;return;}
  const files=editing.fields.filter(f=>f.type==='file').flatMap(field=>Array.from($('record-form').elements.namedItem(field.name).files).map(file=>({field,file})));
  if(files.length){const multipart=new FormData();for(const [key,value] of Object.entries(data))multipart.append(key,typeof value==='object'?JSON.stringify(value):String(value));for(const {field,file} of files){if(field.maxSize&&file.size>field.maxSize){$('record-message').textContent=`${file.name} 超过字段大小上限`;return;}multipart.append(field.name,file);}data=multipart;}
  run(async()=>{try{await client.saveRecord(editing.name,data,editing.id);$('record-dialog').close();await refresh();message('记录已保存到云端');}catch(error){$('record-message').textContent=error.message;throw error;}});
});
$('delete-form').addEventListener('submit',event=>{
  event.preventDefault();if($('delete-confirm').value!==deleting.id){$('delete-message').textContent='请填写对应记录 ID';return;}
  run(async()=>{try{await client.deleteRecord(deleting.name,deleting.id);$('delete-dialog').close();await refresh();message('记录已删除');}catch(error){$('delete-message').textContent=error.message;throw error;}});
});
$('app-form').addEventListener('submit',event=>{
  event.preventDefault();const form=event.currentTarget,data=Object.fromEntries(new FormData(form));data.published=form.elements.namedItem('published').checked;
  run(async()=>{try{await client.publishApp(data,data.id);$('app-dialog').close();await selectCollection('campus_content');message('作品已保存，手机刷新应用目录即可读取');}catch(error){$('app-message').textContent=error.message;throw error;}});
});
syncView();
