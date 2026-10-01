/** Pure authority effects. Unknown syntax is a hold, never evidence of safety. */
import { createHash } from 'node:crypto';
export const POLICY_VERSION = 4;
export const hash = value => createHash('sha256').update(typeof value === 'string' ? value : stable(value)).digest('hex');
export const stable = value => JSON.stringify(value, (_, v) => v && typeof v === 'object' && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).sort(([a],[b]) => a.localeCompare(b))) : v);
export const machineryPath = path => /^(?:\.github\/|\.claude\/(?!memory\/)|\.agents\/|\.codex\/|scripts\/|CLAUDE\.md$|AGENTS\.md$|(?:package(?:-lock)?\.json|yarn\.lock|pnpm-lock\.yaml)$|docs\/(?:MERGE-POLICY|DECISIONS)\.md$)/.test(path);
const selfPolicy = path => /(?:effect-policy|policy-approval|policy-operators|check-machinery-gate|auto-merge|gate-integrity|MERGE-POLICY|DECISIONS)/.test(path);
const record = (kind,path,before,after) => ({kind,path,before,after});
function strictJSON(text) {
  // JSON.parse silently accepts duplicate keys. Reject them before interpretation.
  const seen = []; let inString=false, escape=false, token='', stringStart=0;
  for(let i=0;i<text.length;i++) { const c=text[i];
    if(inString){if(escape){escape=false;continue;}if(c==='\\'){escape=true;continue;}if(c==='"'){inString=false; if(/^\s*:/.test(text.slice(i+1))){const key=JSON.parse(text.slice(stringStart,i+1));const scope=seen.at(-1);if(!scope||scope.has(key))throw Error('duplicate JSON key');scope.add(key);}}continue;}
    if(c==='"'){inString=true;stringStart=i;}else if(c==='{')seen.push(new Set());else if(c==='}')seen.pop();
  }
  return JSON.parse(text);
}
function settingsEffect(file) {
  const a=strictJSON(file.before), b=strictJSON(file.after);
  const aa={...a},bb={...b};delete aa.permissions;delete bb.permissions;
  if(stable(aa)!==stable(bb))return null;
  const x=a.permissions??{},y=b.permissions??{};
  if(Object.keys(x).some(k=>!['allow','deny','ask'].includes(k))||Object.keys(y).some(k=>!['allow','deny','ask'].includes(k)))return null;
  for(const obj of [x,y])for(const arr of Object.values(obj))if(!Array.isArray(arr)||arr.some(s=>typeof s!=='string'))return null;
  const subset=(small,big)=>small.every(v=>big.includes(v));
  if(stable(x.ask??[])!==stable(y.ask??[]))return null;
  const safe=subset(y.allow??[],x.allow??[])&&subset(x.deny??[],y.deny??[]);
  return record(safe?'permissions-narrowed':'authority-expanded',file.path,x,y);
}
function cronEffect(file) {
  // A deliberately small YAML subset: only replacing an existing literal cron.
  // Reject aliases/tags/merges, duplicate cron lines, multiline and expressions.
  const texts=[file.before,file.after];
  if(texts.some(t=>/(?:^|\s)[&*!][A-Za-z_]|<<:/m.test(t)))return null;
  const pattern=/^(    - cron:[ \t]*)(["'])([0-9*,/ -]+)\2[ \t]*(?:#.*)?$/gm;
  if(texts.some(t=>!/^on:\n  schedule:\n    - cron:/m.test(t)||(t.match(/^on:/gm)??[]).length!==1))return null;
  const matches=texts.map(t=>[...t.matchAll(pattern)]);
  if(matches.some(m=>m.length!==1))return null;
  const valid=s=>{const fields=s.trim().split(/\s+/),limits=[[0,59],[0,23],[1,31],[1,12],[0,6]];
    return fields.length===5&&fields.every((f,i)=>f.split(',').every(part=>{const [range,step,...rest]=part.split('/');if(rest.length||step!==undefined&&(!/^\d+$/.test(step)||Number(step)<1||Number(step)>limits[i][1]))return false;
      if(range==='*')return true;const nums=range.split('-');return nums.length<=2&&nums.every(n=>/^\d+$/.test(n)&&Number(n)>=limits[i][0]&&Number(n)<=limits[i][1])&&(nums.length===1||Number(nums[0])<=Number(nums[1]));}));};
  if(matches.some(m=>!valid(m[0][3])))return null;
  if(texts[0].replace(pattern,'<schedule>')!==texts[1].replace(pattern,'<schedule>'))return null;
  return record('schedule-changed',file.path,matches[0][0][3],matches[1][0][3]);
}
export function classifyEffects({files, complete=true, authorityPaths=[],incompleteReason}) {
  if(!complete||!Array.isArray(files)||!files.length)return {verdict:'unknown',effects:[],reasons:[incompleteReason??'Complete changed-file evidence is required.']};
  const effects=[],reasons=[];let verdict='allow';
  const hold=(kind,reason)=>{if(verdict!=='protected'||kind==='protected')verdict=kind;reasons.push(reason);};
  for(const f of files){
    if(!f||typeof f.path!=='string'||f.path.includes('..')||f.path.startsWith('/')){hold('unknown','Invalid file identity.');continue;}
    if(f.status==='renamed'||f.modeChanged||f.binary){hold('unknown',`${f.path}: rename, mode or binary effects need review.`);continue;}
    if(!machineryPath(f.path)&&!authorityPaths.includes(f.path)){effects.push(record('ordinary-change',f.path,null,null));continue;}
    if(selfPolicy(f.path)){effects.push(record('policy-changed',f.path,null,null));hold('protected',`${f.path}: changes the authority policy or its enforcement.`);continue;}
    if(typeof f.before!=='string'||typeof f.after!=='string'){hold('unknown',`${f.path}: full before and after content is required.`);continue;}
    if(f.before===f.after)continue;
    if(!f.after){effects.push(record('enforcement-removed',f.path,null,null));hold('protected',`${f.path}: removes machinery.`);continue;}
    let effect;
    try {if(f.path==='.claude/settings.json')effect=settingsEffect(f);else if(/^\.github\/workflows\/.+\.ya?ml$/.test(f.path))effect=cronEffect(f);}catch{}
    if(effect){effects.push(effect);if(effect.kind==='authority-expanded')hold('protected',`${f.path}: expands effective permission.`);}
    else {effects.push(record('unclassified-machinery-change',f.path,null,null));hold('unknown',`${f.path}: no proven effect-preserving or narrowing transformation.`);}
  }
  return {verdict,effects,reasons};
}
export function bindPolicy(input,policyDigest) {
  const result=classifyEffects(input);
  return {...result,version:1,binding:{repo:input.repo,repoId:input.repoId,pr:input.pr,head:input.head,base:input.base,policyVersion:POLICY_VERSION,policyDigest,diffDigest:hash(input.files)}};
}
export function approvalVerdict(result,reviews,operatorIds) {
  if(result.verdict==='allow')return {allowed:true,reason:'policy_allows'};
  if(!Array.isArray(reviews)||!Array.isArray(operatorIds)||!operatorIds.length)return {allowed:false,reason:'approval_unavailable'};
  const expected=hash(result.binding), latest=new Map();
  for(const r of reviews)if(operatorIds.includes(r.user?.id)&&r.user?.type==='User')latest.set(r.user.id,r);
  for(const r of latest.values()) {
    if(r.state!=='APPROVED'||r.commit_id!==result.binding.head)continue;
    if((r.body??'').trim()===`<!-- overlord:policy-approval:v1 -->\nAction: merge\nBinding-sha256: ${expected}`)return {allowed:true,reason:'revision_bound_human_review',reviewId:r.id};
  }
  return {allowed:false,reason:'protected_or_unknown_effect_requires_current_review'};
}
