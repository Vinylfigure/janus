import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { machineryPath } from './effect-policy.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const run = (script, args, options = {}) => spawnSync('/bin/bash', [join(root, 'scripts', script), ...args], { encoding: 'utf8', ...options });
const fixture = t => {
  const dir = mkdtempSync(join(tmpdir(), 'janus-codex-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
};

test('generated Codex entry preserves canonical rules and detects adapter drift', t => {
  const dir = fixture(t), src = join(dir, 'CLAUDE.md'), out = join(dir, 'AGENTS.md');
  const canonical = '# Fixture\n\n- Keep this rule byte-for-byte.\n';
  writeFileSync(src, canonical);
  assert.equal(run('generate-agents-md.sh', [src, out]).status, 0);
  const generated = readFileSync(out, 'utf8');
  assert.ok(generated.endsWith(canonical));
  assert.match(generated, /\.agents\/skills\/janus-workflow\/SKILL\.md/);
  assert.equal(run('generate-agents-md.sh', ['--check', src, out]).status, 0);
  writeFileSync(out, generated.replace('Codex: read', 'Codex: skip'));
  assert.equal(run('generate-agents-md.sh', ['--check', src, out]).status, 2);
});

test('adapter references shipped shared procedures without copying them', () => {
  const skill = readFileSync(join(root, '.agents/skills/janus-workflow/SKILL.md'), 'utf8');
  assert.match(skill, /^---\nname: janus-workflow\ndescription: .+\n---\n/);
  const refs = [...skill.matchAll(/`(\.claude\/[^`]+\.md)`/g)].map(match => match[1]);
  assert.ok(refs.length >= 7);
  for (const path of refs) assert.ok(readFileSync(join(root, path), 'utf8').length > 0, path);
});

test('unchecked application files report scaffold-only scope', t => {
  const path = join(fixture(t), 'broken.py');
  writeFileSync(path, 'this is not valid python !!!!');
  const result = run('verify.sh', ['quick', path]);
  assert.equal(result.status, 0); // It remains a scaffold dispatcher, not a Python checker.
  assert.match(result.stdout, /scaffold-only; no project check configured/);
});

test('missing JSON validator fails closed instead of reporting green', t => {
  const dir = fixture(t), path = join(dir, 'file.json');
  writeFileSync(path, '{}');
  const result = run('verify.sh', ['quick', path], { env: { ...process.env, PATH: dir } });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /jq is required.*no check ran/);
});

test('native fallback CLI preflight accepts verified defaults and holds unsupported or unreadable evidence', t => {
  const dir=fixture(t), path=join(dir,'fallbacks.json');
  const check=()=>spawnSync(process.execPath,[join(root,'scripts/effect-policy-cli.mjs'),`--codex-fallbacks=${path}`],{encoding:'utf8'});
  for(const [data,status] of [['[]',0],['["TEAM_GUIDE.md"]',1],['null',1],['{}',1],['not JSON',1]]) {
    writeFileSync(path,data);const result=check();assert.equal(result.status,status,data);
    assert.notEqual(JSON.parse(result.stdout).supported,status===1?true:false);
  }
  rmSync(path);assert.equal(check().status,1);
});

const lesson = (id, title) => `## ${id} · 2026-10-01 · ${title}\n- Scope: portable\n- Evidence: 2\n- Status: candidate\n`;
test('harvest recognizes shared titles across legacy and dated learning IDs', t => {
  const dir = fixture(t), own = join(dir, 'own.md'), child = join(dir, 'child.md');
  for (const [ownId, childId] of [['L-001', 'L-20261001-child-rule'], ['L-20261001-own-rule', 'L-002'], ['L-20261001-own-rule', 'L-20261001-child-rule']]) {
    writeFileSync(own, lesson(ownId, 'Shared rule both repos hold'));
    writeFileSync(child, lesson(childId, 'Shared rule both repos hold'));
    const result = run('harvest-ledgers.sh', [own, child]);
    assert.equal(result.status, 0);
    assert.equal(result.stdout, '', `${ownId} versus ${childId}`);
  }
});

test('harvest preserves full dated ID, title and evidence for a new candidate', t => {
  const dir = fixture(t), own = join(dir, 'own.md'), child = join(dir, 'child.md');
  writeFileSync(own, lesson('L-001', 'Existing rule'));
  writeFileSync(child, lesson('L-20261001-new-rule', '123 checks before completion'));
  const result = run('harvest-ledgers.sh', [own, child]);
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${child}\tL-20261001-new-rule\t123 checks before completion\t2\n`);
});

test('candidate payload resolves shared procedures inside one additive native skill', t => {
  assert.ok(machineryPath('.agents/skills/janus-workflow/adoption/candidate.json'));
  assert.ok(machineryPath('.agents/skills/janus-workflow/adoption/PROJECT.md'));
  const manifest = JSON.parse(readFileSync(join(root, '.agents/skills/janus-workflow/adoption/candidate.json'), 'utf8'));
  assert.equal(manifest.status, 'candidate');
  const targetRoot = fixture(t);
  const existing = {
    'AGENTS.md': '# Existing instructions\nKeep the project aggregate.\n',
    'CLAUDE.md': '# Existing Claude instructions\n',
    'docs/LEARNINGS.md': '## L-001\nExisting project evidence must survive.\n',
    '.agents/skills/project/SKILL.md': '---\nname: project\ndescription: Existing workflow\n---\n'
  };
  for (const [path, bytes] of Object.entries(existing)) {
    mkdirSync(dirname(join(targetRoot, path)), { recursive: true });
    writeFileSync(join(targetRoot, path), bytes);
  }
  const destinations = new Set();
  for (const { source, target } of manifest.files) {
    assert.match(target, /^\.agents\/skills\/janus-workflow\/(?:SKILL\.md|PROJECT\.md|references\/[a-z-]+\.md)$/);
    assert.ok(!source.split('/').includes('..'));
    assert.ok(!/settings|hooks|workflows|LEARNINGS|sources-seen/.test(source));
    assert.ok(!destinations.has(target), `duplicate destination: ${target}`);
    destinations.add(target);
    mkdirSync(dirname(join(targetRoot, target)), { recursive: true });
    writeFileSync(join(targetRoot, target), readFileSync(join(root, source)));
  }
  for (const [path, bytes] of Object.entries(existing)) {
    assert.equal(readFileSync(join(targetRoot, path), 'utf8'), bytes);
  }
  const skill = readFileSync(join(targetRoot, '.agents/skills/janus-workflow/SKILL.md'), 'utf8');
  const references = [...skill.matchAll(/`references\/([a-z-]+\.md)`/g)].map(match => match[1]);
  assert.equal(references.length, 7);
  for (const name of references) {
    assert.ok(readFileSync(join(targetRoot, '.agents/skills/janus-workflow/references', name), 'utf8').length);
  }
  assert.match(readFileSync(join(targetRoot, '.agents/skills/janus-workflow/PROJECT.md'), 'utf8'), /UNSET/);
  assert.match(skill, /Unfilled fields, missing files or unresolved conflicts\nmean UNVERIFIED/);
});
