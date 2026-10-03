import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyEffects,bindPolicy,approvalVerdict,hash,codexFallbackCoverage,machineryPath } from './effect-policy.mjs';
import { readFileSync } from 'node:fs';
const classify=(path,before,after,extra={})=>classifyEffects({files:[{path,before,after,...extra}]});
test('ordinary application edits are eligible but enforcement edits need evidence',()=>{
 assert.equal(classify('src/app.js','a','b').verdict,'allow');
 for(const path of ['scripts/guard.sh','scripts/new-helper.mjs','.claude/hooks/pre.sh'])assert.equal(classify(path,'deny bad','exit 0 # guard').verdict,'unknown');
});
test('keyword camouflaged arbitrary code is never a narrowing proof',()=>{
 for(const after of ['deny bad\nexit 0 # guard','deny bad\neval "$INPUT" # test','deny bad\nreturn true // assert'])assert.equal(classify('scripts/guard.sh','deny bad',after).verdict,'unknown');
});
test('native Codex instructions and configuration retain machinery review holds',()=>{
 for(const path of ['AGENTS.md','AGENTS.override.md','apps/api/AGENTS.md','apps/api/AGENTS.override.md','apps/api/agents.OVERRIDE.MD','.agents','.codex','apps/api/.agents','apps/api/.codex','.agents/skills/janus-workflow/SKILL.md','.agents/skills/new/SKILL.md','apps/api/.agents/skills/local/SKILL.md','apps/api/.AGENTS/skills/local/SKILL.md','.codex/config.toml','.codex/hooks.json','apps/api/.codex/config.toml','apps/api/.codex/hooks.json']) {
  assert.equal(classify(path,'old','new').verdict,'unknown');
  assert.equal(classify(path,'','new').verdict,'unknown');
  assert.equal(classify(path,undefined,'new').verdict,'unknown');
  assert.equal(classify(path,'old','').verdict,'protected');
  assert.equal(classify(path,'old','new',{status:'renamed'}).verdict,'unknown');
  const result=bindPolicy({repo:'o/r',repoId:1,pr:2,head:'a'.repeat(40),base:'b'.repeat(40),files:[{path,before:'old',after:'new'}]},'c'.repeat(64));
  assert.equal(approvalVerdict(result,[],[7]).allowed,false);
 }
 assert.equal(classify('.claude/memory/LEARNINGS.md','old','new').verdict,'allow');
 for(const path of ['src/app.js','docs/AGENTS.md.txt','docs/my-AGENTS.md','apps/.agents-old/guide.md','apps/.codex-example/config.toml']) {
  assert.equal(machineryPath(path),false,path);
  assert.equal(classify(path,'old','new').verdict,'allow',path);
 }
});
test('fallback preflight holds unknown configuration and unregistered names',()=>{
 assert.equal(codexFallbackCoverage([]).supported,true);
 assert.equal(codexFallbackCoverage(['AGENTS.md','agents.override.md']).supported,true);
 assert.deepEqual(codexFallbackCoverage(['TEAM_GUIDE.md']),{supported:false,unsupported:['TEAM_GUIDE.md']});
 for(const value of [undefined,null,{},'TEAM_GUIDE.md',[null],[''],['../TEAM_GUIDE.md'],['nested/TEAM_GUIDE.md'],['nested\\TEAM_GUIDE.md']])assert.equal(codexFallbackCoverage(value).supported,false);
});
test('a reviewed literal fallback registration protects its basename at every depth and changes policy identity',async()=>{
 const source=readFileSync(new URL('./effect-policy.mjs',import.meta.url),'utf8');
 const registered=source.replace('CODEX_FALLBACK_FILENAMES = Object.freeze([])','CODEX_FALLBACK_FILENAMES = Object.freeze(["TEAM_GUIDE.md"])');
 assert.notEqual(hash(source),hash(registered));
 const policy=await import(`data:text/javascript;base64,${Buffer.from(registered).toString('base64')}`);
 assert.equal(policy.codexFallbackCoverage(['TEAM_GUIDE.md']).supported,true);
 for(const path of ['TEAM_GUIDE.md','apps/api/TEAM_GUIDE.md','apps/api/team_guide.MD']) {
  assert.equal(policy.machineryPath(path),true,path);
  assert.equal(policy.classifyEffects({files:[{path,before:'old',after:'new'}]}).verdict,'unknown');
 }
 assert.equal(policy.machineryPath('docs/my-TEAM_GUIDE.md'),false);
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
 for(const changed of [{...result,binding:{...result.binding,base:'d'.repeat(40)}},{...result,binding:{...result.binding,head:'d'.repeat(40)}},{...result,binding:{...result.binding,repoId:2}},{...result,binding:{...result.binding,policyVersion:result.binding.policyVersion-1}},{...result,binding:{...result.binding,policyDigest:'changed'}},{...result,binding:{...result.binding,diffDigest:'changed'}}])assert.equal(approvalVerdict(changed,[review],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[review],[]).allowed,false);
 assert.equal(approvalVerdict(result,[{...review,user:{id:7,type:'Bot'}}],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[review,{...review,state:'DISMISSED'}],[7]).allowed,false);
 assert.equal(approvalVerdict(result,[{...review,body:review.body+'\nquoted text'}],[7]).allowed,false);
});
