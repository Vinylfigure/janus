import test from 'node:test';
import assert from 'node:assert/strict';
import {readPolicySnapshot} from './effect-policy-read.mjs';
import {classifyEffects} from './effect-policy.mjs';
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
test('native Codex skill content is read at both exact revisions, not projected as ordinary',async()=>{
 const filename='.agents/skills/janus-workflow/SKILL.md',reads=[];
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
