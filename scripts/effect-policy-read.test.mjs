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
