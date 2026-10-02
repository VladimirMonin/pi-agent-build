import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

// VM-boundary fixture, NOT the restricted-token/native runner.
// No Pi/SDK/provider imports. Input is a host-created read-only Sandbox mapping.
const runtime = process.env.VM_DUMMY_RUNTIME;
const canary = process.env.VM_DUMMY_CANARY;
const role = process.argv[2] === 'descendant' ? 'descendant' : 'root';
if (!runtime || !canary || process.platform !== 'win32') throw new Error('Windows VM fixture paths required');
const receipt = {
  role, pid: process.pid, ppid: process.ppid, version: process.version,
  execPath: process.execPath, modulePath: fileURLToPath(import.meta.url), cwd: process.cwd(),
  environment: Object.fromEntries(Object.entries(process.env).sort(([a], [b]) => a.localeCompare(b))),
  attempts: [], naturalExit: false,
};
fs.writeFileSync(path.join(runtime, `startup-${role}.json`), JSON.stringify(receipt), {flag: 'wx'});
try {
  const start = Date.now();
  while (!fs.existsSync(path.join(runtime, `verified-${process.pid}`))) {
    if (Date.now() - start > 15000) throw new Error('VM process inspection timed out');
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  for (const [target, allowed, options] of [
    [path.join(runtime, `${role}-allowed.txt`), true, {flag: 'wx'}],
    [path.join(canary, `${role}-must-not-exist.txt`), false, {flag: 'wx'}],
    [path.join(canary, 'working-memory-shaped.txt'), false, {}],
  ]) {
    const attempt = {target, expectedAllowed: allowed, allowed: false};
    try { fs.writeFileSync(target, 'synthetic VM fixture output\n', options); attempt.allowed = true; }
    catch (error) { attempt.error = {code: error.code, errno: error.errno, syscall: error.syscall, message: error.message}; }
    receipt.attempts.push(attempt);
    if (attempt.allowed !== allowed || (!allowed && !['EACCES', 'EPERM'].includes(attempt.error?.code))) {
      throw new Error(`Unexpected VM canary result: ${JSON.stringify(attempt)}`);
    }
  }
  if (role === 'root') {
    const fds = [];
    receipt.childStdio = {stdin: 'ignore', openedFds: fds, closedFds: []};
    try {
      fds.push(fs.openSync(path.join(runtime, 'descendant-stdout.txt'), 'wx'));
      fds.push(fs.openSync(path.join(runtime, 'descendant-stderr.txt'), 'wx'));
      const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'descendant'], {
        cwd: runtime, env: process.env, stdio: ['ignore', fds[0], fds[1]], windowsHide: true,
      });
      receipt.childPid = child.pid;
      receipt.childExit = await new Promise((resolve, reject) => {
        child.once('error', reject);
        child.once('exit', (code, signal) => resolve({code, signal}));
      });
      if (receipt.childExit.code !== 0 || receipt.childExit.signal !== null) throw new Error('Descendant did not exit naturally with zero');
    } finally {
      const errors = [];
      for (const fd of fds) {
        try { fs.closeSync(fd); receipt.childStdio.closedFds.push(fd); }
        catch (error) { errors.push(error); }
      }
      if (errors.length) throw new AggregateError(errors, 'Private VM stdio cleanup failed');
    }
  }
  receipt.naturalExit = true;
} catch (error) {
  receipt.failure = {message: error.message, stack: error.stack};
  process.exitCode = 1;
} finally {
  fs.writeFileSync(path.join(runtime, `${role}-receipt.json`), JSON.stringify(receipt, null, 2), {flag: 'wx'});
}
// The owning guest driver must verify the actual root exit and VM cleanup.
// Never force process.exit()/unref() or claim token/MIC/Job enforcement here.
