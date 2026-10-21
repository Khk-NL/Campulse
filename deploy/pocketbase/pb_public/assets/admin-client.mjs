export const collections = Object.freeze({
  users: '用户', course_notes: '笔记', user_courses: '课程',
  study_workspaces: '计划与工作台', course_review_cards: '复习卡片',
  course_artifacts: '学习成果', campus_content: '校园 GitHub 与服务',
  forge_repositories: '社区项目仓库', forge_discussions: '项目讨论与问题',
  forge_replies: '讨论回复', forge_stars: '项目关注', user_favorites: '用户收藏',
  forge_categories: '项目分类', forge_bookmarks: '项目收藏整理',
  forge_subscriptions: '版本订阅', forge_release_events: '版本更新消息',
  community_posts: '校园召集', community_interests: '活动报名',
  community_replies: '活动讨论', community_profiles: '兴趣名片',
});

export const sections = Object.freeze({
  users: { action: '新增用户', description: '管理账号资料、验证状态与个人内容', tone: 'blue' },
  course_notes: { action: '新增笔记', description: '维护笔记正文、课程归属和 PDF 附件', tone: 'gold' },
  user_courses: { action: '新增课程', description: '维护个人课程与课表数据', tone: 'purple' },
  study_workspaces: { action: '新建工作台', description: '管理计划、完成记录与智能体配置', tone: 'gold' },
  course_review_cards: { action: '新增复习卡片', description: '维护正反面、到期时间及排程数据', tone: 'purple' },
  course_artifacts: { action: '新增学习成果', description: '管理测验、闪卡、导图和对话归档', tone: 'blue' },
  campus_content: { action: '新增目录记录', description: '管理校园作品、服务入口与发布状态', tone: 'red' },
  forge_repositories: { action: '新增项目仓库', description: '逐项目核验华师大归属，处理上架申请和修改意见', tone: 'purple' },
  forge_discussions: { action: '新增项目讨论', description: '管理问答、建议、问题反馈与项目进展', tone: 'blue' },
  forge_replies: { action: '新增讨论回复', description: '查看和维护社区成员的交流内容', tone: 'gold' },
  forge_stars: { action: '新增项目关注', description: '管理成员与项目的关注关系', tone: 'red' },
  forge_categories: { action: '新增项目分类', description: '维护个人分类、颜色、排序与 AI 整理锁定状态', tone: 'purple' },
  forge_bookmarks: { action: '新增项目收藏', description: '整理个人标签、备注、README 分析与 GitHub 元数据', tone: 'gold' },
  forge_subscriptions: { action: '新增版本订阅', description: '管理项目版本订阅、预发布选项与检查时间', tone: 'blue' },
  forge_release_events: { action: '新增版本消息', description: '维护订阅关联的版本内容、发布时间与已读状态', tone: 'red' },
  user_favorites: { action: '新增收藏', description: '维护用户收藏的入口与板块归属', tone: 'gold' },
  community_posts: { action: '新增校园召集', description: '管理竞赛组队、运动约局、学习搭子与校园扩列', tone: 'purple' },
  community_interests: { action: '新增活动报名', description: '按用户或发起人查看参加意向和报名留言', tone: 'gold' },
  community_replies: { action: '新增活动讨论', description: '维护召集下的问答与交流', tone: 'blue' },
  community_profiles: { action: '新增兴趣名片', description: '管理个人介绍、兴趣技能与公开状态', tone: 'red' },
});

