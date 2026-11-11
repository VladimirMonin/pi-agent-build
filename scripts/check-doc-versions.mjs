#!/usr/bin/env node
// Version-drift gate: living docs must state the version pinned in
// manifests/runtime.lock.json as the current build. Historical mentions are
// allowed; only the "current" anchors are checked. Wired into verify.
// Exit: 0 consistent, 2 drift found (each line: file: problem), usage 2 too.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.argv[2] ?? process.cwd();
const read = (rel) => readFileSync(join(repoRoot, rel), 'utf8');
const lock = JSON.parse(read('manifests/runtime.lock.json'));
const piVersion = lock.runtime.pi.version;
const problems = [];
const check = (ok, file, problem) => { if (!ok) problems.push(`${file}: ${problem}`); };

// README.md: exactly one "current build" anchor and it must name piVersion.
{
  const file = 'README.md';
  const text = read(file);
  const anchors = [...text.matchAll(/\*\*Текущая сборка: \[Pi (\S+) /g)].map((m) => m[1]);
  check(anchors.length === 1, file, `expected exactly one "Текущая сборка" anchor, found ${anchors.length}`);
  check(anchors.every((v) => v === piVersion), file, `current build names ${anchors.join(', ')}, runtime lock pins ${piVersion}`);
}

// docs/setup.md: the current revision line must name piVersion.
{
  const file = 'docs/setup.md';
  const text = read(file);
  const anchors = [...text.matchAll(/Текущая ревизия — \[Pi (\S+) /g)].map((m) => m[1]);
  check(anchors.length === 1, file, `expected exactly one "Текущая ревизия" line, found ${anchors.length}`);
  check(anchors.every((v) => v === piVersion), file, `current revision names ${anchors.join(', ')}, runtime lock pins ${piVersion}`);
}

// docs/plans/lab-readiness-board.md: the first "current build" section wins.
{
  const file = 'docs/plans/lab-readiness-board.md';
  const text = read(file);
  const first = /## Текущая сборка Pi (\S+)/.exec(text);
  check(first !== null, file, 'no "## Текущая сборка Pi ..." section');
  if (first) {
    check(first[1] === piVersion, file, `first current section is ${first[1]}, runtime lock pins ${piVersion}`);
  }
}

// CHANGELOG.md: the top entry must be a pi-v<piVersion>-build.* tag and its
// release note must exist.
{
  const file = 'CHANGELOG.md';
  const text = read(file);
  const first = /## \[(pi-v\S+)\]/.exec(text);
  check(first !== null, file, 'no release entry found');
  if (first) {
    const tag = first[1];
    check(tag.startsWith(`pi-v${piVersion}-build.`), file, `top entry is ${tag}, runtime lock pins ${piVersion}`);
    const noteName = tag.replace(/^pi-v/, 'pi-');
    check(existsSync(join(repoRoot, `docs/releases/${noteName}.md`)), file, `release note docs/releases/${noteName}.md missing`);
  }
}

// Profile templates: lastChangelogVersion equals the pinned Pi version.
for (const template of ['profiles/code/settings.template.json', 'profiles/task/settings.template.json']) {
  const settings = JSON.parse(read(template));
  check(settings.lastChangelogVersion === piVersion, template,
    `lastChangelogVersion is ${settings.lastChangelogVersion}, runtime lock pins ${piVersion}`);
}

if (problems.length) {
  for (const problem of problems) console.error(`FAIL doc version drift — ${problem}`);
  process.exit(2);
}
console.log(`OK doc versions consistent with runtime lock (Pi ${piVersion})`);
