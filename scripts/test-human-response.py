#!/usr/bin/env python3
"""Exercise producer guards through their executable entry points."""
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = (ROOT / 'scripts/fixtures/human-response-write-outcome.md').read_text()


class HumanResponse(unittest.TestCase):
    def run_body(self, body, script='check-record.sh', args=()):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'body.md'
            path.write_text(body)
            command = [str(ROOT / 'scripts' / script), str(path), *args]
            if script == 'check-ready.sh':
                command = [str(ROOT / 'scripts' / script), '--body', str(path), 'task:']
            return subprocess.run(command, text=True, capture_output=True)

    def test_writing_request_is_valid_but_not_review_or_worker_work(self):
        self.assertEqual(self.run_body(FIXTURE).returncode, 0)
        result = self.run_body(FIXTURE, args=('--ready-for-review',))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('writing request is not a delivered result review', result.stdout)
        if (ROOT / 'scripts/check-ready.sh').exists():
            self.assertNotEqual(self.run_body(FIXTURE, 'check-ready.sh').returncode, 0)

    def test_explicit_target_does_not_follow_parent(self):
        body = FIXTURE.replace('goal/325', 'goal/900').replace('#262', '#901')
        self.assertEqual(self.run_body(body).returncode, 0)
        result = subprocess.run(['python3', str(ROOT / 'scripts/human-response.py'), str(ROOT / 'scripts/fixtures/human-response-write-outcome.md')], capture_output=True, text=True)
        self.assertEqual(result.stdout.strip(), 'write-outcome')

    def test_invalid_and_ambiguous_declarations_are_rejected(self):
        for old, new in [('Target: Vinylfigure/overlord#184', 'Target: #184'), ('Max characters: 220', 'Max characters: 221'), ('Field: Outcome', 'Field: Body'), ('Completion: saved-outcome', 'Completion: accepted-result'), ('Type: write-outcome', 'Type: review'), ('Repair marker: yes', 'Repair marker: no'), ('Type: write-outcome', 'Type: write-outcome\nType: write-outcome')]:
            with self.subTest(new=new):
                self.assertNotEqual(self.run_body(FIXTURE.replace(old, new)).returncode, 0)
        duplicated = FIXTURE.replace('### Parent goal', '### Human response\nType: write-outcome\n\n### Parent goal')
        self.assertNotEqual(self.run_body(duplicated).returncode, 0)

    def test_quoted_or_empty_declarations_cannot_create_an_action(self):
        base = '### In plain words\nThe app opens quickly.\n\n### Done means\nOpens in two seconds.\n'
        response = '### Human response\nType: write-outcome\nTarget: invalid'
        for suffix in ['\n### Human response\n_No response_\n', '\n```md\n' + response + '\n```\n', '\n### Context\n' + response]:
            self.assertEqual(self.run_body(base + suffix).returncode, 0)
            if (ROOT / 'scripts/check-ready.sh').exists():
                self.assertEqual(self.run_body(base + suffix, 'check-ready.sh').returncode, 0)

    def test_malformed_writing_declaration_stays_human_owned(self):
        if not (ROOT / 'scripts/check-ready.sh').exists():
            self.skipTest('consumer uses its native worker gate')
        body = FIXTURE.replace('Target: Vinylfigure/overlord#184', 'Target: invalid')
        self.assertNotEqual(self.run_body(body, 'check-ready.sh').returncode, 0)


if __name__ == '__main__':
    unittest.main()