// Domain views share existing collections; their filters define each relationship.
export const workspaceViews = Object.freeze({
  users: { collection: 'users', label: '用户列表' },
  courses: { collection: 'user_courses', label: '课程', personal: true },
  notes: { collection: 'course_notes', label: '课程笔记', personal: true, course: true },
  cards: { collection: 'course_review_cards', label: '复习卡片', personal: true, course: true },
  artifacts: { collection: 'course_artifacts', label: '学习成果', personal: true, course: true },
  timetable: { collection: 'user_courses', label: '课程表', personal: true },
  plans: { collection: 'study_workspaces', label: '计划与工作台', personal: true },
  notifications: { collection: 'campus_content', label: '个人通知', personal: true, kind: 'announcement' },
  tasks: { collection: 'campus_content', label: '个人待办', personal: true, kind: 'task' },
  announcements: { collection: 'campus_content', label: '校园公告', globalKind: 'announcement' },
  events: { collection: 'campus_content', label: '校园活动', globalKind: 'event' },
  repositories: { collection: 'forge_repositories', label: '个人仓库', personal: true },
  incomingDiscussions: { collection: 'forge_discussions', label: '收到的讨论', personal: true, incoming: 'repository.owner' },
  incomingReplies: { collection: 'forge_replies', label: '收到的回复', personal: true, incoming: 'discussion.repository.owner' },
  community: { collection: 'forge_repositories', label: '社区项目仓库', community: true },
  discussions: { collection: 'forge_discussions', label: '参与的讨论', personal: true, outgoing: 'repository.owner' },
  replies: { collection: 'forge_replies', label: '参与的回复', personal: true, outgoing: 'discussion.repository.owner' },
  stars: { collection: 'forge_stars', label: 'Star 关注', personal: true },
  projectCategories: { collection: 'forge_categories', label: '项目分类', personal: true },
  projectBookmarks: { collection: 'forge_bookmarks', label: '收藏整理', personal: true },
  releaseSubscriptions: { collection: 'forge_subscriptions', label: '版本订阅', personal: true },
  releaseEvents: { collection: 'forge_release_events', label: '版本更新消息', personal: true },
  favorites: { collection: 'user_favorites', label: '个人收藏', personal: true },
  reviews: { collection: 'forge_repositories', label: '项目上架审核', review: true },
  miniPrograms: { collection: 'campus_content', label: '官方小程序', target: 'wechat-mini-program' },
  websites: { collection: 'campus_content', label: '官方网站', target: 'web' },
  squarePosts: { collection: 'community_posts', label: '校园召集', personal: true },
  squareFeed: { collection: 'community_posts', label: '校园广场内容' },
  squareInterests: { collection: 'community_interests', label: '活动报名', personal: true },
  squareReceivedInterests: { collection: 'community_interests', label: '收到的报名', personal: true, incoming: 'post.owner' },
  squareReplies: { collection: 'community_replies', label: '活动讨论', personal: true },
  squareProfiles: { collection: 'community_profiles', label: '兴趣名片', personal: true },
});

export function workspaceFilter(viewId, owner = '', courseId = '') {
  const view = workspaceViews[viewId];
  if (!view) throw new Error('请选择工作区');
  const filters = [];
  if (view.personal) {
    if (!owner) throw new Error('请先从用户列表打开个人工作区');
    ownerFilter(owner);
    if (view.incoming) filters.push(`${view.incoming} = ${JSON.stringify(owner)}`, `owner != ${JSON.stringify(owner)}`);
    else {
      filters.push(ownerFilter(owner));
      if (view.outgoing) filters.push(`${view.outgoing} != ${JSON.stringify(owner)}`);
    }
  }
  if (view.course && courseId) filters.push(`courseId = ${JSON.stringify(courseId)}`);
  if (view.kind) filters.push(`kind = ${JSON.stringify(view.kind)}`);
  if (view.globalKind) filters.push(`kind = ${JSON.stringify(view.globalKind)}`, 'owner = ""');
  if (view.community) filters.push('reviewState = "approved"', 'schoolVerified = true', 'universityId = "ecnu"', 'visibility = "public"');
  if (view.review) filters.push('reviewState = "pending"');
  if (view.target) filters.push('owner = ""', 'kind = "service"', 'payload.origin = "official"', `payload.launchTarget.type = ${JSON.stringify(view.target)}`);
  return filters.join(' && ');
}

export function editableFields(schema) {
  return (schema?.fields || []).filter(field =>
    !['id', 'created', 'updated', 'tokenKey', 'password'].includes(field.name)
    && field.type !== 'autodate');
}

