"""Offline end-to-end producer tests; transports are stubbed, the producer is real."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
BODY = '''### In plain words
Review whether the saved value survives refresh.
### Human check
#### Surface
Delivered change
#### Instruction
Open the page, save a value, then refresh.
#### URL
https://github.com/o/app/pull/9
#### Pass criteria
The saved value remains visible after refresh.
'''
ISSUE = {"number": 1, "state": "open", "title": "task: Preserve saved values", "body": BODY, "labels": ["task:"]}
VERSION = hashlib.sha256(json.dumps([ISSUE["title"], BODY], separators=(",", ":")).encode()).hexdigest()
STUB = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root=Path(os.environ['REVIEW_FIXTURE']); path=sys.argv[2]
state=json.loads((root/'state.json').read_text())
def save(): (root/'state.json').write_text(json.dumps(state))
if '--method' in sys.argv:
    payload=json.load(sys.stdin); state['writes'].append([path,payload])
    if path.endswith('/comments'): state['comments'].append({'body':payload['body']})
    save(); print(json.dumps({})); sys.exit()
if path.endswith('/issues/1'):
    state['reads']+=1; item=json.loads((root/'issue.json').read_text())
    if os.environ.get('CHANGE_SOURCE') and state['reads']>1: item['body']+='Changed'
    save(); print(json.dumps(item))
elif 'actions/runs' in path:
    print(json.dumps({'status':'completed','conclusion': 'failure' if os.environ.get('FAIL_EVIDENCE') else 'success','head_sha':'a'*40,'created_at':os.environ.get('REVIEW_RUN_CREATED','2026-09-06T00:00:00Z')}))
elif '/pulls/' in path:
    print(json.dumps({'head':{'sha': 'b'*40 if os.environ.get('STALE_EVIDENCE') else 'a'*40}}))
elif '/comments' in path: print(json.dumps([state['comments']]))
else: raise RuntimeError(path)
'''


class ProducerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "issue.json").write_text(json.dumps(ISSUE))
        (self.root / "state.json").write_text(json.dumps({"reads": 0, "writes": [], "comments": []}))
        (self.root / "gh").write_text(STUB)
        (self.root / "gh").chmod(0o700)

    def tearDown(self):
        self.tmp.cleanup()

    def run_request(self, write=False, **extra):
        args = [str(ROOT / "scripts/request-human-check.sh"), "--repo", "o/app", "--issue", "1", "--source-version", VERSION, "--evidence", "https://github.com/o/app/actions/runs/7"]
        return subprocess.run(args + (["--write"] if write else []), text=True, capture_output=True,
                              env={**os.environ, "PATH": f"{self.root}:{os.environ['PATH']}", "REVIEW_FIXTURE": str(self.root), **extra})

    def state(self):
        return json.loads((self.root / "state.json").read_text())

    def test_dry_run_has_no_writes(self):
        result = self.run_request()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()["writes"], [])

    def test_receipt_precedes_label_and_retry_reuses_it(self):
        for _ in range(2):
            result = self.run_request(write=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        state = self.state()
        self.assertEqual(len(state["comments"]), 1)
        self.assertTrue(state["writes"][0][0].endswith("/comments"))
        self.assertTrue(state["writes"][1][0].endswith("/labels"))
        self.assertIn(f"Source-version: {VERSION}", state["comments"][0]["body"])

    def test_stale_source_and_failed_or_wrong_revision_evidence_never_write(self):
        for flag in ["CHANGE_SOURCE", "FAIL_EVIDENCE", "STALE_EVIDENCE"]:
            result = self.run_request(write=True, **{flag: "1"})
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.state()["writes"], [])

    def test_failed_review_requires_new_evidence_and_exact_predecessor(self):
        state=self.state()
        state["comments"]=[{"created_at":"2026-09-06T00:01:00Z","body":f"<!-- janus:human-check:v1 -->\nSource-version: {VERSION}\nArtifact: https://github.com/o/app/pull/9\nResult: fail\nOperation: failed-review"}]
        (self.root / "state.json").write_text(json.dumps(state))
        self.assertNotEqual(self.run_request(write=True).returncode,0)
        self.assertEqual(self.state()["writes"],[])
        result=self.run_request(write=True, REVIEW_RUN_CREATED="2026-09-06T00:02:00Z")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn("Supersedes-review-operation: failed-review",self.state()["comments"][-1]["body"])

    def test_new_delivery_supersedes_latest_pass_instead_of_an_older_failure(self):
        fail=f"<!-- janus:human-check:v1 -->\nSource-version: {VERSION}\nArtifact: https://github.com/o/app/pull/9\nResult: fail\nOperation: failed-review"
        state=self.state();state["comments"]=[{"created_at":"2026-09-06T00:01:00Z","body":fail}]
        (self.root / "state.json").write_text(json.dumps(state))
        for _ in range(2):
            result=self.run_request(write=True, REVIEW_RUN_CREATED="2026-09-06T00:02:00Z")
            self.assertEqual(result.returncode,0,result.stderr)
        state=self.state();self.assertEqual(len(state["comments"]),2)
        request=state["comments"][-1]["body"]
        operation=next(line.split(": ",1)[1] for line in request.splitlines() if line.startswith("Operation: "))
        passed=fail.replace("Result: fail","Result: pass").replace("Operation: failed-review","Operation: accepted-review")+f"\nReview-request-operation: {operation}"
        state["comments"].append({"created_at":"2026-09-06T00:03:00Z","body":passed})
        (self.root / "state.json").write_text(json.dumps(state))
        result=self.run_request(write=True, REVIEW_RUN_CREATED="2026-09-06T00:04:00Z")
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn("Supersedes-review-operation: accepted-review",self.state()["comments"][-1]["body"])

    def test_incomplete_current_request_cannot_get_review_label(self):
        item = dict(ISSUE, body=BODY.replace("The saved value remains visible after refresh.", "_No response_"))
        (self.root / "issue.json").write_text(json.dumps(item))
        # Source mismatch is also a refusal. Exercise fields with matching source via the checker.
        path = self.root / "body.md"
        path.write_text(item["body"])
        result = subprocess.run([str(ROOT / "scripts/check-record.sh"), str(path), "--ready-for-review"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state()["writes"], [])


if __name__ == "__main__":
    unittest.main()
