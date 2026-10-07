"""Focused canonical migration, mode and timer regression checks."""
import importlib.util
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
            (target.parent.parent / 'package.json').write_text('{"version":"1.6.0"}')
            target.write_bytes(stock)
            command = ['python', str(ROOT / 'patches/memory-windows-runtime/apply.py'), '--agent-dir', str(agent)]
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(target.read_bytes(), new)
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
                self.assertEqual(canonical[s.REL_FILES[0]], stock[s.REL_FILES[0]])
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
