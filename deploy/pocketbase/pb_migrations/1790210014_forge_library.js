migrate((app) => {
  const users = app.findCollectionByNameOrId('users').id;
  const projects = app.findCollectionByNameOrId('forge_repositories').id;
  const signed = '@request.auth.id != "" && @request.auth.verified = true';
  const owned = signed + ' && owner = @request.auth.id';
  const createOwned = signed + ' && @request.body.owner = @request.auth.id';
  const fixedOwner = '@request.body.owner:changed = false';
  const fixedProject = fixedOwner + ' && @request.body.repository:changed = false';
  const readableProject = '(repository.owner = @request.auth.id || (repository.visibility = "public" && repository.reviewState = "approved" && repository.schoolVerified = true && repository.universityId = "ecnu"))';
  const dates = () => [
    { name: 'created', type: 'autodate', onCreate: true },
    { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
  ];
  const owner = () => ({ name: 'owner', type: 'relation', required: true, collectionId: users, maxSelect: 1, cascadeDelete: true });
  const repository = () => ({ name: 'repository', type: 'relation', required: true, collectionId: projects, maxSelect: 1, cascadeDelete: true });

  const categories = new Collection({
    name: 'forge_categories', type: 'base',
    listRule: owned, viewRule: owned, createRule: createOwned,
    updateRule: owned + ' && ' + fixedOwner, deleteRule: owned,
    fields: [owner(),
      { name: 'name', type: 'text', required: true, max: 80 },
      { name: 'color', type: 'text', required: true, min: 7, max: 7, pattern: '^#[0-9A-Fa-f]{6}$' },
      { name: 'position', type: 'number', onlyInt: true },
      { name: 'locked', type: 'bool' }, ...dates()],
    indexes: ['CREATE INDEX idx_forge_category_owner_position ON forge_categories (owner, position, id)'],
  });
  app.save(categories);

  // Request-body joins check the category being assigned, including PATCH. A
  // category.owner test alone could otherwise check the previously stored value.
  const categoryAssignment = '(@request.body.category:isset = false || @request.body.category = "" || (@collection.forge_categories:assigned.id ?= @request.body.category && @collection.forge_categories:assigned.owner ?= @request.auth.id))';
  app.save(new Collection({
    name: 'forge_bookmarks', type: 'base',
    listRule: owned + ' && ' + readableProject,
    viewRule: owned + ' && ' + readableProject,
    createRule: createOwned + ' && ' + readableProject + ' && ' + categoryAssignment,
    updateRule: owned + ' && ' + readableProject + ' && ' + fixedProject + ' && ' + categoryAssignment,
    deleteRule: owned,
    fields: [owner(), repository(),
      { name: 'category', type: 'relation', collectionId: categories.id, maxSelect: 1, cascadeDelete: false },
      { name: 'tags', type: 'json', maxSize: 8192 },
      { name: 'note', type: 'text', max: 4000 },
      { name: 'analysis', type: 'json', maxSize: 49152 },
      { name: 'analysisAt', type: 'date' },
      { name: 'githubMetadata', type: 'json', maxSize: 32768 }, ...dates()],
    indexes: [
      'CREATE UNIQUE INDEX idx_forge_bookmark_owner_repository ON forge_bookmarks (owner, repository)',
      'CREATE INDEX idx_forge_bookmark_category ON forge_bookmarks (owner, category, updated)',
    ],
  }));

  const subscriptions = new Collection({
    name: 'forge_subscriptions', type: 'base',
    listRule: owned + ' && ' + readableProject,
    viewRule: owned + ' && ' + readableProject,
    createRule: createOwned + ' && ' + readableProject,
    updateRule: owned + ' && ' + readableProject + ' && ' + fixedProject,
    deleteRule: owned,
    fields: [owner(), repository(),
      { name: 'includePrereleases', type: 'bool' },
      { name: 'lastCheckedAt', type: 'date' }, ...dates()],
    indexes: ['CREATE UNIQUE INDEX idx_forge_subscription_owner_repository ON forge_subscriptions (owner, repository)'],
  });
  app.save(subscriptions);

  const relatedSubscription = 'subscription.owner = @request.auth.id && subscription.repository = repository';
  app.save(new Collection({
    name: 'forge_release_events', type: 'base',
    listRule: owned + ' && ' + readableProject + ' && ' + relatedSubscription,
    viewRule: owned + ' && ' + readableProject + ' && ' + relatedSubscription,
    createRule: createOwned + ' && ' + readableProject + ' && ' + relatedSubscription,
    updateRule: owned + ' && ' + readableProject + ' && ' + relatedSubscription + ' && ' + fixedProject + ' && @request.body.subscription:changed = false',
    deleteRule: owned,
    fields: [owner(), repository(),
      { name: 'subscription', type: 'relation', required: true, collectionId: subscriptions.id, maxSelect: 1, cascadeDelete: true },
      { name: 'externalId', type: 'text', required: true, max: 100 },
      { name: 'payload', type: 'json', required: true, maxSize: 98304 },
      { name: 'read', type: 'bool' },
      { name: 'publishedAt', type: 'date' }, ...dates()],
    indexes: [
      'CREATE UNIQUE INDEX idx_forge_release_owner_repository_external ON forge_release_events (owner, repository, externalId)',
      'CREATE INDEX idx_forge_release_owner_read_date ON forge_release_events (owner, read, publishedAt)',
    ],
  }));
}, (app) => {
  for (const name of ['forge_release_events', 'forge_subscriptions', 'forge_bookmarks', 'forge_categories']) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
