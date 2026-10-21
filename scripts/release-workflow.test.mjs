import assert from 'node:assert/strict';
import fs from 'node:fs';
import { test } from 'node:test';

const workflow = fs.readFileSync(new URL('../.github/workflows/android-release.yml', import.meta.url), 'utf8');

test('Android publication uploads the APK, checksum and source metadata to Releases', () => {
  assert.match(workflow, /flutter build apk --release/);
  assert.match(workflow, /sha256sum release\/Campulse-latest\.apk/);
  assert.match(workflow, /sourceCommit.*GITHUB_SHA/);
  assert.match(workflow, /gh release upload campulse-preview release\/Campulse-latest\.apk release\/Campulse-latest\.apk\.sha256 release\/Campulse-latest\.json --clobber/);
});

test('Android publication finishes without committing generated binaries back to main', () => {
  assert.doesNotMatch(workflow, /\bgit\s+(?:add|commit|push|rebase)\b/);
  const ignore = fs.readFileSync(new URL('../.gitignore', import.meta.url), 'utf8');
  assert.match(ignore, /^release\/\*\.apk$/m);
  assert.match(ignore, /^release\/Campulse-latest\.json$/m);
});
