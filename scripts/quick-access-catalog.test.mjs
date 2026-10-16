import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const entries=JSON.parse(readFileSync(new URL('../deploy/catalog/ecnu-quick-access.json',import.meta.url),'utf8'));
test('ECNU launch catalog contains unique real mini-program IDs and public AppIDs',()=>{
  const mini=entries.filter(entry=>entry.launchTarget.type==='wechat-mini-program');
  assert.equal(mini.length,4);
  assert.equal(new Set(mini.map(entry=>entry.launchTarget.originalId)).size,4);
  for(const entry of mini){assert.match(entry.launchTarget.originalId,/^gh_[a-z0-9]+$/);assert.match(entry.miniProgramAppId,/^wx[0-9a-f]{16}$/);assert.equal(entry.launchTarget.path,'');}
});
test('ECNU website catalog uses school HTTPS domains and external browser launch',()=>{
  const websites=entries.filter(entry=>entry.launchTarget.type==='web');
  assert.equal(websites.length,6);
  for(const entry of websites){const url=new URL(entry.launchTarget.url);assert.equal(url.protocol,'https:');assert.ok(url.hostname.endsWith('.ecnu.edu.cn'));assert.equal(entry.launchTarget.preferredMode,'external');}
});

test('campus community references preserve external provenance and link to verified introductions',()=>{
  const resources=entries.filter(entry=>entry.tags.includes('校园社区'));
  assert.equal(resources.length,2);
  assert.deepEqual(new Set(resources.map(entry=>entry.launchTarget.url)),new Set([
    'https://comm.ecnu.edu.cn/a8/be/c41509a567486/page.htm',
    'https://www.ecnu.edu.cn/info/1094/70562.htm',
  ]));
  for(const entry of resources){assert.equal(entry.origin,'external');assert.equal(entry.isOfficial,false);assert.ok(entry.name.endsWith('介绍'));}
});

test('Suishiban links to the official access guide rather than a session-specific portal',()=>{
  const entry=entries.find(entry=>entry.name==='随师办入口与指南');
  assert.equal(entry.category,'official-hub');
  assert.equal(entry.launchTarget.url,'https://eoffice.ecnu.edu.cn/sjmhwssb/list.htm');
  assert.equal(new URL(entry.launchTarget.url).search,'');
});
test('catalog labels have supported categories and preserve external provenance',()=>{
  const categories=['official-hub','academic','library','campus-card','venue','network','map','administration','other'];
  for(const entry of entries){assert.ok(entry.name&&entry.description);assert.ok(categories.includes(entry.category));assert.ok(Array.isArray(entry.tags));assert.equal(entry.isOfficial,entry.origin==='official');}
  assert.equal(entries.find(entry=>entry.name==='HS狮耳').origin,'external');
});
