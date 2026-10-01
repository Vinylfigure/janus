import test from 'node:test';
import assert from 'node:assert/strict';
import {readPolicySnapshot} from './effect-policy-read.mjs';
import {classifyEffects} from './effect-policy.mjs';
import {gitSnapshot} from './effect-policy-cli.mjs';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,symlinkSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
function fixture({alias=false,dynamic=false,truncated=false}={}){
 const sources={'scripts/enforce.mjs':alias?"import '@/helper.js'":dynamic?'import(target)':"import '../lib/helper.js'",'lib/helper.js':'export const permits=true'};
 let contents=0;
 const api=async path=>{
   if(path==='repos/o/r/pulls/2')return {base:{sha:'base',repo:{id:1,full_name:'o/r'}},head:{sha:'head'},changed_files:1};
   if(path.includes('/files?'))return [{filename:'lib/helper.js',status:'modified',changes:1,patch:'test'}];
   if(path.includes('/git/trees/'))return {truncated,tree:Object.keys(sources).map(p=>({path:p,mode:'100644',sha:p+(p==='lib/helper.js'&&path.includes('/head')?'changed':'')}))};
   if(path.includes('/contents/')){contents++;const p=path.split('/contents/')[1].split('?')[0];return {encoding:'base64',content:Buffer.from(sources[p]+(p==='lib/helper.js'&&path.endsWith('head')?' // changed':'')).toString('base64')};}
   throw Error(path);
 };
 return {api,get contents(){return contents;}};
}
test('transitive machinery helper outside scripts is classified; identical source blobs fetched once',async()=>{
 const f=fixture();const snapshot=await readPolicySnapshot('o/r',2,'head',f.api);
 assert.ok(snapshot.authorityPaths.includes('lib/helper.js'));assert.equal(classifyEffects(snapshot).verdict,'unknown');
 assert.equal(f.contents,3);
});
test('aliases/dynamic dependencies cannot classify changed application code safe',async()=>{
 for(const options of [{alias:true},{dynamic:true}])assert.equal(classifyEffects(await readPolicySnapshot('o/r',2,'head',fixture(options).api)).verdict,'unknown');
});
test('incomplete trees and moved heads are refused',async()=>{
 await assert.rejects(readPolicySnapshot('o/r',2,'head',fixture({truncated:true}).api),/Incomplete/);
 await assert.rejects(readPolicySnapshot('o/r',2,'old',fixture().api),/identity/);
});
for(const filename of ['.agents/skills/janus-workflow/SKILL.md','AGENTS.override.md','apps/api/AGENTS.md','apps/api/AGENTS.override.md','apps/api/.agents/skills/local/SKILL.md','apps/api/.codex/config.toml'])test(`native content is read at both exact revisions: ${filename}`,async()=>{
 const reads=[];
 const api=async path=>{
  if(path==='repos/o/r/pulls/2')return {base:{sha:'base',repo:{id:1,full_name:'o/r'}},head:{sha:'head'},changed_files:1};
  if(path.includes('/files?'))return [{filename,status:'modified',changes:1,patch:'changed instructions'}];
  if(path.includes('/git/trees/'))return {tree:[{path:filename,mode:'100644',sha:path.endsWith('/head?recursive=1')?'new':'old'}]};
  if(path.includes('/contents/')){reads.push(path);return {encoding:'base64',content:Buffer.from(path.endsWith('head')?'new instructions':'old instructions').toString('base64')};}
  throw Error(path);
 };
 const snapshot=await readPolicySnapshot('o/r',2,'head',api);
 assert.equal(reads.length,2);
 assert.equal(snapshot.files[0].before,'old instructions');
 assert.equal(snapshot.files[0].after,'new instructions');
 assert.equal(classifyEffects(snapshot).verdict,'unknown');
});
test('unreadable nested native instructions cannot become ordinary-change evidence',async()=>{
 const filename='apps/api/AGENTS.override.md';
 const api=async path=>{
  if(path==='repos/o/r/pulls/2')return {base:{sha:'base',repo:{id:1,full_name:'o/r'}},head:{sha:'head'},changed_files:1};
  if(path.includes('/files?'))return [{filename,status:'modified',changes:1,patch:'partial'}];
  if(path.includes('/git/trees/'))return {tree:[{path:filename,mode:'100644',sha:path.includes('/head')?'new':'old'}]};
  throw Error('Content unavailable');
 };
 await assert.rejects(readPolicySnapshot('o/r',2,'head',api),/Content unavailable/);
});
test('local Git reader preserves exact native instruction content and removal holds',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'janus-native-policy-')),previous=process.cwd();
 const git=(...args)=>execFileSync('git',args,{cwd:dir,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
 const paths=['AGENTS.override.md','apps/api/AGENTS.md','apps/api/AGENTS.override.md','apps/api/.agents/skills/local/SKILL.md','apps/api/.codex/config.toml'];
 try {
  git('init');git('config','user.name','Fixture');git('config','user.email','fixture@example.invalid');
  for(const path of paths){mkdirSync(dirname(join(dir,path)),{recursive:true});writeFileSync(join(dir,path),'old instructions');}
  git('add','.');git('commit','-m','before');const base=git('rev-parse','HEAD');
  for(const path of paths)writeFileSync(join(dir,path),'new instructions');
  symlinkSync('external-skills',join(dir,'.agents'));
  rmSync(join(dir,paths[0]));git('add','-A');git('commit','-m','after');const head=git('rev-parse','HEAD');
  process.chdir(dir);
  const snapshot=await gitSnapshot(base,head);
  assert.equal(snapshot.head,head);assert.equal(snapshot.base,base);assert.equal(snapshot.files.length,paths.length+1);
  for(const file of snapshot.files){
   if(file.path==='.agents') {assert.equal(file.before,'');assert.equal(file.after,'external-skills');assert.equal(classifyEffects({files:[file]}).verdict,'unknown');}
   else {assert.equal(file.before,'old instructions',file.path);assert.equal(file.after,file.path===paths[0]?'':'new instructions',file.path);}
  }
  assert.equal(snapshot.complete,false);assert.match(snapshot.incompleteReason,/Symbolic machinery sources/);
  assert.equal(classifyEffects(snapshot).verdict,'unknown');
 } finally {process.chdir(previous);rmSync(dir,{recursive:true,force:true});}
});
test('unchanged native instruction symlinks hold later edits to ordinary-path targets',async()=>{
 for(const link of ['.agents','apps/api/.agents','AGENTS.md','apps/api/AGENTS.override.md','apps/api/.codex']) {
  const filename='external-skills/review/SKILL.md';
  const api=async path=>{
   if(path==='repos/o/r/pulls/2')return {base:{sha:'base',repo:{id:1,full_name:'o/r'}},head:{sha:'head'},changed_files:1};
   if(path.includes('/files?'))return [{filename,status:'modified',changes:1,patch:'new instruction'}];
   if(path.includes('/git/trees/'))return {tree:[{path:link,mode:'120000',sha:'stable-link'},{path:filename,mode:'100644',sha:path.includes('/head')?'new':'old'}]};
   throw Error('This case needs tree evidence, not source execution');
  };
  const snapshot=await readPolicySnapshot('o/r',2,'head',api);
  assert.equal(snapshot.complete,false,link);assert.match(snapshot.incompleteReason,/Symbolic machinery sources/);
  assert.equal(classifyEffects(snapshot).verdict,'unknown',link);
 }
});
test('large dependency graphs retain an exact reviewable binding without claiming allow',async()=>{
 const {bindPolicy}=await import('./effect-policy.mjs');
 const roots=Array.from({length:190},(_,n)=>`scripts/gate-${n}.mjs`),paths=[...roots,'src/app.js'];let reads=0;
 const api=async path=>{
  if(path==='repos/o/r/pulls/2')return {base:{sha:'base',repo:{id:1,full_name:'o/r'}},head:{sha:'head'},changed_files:1};
  if(path.includes('/files?'))return [{filename:'src/app.js',status:'modified',changes:1,patch:'code'}];
  if(path.includes('/git/trees/'))return {tree:paths.map(p=>({path:p,mode:'100644',sha:p+(path.includes('/head')?'head':'base')}))};
  if(path.includes('/contents/')){reads++;return {encoding:'base64',content:Buffer.from('export const guarded=true').toString('base64')};}
  throw Error(path);
 };
 const snapshot=await readPolicySnapshot('o/r',2,'head',api),result=bindPolicy(snapshot,'policy');
 assert.equal(result.verdict,'unknown');assert.equal(result.binding.head,'head');assert.equal(result.binding.repoId,1);assert.match(result.binding.diffDigest,/^[a-f0-9]{64}$/);
 assert.match(result.reasons[0],/incomplete/);assert.ok(reads<=182);
});
