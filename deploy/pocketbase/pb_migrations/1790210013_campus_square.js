migrate((app) => {
  const users = app.findCollectionByNameOrId('users').id;
  const signed = '@request.auth.id != "" && @request.auth.verified = true';
  const owned = signed + ' && owner = @request.auth.id';
  const create = signed + ' && @request.body.owner = @request.auth.id';
  const dates = () => [
    { name: 'created', type: 'autodate', onCreate: true },
    { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
  ];
  const owner = () => ({ name: 'owner', type: 'relation', collectionId: users, required: true, maxSelect: 1, cascadeDelete: true });
  const posts = new Collection({
    name: 'community_posts', type: 'base',
    listRule: signed, viewRule: signed,
    createRule: create + ' && @request.body.universityId = "ecnu"',
    updateRule: owned + ' && @request.body.owner:changed = false && @request.body.universityId:changed = false',
    deleteRule: owned,
    fields: [owner(),
      { name: 'universityId', type: 'text', required: true, max: 64 },
      { name: 'title', type: 'text', required: true, max: 120 },
      { name: 'body', type: 'text', required: true, max: 10000 },
      { name: 'displayName', type: 'text', required: true, max: 40 },
      { name: 'kind', type: 'select', required: true, maxSelect: 1, values: ['competition', 'sport', 'study', 'social'] },
      { name: 'campus', type: 'select', required: true, maxSelect: 1, values: ['minhang', 'putuo', 'online', 'other'] },
      { name: 'location', type: 'text', max: 160 },
      { name: 'tags', type: 'text', max: 200 },
      { name: 'startsAt', type: 'date' },
      { name: 'status', type: 'select', required: true, maxSelect: 1, values: ['open', 'closed'] },
      ...dates()],
    indexes: ['CREATE INDEX idx_community_posts_browse ON community_posts (universityId, kind, status, created)',
      'CREATE INDEX idx_community_posts_owner ON community_posts (owner, created)'],
  });
  app.save(posts);
  const post = () => ({ name: 'post', type: 'relation', required: true, collectionId: posts.id, maxSelect: 1, cascadeDelete: true });
  const related = signed + ' && post.id != ""';
  app.save(new Collection({
    name: 'community_interests', type: 'base',
    listRule: related + ' && (owner = @request.auth.id || post.owner = @request.auth.id)',
    viewRule: related + ' && (owner = @request.auth.id || post.owner = @request.auth.id)',
    createRule: create + ' && post.status = "open" && post.owner != @request.auth.id',
    updateRule: owned + ' && @request.body.owner:changed = false && @request.body.post:changed = false',
    deleteRule: owned,
    fields: [owner(), post(),
      { name: 'displayName', type: 'text', required: true, max: 40 },
      { name: 'message', type: 'text', max: 1000 }, ...dates()],
    indexes: ['CREATE UNIQUE INDEX idx_community_interest_unique ON community_interests (owner, post)'],
  }));
  app.save(new Collection({
    name: 'community_replies', type: 'base', listRule: related, viewRule: related,
    createRule: create + ' && post.status = "open"',
    updateRule: owned + ' && @request.body.owner:changed = false && @request.body.post:changed = false',
    deleteRule: signed + ' && (owner = @request.auth.id || post.owner = @request.auth.id)',
    fields: [owner(), post(),
      { name: 'displayName', type: 'text', required: true, max: 40 },
      { name: 'body', type: 'text', required: true, max: 3000 }, ...dates()],
    indexes: ['CREATE INDEX idx_community_replies_post ON community_replies (post, created)'],
  }));
  app.save(new Collection({
    name: 'community_profiles', type: 'base',
    listRule: signed + ' && (published = true || owner = @request.auth.id)',
    viewRule: signed + ' && (published = true || owner = @request.auth.id)',
    createRule: create, updateRule: owned + ' && @request.body.owner:changed = false', deleteRule: owned,
    fields: [owner(),
      { name: 'displayName', type: 'text', required: true, max: 40 },
      { name: 'bio', type: 'text', max: 1000 },
      { name: 'interests', type: 'text', max: 200 },
      { name: 'campus', type: 'select', required: true, maxSelect: 1, values: ['minhang', 'putuo', 'online', 'other'] },
      { name: 'published', type: 'bool' }, ...dates()],
    indexes: ['CREATE UNIQUE INDEX idx_community_profile_owner ON community_profiles (owner)'],
  }));
}, (app) => {
  for (const name of ['community_profiles', 'community_replies', 'community_interests', 'community_posts']) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
