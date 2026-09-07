import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { readPolicySnapshot } from './effect-policy-read.mjs';
import { signedApprovalVerdict } from './policy-approval.mjs';
import { bindPolicy, approvalVerdict, machineryPath, hash } from './effect-policy.mjs';
const run=(cmd,args)=>execFileSync(cmd,args,{encoding:'utf8',maxBuffer:20*1024*1024});
const arg=name=>process.argv.find(s=>s.startsWith(`--${name}=`))?.slice(name.length+3);
const policyDigest=hash(readFileSync(new URL('./effect-policy.mjs',import.meta.url),'utf8'));
export function gitSnapshot(base,head='HEAD') {
  const git=args=>run('git',args), files=[];
  const rows=git(['diff','--name-status','--no-renames',`${base}...${head}`]).trim().split('\n').filter(Boolean);
  const mergeBase=git(['merge-base',base,head]).trim();
  for(const row of rows){const [status,path]=row.split('\t'); if(!path)throw Error('Invalid file list');
    const read=(ref,exists)=>exists?git(['show',`${ref}:${path}`]):'';
    const modes=[mergeBase,head].map(ref=>git(['ls-tree',ref,'--',path]).split(' ')[0]);
    files.push({path,status,modeChanged:status==='M'&&modes[0]!==modes[1],before:read(mergeBase,status!=='A'),after:read(head,status!=='D')});
  }
  return {files,base:git(['rev-parse',base]).trim(),head:git(['rev-parse',head]).trim()};
}
if(process.argv[1]===fileURLToPath(import.meta.url))try{
  const repo=arg('repo'),pr=arg('pr');
  const input=arg('input')?JSON.parse(readFileSync(arg('input'),'utf8')):repo?await readPolicySnapshot(repo,pr,arg('head'),async path=>JSON.parse(run('gh',['api',path]))):gitSnapshot(arg('base'),arg('head')??'HEAD');
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