export function isMultilineField(field) {
  return ['json', 'editor', 'geoPoint'].includes(field.type)
    || ['content', 'front', 'back', 'body', 'message', 'bio'].includes(field.name)
    || field.maxSelect > 1 && field.type !== 'file';
}

export function searchFilter(schema, text) {
  if (!text.trim()) return '';
  const fields = ['id', ...(schema?.fields || []).filter(field =>
    ['text', 'email', 'url', 'editor'].includes(field.type) && /^[a-zA-Z0-9_]+$/.test(field.name)
  ).map(field => field.name)];
  if (schema?.fields?.some(field => field.name === 'payload' && field.type === 'json')) fields.push('payload.name');
  return '(' + [...new Set(fields)].map(name => `${name} ~ ${JSON.stringify(text.trim())}`).join(' || ') + ')';
}

export function ownerFilter(id) {
  if (!id) return '';
  if (!/^[a-z0-9]{15}$/.test(id)) throw new Error('请填写有效用户 ID');
  return `owner = "${id}"`;
}

export function workspaceSummary(row) {
  const activities = Array.isArray(row.payload?.activities) ? row.payload.activities : [];
  const completed = activities.filter(activity => activity.completedAt != null).length;
  return `待办 ${activities.length - completed} · 已完成 ${completed}`;
}

export function appPayload(form, existing = {}) {
  const name = String(form.name || '').trim();
  if (!name) throw new Error('请填写作品名称');
  const url = new URL(form.url);
  if (!['https:', 'http:'].includes(url.protocol)) throw new Error('使用入口请填写 HTTP 或 HTTPS 地址');
  const repository = String(form.repository || '').trim();
  if (repository) {
    const repo = new URL(repository);
    if (repo.protocol !== 'https:' || repo.hostname !== 'github.com' || repo.pathname.split('/').filter(Boolean).length !== 2) {
      throw new Error('仓库请填写 GitHub 项目 HTTPS 地址');
    }
  }
  return {
    ...existing,
    origin: existing.origin || 'student-developed',
    universityScope: existing.universityScope || { kind: 'only', universityIds: ['ecnu'] },
    name, description: String(form.description || '').trim(),
    developerName: String(form.developerName || '').trim(),
    repositoryUrl: repository,
    tags: String(form.tags || '').split(/[,，]/).map(x => x.trim()).filter(Boolean).slice(0, 12),
    launchTarget: { type: 'web', url: url.href },
  };
}

export class AdminClient {
  constructor(base = '', request = fetch) {
    this.base = base.replace(/\/$/, '');
    this.request = (...args) => request(...args);
    this.token = '';
    this.schemas = new Map();
  }

