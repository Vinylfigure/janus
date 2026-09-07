import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runWeekly,GitHubRuntime,harvest} from './weekly-learning.mjs';
const digest=v=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const repo=(process.env.GITHUB_REPOSITORY??'Vinylfigure/janus').toLowerCase();
const token=process.env.GH_TOKEN;const write=process.argv.includes('--write');
const config=JSON.parse(readFileSync(new URL('../.github/learning-sources.json',import.meta.url),'utf8'));
if(config.version!==1||!Array.isArray(config.repositories)||config.repositories.length>30)throw Error('Invalid learning source configuration');
async function api(method,path,data){
 if(method!=='GET'&&!write)throw Error('Writes require --write');
 const response=await fetch('https://api.github.com'+path,{method,headers:{Accept:'application/vnd.github+json',Authorization:`Bearer ${token}`,'X-GitHub-Api-Version':'2022-11-28',...(data?{'Content-Type':'application/json'}:{})},...(data?{body:JSON.stringify(data)}:{})});
 if(!response.ok){const error=Error(`GitHub ${response.status}: ${path.split('?')[0]}`);error.status=response.status;throw error;}return response.status===204?{}:response.json();
}
async function list(path){const out=[];for(let page=1;;page++){const batch=await api('GET',`${path}${path.includes('?')?'&':'?'}per_page=100&page=${page}`);if(!Array.isArray(batch))throw Error('Incomplete list');out.push(...batch);if(batch.length<100)return out;}}
const metadata=await api('GET',`/repos/${repo}`);
const revision=process.env.GITHUB_SHA??(await api('GET',`/repos/${repo}/commits/${metadata.default_branch}`)).sha;
const workflow=await api('GET',`/repos/${repo}/contents/.github/workflows/weekly-learning.yml?ref=${revision}`);
const configurationRevision=digest({...config.loop,workflowRevision:workflow.sha});
const resource=`${repo}/github-action/weekly-learning.yml`;
const client={
 async ownLedger(){const f=await api('GET',`/repos/${repo}/contents/.claude/memory/LEARNINGS.md?ref=${revision}`);if(f.encoding!=='base64')throw Error('Template ledger unavailable');return Buffer.from(f.content,'base64').toString('utf8');},
 async sources(){return Promise.all(config.repositories.map(async source=>{try{
   const meta=await api('GET',`/repos/${source}`),head=await api('GET',`/repos/${source}/commits/${meta.default_branch}`);
   for(const path of config.ledgerPaths)try{const ledger=await api('GET',`/repos/${source}/contents/${path}?ref=${head.sha}`);if(ledger.encoding!=='base64')throw Error('Unreadable ledger');return {repo:meta.full_name,revision:head.sha,body:Buffer.from(ledger.content,'base64').toString('utf8')};}catch(e){if(e.status!==404)throw e;}
   throw Error('No configured ledger found');
 }catch(e){return {repo:source,error:e.message};}}));},
 async preflight(){const user=await api('GET','/user');if(user.type!=='User'||!metadata.permissions?.push)throw Error('Weekly dispatch requires the configured user-owned credential and repository write access');
   const channel=await api('GET',`/repos/${repo}/contents/.github/workflows/claude.yml?ref=${revision}`);if(channel.encoding!=='base64'||!Buffer.from(channel.content,'base64').toString('utf8').includes('issue_comment:'))throw Error('Dispatch channel unavailable');},
 async findOperation(id){return (await list(`/repos/${repo}/issues?state=all`)).filter(i=>!i.pull_request&&(i.body??'').split('\n').includes(`Weekly-operation: ${id}`));},
 createTask:draft=>api('POST',`/repos/${repo}/issues`,draft),
 async progress(task,op){
   const pulls=(await list(`/repos/${repo}/pulls?state=all`)).filter(p=>(p.body??'').split('\n').includes(`Weekly-operation: ${op.id}`));
   if(pulls.length>1)throw Error('Multiple PRs for one improvement require reconciliation');
   if(!pulls.length)return {complete:false};
   const pull=await api('GET',`/repos/${repo}/pulls/${pulls[0].number}`);if(!new RegExp(`(?:Closes|Fixes|Resolves) #${task.number}(?:\\s|$)`).test(pull.body??'')||!pull.merged||!pull.merge_commit_sha)return {complete:false};
   const checks=await api('GET',`/repos/${repo}/commits/${pull.merge_commit_sha}/check-runs?per_page=100`);
   if(!Array.isArray(checks.check_runs)||checks.total_count!==checks.check_runs.length||!checks.check_runs.length)return {complete:false};
   return {complete:checks.check_runs.some(c=>c.name==='hook-tests')&&checks.check_runs.every(c=>c.status==='completed'&&c.conclusion==='success')};
 },
 async pulse(pulse){
   const branch=`runtime/execution-pulse/${digest(resource).slice(0,24)}`;
   let ref;try{ref=await api('GET',`/repos/${repo}/git/ref/heads/${branch}`);}catch(e){if(e.status!==404)throw e;}
   const parent=ref?.object.sha??revision;
   const blob=await api('POST',`/repos/${repo}/git/blobs`,{content:JSON.stringify({...pulse,resource}),encoding:'utf-8'});
   const tree=await api('POST',`/repos/${repo}/git/trees`,{tree:[{path:'state.json',mode:'100644',type:'blob',sha:blob.sha}]});
   const commit=await api('POST',`/repos/${repo}/git/commits`,{message:'Record weekly learning execution pulse',tree:tree.sha,parents:[parent]});
   if(ref)await api('PATCH',`/repos/${repo}/git/refs/heads/${branch}`,{sha:commit.sha,force:false});else await api('POST',`/repos/${repo}/git/refs`,{ref:`refs/heads/${branch}`,sha:commit.sha});
 },
};
if(!write){console.log(JSON.stringify(harvest(await client.sources()),null,2));}
else {const store=new GitHubRuntime(api,repo,{write:true});const result=await runWeekly(client,store,{owner:`run:${process.env.GITHUB_RUN_ID??Date.now()}`,runId:process.env.GITHUB_RUN_ID??'manual',sourceRevision:revision,configurationRevision});console.log(JSON.stringify(result));if(result.state==='failed')process.exitCode=1;}
