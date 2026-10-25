"""Focused canonical migration, mode and timer regression checks."""
import importlib.util
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

s = load('search_patch', ROOT / 'patches/session-search-profile/apply.py')
m = load('memory_patch', ROOT / 'patches/memory-windows-runtime/apply.py')

class RuntimeTests(unittest.TestCase):
    def test_memory_upgrade_and_refusal(self):
        stock = m.BACKUP.read_bytes()
        self.assertEqual(m.digest(stock), m.EXPECTED_STOCK_SHA256)
        new = m.build_canonical(stock)
        self.assertEqual(m.classify(stock, stock, new), 'stock-pristine')
        self.assertEqual(m.classify(new, stock, new), 'runtime-safe')
        self.assertEqual(m.classify(new + b'\n// unknown', stock, new), 'noncanonical-drift')
        with tempfile.TemporaryDirectory() as td:
            agent = Path(td)
            target = agent / 'npm/node_modules/@samfp/pi-memory/dist/index.js'
            target.parent.mkdir(parents=True)
            (target.parent.parent / 'package.json').write_text('{"version":"1.6.1"}')
            target.write_bytes(stock)
            command = ['python', str(ROOT / 'patches/memory-windows-runtime/apply.py'), '--agent-dir', str(agent)]
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(target.read_bytes(), new)
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(target.read_bytes(), new)
            self.assertEqual(subprocess.run(command + ['--check'], capture_output=True).returncode, 0)
            subprocess.run(command + ['--restore'], check=True, capture_output=True)
            self.assertEqual(target.read_bytes(), stock)
            self.assertEqual(subprocess.run(command + ['--check'], capture_output=True).returncode, 1)
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(target.read_bytes(), new)
            drift = new + b'\n// unknown'
            target.write_bytes(drift)
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)
            self.assertEqual(target.read_bytes(), drift)

    def test_search_modes_upgrade_restore_refusal(self):
        for runtime in (False, True):
            stock, canonical = s.canonical_files(runtime)
            if runtime:
                # Code's complete path selection stays stock; changed load/save
                # semantics have separate behavioral coverage.
                def paths(body):
                    text = body.decode()
                    return text[text.index('function globalConfigDir'):text.index('// ─── Load / Save')]
                self.assertEqual(paths(canonical[s.REL_FILES[0]]), paths(stock[s.REL_FILES[0]]))
                self.assertIn(b'PI_CODING_AGENT_SESSION_DIR', canonical[s.REL_FILES[1]])
                self.assertIn(b'relative(canonicalRoot, resolvedPath)', canonical[s.REL_FILES[2]])
            else:
                self.assertIn(b'PI_CODING_AGENT_DIR', canonical[s.REL_FILES[0]])
            with tempfile.TemporaryDirectory() as td:
                root = Path(td)
                s.configure_paths(root)
                for rel, body in stock.items():
                    (root / rel).parent.mkdir(parents=True, exist_ok=True)
                    (root / rel).write_bytes(body)
                s.apply(root, runtime)
                self.assertEqual(s.read_files(root), canonical)
                s.apply(root, runtime)
                self.assertEqual(s.read_files(root), canonical)
                self.assertEqual(s.classify(root, not runtime)[0], 'unknown')
                drift = canonical[s.REL_FILES[2]] + b'\n// unknown'
                (root / s.REL_FILES[2]).write_bytes(drift)
                for action in (s.apply, s.restore):
                    with self.assertRaises(RuntimeError):
                        action(root, runtime)
                    self.assertEqual((root / s.REL_FILES[2]).read_bytes(), drift)
                (root / s.REL_FILES[2]).write_bytes(canonical[s.REL_FILES[2]])
                s.restore(root, runtime)
                self.assertEqual(s.read_files(root), stock)

    def test_exact_historical_transitions_and_backups(self):
        # Fingerprints retained before this repair, in REL_FILES order. A marker
        # or a freshly regenerated "previous" alone cannot validate old bytes.
        expected = {
            False: {'published': 'e609de573f69a7b74fac1b1c4ae3c405085a4c25a175853fa3bccf18254bcdbf',
                    'previous': '2af764d247ad59e83b58addeee26c10e2207d9fe76b11152d5ad4c64140805b2',
                    'released': '7a03ba46925a00030c342235051d9cf22ec5b5d2df14360780ee59f3e3e557ea',
                    'build3': '01517f8f424605a5f8b7d40bc0cff4633ae73e049e9775eb24ab7c127775f1fa'},
            True: {'published': '098c746f0802e8e2d2723d9a7c71be1fc82cd6c93d5ab06868586144b50d332a',
                   'previous': 'a9f642673f17a9d3c9a57544ee1f86990500b50d18d1b178bcea89dad326c5d9',
                   'released': 'b9e9c903709bc7ceff7800f81ba6c87e317c94d764b43ea1202b3ee02bc4d5fc',
                   'build3': 'b0673ece7f61c833e062ab6b3b614d3fcbdf02d014e7436f35f186b3bcab2bb2'},
        }
        for mode in (False, True):
            for revision in ('published', 'previous', 'released', 'build3'):
                with self.subTest(mode=mode, revision=revision), tempfile.TemporaryDirectory() as td:
                    stock, historical = s.canonical_files(mode, **{revision: True})
                    _, current = s.canonical_files(mode)
                    # Original nine-file fingerprints stay frozen. The newly
                    # guarded embedder was untouched in all those exact releases.
                    fingerprint_files = s.REL_FILES if revision == 'build3' else s.REL_FILES[:-1]
                    self.assertEqual(hashlib.sha256(b''.join(historical[r] for r in fingerprint_files)).hexdigest(), expected[mode][revision])
                    if revision != 'build3':
                        self.assertEqual(historical[Path('src/embedder.ts')], stock[Path('src/embedder.ts')])
                    root = Path(td)
                    (root / 'package.json').write_text('{"version":"1.6.0"}')
                    for rel, body in historical.items():
                        (root / rel).parent.mkdir(parents=True, exist_ok=True)
                        (root / rel).write_bytes(body)
                    s.configure_paths(root)
                    self.assertEqual(s.classify(root, mode)[0], revision + '-patched')
                    s.apply(root, mode)
                    self.assertEqual(s.read_files(root), current)
                    receipts = list(s.BACKUP_ROOT.glob('*/receipt.json'))
                    self.assertEqual(len(receipts), 1)
                    receipt = json.loads(receipts[0].read_text())
                    self.assertEqual(receipt['state'], revision + '-patched')
                    for rel, body in historical.items():
                        self.assertEqual((receipts[0].parent / rel).read_bytes(), body)
                        self.assertEqual(receipt['sha256'][rel.as_posix()], hashlib.sha256(body).hexdigest())
                    s.apply(root, mode)
                    self.assertEqual(len(list(s.BACKUP_ROOT.glob('*/receipt.json'))), 1)
                    self.assertEqual(s.read_files(root), current)
                    s.restore(root, mode)
                    self.assertEqual(s.read_files(root), stock)
                    # Mixed main/worker is unknown even if every file is from
                    # a recognized state; refusal must not make a backup/write.
                    (root / 'dist/index-worker.js').write_bytes(current[Path('dist/index-worker.js')])
                    before = s.read_files(root)
                    count = len(list(s.BACKUP_ROOT.glob('*/receipt.json')))
                    self.assertEqual(s.classify(root, mode)[0], 'unknown')
                    for action in (s.apply, s.restore):
                        with self.assertRaises(RuntimeError): action(root, mode)
                        self.assertEqual(s.read_files(root), before)
                    self.assertEqual(len(list(s.BACKUP_ROOT.glob('*/receipt.json'))), count)
                    (root / 'package.json').write_text('{"version":"1.6.1"}')
                    with self.assertRaises(RuntimeError): s.assert_version(root)

    def test_real_timer_settlement(self):
        # Execute the exact generated production bodies, with real timers and
        # tracking wrappers to assert cleanup on both settlement branches.
        script = '''const assert = require('node:assert/strict');
const nativeSet = setTimeout, nativeClear = clearTimeout, live = new Set();
global.setTimeout = (fn, ms) => { const h = nativeSet(() => {live.delete(h); fn();}, ms); live.add(h); return h; };
global.clearTimeout = h => {live.delete(h); nativeClear(h);};
const pendingTimers = new Set();
function scheduleTimer(fn, ms) {const h = setTimeout(() => {pendingTimers.delete(h); fn();}, ms); pendingTimers.add(h); return h;}
let operation; const index = {sync: () => operation};
const ctx = {ui:{setStatus(){}}}; const notifySyncError = () => () => {};
const SYNC_TIMEOUT_MS = 20;
SEARCH
(async () => {
 const error = new Error('reject');
 operation = Promise.resolve(9); assert.equal(await runSync(),9);
 assert.equal(live.size,0); assert.equal(pendingTimers.size,0);
 operation = Promise.reject(error); await assert.rejects(runSync(), e => e === error);
 assert.equal(live.size,0); assert.equal(pendingTimers.size,0);
 operation = new Promise(() => {}); assert.equal(await runSync(),null);
 assert.equal(live.size,0); assert.equal(pendingTimers.size,0);
 console.log('resolve/reject/real timeout: production sync timer clean');
})().catch(e => {console.error(e);process.exitCode=1;});'''
        script = script.replace('SEARCH', s.TIMER_NEW)
        subprocess.run(['node', '-e', script], check=True, timeout=5)

if __name__ == '__main__':
    unittest.main()