  async api(path, method = 'GET', body) {
    const response = await this.request(this.base + '/api' + path, {
      method,
      headers: { ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }), ...(this.token ? { Authorization: this.token } : {}) },
      body: body === undefined ? undefined : body instanceof FormData ? body : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
      cache: 'no-store',
    });
    let data = {};
    if (response.status !== 204) {
      try { data = await response.json(); } catch { throw new Error('服务响应格式错误，请重试'); }
    }
    if (!response.ok) {
      if (response.status === 401) this.logout();
      throw new Error(response.status === 400 && path.includes('auth-with-password')
        ? '登录失败，请核对管理员邮箱和密码'
        : `操作失败（HTTP ${response.status}），请检查输入或登录后重试${Object.keys(data.data || {}).length ? '：' + Object.keys(data.data).slice(0, 10).join('、') : ''}`);
    }
    return data;
  }

  async login(email, password) {
    this.logout();
    const result = await this.api('/collections/_superusers/auth-with-password', 'POST', {
      identity: email.trim(), password,
    });
    if (!result.token) throw new Error('请重新登录');
    this.token = result.token;
  }

  logout() { this.token = ''; this.schemas.clear(); }

  async loadCollections() {
    const schemas = [];
    for (let page = 1; ; page++) {
      const result = await this.api('/collections?' + new URLSearchParams({ page: String(page), perPage: '100', sort: 'name' }));
      schemas.push(...result.items);
      if (page >= result.totalPages) break;
    }
    this.schemas = new Map(schemas.map(schema => [schema.name, schema]));
    return schemas;
  }

  collectionPath(name, id = '') {
    if ((!Object.hasOwn(collections, name) && !this.schemas.has(name)) || !/^[a-zA-Z0-9_]+$/.test(name)) throw new Error('请选择运营数据分区');
    if (id && !/^[a-z0-9]{15}$/.test(id)) throw new Error('请填写有效记录 ID');
    return '/collections/' + name + '/records' + (id ? '/' + id : '');
  }

  async list(name, { page = 1, owner = '', search = '', kind = '', reviewState = '', view = '', courseId = '' } = {}) {
    const query = new URLSearchParams({ page: String(page), perPage: '25' });
    const schema = this.schemas.get(name), filters = [];
    const hasOwner = schema ? schema.fields.some(field => field.name === 'owner') : name !== 'users' && name !== 'campus_content';
    if (hasOwner) {
      query.set('expand', 'owner');
      if (owner && !view) filters.push(ownerFilter(owner));
    }
    if (view) {
      if (workspaceViews[view]?.collection !== name) throw new Error('工作区与数据集合不匹配');
      const scope = workspaceFilter(view, owner, courseId);
      if (scope) filters.push(scope);
    }
    if (search.trim()) filters.push(searchFilter(schema, search));
    if (kind && name === 'campus_content') filters.push(`kind = ${JSON.stringify(kind)}`);
    if (reviewState && name === 'forge_repositories') {
      if (!['draft', 'pending', 'approved', 'rejected'].includes(reviewState)) throw new Error('请选择审核状态');
      filters.push(`reviewState = ${JSON.stringify(reviewState)}`);
    }
    if (filters.length) query.set('filter', filters.join(' && '));
    if (schema ? schema.fields.some(field => field.name === 'updated') : ['users', 'course_notes', 'course_review_cards', 'course_artifacts'].includes(name)) query.set('sort', '-updated');
    return this.api(this.collectionPath(name) + '?' + query);
  }

  getRecord(name, id) { return this.api(this.collectionPath(name, id)); }

  async reviewProject(id, approved, note = '') {
    const row = await this.getRecord('forge_repositories', id);
    if (approved && (row.reviewState !== 'pending' || row.visibility !== 'public' || row.universityId !== 'ecnu' || !row.schoolProof?.trim())) {
      throw new Error('请确认项目已提交审核、申请公开且华师大归属材料齐全');
    }
    return this.saveRecord('forge_repositories', {
      reviewState: approved ? 'approved' : 'rejected',
      schoolVerified: !!approved,
      reviewNote: note.trim(),
    }, id);
  }

  saveRecord(name, data, id = '') {
    if (this.schemas.get(name)?.type === 'view') throw new Error('视图通过来源集合维护');
    return this.api(this.collectionPath(name, id), id ? 'PATCH' : 'POST', data);
  }

  deleteRecord(name, id) {
    if (!id) throw new Error('请指定记录 ID');
    if (this.schemas.get(name)?.type === 'view') throw new Error('视图通过来源集合维护');
    return this.api(this.collectionPath(name, id), 'DELETE');
  }

  async publishApp(form, id = '') {
    const path = this.collectionPath('campus_content', id);
    const existing = id ? await this.api(path) : {};
    if (id && existing.kind !== 'app') throw new Error('请通过数据库后台编辑校园服务记录');
    const payload = appPayload(form, existing.payload || {});
    return this.api(path, id ? 'PATCH' : 'POST', {
      kind: 'app', universityId: 'ecnu', schemaVersion: 1,
      published: !!form.published, demo: false, payload,
    });
  }

  async setPublished(id, published) {
    return this.api(this.collectionPath('campus_content', id), 'PATCH', { published: !!published });
  }
}
