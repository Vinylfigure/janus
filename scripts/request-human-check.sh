#!/usr/bin/env bash
# Source-bound review producer. Dry-run unless --write; never changes issue text.
# Usage: request-human-check.sh --repo owner/repo --issue N --source-version SHA --evidence RUN_URL [--write]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec python3 - "$ROOT" "$@" <<'PY'
import argparse, hashlib, json, re, subprocess, sys, tempfile, urllib.request, urllib.error
from datetime import datetime
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--repo',required=True); p.add_argument('--issue',type=int,required=True)
p.add_argument('--source-version',required=True); p.add_argument('--evidence',required=True); p.add_argument('--write',action='store_true')
a=p.parse_args(sys.argv[2:]); root=Path(sys.argv[1])
def fail(message): raise RuntimeError(message)
def api(path, payload=None, paginate=False):
    args=['gh','api',path]
    if paginate: args+=['--paginate','--slurp']
    if payload is not None: args+=['--method','POST','--input','-']
    result=subprocess.run(args,input=json.dumps(payload) if payload is not None else None,text=True,capture_output=True,check=True)
    return json.loads(result.stdout)
def version(issue): return hashlib.sha256(json.dumps([issue['title'],issue.get('body') or ''],ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
def current():
    item=api(f'repos/{a.repo}/issues/{a.issue}')
    if item.get('state')!='open' or item.get('pull_request') or version(item)!=a.source_version: fail('The task changed or closed; reread its current review instructions.')
    return item
try:
    if not re.fullmatch(r'[\w.-]+/[\w.-]+',a.repo) or a.issue<1 or not re.fullmatch(r'[a-f0-9]{64}',a.source_version): fail('Invalid issue identity or source version.')
    item=current(); body=item.get('body') or ''
    labels=[l if isinstance(l,str) else l.get('name') for l in item.get('labels',[])]
    if re.match(r'^task:\s*\[operator\]',item['title'],re.I) or any(label in labels for label in ('human-action:','intent:','goal:')) or body.lstrip().startswith('<!-- overlord:human-work:v1 -->'): fail('A human action or outcome is not a delivered task review.')
    if 'task:' not in labels and not item['title'].lower().startswith('task:'): fail('Only a delivered task may request a result review.')
    with tempfile.TemporaryDirectory(prefix='janus-review-') as tmp:
        path=Path(tmp)/'body.md'; path.write_text(body)
        subprocess.run([str(root/'scripts/check-record.sh'),str(path),'--ready-for-review'],check=True)
    raw=re.search(r'^### Human check[ \t]*\n(.*?)(?=^#{1,3}[ \t]|\Z)',body.replace('\r\n','\n'),re.M|re.S)[1]
    url=re.search(r'^#### URL[ \t]*\n(.*?)(?=^#{1,4}[ \t]|\Z)',raw,re.M|re.S)
    target=url[1].strip() if url else re.search(r'^URL:[ \t]*(.+)$',raw,re.M|re.I)[1].strip()
    run_ref=re.fullmatch(r'https://github.com/([\w.-]+/[\w.-]+)/actions/runs/([1-9]\d*)',a.evidence)
    if not run_ref: fail('Evidence must be a completed GitHub Actions run URL.')
    run=api(f'repos/{run_ref[1]}/actions/runs/{run_ref[2]}')
    if run.get('status')!='completed' or run.get('conclusion')!='success' or not re.fullmatch(r'[a-f0-9]{40,64}',run.get('head_sha','')): fail('Automated verification has not passed on a known revision.')
    pull_ref=re.fullmatch(r'https://github.com/([\w.-]+/[\w.-]+)/pull/([1-9]\d*)',target)
    if pull_ref:
        pull=api(f'repos/{pull_ref[1]}/pulls/{pull_ref[2]}')
        if pull_ref[1].lower()!=run_ref[1].lower() or pull.get('head',{}).get('sha')!=run['head_sha']: fail('Verification does not cover the delivered pull request revision.')
    else:
        # No source credentials are forwarded to a preview host.
        with urllib.request.urlopen(target,timeout=15) as response:
            if response.status>=400: fail('The delivered artifact cannot be opened.')
    pages=api(f'repos/{a.repo}/issues/{a.issue}/comments?per_page=100',paginate=True)
    comments=[c for page in pages for c in page]
    def field(text,name):
        match=re.search(r'^'+re.escape(name)+r':[ \t]*(\S+)[ \t]*$',text,re.M)
        return match[1] if match else None
    # Replay the same delivery/verdict chain as the human workspace. An old
    # failed verdict is not the predecessor after a newer review was accepted.
    state=None; seen_requests=set()
    for comment in comments:
        text=comment.get('body') or ''
        if field(text,'Source-version')!=a.source_version or field(text,'Artifact')!=target or not field(text,'Operation'): continue
        if field(text,'Action-version') and field(text,'Action-version')!=a.source_version: continue
        marker=next((line for line in text.splitlines() if line.strip()),'')
        if marker=='<!-- janus:human-check-request:v1 -->':
            op=field(text,'Operation')
            if field(text,'Status')!='ready' or not re.fullmatch(r'https?://\S+',field(text,'Evidence') or '') or not re.fullmatch(r'[a-f0-9]{40,64}',field(text,'Source-revision') or '') or op in seen_requests: continue
            if state and state.get('operation') and field(text,'Supersedes-review-operation')!=state['operation']: continue
            seen_requests.add(op); state={'status':'ready','request':op,'comment':comment}
        elif marker=='<!-- janus:human-check:v1 -->':
            if field(text,'Review-request-operation')!=(state or {}).get('request'): continue
            if field(text,'Result') in ('pass','fail'): state={'status':field(text,'Result'),'operation':field(text,'Operation'),'request':field(text,'Review-request-operation'),'comment':comment}
    verdict=state['comment'] if state and state['status'] in ('pass','fail') else None
    supersedes=state['operation'] if verdict else None
    if verdict:
        if not verdict.get('created_at') or not run.get('created_at') or datetime.fromisoformat(run['created_at'].replace('Z','+00:00'))<=datetime.fromisoformat(verdict['created_at'].replace('Z','+00:00')): fail('An answered review needs new delivery evidence before requesting review again.')
    operation=hashlib.sha256(json.dumps([a.repo.lower(),a.issue,a.source_version,target,a.evidence,supersedes],separators=(',',':')).encode()).hexdigest()
    receipt='\n'.join(['<!-- janus:human-check-request:v1 -->',f'Source-version: {a.source_version}',f'Operation: {operation}',f'Artifact: {target}',f'Evidence: {a.evidence}',f'Source-revision: {run["head_sha"]}','Status: ready'])
    if supersedes: receipt+='\nSupersedes-review-operation: '+supersedes
    if state and state['status']=='ready' and field(state['comment']['body'],'Evidence')==a.evidence:
        receipt=state['comment']['body'].strip(); operation=state['request']
    if not a.write:
        print(json.dumps({'ready':True,'write':False,'sourceVersion':a.source_version,'artifact':target,'evidence':a.evidence})); sys.exit(0)
    existing=[c for c in comments if (c.get('body') or '').strip()==receipt]
    current()
    if not existing: api(f'repos/{a.repo}/issues/{a.issue}/comments',{'body':receipt})
    current()
    api(f'repos/{a.repo}/issues/{a.issue}/labels',{'labels':['human-check:']})
    print(json.dumps({'ready':True,'recorded':True,'operation':operation,'sourceVersion':a.source_version}))
except (RuntimeError, subprocess.CalledProcessError, urllib.error.URLError, ValueError, KeyError, TypeError) as error:
    print(f'Review request held: {error}',file=sys.stderr); sys.exit(1)
PY
