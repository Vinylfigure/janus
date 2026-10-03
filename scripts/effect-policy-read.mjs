/** Shared GitHub read projection. No writes; no candidate code execution. */
import { posix } from 'node:path';
import { machineryPath } from './effect-policy.mjs';
const source=/\.(?:[cm]?[jt]sx?|sh|ya?ml|json|node|wasm)$/;
export async function readPolicySnapshot(repo,pr,expectedHead,api) {
  const pull=await api(`repos/${repo}/pulls/${pr}`);
  if(pull.head?.sha!==expectedHead||!pull.base?.sha||!Number.isSafeInteger(pull.base.repo?.id))throw Error('PR identity changed or unavailable');
  const base=pull.base.sha,head=pull.head.sha,files=[];let page=1;
  while(true){const batch=await api(`repos/${repo}/pulls/${pr}/files?per_page=100&page=${page++}`);if(!Array.isArray(batch))throw Error('Unreadable file list');files.push(...batch);if(batch.length<100)break;}
  if(files.length!==pull.changed_files)throw Error('Incomplete file list');
  const trees=await Promise.all([base,head].map(async ref=>{const tree=await api(`repos/${repo}/git/trees/${ref}?recursive=1`);if(tree.truncated||!Array.isArray(tree.tree))throw Error('Incomplete source tree');return new Map(tree.tree.map(f=>[f.path,f]));}));
  // A stable instruction symlink can give an ordinary-path target authority.
  // Without a proven target resolver, even edits beyond that link must hold.
  const linkedAuthority=trees.some(tree=>[...tree.values()].some(f=>f.mode==='120000'&&machineryPath(f.path)));
  const cache=new Map();let reads=0,changedReads=0;const maxReads=180;let dependencyIncomplete=false;
  const read=async(path,ref,changed=false)=>{const tree=trees[ref===base?0:1];const key=tree.get(path)?.sha??ref+':'+path;if(!cache.has(key))cache.set(key,(async()=>{if(changed?++changedReads>200:++reads>maxReads){const error=Error('Authority dependency expansion incomplete: bounded source budget exhausted');error.code='POLICY_BUDGET';throw error;}const f=await api(`repos/${repo}/contents/${path}?ref=${ref}`);if(f.encoding!=='base64'||typeof f.content!=='string')throw Error('Unreadable source');return Buffer.from(f.content,'base64').toString('utf8');})());return cache.get(key);};
  // Follow both trees: a PR cannot move enforcement to an ordinary helper and
  // thereby escape classification. Unknown dynamic local imports protect all
  // changed executable files instead of guessing their destination.
  const authorityPaths=new Set();let dynamic=false;
  if(files.some(f=>source.test(f.filename)&&!machineryPath(f.filename))){
    try { for(let i=0;i<2;i++){
      const ref=[base,head][i],tree=trees[i],queue=[...tree.keys()].filter(p=>machineryPath(p)&&source.test(p));
      const seen=new Set();
      while(queue.length){
        const batch=queue.splice(0,12).filter(p=>!seen.has(p));batch.forEach(p=>seen.add(p));
        await Promise.all(batch.map(async path=>{
          authorityPaths.add(path);const text=await read(path,ref);
          if(/\b(?:import|require)\s*\(\s*[^'"\s]/.test(text))dynamic=true;
          const literals=[...text.matchAll(/(?:\bfrom\s*|\bimport\s*\(?\s*|\brequire\s*\(\s*|\bsource\s+|\bnode\s+|\bbash\s+)['"]?([.@~\w:/-]+(?:\.[\w]+)?)/g)].map(m=>m[1]);
          for(const target of literals){
            if(target.startsWith('@')||target.startsWith('~'))dynamic=true;
            if(target.startsWith('node:'))continue;
            const candidates=[posix.normalize(posix.join(posix.dirname(path),target)),target.replace(/^\.\//,'')];
            for(const candidate of candidates)for(const suffix of ['','.mjs','.js','.ts','/index.js','/index.ts']){
              const resolved=candidate+suffix;if(tree.has(resolved)&&source.test(resolved)&&!seen.has(resolved))queue.push(resolved);
            }
          }
        }));
      }
    }
    } catch(error) { if(error.code!=='POLICY_BUDGET')throw error;dependencyIncomplete=true;dynamic=true; }
  }
  if(dynamic)for(const f of files)if(source.test(f.filename))authorityPaths.add(f.filename);
  const changedContent=async(path,ref)=>{try{return await read(path,ref,true);}catch(error){if(error.code!=='POLICY_BUDGET')throw error;dependencyIncomplete=true;return null;}};
  const projected=await Promise.all(files.map(async f=>{
    const relevant=machineryPath(f.filename)||authorityPaths.has(f.filename);
    const before=trees[0].get(f.filename),after=trees[1].get(f.filename);
    return {path:f.filename,status:f.status,binary:!f.patch&&f.changes>0,modeChanged:!!before&&!!after&&before.mode!==after.mode,
      beforeBlob:before?.sha??null,afterBlob:after?.sha??null,
      before:relevant&&before?await changedContent(f.filename,base):'',after:relevant&&after?await changedContent(f.filename,head):''};
  }));
  return {repo:pull.base.repo.full_name.toLowerCase(),repoId:pull.base.repo.id,pr:Number(pr),base,head,complete:!dependencyIncomplete&&!linkedAuthority,incompleteReason:linkedAuthority?'Symbolic machinery sources are unsupported; target authority requires exact-revision review.':dependencyIncomplete?'Authority dependency expansion incomplete; exact revision requires review.':null,authorityPaths:[...authorityPaths].sort(),files:projected.sort((a,b)=>a.path.localeCompare(b.path))};
}
