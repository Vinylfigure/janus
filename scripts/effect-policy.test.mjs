import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyEffects,bindPolicy,approvalVerdict,hash } from './effect-policy.mjs';
const classify=(path,before,after,extra={})=>classifyEffects({files:[{path,before,after,...extra}]});
test('ordinary application edits are eligible but enforcement edits need evidence',()=>{
 assert.equal(classify('src/app.js','a','b').verdict,'allow');
 for(const path of ['scripts/guard.sh','scripts/new-helper.mjs','.claude/hooks/pre.sh'])assert.equal(classify(path,'deny bad','exit 0 # guard').verdict,'unknown');
});
test('keyword camouflaged arbitrary code is never a narrowing proof',()=>{
 for(const after of ['deny bad\nexit 0 # guard','deny bad\neval "$INPUT" # test','deny bad\nreturn true // assert'])assert.equal(classify('scripts/guard.sh','deny bad',after).verdict,'unknown');
});
test('settings support only actual permission set narrowing',()=>{
 const before=JSON.stringify({hooks:{},permissions:{allow:['Read','Write'],deny:['bad'],ask:[]}});
 const after=JSON.stringify({permissions:{ask:[],allow:['Read'],deny:['bad','worse']},hooks:{}});
 assert.equal(classify('.claude/settings.json',before,after).verdict,'allow');
 assert.equal(classify('.claude/settings.json',after,before).verdict,'protected');
 assert.equal(classify('.claude/settings.json',before,'{"permissions":{"allow":[],"allow":["Bash(*)"]}}').verdict,'unknown');
 assert.equal(classify('.claude/settings.json',before,JSON.stringify({hooks:{Stop:[]},permissions:{allow:[]}})).verdict,'unknown');
});
test('only existing literal on.schedule cron replacement is recognized',()=>{
 const before='name: test\non:\n  schedule:\n    - cron: "47 9 * * 1"\njobs:\n  test:\n    run: script\n';
 assert.equal(classify('.github/workflows/run.yml',before,before.replace('47 9','17 9')).verdict,'allow');
 assert.equal(classify('.github/workflows/run.yml',before,before.replace('run: script','run: exit 0 # check')).verdict,'unknown');
 assert.equal(classify('.github/workflows/run.yml',before,before+'  permissions: write-all\n').verdict,'unknown');
 assert.equal(classify('.github/workflows/run.yml',before,before+'alias: *permissions\n').verdict,'unknown');
 assert.equal(classify('.github/workflows/run.yml',before,before.replace('47 9','90 9')).verdict,'unknown');
 const expression=before+'  env: ${{ secrets.TOKEN }}\n';
 assert.equal(classify('.github/workflows/run.yml',expression,expression.replace('47 9','17 9')).verdict,'allow');
});
test('policy changes and removals are protected; incomplete sources fail closed',()=>{
 assert.equal(classify('scripts/effect-policy.mjs','a','b').verdict,'protected');
 assert.equal(classify('scripts/check.sh','deny bad','').verdict,'protected');
 assert.equal(classify('scripts/check.sh',undefined,'check good').verdict,'unknown');
 assert.equal(classify('src/a.js','a','b',{modeChanged:true}).verdict,'unknown');
 assert.equal(classifyEffects({files:[],complete:false}).verdict,'unknown');
});
test('human review binds exact policy, source and operation; later dismissal wins',()=>{
 const result=bindPolicy({repo:'o/r',repoId:1,pr:2,head:'a'.repeat(40),base:'b'.repeat(40),files:[{path:'scripts/check.sh',before:'old',after:'new'}]},'c'.repeat(64));
 const review={id:4,user:{id:7,type:'User'},state:'APPROVED',commit_id:result.binding.head,body:`<!-- overlord:policy-approval:v1 -->\nAction: merge\nBinding-sha256: ${hash(result.binding)}`};
 assert.equal(approvalVerdict(result,[review],[7]).allowed,true);
 for(const changed of [{...result,binding:{...result.binding,base:'d'.repeat(40)}},{...result,binding:{...result.binding,head:'d'.repeat(40)}},{...result,binding:{...result.binding,repoId:2}}])assert.equal(approvalVerdict(changed,[review],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[review],[]).allowed,false);
 assert.equal(approvalVerdict(result,[{...review,user:{id:7,type:'Bot'}}],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[review,{...review,state:'DISMISSED'}],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[{...review,body:review.body+'\nquoted text'}],[7]).allowed,false);
});
