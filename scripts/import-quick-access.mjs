import fs from 'node:fs';
import assert from 'node:assert/strict';
import { AdminClient } from '../deploy/pocketbase/pb_public/assets/admin-client.mjs';

const base = process.env.CAMPULSE_ACCEPTANCE_BASE_URL || 'https://campus.allezafrique.cn';
const selectedName = process.argv.find(arg => arg.startsWith('--name='))?.slice('--name='.length);
const catalog = JSON.parse(fs.readFileSync(new URL('../deploy/catalog/ecnu-quick-access.json', import.meta.url),'utf8'))
  .filter(entry => selectedName === undefined || entry.name === selectedName);
assert.ok(catalog.length > 0, '目录名称未匹配，请检查 --name 参数');
const apply = process.argv.includes('--apply');
const env = Object.fromEntries(fs.readFileSync(process.env.CAMPULSE_ACCEPTANCE_ENV || '.tools/remote-acceptance.env','utf8').split(/\r?\n/).filter(line => line.includes('=') && !line.trim().startsWith('#')).map(line => {const i=line.indexOf('=');return [line.slice(0,i).trim(),line.slice(i+1).trim().replace(/^['"]|['"]$/g,'')];}));
const client = new AdminClient(base);
const key = target => target.type === 'web' ? target.url.replace(/\/$/,'') : target.originalId;
const report = [];
try {
  await client.login(env.REMOTE_ADMIN_EMAIL,env.REMOTE_ADMIN_PASSWORD);
  await client.loadCollections();
  const current = [];
  for (let page=1;;page++) {const result=await client.list('campus_content',{page,kind:'service'});current.push(...result.items);if(page>=result.totalPages)break;}
  if (apply) {
    fs.mkdirSync('.tools',{recursive:true});
    fs.writeFileSync(`.tools/quick-access-before-${Date.now()}.json`,JSON.stringify(current,null,2));
  }
  for (const entry of catalog) {
    assert.ok(entry.name && entry.launchTarget);
    if (entry.launchTarget.type === 'wechat-mini-program') assert.match(entry.launchTarget.originalId,/^gh_[a-z0-9]+$/);
    const matches = current.filter(row=>row.universityId==='ecnu' && !row.owner && row.payload?.launchTarget?.type===entry.launchTarget.type && key(row.payload.launchTarget)===key(entry.launchTarget));
    assert.ok(matches.length <= 1,`重复目录入口：${entry.name}`);
    const existing=matches[0];
    const payload={...existing?.payload,...entry,type:entry.launchTarget.type,sourceSystem:'manual',status:'active'};
    // Website ownership and availability were checked; mini-program IDs came from the user.
    if(entry.launchTarget.type==='web') payload.lastVerifiedAt=new Date().toISOString();
    const data={owner:'',kind:'service',universityId:'ecnu',schemaVersion:1,published:true,demo:false,payload};
    if (!apply) {console.log(`${existing?'UPDATE':'CREATE'} ${entry.name}`);continue;}
    const saved=await client.saveRecord('campus_content',data,existing?.id || '');
    const publicResponse=await fetch(base+'/api/collections/campus_content/records/'+saved.id,{signal:AbortSignal.timeout(15000)});
    assert.equal(publicResponse.status,200);
    const publicRow=await publicResponse.json();
    assert.equal(publicRow.payload.name,entry.name);
    assert.equal(key(publicRow.payload.launchTarget),key(entry.launchTarget));
    assert.equal(publicRow.owner,''); assert.equal(publicRow.demo,false);
    report.push({id:saved.id,name:entry.name,target:entry.launchTarget,origin:entry.origin,publicRead:true});
    console.log(`PASS ${existing?'更新':'新增'} + 公开读回：${entry.name} (${saved.id})`);
  }
  if (apply) fs.writeFileSync('.tools/quick-access-report.json',JSON.stringify({base,checkedAt:new Date().toISOString(),records:report},null,2));
} finally {client.logout();}
