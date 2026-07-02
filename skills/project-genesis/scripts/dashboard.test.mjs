// dashboard.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { parseProgress } from './dashboard.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const sample = readFileSync(join(here, 'fixtures/PROGRESS.sample.md'), 'utf8');

test('parseProgress: status section', () => {
  const p = parseProgress(sample);
  assert.equal(p.status.blocker, 'M-1.T3');
  assert.match(p.status.nextAction, /M-1\.T3/);
  assert.match(p.status.latestHandoff, /\.md$/);
});

test('parseProgress: rollup rows', () => {
  const p = parseProgress(sample);
  const m1 = p.rollup.find(r => r.id === 'M-1');
  assert.equal(m1.status, 'doing');
  assert.equal(m1.total, 7);
  assert.ok(m1.done >= 1);
});

test('parseProgress: task tables per milestone', () => {
  const p = parseProgress(sample);
  assert.ok(Array.isArray(p.tasks['M-1']));
  const blocked = p.tasks['M-1'].find(t => t.status === 'blocked');
  assert.ok(blocked, 'expected a blocked task in M-1');
  assert.match(blocked.id, /^M-1\.T\d+$/);
});
