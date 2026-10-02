"""Execute the real merge engine against strict offline GitHub/policy doubles."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
HEAD = "a" * 40
BASE = "b" * 40
MARKER = "<!-- janus:automerge:v1 -->"

# Each invocation persists its calls. An unrecognised command fails the test even
# if the engine handles the resulting command failure as an ordinary hold.
STUB = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['MERGE_FIXTURE'])
path = root / 'state.json'
s = json.loads(path.read_text())
args = sys.argv[1:]
tool = Path(sys.argv[0]).name
s['calls'].append([tool, args])
def save(): path.write_text(json.dumps(s))
def emit(value):
    save(); print(json.dumps(value)); sys.exit(0)
def fail(message):
    save(); print(message, file=sys.stderr); sys.exit(1)
def next_value(key, fallback):
    n = s['reads'].get(key, 0)
    s['reads'][key] = n + 1
    values = s.get(key, [fallback])
    value = values[min(n, len(values)-1)]
    if value == 'ERROR': fail('fixture read refused: ' + key)
    return value
if tool == 'node':
    expected = [str(Path(os.environ['ENGINE_ROOT']) / 'scripts/effect-policy-cli.mjs'),
                '--repo=example/project', '--pr=7', '--head=' + s['pr']['headRefOid']]
    if args == expected:
        allowed = next_value('policy', False)
        emit({'authorization': {'allowed': allowed}, 'reasons': [] if allowed else ['fixture policy requires current approval']})
elif tool == 'gh':
    if args == ['repo', 'view', '--json', 'defaultBranchRef']:
        emit(next_value('defaults', {'defaultBranchRef': {'name': 'main'}}))
    if args == ['label', 'list', '--limit', '300', '--json', 'name']:
        emit([{'name': n} for n in ['human-check:', 'question:', 'loop:hold', 'machinery-change']])
    if len(args) == 8 and args[:6] == ['pr', 'list', '--state', 'open', '--limit', '200'] and args[6] == '--json':
        requested = set(args[7].split(','))
        if requested <= set(s['pr']) | set(s.get('missing', [])):
            emit([s['pr']])
    if args == ['pr', 'view', '7', '--json', 'state,headRefOid,baseRefName,mergeCommit']:
        emit(next_value('outcomes', {'state': 'MERGED', 'headRefOid': s['pr']['headRefOid'], 'baseRefName': s['pr']['baseRefName'], 'mergeCommit': {'oid': 'd' * 40}}))
    if len(args) == 5 and args[:3] == ['pr', 'view', '7'] and args[3] == '--json':
        requested = set(args[4].split(','))
        if requested <= set(s['pr']) | set(s.get('missing', [])):
            emit(next_value('fresh_prs', s['pr']))
    if args == ['issue', 'view', '3', '--json', 'state,title,body,labels']:
        emit(next_value('issues', {'state': 'OPEN', 'title': 'task: Improve a report', 'body': '### Done means\nVerified.', 'labels': [{'name': 'task:'}]}))
    if args == ['api', '--paginate', 'repos/example/project/issues?labels=human-check%3A&state=open&per_page=100']:
        emit(next_value('human_checks', []))
    if args == ['api', '--paginate', 'repos/example/project/issues/7/comments?per_page=100']:
        emit(next_value('comment_reads', s['comments']))
    if args == ['api', '--paginate', 'repos/example/project/pulls/7/files?per_page=100']:
        emit([{'filename': p} for p in s['files']])
    if args == ['pr', 'checks', '7']:
        status = next_value('checks', 'pass')
        save(); print('verify\t' + status + '\t1m\thttps://example.invalid/check')
        sys.exit(0 if status == 'pass' else 1)
    if len(args) == 5 and args[:4] == ['pr', 'comment', '7', '--body']:
        s['writes'].append(['comment', args[4]])
        s['comments'].append({'body': args[4]})
        emit({})
    if args[:3] == ['pr', 'merge', '7']:
        if '--match-head-commit' in args and args[args.index('--match-head-commit') + 1] == s['pr']['headRefOid'] and '--merge' in args:
            s['writes'].append(['merge', args]); emit({})
s['unexpected'].append([tool, args])
fail('unexpected fixture command: ' + repr([tool, args]))
'''


def lifecycle(action, head=HEAD):
    return {"body": f"{MARKER}\nAction: {action}\nHead: {head}"}


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="janus-merge-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for tool in ("gh", "node"):
            path = self.root / tool
            path.write_text(STUB)
            path.chmod(0o700)
        self.initial = {
            "pr": {
                "number": 7, "title": "Improve a report", "headRefName": "task/report",
                "baseRefName": "main", "baseRefOid": BASE, "state": "OPEN", "body": "",
                "isDraft": False, "labels": [], "author": {"login": "fixture"},
                "reviewDecision": "", "mergeStateStatus": "CLEAN", "changedFiles": 1,
                "headRefOid": HEAD, "mergeable": "MERGEABLE", "reviews": [],
            },
            "files": ["README.md"], "comments": [], "calls": [], "writes": [],
            "reads": {}, "unexpected": [],
        }
        self.write(self.initial)

    def write(self, state):
        (self.root / "state.json").write_text(json.dumps(state))

    def state(self):
        return json.loads((self.root / "state.json").read_text())

    def configure(self, **changes):
        state = self.state()
        state.update(changes)
        self.write(state)

    def pr(self, **changes):
        state = self.state()
        state["pr"].update(changes)
        self.write(state)

    def run_engine(self, dry=False):
        env = {**os.environ, "PATH": f"{self.root}:{os.environ['PATH']}",
               "MERGE_FIXTURE": str(self.root), "ENGINE_ROOT": str(ROOT),
               "GITHUB_REPOSITORY": "example/project"}
        result = subprocess.run(["bash", str(ROOT / "scripts/auto-merge.sh")] + (["--dry-run"] if dry else []),
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(self.state()["unexpected"], [], result.stdout + result.stderr)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def merges(self):
        return [w for w in self.state()["writes"] if w[0] == "merge"]

    def comments(self, action):
        return [w for w in self.state()["writes"] if w[0] == "comment" and f"Action: {action}\n" in w[1]]

    def test_ordinary_merge_pins_head_and_preserves_dependency_branch(self):
        self.run_engine()
        self.assertEqual(len(self.merges()), 1)
        args = self.merges()[0][1]
        self.assertNotIn("--delete-branch", args)
        self.assertIn("--match-head-commit", args)
        self.assertEqual(self.state()["reads"]["fresh_prs"], 1)
        self.assertEqual(self.state()["reads"]["defaults"], 2)
        calls = self.state()["calls"]
        merge_index = next(i for i, c in enumerate(calls) if c[1][:2] == ["pr", "merge"])
        self.assertEqual([c[1][:2] for c in calls[merge_index-2:merge_index]], [["repo", "view"], ["pr", "view"]])

    def test_ready_stacked_pr_holds_without_merge_or_branch_deletion(self):
        self.pr(baseRefName="task/predecessor")
        self.assertIn("base", self.run_engine())
        self.assertEqual(self.merges(), [])

    def test_initial_missing_or_malformed_target_holds(self):
        for field, value in [("baseRefName", None), ("baseRefName", []), ("baseRefOid", None), ("baseRefOid", "invalid"), ("headRefOid", "invalid")]:
            with self.subTest(field=field, value=value):
                self.write(copy.deepcopy(self.initial))
                self.pr(**{field: value})
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_initial_default_read_failure_or_missing_holds_whole_pass(self):
        for value in ["ERROR", {}, {"defaultBranchRef": {"name": []}}]:
            with self.subTest(value=value):
                self.write(copy.deepcopy(self.initial))
                self.configure(defaults=[value])
                env = {**os.environ, "PATH": f"{self.root}:{os.environ['PATH']}", "MERGE_FIXTURE": str(self.root), "ENGINE_ROOT": str(ROOT), "GITHUB_REPOSITORY": "example/project"}
                result = subprocess.run(["bash", str(ROOT / "scripts/auto-merge.sh")], env=env, capture_output=True, text=True, timeout=30)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(self.state()["unexpected"], [])
                self.assertEqual(self.state()["writes"], [])

    def test_final_target_or_gate_change_holds(self):
        for changes in [{"headRefOid": "c" * 40}, {"baseRefName": "task/predecessor"}, {"baseRefOid": "c" * 40}, {"baseRefName": None}, {"isDraft": True}, {"labels": [{"name": "human-check:"}]}, {"reviewDecision": "CHANGES_REQUESTED"}, {"mergeable": "CONFLICTING"}, {"state": "CLOSED"}]:
            with self.subTest(changes=changes):
                self.write(copy.deepcopy(self.initial))
                self.configure(fresh_prs=[{**self.initial["pr"], **changes}])
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_final_default_change_missing_and_read_failure_hold(self):
        for value in ["ERROR", {}, {"defaultBranchRef": {"name": "trunk"}}]:
            with self.subTest(value=value):
                self.write(copy.deepcopy(self.initial))
                self.configure(defaults=[{"defaultBranchRef": {"name": "main"}}, value])
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_final_pr_read_failure_or_malformed_payload_hold(self):
        for value in ["ERROR", {}, [], {"headRefOid": HEAD, "baseRefName": "main", "baseRefOid": BASE}]:
            with self.subTest(value=value):
                self.write(copy.deepcopy(self.initial))
                self.configure(fresh_prs=[value])
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_non_main_default_is_supported(self):
        self.pr(baseRefName="trunk")
        self.configure(defaults=[{"defaultBranchRef": {"name": "trunk"}}])
        self.run_engine()
        self.assertEqual(len(self.merges()), 1)

    def test_linked_eligible_task_survives_both_reads(self):
        self.pr(body="Closes #3")
        self.run_engine()
        self.assertEqual(self.state()["reads"].get("issues"), 2)
        self.assertEqual(len(self.merges()), 1)

    def test_linked_task_changed_or_failed_on_second_read_holds(self):
        eligible = {"state": "OPEN", "title": "task: Improve a report", "body": "", "labels": []}
        for changed in ["ERROR", {}, {**eligible, "labels": [{"name": "human-check:"}]}, {**eligible, "state": "CLOSED"}]:
            with self.subTest(changed=changed):
                self.write(copy.deepcopy(self.initial))
                self.pr(body="Closes #3")
                self.configure(issues=[eligible, changed])
                self.run_engine()
                self.assertEqual(self.state()["reads"].get("issues"), 2)
                self.assertEqual(self.merges(), [])

    def test_partial_linked_task_payload_never_authorizes_either_read(self):
        eligible = {"state": "OPEN", "title": "task: Improve a report", "body": "", "labels": []}
        partials = [{"state": "OPEN"}, {**eligible, "body": None}, {**eligible, "title": []},
                    {**eligible, "labels": None}, {**eligible, "labels": [{}]},
                    {**eligible, "labels": [{"name": 7}]}]
        for read in (1, 2):
            for partial in partials:
                with self.subTest(read=read, partial=partial):
                    self.write(copy.deepcopy(self.initial))
                    self.pr(body="Closes #3")
                    self.configure(issues=([eligible] if read == 2 else []) + [partial])
                    self.run_engine()
                    self.assertEqual(self.merges(), [])

    def test_old_hold_can_resume_through_current_policy_and_checks(self):
        self.configure(files=["scripts/check.sh"], policy=[False, True])
        self.run_engine()
        self.assertEqual(len(self.comments("held")), 1)
        self.assertEqual(self.merges(), [])
        self.run_engine()
        self.assertEqual(self.state()["reads"].get("policy"), 2)
        self.assertEqual(self.state()["reads"].get("checks"), 1)
        self.assertEqual(len(self.merges()), 1)

    def test_unchanged_policy_hold_reevaluates_without_comment_spam(self):
        self.configure(files=["scripts/check.sh"], policy=[False])
        self.run_engine()
        self.run_engine()
        self.assertEqual(self.state()["reads"].get("policy"), 2)
        self.assertEqual(len(self.comments("held")), 1)
        self.assertEqual(self.merges(), [])

    def test_current_red_checks_still_hold_after_old_policy_hold(self):
        self.configure(comments=[lifecycle("held")], files=["scripts/check.sh"], policy=[True], checks=["fail"])
        self.run_engine()
        self.assertEqual(self.state()["reads"].get("policy"), 1)
        self.assertEqual(self.state()["reads"].get("checks"), 1)
        self.assertEqual(self.merges(), [])

    def test_current_labels_and_required_review_still_hold(self):
        for changes in [{"labels": [{"name": "human-check:"}]}, {"labels": [{"name": "loop:hold"}]}, {"reviewDecision": "REVIEW_REQUIRED"}, {"reviews": [{"state": "CHANGES_REQUESTED"}]}]:
            with self.subTest(changes=changes):
                self.write(copy.deepcopy(self.initial))
                self.configure(comments=[lifecycle("held")])
                self.pr(**changes)
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_unknown_and_forbidden_prefixes_are_not_expanded(self):
        for head in ["codex/report", "intent/report", "heartbeat/report"]:
            with self.subTest(head=head):
                self.write(copy.deepcopy(self.initial))
                self.pr(headRefName=head)
                self.run_engine()
                self.assertEqual(self.merges(), [])

    def test_terminal_merge_is_idempotent_on_same_head(self):
        self.run_engine()
        self.run_engine()
        self.assertEqual(len(self.merges()), 1)
        self.assertEqual(len(self.comments("merged")), 1)

    def test_merged_receipt_follows_confirmed_remote_state(self):
        self.run_engine()
        self.assertEqual(self.state()["reads"].get("outcomes"), 1)
        self.assertIn("Merge-commit: " + "d" * 40, self.comments("merged")[0][1])
        calls = self.state()["calls"]
        receipt_index = next(i for i, c in enumerate(calls) if c[1][:2] == ["pr", "comment"])
        self.assertEqual(calls[receipt_index-1][1], ["pr", "view", "7", "--json", "state,headRefOid,baseRefName,mergeCommit"])

    def test_successful_command_without_matching_readback_is_not_merged(self):
        confirmed = {"state": "MERGED", "headRefOid": HEAD, "baseRefName": "main", "mergeCommit": {"oid": "d" * 40}}
        for outcome in ["ERROR", {}, {**confirmed, "state": "OPEN"}, {**confirmed, "headRefOid": "c" * 40}, {**confirmed, "baseRefName": "task/other"}, {**confirmed, "mergeCommit": None}, {**confirmed, "mergeCommit": {"oid": ""}}]:
            with self.subTest(outcome=outcome):
                self.write(copy.deepcopy(self.initial))
                self.configure(outcomes=[outcome])
                output = self.run_engine()
                self.assertEqual(len(self.merges()), 1)
                self.assertEqual(self.comments("merged"), [])
                self.assertNotIn("\tmerged\t", output)
                self.assertIn("unconfirmed", output)

    def test_rebase_request_is_deduplicated_and_then_resumes(self):
        self.pr(mergeable="CONFLICTING")
        self.run_engine()
        self.run_engine()
        self.assertEqual(len(self.comments("rebase-requested")), 1)
        self.pr(mergeable="MERGEABLE")
        self.run_engine()
        self.assertEqual(len(self.merges()), 1)

    def test_actions_are_deduplicated_separately(self):
        self.configure(comments=[lifecycle("held")])
        self.pr(mergeable="CONFLICTING")
        self.run_engine()
        self.assertEqual(len(self.comments("rebase-requested")), 1)

    def test_unreadable_and_malformed_comments_hold(self):
        for comments in ["ERROR", {}, [None], [{"body": None}], [{"body": f"{MARKER}\nHead: {HEAD}"}], [lifecycle("unexpected")], [{"body": f"{MARKER}\nAction: held\nAction: merged\nHead: {HEAD}"}]]:
            with self.subTest(comments=comments):
                self.write(copy.deepcopy(self.initial))
                self.configure(comment_reads=[comments])
                self.run_engine()
                self.assertEqual(self.state()["writes"], [])

    def test_unrelated_comment_does_not_authorize_or_block(self):
        self.configure(comments=[{"body": "Please check the examples."}])
        self.run_engine()
        self.assertEqual(len(self.merges()), 1)

    def test_dry_run_has_no_writes(self):
        self.assertIn("would merge-merge", self.run_engine(dry=True))
        self.assertEqual(self.state()["writes"], [])

    def test_engine_body_matches_policy_pin(self):
        source = (ROOT / "scripts/auto-merge.sh").read_bytes()
        body = source.split(b"# janus:merge-config:end\n", 1)[1]
        expected = next(line.split(": ", 1)[1] for line in (ROOT / "docs/MERGE-POLICY.md").read_text().splitlines() if line.startswith("Engine-sha256: "))
        self.assertEqual(hashlib.sha256(body).hexdigest(), expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
