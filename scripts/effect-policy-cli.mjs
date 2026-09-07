import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { readPolicySnapshot } from './effect-policy-read.mjs';
import { signedApprovalVerdict } from './policy-approval.mjs';
import { bindPolicy, approvalVerdict, machineryPath, hash } from './effect-policy.mjs';
const run=(cmd,args)=>execFileSync(cmd,args,{encoding:'utf8',maxBuffer:20*1024*1024});
const arg=name=>process.argv.find(s=>s.startsWith(`--${name}=`))?.slice(name.length+3);
const policyDigest=hash(readFileSync(new URL('./effect-policy.mjs',import.meta.url),'utf8'));
export async function gitSnapshot(base,head='HEAD') {
  const git=args=>run('git',args),baseSHA=git(['rev-parse',base]).trim(),headSHA=git(['rev-parse',head]).trim();
  const rows=git(['diff','--name-status','--no-renames',`${baseSHA}...${headSHA}`]).trim().split('\n').filter(Boolean);
  const files=rows.map(row=>{const [status,filename]=row.split('\t');if(!filename)throw Error('Invalid file list');return {filename,status:({A:'added',D:'removed',M:'modified'})[status]??'renamed',changes:1,patch:'local source comparison'};});
  const api=async path=>{
    if(path==='repos/local/worktree/pulls/1')return {base:{sha:baseSHA,repo:{id:1,full_name:'local/worktree'}},head:{sha:headSHA},changed_files:files.length};
    if(path.includes('/files?')){const page=Number(/page=(\d+)$/.exec(path)?.[1]??1);return files.slice((page-1)*100,page*100);}
    if(path.includes('/git/trees/')){const ref=path.split('/git/trees/')[1].split('?')[0];return {tree:git(['ls-tree','-rz','--full-tree',ref]).split('\0').filter(Boolean).map(row=>{const [meta,path]=row.split('\t'),[mode,type,sha]=meta.split(' ');return {path,mode,type,sha};})};}
    if(path.includes('/contents/')){const [file,ref]=path.split('/contents/')[1].split('?ref=');return {encoding:'base64',content:Buffer.from(git(['show',`${ref}:${file}`])).toString('base64')};}
    throw Error('Unknown local policy read');
  };
  return readPolicySnapshot('local/worktree',1,headSHA,api);
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{
  const repo=arg('repo'),pr=arg('pr');
  const input=arg('input')?JSON.parse(readFileSync(arg('input'),'utf8')):repo?await readPolicySnapshot(repo,pr,arg('head'),async path=>JSON.parse(run('gh',['api',path]))):await gitSnapshot(arg('base'),arg('head')??'HEAD');
  const result=bindPolicy(input,policyDigest);
  const reviews=repo?JSON.parse(run('gh',['api','--paginate','--slurp',`repos/${repo}/pulls/${pr}/reviews?per_page=100`])).flat():[];
  const operators=(process.env.POLICY_OPERATOR_IDS??'').split(',').filter(Boolean).map(Number);
  let authorization=approvalVerdict(result,reviews,operators);
  if(repo&&result.verdict!=='allow'){
    const comments=JSON.parse(run('gh',['api','--paginate','--slurp',`repos/${repo}/issues/${pr}/comments?per_page=100`])).flat();
    const config=JSON.parse(readFileSync(new URL('../.github/policy-operators.json',import.meta.url),'utf8'));
    const signed=signedApprovalVerdict(result,comments,config);
    if(signed.reason==='approval_revoked'||signed.allowed||!authorization.allowed)authorization=signed;
  }
  console.log(JSON.stringify({...result,authorization}));process.exitCode=authorization.allowed?0:1;
}catch(e){console.log(JSON.stringify({version:1,verdict:'unknown',reasons:[String(e.message)],authorization:{allowed:false,reason:'policy_evidence_unavailable'}}));process.exitCode=1;}
