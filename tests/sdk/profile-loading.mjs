import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';

// Run only against a synthetic profile in a private HOME. No model or session.
const [sdkRoot, profileRoot] = process.argv.slice(2);
assert(sdkRoot && profileRoot, 'Explicit SDK and synthetic profile paths required');
assert(!path.resolve(profileRoot).replaceAll('\\', '/').includes('/.pi/'), 'Do not use a working user profile as a fixture');
const settings = JSON.parse(fs.readFileSync(path.join(profileRoot, 'settings.json'), 'utf8'));
assert(settings.extensions?.includes('-builtin:mcp'), 'Retained adapter must explicitly disable builtin:mcp');
let fetchAttempts = 0;
const originalFetch = globalThis.fetch;
globalThis.fetch = () => { fetchAttempts++; throw Error('Network forbidden in profile loading test'); };
try {
  const sdk = await import(pathToFileURL(path.join(sdkRoot, 'dist/index.js')).href);
  const loader = new sdk.DefaultResourceLoader({cwd: process.cwd(), agentDir: profileRoot,
    settingsManager: sdk.SettingsManager.inMemory(settings), noSkills: true,
    noPromptTemplates: true, noThemes: true, noContextFiles: true});
  await loader.reload();
  const result = loader.getExtensions();
  assert.deepEqual(result.errors, [], 'Extension loading errors');
  assert.deepEqual(result.warnings ?? [], [], 'Extension package/startup warnings');
  assert(!result.extensions.some(e => e.path.includes('pi-trace-extension')), 'Trace must remain default-off');
  assert.equal(fetchAttempts, 0);
  console.log(JSON.stringify({status: 'PASS', scope: 'SYNTHETIC_PROFILE_LOADING_NOT_LIVE_PROVIDER_OR_TUI',
    extensions: result.extensions.length, warnings: 0, errors: 0, fetchAttempts}));
} finally { globalThis.fetch = originalFetch; }
